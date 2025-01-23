// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import "forge-std/console.sol";
import {Committee, ICommitteeRegistry} from "./interfaces/ICommitteeRegistry.sol";
import {Stream, Packet, SlotState, StreamManager} from "./StreamManager.sol";
import {IBitcoinManager} from "./interfaces/IBitcoinManager.sol";
import {BtcTransaction, BtcTxOut, PegInRequestTxSPVProof, IPegManager} from "./interfaces/IPegManager.sol";
import {
    Bridge,
    RSK_BRIDGE_ADDRESS,
    BTC_TRANSACTION_CONFIRMATION_MAX_DEPTH,
    BTC_TRANSACTION_CONFIRMATION_INEXISTENT_BLOCK_HASH_ERROR_CODE,
    BTC_TRANSACTION_CONFIRMATION_BLOCK_NOT_IN_BEST_CHAIN_ERROR_CODE,
    BTC_TRANSACTION_CONFIRMATION_INCONSISTENT_BLOCK_ERROR_CODE,
    BTC_TRANSACTION_CONFIRMATION_BLOCK_TOO_OLD_ERROR_CODE,
    BTC_TRANSACTION_CONFIRMATION_INVALID_MERKLE_BRANCH_ERROR_CODE
} from "./interfaces/Bridge.sol";
import {BtcHelper} from "./libraries/BtcHelper.sol";
import {BytesHelper} from "./libraries/BytesHelper.sol";
import {OpCodes} from "./libraries/OpCodes.sol";

