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

struct PrevoutData {
    uint64 value;
    bytes scriptPubKey;
}

interface IBitcoinManager {
    /// @notice Allows users generate a temporary Bitcoin address to perform a peg-in.
    /// @param _rskDestinationAddress The RSK deposit address
    /// @param _value uint64 The amount to peg in
    /// @param _btcReimbursementPubKey The BTC reimbursement public key x-cordinate only
    /// @param _committeePubKey bytes32 Get the current packet's committee key
    /// @return temporaryPeginAddress The temporary peg-in address
    function getTemporaryPeginAddress(
        address _rskDestinationAddress,
        uint64 _value,
        bytes32 _btcReimbursementPubKey,
        bytes32 _committeePubKey
    ) external view returns (string memory temporaryPeginAddress);

    /// @notice Extracts data from a Bitcoin transaction's OP_RETURN output
    /// @dev Expected OP_RETURN format: [OP_RETURN][RSK_PEGIN][packet number][rsk address][btc address]
    /// @param _opReturnOut The Bitcoin transaction output containing OP_RETURN data
    /// @return packetNumber The packet number encoded in the OP_RETURN data
    /// @return destinationAddress The RSK destination address encoded in the OP_RETURN data
    /// @return btcReimbursementPubKey The Bitcoin reimbursement public key (x only) encoded in the OP_RETURN data
    function getPeginOpReturnData(BtcTxOut calldata _opReturnOut) external pure returns (uint64, address, bytes32);

    function validateRequestPeginP2TROutput(
        address _rskDestinationAddress,
        uint64 _value,
        bytes32 _btcReimbursementPubKey,
        bytes32 _committeePubKey,
        BtcTxOut calldata _p2trOut
    ) external pure;

    /// @notice Calculates the Bitcoin transaction hash (txid) for a given transaction
    /// @dev Encodes the transaction into Bitcoin's raw format and performs double SHA256 hash
    /// @param _btcTx The Bitcoin transaction to hash
    /// @return txHash The transaction hash in big-endian format
    function getBtcTxHash(BtcTransaction calldata _btcTx) external pure returns (bytes32);

    /// @notice Generates a Taproot script pub key for the PeginRequest with both key spend and script spend paths
    /// @param _rskDestinationAddress address that will get the RBTC
    /// @param _value amount sent in btc, should be equal to stream denomination
    /// @param _btcReimbursementPubKey The user's public key (x-only, 32 bytes)
    /// @param _committeePubKey The committee's public key (x-only, 32 bytes)
    function getPeginRequestP2TRScriptPub(
        address _rskDestinationAddress,
        uint64 _value,
        bytes32 _btcReimbursementPubKey,
        bytes32 _committeePubKey
    ) external pure returns (bytes memory);

    /// @notice Get the hash to sign of a Bitcoin  accept peg-in transaction
    /// @param _committeePubKey The committee's public key
    /// @param _userXOnlyPubKey The user's public key (x-only, 32 bytes)
    /// @param _registerPeginTx The transaction hash of the register peg-in tx being spent
    /// @param _prevoutData Data about the previous output being spent (amount and scriptPubKey)
    /// @return the tagged hash and the encoded data before hashing
    function getAcceptPeginSignatureHash(
        bytes32 _committeePubKey,
        bytes32 _userXOnlyPubKey,
        bytes32 _registerPeginTx,
        PrevoutData memory _prevoutData
    ) external pure returns (bytes32, bytes32, bytes memory);

    /// @notice Generates a Taproot script pub key for the AcceptPegin with both key spend and script spend paths
    /// @param _committeePubKey The committee's public key (x-only, 32 bytes)
    /// @return The Taproot script pub key
    function getAcceptPeginP2TRScriptPub(bytes32 _committeePubKey) external pure returns (bytes memory);

    /// @notice Validates the accept peg in P2TR output
    /// @param _committeePubKey The committee's public key (x-only, 32 bytes)
    /// @param _inputAmount The amount of the input
    /// @param _p2trOut The Bitcoin transaction output containing the P2TR output
    function validateAcceptPeginP2TROutput(bytes32 _committeePubKey, uint64 _inputAmount, BtcTxOut calldata _p2trOut)
        external
        pure;

    /// @notice Generates a P2WPKH script pub key for the speed up output
    /// @param _pubKey The user's public key (x-only, 32 bytes)
    /// @return The P2WPKH script pub key
    function getSpeedUpScriptPub(bytes32 _pubKey) external pure returns (bytes memory);

    /// @notice Validates the speed up output
    /// @param _pubKey The user's public key (x-only, 32 bytes)
    /// @param _speedUpOut The Bitcoin transaction output containing the speed up output
    function validateSpeedUpOutput(bytes32 _pubKey, BtcTxOut calldata _speedUpOut) external pure;

    /// @notice Get the hash to sign of a Bitcoin peg-out transaction
    /// @param _userPubKey The user's public key in compact size that will receive the funds
    /// @param _acceptPeginTx The transaction hash of the accept peg-in tx being spent
    /// @param _prevoutData Data about the previous output being spent (amount and scriptPubKey)
    /// @return the tagged hash and the encoded data before hashing
    function getPegoutSignatureHash(bytes memory _userPubKey, bytes32 _acceptPeginTx, PrevoutData memory _prevoutData)
        external
        pure
        returns (bytes32, bytes memory);

    /// @notice Validates that the peg-out transaction output is a P2WPKH paying the user
    /// @param _pegoutOutput The Bitcoin transaction output to validate
    /// @param _userPubKey The user's public key that should receive the funds
    function validatePegoutUserOutput(BtcTxOut calldata _pegoutOutput, bytes memory _userPubKey) external pure;

    error InvalidOpReturnLength(uint256 actual, uint256 expected);
    error IncorrectlyFormedOpReturn(uint256 index);
    error IncorrectOutputScript(bytes actual, bytes expected);
    error InvalidPublicKey(bytes32 publicKey);
    error InvalidAddress(address _address);
    error InvalidValue(uint64 _value, uint64 expected);
    error InvalidInputAmount(uint64 _value);
    error InvalidOutputAmount(uint64 actual, uint64 expected);
}
