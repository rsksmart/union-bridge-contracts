// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {IPeginManager} from "./IPeginManager.sol";

/// @notice Represents a Bitcoin transaction input that references a previous UTXO
/// @dev This struct follows Bitcoin's transaction input format as defined in BIP-141
/// @dev All multi-byte fields are stored in little-endian format (Bitcoin's native format)
/// @dev For more details on Bitcoin transaction inputs, see: https://learnmeabitcoin.com/technical/transaction/#structure-inputs-txid
struct BtcTxIn {
    /// @notice Transaction ID of the previous transaction being spent (little-endian)
    /// @dev 32 bytes stored in little-endian format (reversed from standard hex representation)
    /// @dev Example: "360b81785dc7c2f40627fea364676dbb73e6276683caffd9f906b0e0bd36b3d2"
    bytes32 txId;
    /// @notice Output index of the previous transaction being spent
    /// @dev Example: 1694 indicates the 1694th output of the referenced transaction
    uint32 vout;
    /// @notice Sequence number for relative locktime or replace-by-fee
    /// @dev 4 bytes stored in little-endian format
    /// @dev Example: 4294967293 (0xfdffffff) enables replace-by-fee
    /// @dev Default value 0xffffffff disables relative locktime
    uint32 sequence;
    /// @notice Unlocking script (signature script)
    /// @dev For SegWit inputs, this is typically empty as signatures are in the witness
    /// @dev For non-SegWit inputs, contains the unlocking script with signatures and public keys
    /// @dev Note: Witness data is excluded as it's not needed for transaction id calculation
    bytes scriptSig;
}

/// @notice Represents a Bitcoin transaction output that creates a new UTXO
/// @dev This struct follows Bitcoin's transaction output format, see: https://learnmeabitcoin.com/technical/transaction/#structure-inputs-txid
/// @dev All multi-byte fields are stored in little-endian format (Bitcoin's native format)
struct BtcTxOut {
    /// @notice Amount in satoshis (little-endian)
    /// @dev 8 bytes stored in little-endian format
    /// @dev Example: 0x0db9a60000000000 represents 10,000,000 satoshis (0.1 BTC)
    uint64 amount;
    /// @notice Locking script (scriptPubKey) that defines spending conditions
    /// @dev Contains the script that defines how this output can be spent
    /// @dev Example: "0014d3b4045c40a133ee361f766ceae4d82398fc5058" (P2WPKH)
    bytes scriptPubKey;
}

/// @notice Represents a complete Bitcoin transaction structure for union bridge operations
/// @dev This struct follows Bitcoin's transaction format as defined in BIP-141 and related specifications
/// @dev All multi-byte fields are stored in little-endian format (Bitcoin's native format)
/// @dev The witness data is excluded from this struct as it's not needed for transaction id calculation
/// @dev For more details on Bitcoin transaction structure, see: https://learnmeabitcoin.com/technical/transaction/#structure-inputs-txid
struct BtcTransaction {
    /// @notice Transaction version number indicating the transaction format and features
    /// @dev 4 bytes stored in little-endian format
    /// @dev Example: 0x02000000 represents version 2
    /// @dev This field indicates the transaction format and features supported
    uint32 version;
    /// @notice Array of transaction inputs that reference previous UTXOs to be spent
    /// @dev Each input references a previous transaction output (UTXO) to be spent
    /// @dev The order of inputs is significant for transaction signing
    BtcTxIn[] inputs;
    /// @notice Array of transaction outputs that create new UTXOs
    /// @dev Each output creates new UTXOs that can be spent in future transactions
    /// @dev Example outputs:
    /// @dev - Output 01: 40420f00000000001976a914341b568f59229818c460b1795ad48cd78895c54d88ac
    /// @dev - Output 02: 6eeefa4a00000000160014d701ce5e753bd9454d343c8a3b86d84a3c34dbf5
    /// @dev The first output is typically the main payment, second is often change or OP_RETURN
    BtcTxOut[] outputs;
    /// @notice Transaction locktime that prevents inclusion before a specific time/height
    /// @dev 4 bytes stored in little-endian format
    /// @dev Example: 0x00000000 means no locktime
    /// @dev If locktime is non-zero, the transaction cannot be included in a block before that time/height
    /// @dev Used for time-locked transactions and relative locktimes
    uint32 locktime;
}