/// @title PegManager
/// @notice Manages peg-in and peg-out operations between Bitcoin and Rootstock
contract PegManager is IPegManager, StreamManager {
    ICommitteeRegistry public committeeRegistry;
    IBitcoinManager public bitcoinManager;
    Bridge public bridge;

    function initialize(ICommitteeRegistry _committeeRegistry, IBitcoinManager _bitcoinManager) public initializer {
        committeeRegistry = _committeeRegistry;
        bitcoinManager = _bitcoinManager;
        bridge = Bridge(RSK_BRIDGE_ADDRESS);
        Committee memory committee = committeeRegistry.getNextAvailableCommittee();
        StreamManager.initialize(committee.internalKey);
    }

    function getTemporaryPegInAddress(
        bytes calldata _rootstockDepositAddress,
        // bytes calldata bitcoinReimbursementAddress,
        uint64 _value
    ) external view returns (bytes memory bitcoinDepositAddress) {
        // Get the stream for this value
        Stream memory stream = getStream(_value);

        // Get the current packet's committee key
        Packet memory currentPacket = packets[stream.streamId][stream.peginPointer];
        bytes32 committeeKey = currentPacket.committeeInternalKey;

        return bitcoinManager.getTemporaryPegInAddress(_rootstockDepositAddress, _value, committeeKey);
    }

    function acceptPegInRequest(PegInRequestTxSPVProof calldata pegInRequestTxSPVProof) external {
        // TODO validate who can call this function

        if (pegInRequestTxSPVProof.btcTx.outputs.length < 2) {
            revert incorrectOutputNumber(uint64(pegInRequestTxSPVProof.btcTx.outputs.length), 2);
        }
        // Second transaction should be OP_RETURN
        (uint64 packetNumber, address destinationAddress, string memory btcReinburstmentAddress) =
            _getAndValidateTxOpReturn(pegInRequestTxSPVProof.btcTx.outputs[1]);

        //  TODO Check destination address from second output, after OP_RETURN, and compare it with the destination address from the first output script.
        //  Contains value bitcoin to the taproot temporary address
        // TODO Validate data in Taproot transaction
        // TODO  should also validate witness data??? https://learnmeabitcoin.com/technical/transaction/wtxid/#commitment

        bytes32 txHash = BtcHelper.getBtcTxHash(pegInRequestTxSPVProof.btcTx);

        // Get corresponding stream
        Stream memory stream = getStream(pegInRequestTxSPVProof.value);
        // Verify the Tx is mined in a Block inside the Mainchain and has enough confirmations
        _verifyTxConfirmations(
            stream.pegInConfirmations,
            txHash,
            pegInRequestTxSPVProof.blockHash,
            pegInRequestTxSPVProof.merkleBranchPath,
            pegInRequestTxSPVProof.merkleBranchHashes
        );

        // TODO Validate Committee Key against the bitcoin Tx
        // Get corresponding packet
        Packet memory packet = getPacket(stream.streamId, packetNumber);
        packet.committeeInternalKey;

        // Store Tx in pegInSlot as Prepared
        // TODO corroborate if state should be prepared with Diego
        uint256 slotId = preparePegInTx(stream.streamId, packetNumber, txHash, pegInRequestTxSPVProof.utxo);

        // TODO Check if info emitted is enough or too much
        emit PrepareTakeTransaction(
            pegInRequestTxSPVProof.blockHash,
            txHash,
            pegInRequestTxSPVProof.value,
            packetNumber,
            slotId,
            destinationAddress,
            btcReinburstmentAddress,
            pegInRequestTxSPVProof.utxo
        );
    }

    function _verifyTxConfirmations(
        uint256 _minConfirmations,
        bytes32 _txHash,
        bytes32 _blockHash,
        uint256 _merkleBranchPath,
        bytes32[] memory _merkleBranchHashes
    ) internal {
        // Get tx confirmations using SPV from Rsk bridge precompiled contract
        int256 confirmations =
            bridge.getBtcTransactionConfirmations(_txHash, _blockHash, _merkleBranchPath, _merkleBranchHashes);
        // Validate block is in the Mainchain
        if (confirmations == BTC_TRANSACTION_CONFIRMATION_INEXISTENT_BLOCK_HASH_ERROR_CODE) {
            revert bridgeBtcInexistantBlockHash(_blockHash);
        }
        if (confirmations == BTC_TRANSACTION_CONFIRMATION_BLOCK_NOT_IN_BEST_CHAIN_ERROR_CODE) {
            revert bridgeBtcBlockNotInBestChain(_blockHash);
        }
        if (confirmations == BTC_TRANSACTION_CONFIRMATION_INCONSISTENT_BLOCK_ERROR_CODE) {
            revert bridgeBtcInconsistentBlock(_blockHash);
        }
        // Rsk only allows to retrieve blocks up to 1 month
        if (confirmations == BTC_TRANSACTION_CONFIRMATION_BLOCK_TOO_OLD_ERROR_CODE) {
            revert bridgeBtcBlockTooOld(BTC_TRANSACTION_CONFIRMATION_MAX_DEPTH);
        }
        // Validate transaction is in the Block
        if (confirmations == BTC_TRANSACTION_CONFIRMATION_INVALID_MERKLE_BRANCH_ERROR_CODE) {
            revert bridgeBtcTxInvalidMerkleBranch(_txHash, _merkleBranchPath, _merkleBranchHashes);
        }
        if (confirmations < 0) {
            revert bridgeBtcUnknownError(confirmations);
        }

        // Validate block has enough Confirmations
        if (confirmations < int256(_minConfirmations)) {
            revert notEnoughConfirmations(confirmations, _minConfirmations);
        }
    }

    function _getAndValidateTxOpReturn(BtcTxOut memory opReturnOut) internal returns (uint64, address, string memory) {
        // [OP_RETURN][OP_PUSHBYTES_9][RSK_PEGIN][OP_PUSHBYTES_8][packet number][OP_PUSHBYTES_20][rsk destination address][OP_PUSHBYTES_62][reimburstment address]
        // Size: 1   +          1    +      9    +       1       +      8       +       1       +       20               +        1         +       62
        uint8 expectedSize = (1 + 1 + 9 + 1 + 8 + 1 + 20 + 1 + 62);
        if (opReturnOut.scriptPubKey.length == expectedSize) {
            revert invalidOpReturnLength(opReturnOut.scriptPubKey.length, expectedSize);
        }
        // OP_RETURN
        uint8 index = 0;
        if (opReturnOut.scriptPubKey[index] == OpCodes.OP_RETURN) {
            revert incorrectlyFormedOpReturn(index);
        }
        index++;

        // RSK_PEGIN string used as flag
        if (opReturnOut.scriptPubKey[index] == OpCodes.OP_PUSHBYTES_9) {
            revert incorrectlyFormedOpReturn(index);
        }
        index++;
        if (
            BytesHelper.stringCompare(
                BytesHelper.bytesToString(opReturnOut.scriptPubKey, index, index + 9), "RSK_PEGIN"
            )
        ) {
            revert incorrectlyFormedOpReturn(index);
        }
        index = index + 9;

        // Packet Index in the Stream
        if (opReturnOut.scriptPubKey[index] == OpCodes.OP_PUSHBYTES_8) {
            revert incorrectlyFormedOpReturn(index);
        }
        index++;
        uint64 packetNumber = BytesHelper.bytesToUint64(opReturnOut.scriptPubKey, index);
        index = index + 8; // uint64 length

        // destination Address in Rootstock
        if (opReturnOut.scriptPubKey[index] == OpCodes.OP_PUSHBYTES_20) {
            revert incorrectlyFormedOpReturn(index);
        }
        index++;
        address destinationAddress = BytesHelper.bytesToAddress(opReturnOut.scriptPubKey, index);
        index = index + 20; // address length

        // Bitcoin reimburstment address
        if (opReturnOut.scriptPubKey[index] == OpCodes.OP_PUSHBYTES_62) {
            revert incorrectlyFormedOpReturn(index);
        }
        index++;
        string memory btcReinburstmentAddress = BytesHelper.bytesToString(opReturnOut.scriptPubKey, index, index + 62);
        index = index + 62; // Btc reimbursment address as base58 string length

        return (packetNumber, destinationAddress, btcReinburstmentAddress);
    }
}
