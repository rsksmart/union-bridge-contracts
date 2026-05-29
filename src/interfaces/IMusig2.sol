// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Point struct for MuSig2
/// @dev Used to represent a point on the secp256k1 curve
struct Point {
    /// @notice x coordinate of the point
    uint256 x;
    /// @notice y coordinate of the point
    uint256 y;
}

/// @notice Nonce struct for MuSig2
/// @dev Used to represent a nonce for MuSig2
struct Nonce {
    /// @notice R1 nonce
    Point R1;
    /// @notice R2 nonce
    Point R2;
}

/// @notice Interface for pauser in the union bridge
/// @dev This interface provides error definitions for pauser operations
/// @dev Used to implement open zeppelin's pauser functionality
interface IMusig2 {
    /// @notice Checks if a public key is valid
    /// @param pubKey The public key to check
    /// @return true if the public key is valid, false otherwise
    function isValidPubKey(Point memory pubKey) external pure returns (bool);

    /// @notice Verify a partial signature for a given public key index
    /// @dev This function expects the public keys to be in the same order and have the same length as the nonces.
    /// @dev This function expects the public keys and nonces to be already validated.
    /// @dev We are following the specification BIP-327: MuSig2 for BIP340-compatible Multi-Signatures https://github.com/bitcoin/bips/blob/master/bip-0327.mediawiki.
    /// @dev We check for correctnes of the implementation against the rust musgi2 implementation: https://github.com/FairgateLabs/rust-bitvmx-key-manager/pull/48
    /// @dev The implementation uses the RSKJ Secp256k1 precompiled contract: https://github.com/rsksmart/rskj/pull/3210/files#diff-6449788dd39d9278472df8fb3a946ef83b7d16c8452a90cc6e2a238f6615e8bf
    /// @dev The specification can be found in RSKIP-516: https://github.com/rsksmart/RSKIPs/blob/master/IPs/RSKIP516.md.
    /// @param _partialSignature The partial signature
    /// @param _pubKeyIndex The index of the public key to verify
    /// @param _participantsPubKeys The list of public keys to aggregate
    /// @param _nonces The list of nonces
    /// @param _message The message to sign
    /// @return true if the partial signature is valid, false otherwise
    function verifyPartialSignature(
        uint256 _partialSignature,
        uint256 _pubKeyIndex,
        Point[] memory _participantsPubKeys,
        Nonce[] memory _nonces,
        bytes memory _message
    ) external view returns (bool);

    /// @notice Thrown when the nonces length is invalid
    /// @param length The actual length of the nonces
    /// @param pubKeysLength The actual length of the public keys
    error InvalidNoncesLength(uint256 length, uint256 pubKeysLength);
    /// @notice Thrown when the public key index is invalid
    /// @param index The actual index of the public key
    /// @param pubKeysLength The actual length of the public keys
    error InvalidPubKeyIndex(uint256 index, uint256 pubKeysLength);
    /// @notice Thrown when the participants length is invalid
    /// @param length The actual length of the participants
    /// @param minLength The minimum length expected
    error InvalidParticipantsLength(uint256 length, uint256 minLength);
    /// @notice Thrown when all public keys are the same
    error AllPubkeysAreTheSame();
    /// @notice Thrown when the ec add precompile failed
    error EcAddPrecompileFailed();
    /// @notice Thrown when the ec mul precompile failed
    error EcMulPrecompileFailed();
    /// @notice Thrown when the partial signature is invalid
    error InvalidPartialSignature();
    /// @notice Thrown when the message is invalid
    error InvalidMessage();
}
