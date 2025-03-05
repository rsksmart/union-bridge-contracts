// SPDX-License-Identifier: UNKNOWN
pragma solidity ^0.8.20;

// https://learnmeabitcoin.com/technical/transaction/#structure-inputs-txid
struct BtcTxIn {
    bytes32 txId; // (reversed little endian) "txid": "360b81785dc7c2f40627fea364676dbb73e6276683caffd9f906b0e0bd36b3d2"
    uint32 vout; // "vout": 1694
    uint32 sequence; // "sequence": 4294967293 (reversed little endian)
    bytes scriptSig; // Unlocking script: EMPTY (note: non-SegWit inputs will have script length >0 and have the unlocking script here instead of in the witness, so for non-SegWit this will not be EMPTY)
        // We don't need the witness for the txHash
        // bytes[] witness; // All witness  Witness 01: 473044022001609cd43eb8e9b8f8438eded9f6b10bad32efd7620724ccd2ed5277c0c6a3ae02200f0c1c3f4c409ada536d2363a2d8bdad418df67fed9b36bfa4482bd9985bf39601 Witness 02: 2102ee3c98964dd1bfe13bee16c0b95fcf8281f12c5885d1fcb7b59fc2cb01ca7632
}

// https://learnmeabitcoin.com/technical/transaction/#structure-inputs-txid
struct BtcTxOut {
    uint64 amount; // In satoshi hex 0db9a60000000000 (reversed little endian)
    bytes scriptPubKey; // "hex": "0014d3b4045c40a133ee361f766ceae4d82398fc5058"
}

// Obtained from https://learnmeabitcoin.com/technical/transaction/wtxid/#commitment
// https://learnmeabitcoin.com/technical/transaction/#structure-inputs-txid
// TODO this structure still needs some fixes
struct BtcTransaction {
    uint32 version; // TX version: 02000000 (reversed little endian)
    // bytes2 witnessMarkerFlag; // Witness marker and flag: 0001 // We don't need it for TxHash
    BtcTxIn[] inputs; // All inputs
    BtcTxOut[] outputs; // All outputs Output 01: 40420f00000000001976a914341b568f59229818c460b1795ad48cd78895c54d88ac Output 02: 6eeefa4a00000000160014d701ce5e753bd9454d343c8a3b86d84a3c34dbf5
    uint32 locktime; // TX locktime: 00000000 (reversed little endian)
}

interface IBitcoinManager {
    /// @notice Allows users generate a temporary Bitcoin address to perform a peg-in.
    /// @param _rskDestinationAddress The RSK deposit address
    /// @param _value uint64 The amount to peg in
    /// @param _btcReimbursementPubKey The BTC reimbursement public key x-cordinate only
    /// @param _committeePubKey bytes32 Get the current packet's committee key
    /// @return temporaryPegInAddress The temporary peg-in address
    function getTemporaryPegInAddress(
        address _rskDestinationAddress,
        uint64 _value,
        bytes32 _btcReimbursementPubKey,
        bytes32 _committeePubKey
    ) external view returns (bytes calldata temporaryPegInAddress);

    /// @notice Validates a Bitcoin peg-in transaction
    /// @dev Checks that the transaction has at least 2 outputs - one for the peg-in amount and one for the OP_RETURN data
    /// @param _pegInBtcTx The Bitcoin transaction to validate
    /// @custom:throws IncorrectOutputNumber if transaction has less than 2 outputs
    function validatePegInTx(BtcTransaction calldata _pegInBtcTx) external pure;

    /// @notice Extracts data from a Bitcoin transaction's OP_RETURN output
    /// @param _opReturnOut The Bitcoin transaction output containing OP_RETURN data
    /// @return packetNumber The packet number encoded in the OP_RETURN data
    /// @return destinationAddress The RSK destination address encoded in the OP_RETURN data
    /// @return btcReimbursementPubKey The Bitcoin reimbursement public key (x only) encoded in the OP_RETURN data
    /// @dev Expected OP_RETURN format: [OP_RETURN][RSK_PEGIN][packet number][rsk address][btc address]
    function getPegInOpReturnData(BtcTxOut calldata _opReturnOut) external pure returns (uint64, address, bytes32);

    function validatePegInP2TRData(
        address _rskDestinationAddress,
        uint64 _value,
        bytes32 _btcReimbursementPubKey,
        bytes32 _committeePubKey,
        BtcTxOut calldata _p2trOut
    ) external pure;

    /// @notice Calculates the Bitcoin transaction hash (txid) for a given transaction
    /// @dev Encodes the transaction into Bitcoin's raw format and performs double SHA256 hash
    /// @param _btcTx The Bitcoin transaction to hash
    /// @return The transaction hash (txid) in big-endian format
    function getBtcTxHash(BtcTransaction calldata _btcTx) external pure returns (bytes32);

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

    error IncorrectOutputNumber(uint256 actual, uint256 expected);
    error InvalidOpReturnLength(uint256 actual, uint256 expected);
    error IncorrectlyFormedOpReturn(uint256 index);
    error IncorrectP2TRScriptPub(bytes actual, bytes expected);
    error InvalidPublicKey(bytes32 publicKey);
    error InvalidAddress(address _address);
    error InvalidValue(uint64 _value);
}
