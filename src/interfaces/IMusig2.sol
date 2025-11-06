// SPDX-License-Identifier: UNKNOWN
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

    /// @notice Create an aggregated public key from a list of public keys
    /// @param _participantsPubKeys The list of public keys to aggregate
    /// @return aggregatedPubKey The aggregated public key
    function createAggregatedPubKey(Point[] memory _participantsPubKeys)
        external
        returns (Point memory aggregatedPubKey);
}