/// @notice Represents data about a previous transaction output being spent
/// @dev Used for signature hash calculation and validation
struct PrevoutData {
    /// @notice Amount in satoshis of the previous output being spent
    uint64 value;
    /// @notice Script pubkey of the previous output being spent
    /// @dev This is the locking script that defined how the output could be spent
    bytes scriptPubKey;
}

/// @notice Data structure for Bitcoin transaction signature information
/// @dev Used by both accept peg-in and peg-out signature generation functions
struct BitcoinSignatureData {
    BtcTransaction tx;
    /// @notice The transaction id (txid)
    bytes32 txid;
    /// @notice The hash to be signed by committee members
    bytes32 signatureHash;
    /// @notice The encoded data before hashing
    bytes signatureMessage;
}

/// @notice Interface for managing Bitcoin transaction operations in the union bridge
/// @dev This interface provides functions for generating addresses, validating transactions,
/// @dev and calculating signature hashes for Bitcoin operations in the RSK union bridge
interface IBitcoinManager {
    /// @notice Sets the Pegin Manager contract address
    /// @dev Only callable by the contract owner
    /// @param _peginManager The address of the Pegin Manager contract
    function setPeginManager(IPeginManager _peginManager) external;

    /// @notice Obtains a temporary Bitcoin address for request peg-in operations
    /// @dev Creates a Taproot address with committee and user key paths for secure peg-in
    /// @param _timelockBlocks The timelock blocks for the Bitcoin transaction
    /// @param _rskDestinationAddress The RSK address that will receive the RBTC
    /// @param _value The amount in satoshis to peg in (must match stream denomination)
    /// @param _btcReimbursementPubKey The user's Bitcoin public key (x-coordinate only, 32 bytes)
    /// @param _committeePubKey The committee's public key
    /// @return temporaryPeginAddress The generated temporary Bitcoin address for deposit
    function getTemporaryPeginAddress(
        uint32 _timelockBlocks,
        address _rskDestinationAddress,
        uint64 _value,
        bytes32 _btcReimbursementPubKey,
        bytes memory _committeePubKey
    ) external view returns (string memory temporaryPeginAddress);

    /// @notice Extracts data from a request peg-in Bitcoin transaction's OP_RETURN output
    /// @dev Expected OP_RETURN format: [OP_RETURN][RSK_PEGIN][packet number][rsk address][btc address]
    /// @dev This function parses the structured data embedded in the OP_RETURN output
    /// @param _opReturnOut The Bitcoin transaction output containing OP_RETURN data
    /// @return packetNumber The packet number encoded in the OP_RETURN data
    /// @return destinationAddress The RSK destination address encoded in the OP_RETURN data
    /// @return btcReimbursementPubKey The Bitcoin reimbursement public key (x only) encoded in the OP_RETURN data
    function getPeginOpReturnData(BtcTxOut calldata _opReturnOut) external pure returns (uint64, address, bytes32);

    /// @notice Validates a P2TR output for request peg-in transactions
    /// @dev Ensures the Taproot output has the correct script structure with committee and user key paths
    /// @param _timelockBlocks The timelock blocks for the Bitcoin transaction
    /// @param _rskDestinationAddress The RSK address that should receive the RBTC
    /// @param _streamDenomination The expected amount in satoshis
    /// @param _btcReimbursementPubKey The user's Bitcoin public key (x-coordinate only)
    /// @param _committeePubKey The committee's public key
    /// @param _p2trOut The Bitcoin transaction output to validate
    function validateRequestPeginP2TROutput(
        uint32 _timelockBlocks,
        address _rskDestinationAddress,
        uint64 _streamDenomination,
        bytes32 _btcReimbursementPubKey,
        bytes memory _committeePubKey,
        BtcTxOut calldata _p2trOut
    ) external view;

