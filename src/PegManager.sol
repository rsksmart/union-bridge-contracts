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
    IPegManager
} from "./interfaces/IPegManager.sol";
import {Stream, Packet, SlotState, StreamManager} from "./StreamManager.sol";
import {ProofValidator} from "./ProofValidator.sol";

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

    function initialize(address _initialOwner, ICommitteeRegistry _committeeRegistry, IBitcoinManager _bitcoinManager)
        public
        initializer
    {
        committeeRegistry = _committeeRegistry;
        bitcoinManager = _bitcoinManager;
        Committee memory committee = committeeRegistry.getNextAvailableCommittee();
        StreamManager.initialize(committee.internalKey);
        __BaseProxy_init(_initialOwner);
    }

    function getTemporaryPegInAddress(address _rootstockDepositAddress, uint64 _value, bytes32 _btcReimbursementPubKey)
        external
        view
        returns (bytes memory bitcoinDepositAddress)
    {
        // Get the stream for this value
        Stream memory stream = getStream(_value);

        // Get the current packet's committee key
        Packet memory currentPacket = packets[stream.streamId][stream.peginPointer];

        return bitcoinManager.getTemporaryPegInAddress(
            _rootstockDepositAddress, _value, _btcReimbursementPubKey, currentPacket.committeePubKey
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

        // TODO Missing Backup committee in Taproot validation.
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

        // Store pegInRequest to avpod processing it again
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
        uint64 packetNumber;

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
}
