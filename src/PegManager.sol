// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import "forge-std/console.sol";
import {Committee, ICommitteeRegistry} from "./interfaces/ICommitteeRegistry.sol";
import {Stream, Packet, SlotState, StreamManager} from "./StreamManager.sol";
import {IBitcoinManager} from "./interfaces/IBitcoinManager.sol";
import {IPegManager} from "./interfaces/IPegManager.sol";

/// @title PegManager
/// @notice Manages peg-in and peg-out operations between Bitcoin and Rootstock
contract PegManager is IPegManager, StreamManager {
    ICommitteeRegistry public committeeRegistry;
    IBitcoinManager public bitcoinManager;

    function initialize(ICommitteeRegistry _committeeRegistry, IBitcoinManager _bitcoinManager) public initializer {
        committeeRegistry = _committeeRegistry;
        bitcoinManager = _bitcoinManager;
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

    struct PegInRequestTxSPVProof {
        uint256 packetNumber; // Packet Index in the Stream
        address destinationAddress; // destination Address in Rootstock
        bytes32 btcReinburstmentAddress; // Bitcoin reimburstment address
        uint64 value; // The denomination of the stream in satoshis
        bytes32 txHash; // The Bitcoin PegIn Transaction Hash
        bytes32 blockHash; // The Bitcoin Block Hash where the pegin tx happened
        string utxo; // UTXO of the PegIn Transaction
    }

    function acceptPegInRequest(PegInRequestTxSPVProof calldata pegInRequestTxSPVProof) public {
        // TODO validate who can call this function

        // Validate data in transaction
        //  Check destination address from second output, after OP_RETURN, and compare it with the destination address from the first output script.
        //  Contains value bitcoin to the taproot temporary address

        // Validate transaction is in the Block

        // Validate Block is in the BTC Blockchain

        // Validate Block has enough confirmations
        Stream memory stream = getStream(pegInRequestTxSPVProof.value);
        stream.pegInConfirmations;

        // Calidate Committee Key against the bitcoin Tx
        Packet memory packet = getPacket(stream.streamId, pegInRequestTxSPVProof.packetNumber);
        packet.committeeInternalKey;

        // Store Tx in pegInSlot as Prepared
        preparePegInTx(
            stream.streamId,
            pegInRequestTxSPVProof.packetNumber,
            pegInRequestTxSPVProof.txHash,
            pegInRequestTxSPVProof.utxo
        );

        // Emit event to prepareTakeTransactions
    }
}