    /// @notice Validates the enabler output in a request peg-in transaction
    /// @param _committeePubKey The committee's public key
    /// @param _disputeKeys The dispute keys (covenant public keys) for the committee
    /// @param _enablerOut The enabler output to validate
    function validateRequestPeginEnablerOutput(
        bytes memory _committeePubKey,
        bytes32[] memory _disputeKeys,
        BtcTxOut calldata _enablerOut
    ) external view;

    /// @notice Calculates the Bitcoin transaction id (txid) for a given transaction
    /// @dev Encodes the transaction into Bitcoin's raw format and performs double SHA256 hash
    /// @dev This is the standard Bitcoin transaction ID used for referencing transactions
    /// @param _btcTx The Bitcoin transaction to hash
    /// @return txid The transaction id in big-endian format (standard hex representation)
    function getBtcTxid(BtcTransaction calldata _btcTx) external pure returns (bytes32);

    /// @notice Calculates the signature hash for Bitcoin accept peg-in transactions
    /// @dev Generates the hash that committee members must sign to accept a peg-in
    /// @param _committeePubKey The committee's public key (x-coordinate only)
    /// @param _userXOnlyPubKey The user's public key (x-coordinate only, 32 bytes)
    /// @param _registerPeginTx The transaction id of the peg-in request being spent
    /// @param _prevoutDatas Array of prevout data for all inputs being spent (taptree + enabler outputs)
    /// @param _operatorDisputeKeys The dispute keys (covenant public keys) for OPERATOR members only
    /// @return BitcoinSignatureData containing txid, signatureHash, and signatureMessage
    function getAcceptPeginSignatureHash(
        bytes memory _committeePubKey,
        bytes32 _userXOnlyPubKey,
        bytes32 _registerPeginTx,
        PrevoutData[] memory _prevoutDatas,
        bytes32[] memory _operatorDisputeKeys
    ) external view returns (BitcoinSignatureData memory);

    /// @notice Generates the enabler output P2TR script pub key
    /// @dev Creates a Taproot script for the enabler output with dispute keys in the merkle tree
    /// @param _committeePubKey The committee's aggregated public key (33 bytes compressed)
    /// @param _disputeKeys Array of dispute keys for committee members (x-only, 32 bytes each)
    /// @return The P2TR script pub key bytes
    function getEnablerOutputP2TRScriptPub(bytes memory _committeePubKey, bytes32[] memory _disputeKeys)
        external
        pure
        returns (bytes memory);

    /// @notice Generates a P2WPKH script pub key for speed-up outputs
    /// @dev Creates a P2WPKH script for Child Pays for Parent (CPFP) transactions to speed up the original transaction
    /// @param _pubKey The user's public key (x-coordinate only, 32 bytes)
    /// @return The P2WPKH script pub key
    function getSpeedUpScriptPub(bytes32 _pubKey) external pure returns (bytes memory);

    /// @notice Validates a speed-up output transactions
    /// @dev Ensures the output is a valid P2WPKH for CPFP transactions to accelerate the parent transaction
    /// @param _pubKey The user's public key (x-coordinate only, 32 bytes)
    /// @param _speedUpOut The Bitcoin transaction output containing the speed-up output
    function validateSpeedUpOutput(bytes32 _pubKey, BtcTxOut calldata _speedUpOut) external pure;

    /// @notice Calculates the signature hash for Bitcoin peg-out transactions
    /// @dev Generates the hash that committee members must sign to authorize a peg-out
    /// @param _userPubKey The user's public key in compressed format that will receive the funds
    /// @param _acceptPeginTx The transaction id of the accept peg-in tx being spent
    /// @param _prevoutDatas Array of prevout data for all inputs being spent (taptree + enabler outputs)
    /// @return BitcoinSignatureData containing txid, signatureHash, and signatureMessage
    function getPegoutTxData(bytes memory _userPubKey, bytes32 _acceptPeginTx, PrevoutData[] memory _prevoutDatas)
        external
        pure
        returns (BitcoinSignatureData memory);

