// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import "forge-std/console.sol";
import {Committee, ICommitteeRegistry} from "./interfaces/ICommitteeRegistry.sol";
import {BtcTransaction, BtcTxOut, IBitcoinManager} from "./interfaces/IBitcoinManager.sol";
import {PegInRequestTxSPVProof, IPegManager} from "./interfaces/IPegManager.sol";
import {Stream, Packet, SlotState, StreamManager} from "./StreamManager.sol";
import {ProofValidator} from "./ProofValidator.sol";

/// @title PegManager
/// @notice Manages peg-in and peg-out operations between Bitcoin and Rootstock
contract PegManager is IPegManager, StreamManager, ProofValidator {
    ICommitteeRegistry public committeeRegistry;
    IBitcoinManager public bitcoinManager;

    function initialize(ICommitteeRegistry _committeeRegistry, IBitcoinManager _bitcoinManager) public initializer {
        committeeRegistry = _committeeRegistry;
        bitcoinManager = _bitcoinManager;
        Committee memory committee = committeeRegistry.getNextAvailableCommittee();
        StreamManager.initialize(committee.internalKey);
    }

    function getTemporaryPegInAddress(address _rootstockDepositAddress, bytes32 _btcReimbursementPubKey, uint64 _value)
        external
        view
        returns (bytes memory bitcoinDepositAddress)
    {
        // Get the stream for this value
        Stream memory stream = getStream(_value);

        // Get the current packet's committee key
        Packet memory currentPacket = packets[stream.streamId][stream.peginPointer];
        bytes32 committeeKey = currentPacket.committeeInternalKey;

        return bitcoinManager.getTemporaryPegInAddress(
            _rootstockDepositAddress, _btcReimbursementPubKey, _value, committeeKey
        );
    }

    function registerPegInRequest(PegInRequestTxSPVProof calldata _pegInRequestTxSPVProof) external {
        // TODO validate who can call this function

        // Validate transaction has at least 2 outputs
        bitcoinManager.validatePegInTx(_pegInRequestTxSPVProof.btcTx);

        // Second transaction should be OP_RETURN with data
        (uint64 packetNumber, address destinationAddress, bytes32 btcReimbursementPubKey) =
            bitcoinManager.getPegInOpReturnData(_pegInRequestTxSPVProof.btcTx.outputs[1]);

        // First transaction is the PegIn P2TR _pegInRequestTxSPVProof.btcTx.outputs[0]
        // Get corresponding stream for the amount if non found reverts
        Stream memory stream = getStream(_pegInRequestTxSPVProof.btcTx.outputs[0].amount);

        // TODO Missing Backup committee in Taproot validation.
        // Validates that the Taproot Script has a Key Path for the committeeInternalKey
        // and has a timelock for btcReimbursementPubKey
        bitcoinManager.validatePegInP2TRData(
            _pegInRequestTxSPVProof.btcTx.outputs[0],
            btcReimbursementPubKey,
            // getPacket reverts if packet does not exist
            getPacket(stream.streamId, packetNumber).committeeInternalKey
        );

        // Calculate txHash from BtcTransaction
        bytes32 txHash = bitcoinManager.getBtcTxHash(_pegInRequestTxSPVProof.btcTx);

        // Verify the TxHash part of the Merkle Root of Tx of a Block
        // and that block is inside Bitcoin Mainchain
        // annd has enough confirmations
        verifyTxConfirmations(
            stream.pegInConfirmations,
            txHash,
            _pegInRequestTxSPVProof.blockHash,
            _pegInRequestTxSPVProof.merkleBranchPath,
            _pegInRequestTxSPVProof.merkleBranchHashes
        );

        // Store Tx in pegInSlot as Prepared
        // TODO corroborate if state should be prepared with Diego
        uint256 slotId =
            preparePegInTx(stream.streamId, packetNumber, txHash, _pegInRequestTxSPVProof.btcTx.outputs[0].scriptPubKey);

        // TODO Check if info emitted is enough or too much
        emit RegisteredPegInRequest(
            _pegInRequestTxSPVProof.blockHash,
            txHash,
            stream.denomination,
            packetNumber,
            slotId,
            destinationAddress,
            btcReimbursementPubKey,
            _pegInRequestTxSPVProof.btcTx.outputs[0].scriptPubKey
        );
    }
}
