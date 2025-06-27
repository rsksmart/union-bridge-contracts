// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// https://github.com/witnet/elliptic-curve-solidity/blob/master/contracts/EllipticCurve.sol
import {EllipticCurve} from "elliptic-curve-solidity/contracts/EllipticCurve.sol";

/**
 * @title Secp256k1 Elliptic Curve
 * @notice Library for secp256k1 elliptic curve operations used in Bitcoin cryptography
 * @dev Particularization of Elliptic Curve for secp256k1 curve parameters
 * @dev Used for Bitcoin public key operations and signature verification
 * @author Witnet Foundation
 */
library Secp256k1 {
    // Secp256k1 Curve Parameters
    /// @dev Generator point x-coordinate for secp256k1 curve
    /// @dev Base point G used for public key generation
    uint256 public constant GX = 0x79BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798;

    /// @dev Generator point y-coordinate for secp256k1 curve
    /// @dev Base point G used for public key generation
    uint256 public constant GY = 0x483ADA7726A3C4655DA4FBFC0E1108A8FD17B448A68554199C47D08FFB10D4B8;

    /// @dev Coefficient 'a' in the secp256k1 curve equation y² = x³ + ax + b
    /// @dev For secp256k1, a = 0
    uint256 public constant AA = 0;

    /// @dev Coefficient 'b' in the secp256k1 curve equation y² = x³ + ax + b
    /// @dev For secp256k1, b = 7
    uint256 public constant BB = 7;

    /// @dev Prime field modulus for secp256k1 curve
    /// @dev Defines the finite field over which the curve is defined
    uint256 public constant PP = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F;

    /// @notice Derives the y coordinate from a compressed-format point x
    /// @dev Implements the algorithm from [SEC-1](https://www.secg.org/SEC1-Ver-1.0.pdf)
    /// @param _prefix Parity byte (0x02 for even y, 0x03 for odd y)
    /// @param _x X coordinate of the point
    /// @return y Y coordinate of the point
    function deriveY(uint8 _prefix, uint256 _x) internal pure returns (uint256) {
        return EllipticCurve.deriveY(_prefix, _x, AA, BB, PP);
    }

    /// @notice Check whether point (x,y) is on the secp256k1 curve
    /// @dev Verifies that the point satisfies the curve equation y² = x³ + 7
    /// @param _x X coordinate of the point to check
    /// @param _y Y coordinate of the point to check
    /// @return true if the point is on the curve, false otherwise
    function isOnCurve(uint256 _x, uint256 _y) internal pure returns (bool) {
        return EllipticCurve.isOnCurve(_x, _y, AA, BB, PP);
    }

    /// @notice Add two points (x1, y1) and (x2, y2) in affine coordinates
    /// @dev Performs elliptic curve point addition: P1 + P2
    /// @param _x1 X coordinate of the first point P1
    /// @param _y1 Y coordinate of the first point P1
    /// @param _x2 X coordinate of the second point P2
    /// @param _y2 Y coordinate of the second point P2
    /// @return (qx, qy) Result of P1 + P2 in affine coordinates
    function ecAdd(uint256 _x1, uint256 _y1, uint256 _x2, uint256 _y2) internal pure returns (uint256, uint256) {
        return EllipticCurve.ecAdd(_x1, _y1, _x2, _y2, AA, PP);
    }

    /// @notice Multiply point (x1, y1) by scalar k in affine coordinates
    /// @dev Performs scalar multiplication: k * P
    /// @param _k Scalar to multiply the point by
    /// @param _x X coordinate of the point P
    /// @param _y Y coordinate of the point P
    /// @return (qx, qy) Result of k * P in affine coordinates
    function ecMul(uint256 _k, uint256 _x, uint256 _y) internal pure returns (uint256, uint256) {
        return EllipticCurve.ecMul(_k, _x, _y, AA, PP);
    }
}
