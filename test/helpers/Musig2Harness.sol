// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Musig2, Point, Nonce} from "src/Musig2.sol";
import {Secp256k1} from "src/libraries/Secp256k1.sol";

/// @title SPVHarness
/// @notice Wrapper for testing Musig2
contract Musig2Harness is Musig2 {
    function ecAdd(uint256 x1, uint256 y1, uint256 x2, uint256 y2) public pure returns (uint256 rx, uint256 ry) {
        return _ecAdd(x1, y1, x2, y2);
    }

    function _ecAdd(uint256 x1, uint256 y1, uint256 x2, uint256 y2)
        internal
        pure
        override
        returns (uint256 rx, uint256 ry)
    {
        return Secp256k1.ecAdd(x1, y1, x2, y2);
    }

    function ecMul(uint256 x, uint256 y, uint256 scalar) public pure returns (uint256 rx, uint256 ry) {
        return _ecMul(x, y, scalar);
    }

    function _ecMul(uint256 x, uint256 y, uint256 scalar) internal pure override returns (uint256 rx, uint256 ry) {
        return Secp256k1.ecMul(scalar, x, y);
    }

    function insertionSort(Point[] memory points) public pure returns (Point[] memory) {
        return _insertionSort(points);
    }

    function toCompressPubKey(Point memory point) public pure returns (bytes memory) {
        return _toCompressPubKey(point);
    }

    function aggregatedNonce(uint256 xOnlyAggregatedPubKey, Nonce[] memory _nonces, bytes memory _message)
        external
        view
        returns (Point memory adaptedAggregatedNonce, uint256 nonceCoef)
    {
        return _aggregatedNonce(xOnlyAggregatedPubKey, _nonces, _message);
    }

    function aggregatedAndEffectivePubKeys(Point[] memory _participantsPubKeys, uint256 _pubKeyIndex)
        public
        view
        returns (Point memory aggregatedPubKey, Point memory individualEffectivePubkey)
    {
        return _aggregatedAndEffectivePubKey(_participantsPubKeys, _pubKeyIndex);
    }
}
