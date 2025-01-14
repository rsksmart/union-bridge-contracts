// SPDX-License-Identifier: UNKNOWN
pragma solidity ^0.8.20;

interface IBitcoinManager {
    /// @notice Allows users generate a temporary Bitcoin address to perform a peg-in.
    /// @param _rootstockDepositAddress The RSK deposit address
    // /// @param bitcoinReimbursementAddress The BTC reimbursement address
    /// @param _value uint64 The amount to peg in
    /// @param _committeeKey bytes32 Get the current packet's committee key
    /// @return temporaryPegInAddress The temporary peg-in address
    function getTemporaryPegInAddress(
        bytes calldata _rootstockDepositAddress,
        // bytes calldata bitcoinReimbursementAddress,
        uint64 _value,
        bytes32 _committeeKey
    ) external view returns (bytes memory temporaryPegInAddress);

    // /// @notice Accepts a peg-in request
    // /// @param pegInRequestTxSPVProof The SPV proof of the peg-in request transaction
    // /// @param numberOfConfirmations Number of confirmations required
    // function acceptPegInRequest(bytes calldata pegInRequestTxSPVProof, uint8 numberOfConfirmations) external;

    // /// @notice Registers peg transactions
    // /// @param take0Tx First take transaction
    // /// @param take1Tx Second take transaction
    // /// @param acceptPegInTx Accept peg-in transaction
    // /// @param take0AggregatedSignatures Signatures for take0Tx
    // /// @param take1AggregatedSignatures Signatures for take1Tx
    // /// @param acceptPegInAggregatedSignatures Signatures for acceptPegInTx
    // function registerPegTransactions(
    //     bytes calldata take0Tx,
    //     bytes calldata take1Tx,
    //     bytes calldata acceptPegInTx,
    //     bytes calldata take0AggregatedSignatures,
    //     bytes calldata take1AggregatedSignatures,
    //     bytes calldata acceptPegInAggregatedSignatures
    // ) external;

    // /// @notice Selects UTXOs for peg-out
    // /// @param streamId The stream identifier
    // /// @param sequenceNumber The sequence number
    // /// @param slotId The slot identifier
    // function selectUTXOsForPegOut(uint256 streamId, uint256 sequenceNumber, uint256 slotId) external;
}