    /// @notice Validates that a peg-out transaction output is a P2WPKH paying the user
    /// @dev Ensures the output correctly pays the user with the expected P2WPKH script
    /// @param _pegoutOutput The Bitcoin transaction output to validate
    /// @param _userPubKey The user's public key that should receive the funds
    function validatePegoutUserOutput(BtcTxOut calldata _pegoutOutput, bytes memory _userPubKey) external pure;

    /// @notice Validates that a peg-out transaction output is a P2WPKH paying the committee member
    /// @dev Ensures the output correctly pays the committee member with the expected P2WPKH script
    /// @param _pegoutOutput The Bitcoin transaction output to validate
    /// @param _memberPubKey The committee member's public key that should receive the funds
    function validatePegoutMemberOutput(BtcTxOut calldata _pegoutOutput, bytes32 _memberPubKey) external pure;

    /// @notice Validates that a peg-out transaction output encodes the correct peg-out id in OP_RETURN
    /// @dev Ensures the OP_RETURN output contains the expected peg-out id for tracking
    /// @param _pegoutIdOutput The Bitcoin transaction output containing OP_RETURN data
    /// @param _pegoutId The expected peg-out id to validate against
    function validatePegoutIdOutput(BtcTxOut calldata _pegoutIdOutput, bytes32 _pegoutId) external pure;

    // Errors
    /// @notice Thrown when OP_RETURN data length doesn't match expected format
    /// @param actual The actual length of the OP_RETURN data
    /// @param expected The expected length of the OP_RETURN data
    error InvalidOpReturnLength(uint256 actual, uint256 expected);

    /// @notice Thrown when OP_RETURN data is incorrectly formatted at a specific index
    /// @param index The index where the formatting error occurred
    error IncorrectlyFormedOpReturn(uint256 index);

    /// @notice Thrown when a transaction output script doesn't match the expected format
    /// @param actual The actual script bytes found
    /// @param expected The expected script bytes
    error IncorrectOutputScript(bytes actual, bytes expected);

    /// @notice Thrown when a public key is invalid or malformed
    /// @param publicKey The invalid public key that was provided
    error InvalidPublicKey(bytes32 publicKey);

    /// @notice Thrown when a timelock blocks is invalid or zero
    /// @param timelockBlocks The invalid timelock blocks that was provided
    error InvalidTimelockBlocks(uint32 timelockBlocks);

    /// @notice Thrown when a public key has invalid length
    /// @param length The invalid length that was provided
    error InvalidPublicKeyLength(uint256 length);

    /// @notice Error thrown when the committee public key has an invalid length
    /// @param length The actual length provided
    /// @param expected The expected length (33 bytes)
    error InvalidCommitteePublicKeyLength(uint256 length, uint256 expected);

    /// @notice Error thrown when the committee public key is all zeros
    error InvalidCommitteePublicKeyZero();

    /// @notice Thrown when an address is invalid or zero address
    /// @param _address The invalid address that was provided
    error InvalidAddress(address _address);

    /// @notice Thrown when a value doesn't match the expected amount
    /// @param _value The actual value provided
    /// @param expected The expected value
    error InvalidValue(uint64 _value, uint64 expected);

    /// @notice Thrown when an input amount is invalid or zero
    /// @param _value The invalid input amount
    error InvalidInputAmount(uint64 _value);

    /// @notice Thrown when an output amount doesn't match the expected value
    /// @param actual The actual output amount
    /// @param expected The expected output amount
    error InvalidOutputAmount(uint64 actual, uint64 expected);

    /// @notice Error thrown when an account is not authorized
    /// @param account The unauthorized account
    error UnauthorizedAccount(address account);

    /// @notice Thrown when an address is zero
    error InvalidZeroAddress();

    /// @notice Event emitted when pegin manager address is updated
    /// @param peginManager The new peg manager address
    event PeginManagerUpdated(address peginManager);
}
