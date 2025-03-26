// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import "forge-std/console.sol";
import {BaseProxy} from "./BaseProxy.sol";
import {Committee, ICommitteeRegistry} from "./interfaces/ICommitteeRegistry.sol";
import {BtcTransaction, BtcTxOut, IBitcoinManager} from "./interfaces/IBitcoinManager.sol";
import {
    PegInRequestTxSPVProof,
    PegInAcceptedTxSPVProof,
    StreamPosition,
    PegInTempInfo,
    PrevoutData,
    IPegManager
} from "./interfaces/IPegManager.sol";
import {Slot, Stream, Packet, SlotState, StreamManager} from "./StreamManager.sol";
import {ProofValidator} from "./ProofValidator.sol";
import {BtcHelper} from "./libraries/BtcHelper.sol";
import {BtcScriptParser} from "./libraries/BtcScriptParser.sol";
import {BtcTaprootParser} from "./libraries/BtcTaprootParser.sol";
import {OpCodes} from "./libraries/OpCodes.sol";

/// @title PegManager
/// @notice Manages peg-in and peg-out operations between Bitcoin and Rootstock
contract PegManager is IPegManager, StreamManager, ProofValidator, BaseProxy {
    ICommitteeRegistry public committeeRegistry;
    IBitcoinManager public bitcoinManager;
    uint64 constant VOUT_INDEX = 0;
    // Bitcoin txHash => Position in the Stream / Packet
    mapping(bytes32 => StreamPosition) internal pegInRequests;
    // Bitcoin txHash => TempInfo
    mapping(bytes32 => PegInTempInfo) internal pegInsTempInfo;
    // key = keccak256(abi.encodePacked(_bitcoinUserAddress, _amount))
    mapping(bytes32 key => bytes32 pegOutTxHash) internal pegOutTxHashes;

    function initialize(
        address _initialOwner,
        address payable _bridgeAddress,
        ICommitteeRegistry _committeeRegistry,
        IBitcoinManager _bitcoinManager,
        uint64[] memory _denominations
    ) public virtual initializer {
        committeeRegistry = _committeeRegistry;
        bitcoinManager = _bitcoinManager;
        StreamManager.initialize(_denominations);
        __ProofValidator_init(_bridgeAddress);
        __BaseProxy_init(_initialOwner);
    }

    function getTemporaryPegInAddress(address _rootstockDepositAddress, uint64 _value, bytes32 _btcReimbursementPubKey)
        external
        view
        returns (string memory bitcoinDepositAddress)
    {
        // Get the stream for this value
        Stream memory stream = getStream(_value);

        // Get the current packet's committee key
        Packet memory currentPacket = packets[stream.streamId][stream.peginPointer];
        bytes32 committeeKey = currentPacket.committeePubKey;

        return bitcoinManager.getTemporaryPegInAddress(
            _rootstockDepositAddress, _value, _btcReimbursementPubKey, committeeKey
        );
    }

    function getPegInRequest(bytes32 btcTxHash) external view returns (StreamPosition memory) {
        return pegInRequests[btcTxHash];
    }

    function registerPegInRequest(PegInRequestTxSPVProof calldata _pegInRequestTxSPVProof) external {
        // TODO validate who can call this function

        // Calculate txHash from BtcTransaction
        bytes32 txHash = bitcoinManager.getBtcTxHash(_pegInRequestTxSPVProof.btcTx);
        if (pegInRequests[txHash].registered) {
            revert AlreadyRegisteredPegIn(txHash);
        }

        // Validate transaction has at least 2 outputs
        bitcoinManager.validatePegInTx(_pegInRequestTxSPVProof.btcTx);

        // Second transaction should be OP_RETURN with data
        (uint64 packetNumber, address rskDestinationAddress, bytes32 btcReimbursementPubKey) =
            bitcoinManager.getPegInOpReturnData(_pegInRequestTxSPVProof.btcTx.outputs[VOUT_INDEX + 1]);

        // First transaction is the PegIn P2TR _pegInRequestTxSPVProof.btcTx.outputs[0]
        // Get corresponding stream for the amount if non found reverts
        Stream memory stream = getStream(_pegInRequestTxSPVProof.btcTx.outputs[VOUT_INDEX].amount);

        // Validates that the Taproot Script has a Key Path for the committeePubKey
        // and has a timelock for btcReimbursementPubKey
        bitcoinManager.validatePegInP2TRData(
            rskDestinationAddress,
            stream.denomination,
            btcReimbursementPubKey,
            // getPacket reverts if packet does not exist
            getPacket(stream.streamId, packetNumber).committeePubKey,
            _pegInRequestTxSPVProof.btcTx.outputs[VOUT_INDEX]
        );

        // Verify the txHash part of the Merkle Root of Tx of a Block
        // and that block is inside Bitcoin Mainchain
        // annd has enough confirmations
        verifyTxConfirmations(
            stream.pegInConfirmations,
            txHash,
            _pegInRequestTxSPVProof.blockHash,
            _pegInRequestTxSPVProof.merkleBranchPath,
            _pegInRequestTxSPVProof.merkleBranchHashes
        );

        // Store pegInRequest to avoid processing it again
        pegInRequests[txHash] =
            StreamPosition({streamId: stream.streamId, packetNumber: packetNumber, registered: true});

        pegInsTempInfo[txHash] = PegInTempInfo({
            value: stream.denomination,
            rskDestinationAddress: rskDestinationAddress,
            btcReimbursementPubKey: btcReimbursementPubKey,
            utxoScriptPubKey: _pegInRequestTxSPVProof.btcTx.outputs[VOUT_INDEX].scriptPubKey
        });

        // TODO Check if info emitted is enough or too much
        emit RegisteredPegInRequest(
            _pegInRequestTxSPVProof.blockHash,
            txHash,
            // vout is the first tx, is the P2TR output
            VOUT_INDEX + 1, // +1 is added as the index starts at 0
            stream.denomination,
            packetNumber,
            rskDestinationAddress,
            btcReimbursementPubKey,
            _pegInRequestTxSPVProof.btcTx.outputs[VOUT_INDEX].scriptPubKey
        );
    }

    function getPegInTempInfo(bytes32 btcTxHash) external view returns (PegInTempInfo memory) {
        return pegInsTempInfo[btcTxHash];
    }

    function acceptPegInRequest(PegInAcceptedTxSPVProof calldata _pegInAcceptedTxSPVProof) external {
        // TODO validate the inputs match the peg in request utxo,
        // do i need vout?
        // TODO validate the outputs take0 and such

        // Calculate txHash from BtcTransaction
        bytes32 txHash = bitcoinManager.getBtcTxHash(_pegInAcceptedTxSPVProof.btcTx);
        if (pegInRequests[txHash].registered) {
            // TODO maybe use same mapping for all? change revert name
            revert AlreadyRegisteredPegIn(txHash);
        }

        Stream memory stream = getStream(_pegInAcceptedTxSPVProof.btcTx.outputs[VOUT_INDEX].amount);
        // TODO get packet number
        uint64 packetNumber = 0;

        // Verify the txHash part of the Merkle Root of Tx of a Block
        // and that block is inside Bitcoin Mainchain
        // annd has enough confirmations
        verifyTxConfirmations(
            stream.pegInConfirmations,
            txHash,
            _pegInAcceptedTxSPVProof.blockHash,
            _pegInAcceptedTxSPVProof.merkleBranchPath,
            _pegInAcceptedTxSPVProof.merkleBranchHashes
        );

        // Store Tx in pegInSlot as Prepared
        // TODO corroborate if state should be prepared with Diego
        uint256 slotId = preparePegInTx(
            stream.streamId, packetNumber, txHash, _pegInAcceptedTxSPVProof.btcTx.outputs[VOUT_INDEX].scriptPubKey
        );
    }

    function validatePegOutRequest(bytes calldata _usrPubKey, uint256 amountInWei) internal pure {
        if (BtcHelper.weiToSatoshi(amountInWei) > type(uint64).max) {
            revert PegoutRequestAmountExceedsUint64Limit(BtcHelper.weiToSatoshi(amountInWei));
        }

        // Validate the _usrPubKey is 33 bytes
        if (_usrPubKey.length != 33) {
            revert InvalidPubKeyLength(_usrPubKey.length);
        }

        // TODO: validate who can request a peg-out
    }

    function requestPegOut(bytes calldata _usrPubKey, bool _batchFlag) external payable {
        validatePegOutRequest(_usrPubKey, msg.value);

        uint64 amount = uint64(BtcHelper.weiToSatoshi(msg.value));
        // TODO: acount for batchFlag

        // Get first filled Slot
        Stream memory stream = getStream(amount); //TODO: add test for a revert
        (Slot memory slot, uint64 packetNumber) = getFirstFilledSlot(stream.streamId); //TODO: add test for a revert no filled slot

        // Prepare prevouts data
        PrevoutData[] memory prevoutsData = new PrevoutData[](1);
        prevoutsData[0] = PrevoutData({txid: slot.txId, vout: 0, value: amount, scriptPubKey: slot.scriptPubKey});

        // Calculate fee and dust from amount
        // TODO: atm is returning hardcoded values, should be calculated
        (uint64 fee, uint64 dust) = BtcHelper.calculateFeeAndDust(amount);

        // Compute the Bitcoin peg-out transaction hash
        (bytes32 pegOutTxHash, bytes memory digest) =
            computePegOutTxHash(_usrPubKey, prevoutsData, amount - dust - fee, dust);

        // Store the peg-out transaction hash on-chain
        pegOutTxHashes[keccak256(abi.encodePacked(_usrPubKey, amount))] = pegOutTxHash;

        // Lock the used slot
        lockSlot(stream.streamId, packetNumber, slot.slotId);

        // TODO: return RBTC to the RSK Legacy Bridge following https://github.com/rsksmart/RSKIPs/pull/502

        // Emit an event
        emit PegOutRequested(
            _usrPubKey,
            amount,
            pegOutTxHash,
            //TODO: delet this todo
            digest,
            stream.streamId,
            packetNumber,
            slot.slotId
        );
    }

    function computePegOutTxHash(bytes memory usrPubKey, PrevoutData[] memory prevoutsData, uint64 amount, uint64 dust)
        public
        pure
        returns (bytes32, bytes memory)
    {
        // Prepare the more complex parts of the data

        // sha_prevouts (32): the SHA256 of the serialization of all input outpoints.
        //TODO: consider having just one prevout
        bytes memory prevouts;
        for (uint256 i = 0; i < prevoutsData.length; i++) {
            prevouts = abi.encodePacked(prevouts, BtcHelper.reverseBytes32(prevoutsData[i].txid), prevoutsData[i].vout);
        }

        // sha_amounts (32): the SHA256 of the serialization of all input outpoints amounts.
        bytes memory amounts;
        for (uint256 i = 0; i < prevoutsData.length; i++) {
            amounts = abi.encodePacked(amounts, BtcHelper.reverseUint64(prevoutsData[i].value));
        }

        // sha_scriptpubkeys (32): the SHA256 of the serialization of all spent output scriptPubKeys.
        bytes memory scriptPubKeys;
        for (uint256 i = 0; i < prevoutsData.length; i++) {
            scriptPubKeys = abi.encodePacked(
                scriptPubKeys,
                BtcHelper.toCompactSize(prevoutsData[i].scriptPubKey.length),
                prevoutsData[i].scriptPubKey
            );
        }

        //TODO: consider un-hardcoding this
        // sha_sequences (32): the SHA256 of the serialization of all input nSequences.
        bytes memory sequences = hex"FFFFFFFF";

        // sha_outputs (32): the SHA256 of the serialization of all outputs in CTxOut format.
        bytes memory outputs;
        bytes memory scriptPubKey = BtcScriptParser.getP2WPKHScript(usrPubKey);
        outputs = abi.encodePacked(
            BtcHelper.reverseUint64(amount), BtcHelper.toCompactSize(scriptPubKey.length), scriptPubKey
        );

        bytes memory speedUpScriptPubKey = BtcScriptParser.getP2WSHScript(abi.encodePacked(OpCodes.OP_1));
        outputs = abi.encodePacked(
            outputs,
            BtcHelper.reverseUint64(dust),
            BtcHelper.toCompactSize(speedUpScriptPubKey.length),
            speedUpScriptPubKey
        );

        // Concatenate all the data
        bytes memory encodedData = abi.encodePacked(
            uint8(0), // epoch
            uint8(0x00), // hash_type
            bytes4(hex"02000000"), // nVersion
            uint32(0), // nLockTime
            sha256(prevouts), // sha_prevouts
            sha256(amounts), // sha_amounts
            sha256(scriptPubKeys), // sha_scriptpubkeys
            sha256(sequences), // sha_sequences
            sha256(outputs), // sha_outputs
            uint8(0), // spend_type
            uint32(0) // input_index
        );
        //TODO: hash_type check if 0x00 (default) or 0x01 (SIGHASH_ALL) is the value being used in the protocol builder

        // Return the tagged hash and the encoded data before hashing
        return (BtcHelper.taggedHash(BtcTaprootParser.TAP_SIGHASH, encodedData), encodedData);
    }

    // function debug_computePegOutTxHash(bytes memory usrPubKey, PrevoutData[] memory prevoutsData, uint64 amount, uint64 dust)
    //     public
    //     pure
    //     returns (bytes32)
    // {
    //     bytes memory encodedData = "";

    //     // epoch
    //     encodedData = abi.encodePacked(encodedData, uint8(0));
    //     console.log("epoch");
    //     console.logBytes1(bytes1(0));

    //     // hash_type
    //     //TODO check if 0x00 (default) or 0x01 (SIGHASH_ALL) is the value being used in the protocol builder
    //     encodedData = abi.encodePacked(encodedData, uint8(0x00));
    //     console.log("hash_type");
    //     console.logBytes1(bytes1(0x00));

    //     // nVersion
    //     encodedData = abi.encodePacked(encodedData, bytes4(hex"02000000"));
    //     console.log("nVersion");
    //     console.logBytes4(bytes4(hex"02000000"));

    //     // nLockTime
    //     encodedData = abi.encodePacked(encodedData, uint32(0));
    //     console.log("nLockTime");
    //     console.logBytes4(bytes4(0));

    //     // sha_prevouts (32): the SHA256 of the serialization of all input outpoints.
    //     //TODO: consider having just one prevout
    //     bytes memory prevouts;
    //     for (uint256 i = 0; i < prevoutsData.length; i++) {
    //         prevouts = abi.encodePacked(prevouts, BtcHelper.reverseBytes32(prevoutsData[i].txid), prevoutsData[i].vout);
    //     }
    //     encodedData = abi.encodePacked(encodedData, sha256(prevouts));
    //     console.log("sha_prevouts txid reversed");
    //     console.logBytes32(BtcHelper.reverseBytes32(prevoutsData[0].txid));
    //     console.log("sha_prevouts vout");
    //     console.logBytes4(bytes4(prevoutsData[0].vout));
    //     console.log("sha_prevouts prehashed");
    //     console.logBytes(prevouts);
    //     console.log("sha_prevouts hashed");
    //     console.logBytes32(sha256(prevouts));

    //     // sha_amounts (32): the SHA256 of the serialization of all input outpoints amounts.
    //     bytes memory amounts;
    //     for (uint256 i = 0; i < prevoutsData.length; i++) {
    //         amounts = abi.encodePacked(amounts, BtcHelper.reverseUint64(prevoutsData[i].value));
    //     }
    //     encodedData = abi.encodePacked(encodedData, sha256(amounts));
    //     console.log("sha_amounts prehashed");
    //     console.logBytes(amounts);
    //     console.log("sha_amounts hashed");
    //     console.logBytes32(sha256(amounts));

    //     // sha_scriptpubkeys (32): the SHA256 of the serialization of all spent output scriptPubKeys.
    //     bytes memory scriptPubKeys;
    //     for (uint256 i = 0; i < prevoutsData.length; i++) {
    //         scriptPubKeys = abi.encodePacked(
    //             scriptPubKeys,
    //             BtcHelper.toCompactSize(prevoutsData[i].scriptPubKey.length),
    //             prevoutsData[i].scriptPubKey
    //         );
    //     }
    //     encodedData = abi.encodePacked(encodedData, sha256(scriptPubKeys));
    //     console.log("sha_scriptpubkeys prehashed");
    //     console.logBytes(scriptPubKeys);
    //     console.log("sha_scriptpubkeys hashed");
    //     console.logBytes32(sha256(scriptPubKeys));

    //     //TODO: consider un-hardcoding this
    //     // sha_sequences (32): the SHA256 of the serialization of all input nSequences.
    //     bytes memory sequences = hex"FFFFFFFF";
    //     encodedData = abi.encodePacked(encodedData, sha256(sequences));
    //     console.log("sha_sequences");
    //     console.logBytes32(sha256(sequences));

    //     // sha_outputs (32): the SHA256 of the serialization of all outputs in CTxOut format.
    //     bytes memory outputs;
    //     bytes memory scriptPubKey = BtcScriptParser.getP2WPKHScript(usrPubKey);
    //     outputs = abi.encodePacked(
    //         BtcHelper.reverseUint64(amount), BtcHelper.toCompactSize(scriptPubKey.length), scriptPubKey
    //     );

    //     bytes memory speedUpScriptPubKey = BtcScriptParser.getP2WSHScript(abi.encodePacked(OpCodes.OP_1));
    //     outputs = abi.encodePacked(
    //         outputs,
    //         BtcHelper.reverseUint64(dust),
    //         BtcHelper.toCompactSize(speedUpScriptPubKey.length),
    //         speedUpScriptPubKey
    //     );
    //     encodedData = abi.encodePacked(encodedData, sha256(outputs));
    //     console.log("sha_outputs prehashed");
    //     console.logBytes(outputs);
    //     console.log("sha_outputs hashed");
    //     console.logBytes32(sha256(outputs));

    //     // spend_type (1):
    //     uint8 spendType = 0;
    //     encodedData = abi.encodePacked(encodedData, spendType);
    //     console.log("spend_type");
    //     console.logBytes1(bytes1(spendType));

    //     // input_index (4):
    //     uint32 inputIndex = 0;
    //     encodedData = abi.encodePacked(encodedData, inputIndex);
    //     console.log("input_index");
    //     console.logBytes4(bytes4(inputIndex));

    //     return BtcHelper.taggedHash(BtcTaprootParser.TAP_SIGHASH, encodedData);
    // }

    function getPegOutTxHash(bytes32 key) external view returns (bytes32) {
        return pegOutTxHashes[key];
    }
}
