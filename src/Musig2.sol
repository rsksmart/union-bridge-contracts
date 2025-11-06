// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BtcTaproot} from "./libraries/BtcTaproot.sol";
import {Secp256k1} from "./libraries/Secp256k1.sol";
import {IMusig2, Point, Nonce} from "./interfaces/IMusig2.sol";
import {BytesHelper} from "./libraries/BytesHelper.sol";
import {Constants} from "./libraries/Constants.sol";

/// @title Musig2 Contract
/// @notice Contract for verifying Musig2 signatures
/// @dev MuSig2 is a two-round multi-signature scheme that allows multiple parties to jointly produce a single Schnorr signature. It provides better privacy and efficiency compared to script-based multi-signatures, as the aggregated signature is indistinguishable from a single-party signature.
/// @dev MuSig2 allows groups of mutually distrusting parties to cooperatively sign data and aggregate their signatures into a single aggregated signature which is indistinguishable from a signature made by a single private key. The group collectively controls an aggregated public key which can only create signatures if everyone in the group cooperates (AKA an N-of-N multisignature scheme). MuSig2 is optimized to support secure signature aggregation with only two round-trips of network communication.
/// @dev Specifically, this library [implements BIP-0327](https://en.bitcoin.it/wiki/BIP_0327), for creating and verifying signatures which validate under Bitcoin consensus rules, but the protocol is flexible and can be applied to any N-of-N multisignature use-case.
/// @dev The process of cooperative signing runs like so:
/// @dev 1. All signers share their public keys with one-another. The group computes an aggregated public key which they collectively control.
/// @dev 2. In the first signing round, signers generate and share nonces (random numbers) with one-another. These nonces have both secret and public versions. Only the public nonce (AKA PubNonce) should be shared, while the corresponding secret nonce (AKA SecNonce) must be kept secret.
/// @dev 3. Once every signer has received the public nonces of every other signer, each signer makes a partial signature for a message using their secret key and secret nonce.
/// @dev 4. In the second signing round, signers share their partial signatures with one-another. Partial signatures can be verified to place blame on misbehaving signers (but are not themselves unforgeable).
/// @dev 5. A valid set of partial signatures can be aggregated into a final signature, which is just a normal Schnorr signature, valid under the aggregated public key.
/// @dev This Contract uses the secp256k1 precompiled contracts from the RSKJ implementation.
/// @dev Following RSKIP-516: https://github.com/rsksmart/RSKIPs/blob/master/IPs/RSKIP516.md
/// @dev code: https://github.com/rsksmart/rskj/pull/3210/files#diff-6449788dd39d9278472df8fb3a946ef83b7d16c8452a90cc6e2a238f6615e8bf
/// @author The Fairgate Team
contract Musig2 is IMusig2 {
    /// @notice KeyAgg list for MuSig2
    bytes constant KEYAGG_LIST = bytes("KeyAgg list");
    /// @notice KeyAgg coefficient for MuSig2
    bytes constant KEYAGG_COEFFICIENT = bytes("KeyAgg coefficient");
    /// @notice Nonce coefficient for MuSig2
    bytes constant MUSIG_NONCECOEF = bytes("MuSig/noncecoef");
    /// @notice Challenge for BIP0340
    bytes constant BIP0340_CHALLENGE = bytes("BIP0340/challenge");

    /// @notice Addresses of the secp256k1 multiplication Rskj precompiled contracts
    /// @dev Following RSKIP-516: https://github.com/rsksmart/RSKIPs/blob/master/IPs/RSKIP516.md
    /// @dev code: https://github.com/rsksmart/rskj/pull/3210/files#diff-6449788dd39d9278472df8fb3a946ef83b7d16c8452a90cc6e2a238f6615e8bf
    address constant SECP256K1_ADDITION_ADDR = address(0x0000000000000000000000000000000001000016);
    // @notice Addresses of the secp256k1 addition  Rskj precompiled contracts
    /// @dev Following RSKIP-516: https://github.com/rsksmart/RSKIPs/blob/master/IPs/RSKIP516.md
    /// @dev code: https://github.com/rsksmart/rskj/pull/3210/files#diff-6449788dd39d9278472df8fb3a946ef83b7d16c8452a90cc6e2a238f6615e8bf
    address constant SECP256K1_MULTIPLICATION_ADDR = address(0x0000000000000000000000000000000001000017);

    /// @notice Check if a public key is valid
    /// @param pubKey The public key to check
    /// @return true if the public key is valid, false otherwise
    function isValidPubKey(Point memory pubKey) external pure returns (bool) {
        return Secp256k1.isOnCurve(pubKey.x, pubKey.y);
    }

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
    ) external view returns (bool) {
        // We expect that all public keys are previously validated
        uint256 length = _participantsPubKeys.length;
        if (length < 2) {
            revert InvalidParticipantsLength(length, 2);
        }
        if (_pubKeyIndex >= length) {
            revert InvalidPubKeyIndex(_pubKeyIndex, length);
        }
        // We limit the number of participants to the maximum number of candidates
        if (length > Constants.MAX_CANDIDATES_SIZE_PER_ROLE) {
            revert InvalidParticipantsLength(length, Constants.MAX_CANDIDATES_SIZE_PER_ROLE);
        }
        if (_nonces.length != length) {
            revert InvalidNoncesLength(_nonces.length, length);
        }
        if (_message.length == 0) {
            revert InvalidMessage();
        }

        // participants and  index are validated when calling this function.
        (Point memory aggregatedPubKey, Point memory individualEffectivePubkey) =
            _aggregatedAndEffectivePubKey(_participantsPubKeys, _pubKeyIndex);
        (Point memory adaptedAggregatedNonce, uint256 nonceCoef) =
            _aggregatedNonce(aggregatedPubKey.x, _nonces, _message);
        // partial signature is validated when calling this function.
        return _verifyChallenge(
            _partialSignature,
            _effectiveNonce(_nonces[_pubKeyIndex], nonceCoef, adaptedAggregatedNonce),
            _challengePoint(adaptedAggregatedNonce, individualEffectivePubkey, aggregatedPubKey, _message)
        );
    }

    /// @notice Calculate an aggregated public key from a list of public keys
    /// @param _participantsPubKeys The list of public keys to aggregate
    /// @return aggregatedPubKey The aggregated public key
    /// @return individualEffectivePubkey The individual effective public key
    function _aggregatedAndEffectivePubKey(Point[] memory _participantsPubKeys, uint256 _pubKeyIndex)
        internal
        view
        returns (Point memory aggregatedPubKey, Point memory individualEffectivePubkey)
    {
        // We expect that all parameters are previously validated
        uint256 length = _participantsPubKeys.length;

        // Save the individual public key before sorting
        Point memory individualPubkey = Point({x: 0, y: 0});
        individualPubkey.x = _participantsPubKeys[_pubKeyIndex].x;
        individualPubkey.y = _participantsPubKeys[_pubKeyIndex].y;

        // ------------------- Public Key List Sorting Step -------------------
        // Sort in-place (modifies the array) the compressed public keys
        _participantsPubKeys = _insertionSort(_participantsPubKeys);

        // Compress the public keys
        bytes[] memory compressedPubKeys = new bytes[](length);
        for (uint256 i = 0; i < length; ++i) {
            compressedPubKeys[i] = _toCompressPubKey(_participantsPubKeys[i]);
        }

        // ------------------- PK2 Calculation Step -------------------
        // If all pubkeys are the same, `pk2` will be set to `None`, indicating
        // that every public key `X` should be tweaked with a coefficient `H_agg(L, X)`
        // to prevent collisions (See appendix B of the musig2 paper).
        bytes memory pk2 = compressedPubKeys[0];
        for (uint256 i = 1; i < length; ++i) {
            if (!_equalCompressedPubKeys(compressedPubKeys[i], pk2)) {
                pk2 = compressedPubKeys[i];
                break;
            }
        }
        // Instead of twaking we should revert if all pubkeys are the same in this implementation
        if (_equalCompressedPubKeys(pk2, compressedPubKeys[0])) {
            revert AllPubkeysAreTheSame();
        }

        // ------------------- Public Key List Hash Step -------------------
        // Compute the hash of the public keys
        bytes memory data = "";
        for (uint256 i = 0; i < length; ++i) {
            // slither-disable-next-line encode-packed-collision
            data = abi.encodePacked(data, compressedPubKeys[i]);
        }
        bytes32 pubKeyListHash = BtcTaproot.taggedHash(KEYAGG_LIST, data);

        // ------------------- Effective Pubkey Step -------------------
        // Compute the effective pubkeys, key coefficients and aggregated public key
        for (uint256 i = 0; i < length; ++i) {
            Point memory effectivePubKey = Point({x: 0, y: 0});
            // Compute the key coefficient
            uint256 key_coefficient = 1;
            if (!_equalCompressedPubKeys(pk2, compressedPubKeys[i])) {
                bytes32 coefficientHash =
                    BtcTaproot.taggedHash(KEYAGG_COEFFICIENT, abi.encodePacked(pubKeyListHash, compressedPubKeys[i]));
                // Reduce from hash to a scalar
                key_coefficient = _reduceToScalar(coefficientHash);
            }

            // Compute the effective pubkey
            (effectivePubKey.x, effectivePubKey.y) =
                _ecMul(_participantsPubKeys[i].x, _participantsPubKeys[i].y, key_coefficient);

            // if it's the individual pubkey, we should use it to compute the effective pubkey
            if (individualPubkey.x == _participantsPubKeys[i].x && individualPubkey.y == _participantsPubKeys[i].y) {
                individualEffectivePubkey.x = effectivePubKey.x;
                individualEffectivePubkey.y = effectivePubKey.y;
            }

            // Compute the aggregated public key
            if (i == 0) {
                aggregatedPubKey.x = effectivePubKey.x;
                aggregatedPubKey.y = effectivePubKey.y;
            } else {
                (aggregatedPubKey.x, aggregatedPubKey.y) =
                    _ecAdd(aggregatedPubKey.x, aggregatedPubKey.y, effectivePubKey.x, effectivePubKey.y);
            }
        }

        return (aggregatedPubKey, individualEffectivePubkey);
    }

    function _effectiveNonce(Nonce memory _individualPubNonce, uint256 _nonceCoef, Point memory _adaptedAggregatedNonce)
        internal
        view
        returns (Point memory effectiveNonce)
    {
        Point memory pubNonceCoef = Point({x: 0, y: 0});
        (pubNonceCoef.x, pubNonceCoef.y) = _ecMul(_individualPubNonce.R2.x, _individualPubNonce.R2.y, _nonceCoef);
        (effectiveNonce.x, effectiveNonce.y) =
            _ecAdd(_individualPubNonce.R1.x, _individualPubNonce.R1.y, pubNonceCoef.x, pubNonceCoef.y);

        // if has odd y use the negative point to get even y
        if (_adaptedAggregatedNonce.y % 2 == 1) {
            // Negate the point to get even y, x stays the same
            effectiveNonce.y = Secp256k1.PP - effectiveNonce.y;
        }
        return effectiveNonce;
    }

    function _challengePoint(
        Point memory _adaptedAggregatedNonce,
        Point memory _effectivePubkey,
        Point memory _aggregatedPubKey,
        bytes memory _message
    ) internal view returns (Point memory challengePoint) {
        // ------------------- Challenge Hash Tweak and Parity Step -------------------
        // compute_challenge_hash_tweak
        bytes memory data = abi.encodePacked(_adaptedAggregatedNonce.x, _aggregatedPubKey.x, _message);
        bytes32 bip0340ChallengeHash = BtcTaproot.taggedHash(BIP0340_CHALLENGE, data);

        uint256 e = _reduceToScalar(bip0340ChallengeHash);
        uint256 challengeParity = _aggregatedPubKey.y % 2;
        // TODO if there is a tweak, we should use it to calculate the parity
        // let challengeParity = aggregated_pub_key_parity ^ key_agg_ctx.parity_acc;
        (challengePoint.x, challengePoint.y) = _ecMul(_effectivePubkey.x, _effectivePubkey.y, e);
        if (challengeParity == 1) {
            // Negate the point to get even y, x stays the same
            challengePoint.y = Secp256k1.PP - challengePoint.y;
        }
        return challengePoint;
    }

    function _verifyChallenge(
        uint256 _partialSignature,
        Point memory _individualEffectiveNonce,
        Point memory _aggregatedChallengePoint
    ) internal view returns (bool) {
        if (_partialSignature == 0) {
            revert InvalidPartialSignature();
        }
        // G is the generator point
        Point memory G = Point({x: Secp256k1.GX, y: Secp256k1.GY});
        // ------------------- Verification Step -------------------
        // s * G == R + (g * gacc * e * a * P)
        (uint256 sGx, uint256 sGy) = _ecMul(G.x, G.y, _partialSignature);
        (uint256 Rx, uint256 Ry) = _ecAdd(
            _individualEffectiveNonce.x,
            _individualEffectiveNonce.y,
            _aggregatedChallengePoint.x,
            _aggregatedChallengePoint.y
        );
        return sGx == Rx && sGy == Ry;
    }

    /// @notice Calculate the adapted aggregated nonce
    /// @param xOnlyAggregatedPubKey The x-only aggregated public key
    /// @param _nonces The list of nonces
    /// @param _message The message to sign
    /// @return adaptedAggregatedNonce The adapted aggregated nonce
    /// @return nonceCoef The nonce coefficient
    function _aggregatedNonce(uint256 xOnlyAggregatedPubKey, Nonce[] memory _nonces, bytes memory _message)
        internal
        view
        returns (Point memory adaptedAggregatedNonce, uint256 nonceCoef)
    {
        // ------------------- Nonce Aggregation Step -------------------
        uint256 length = _nonces.length;
        // We limit the number of participants to the maximum number of candidates
        if (length > Constants.MAX_CANDIDATES_SIZE_PER_ROLE) {
            revert InvalidParticipantsLength(length, Constants.MAX_CANDIDATES_SIZE_PER_ROLE);
        }
        // Manual calculation of the aggregated nonce (as its a sum no need to be ordered by pubkey)
        Nonce memory aggregatedNonce = Nonce({R1: Point({x: 0, y: 0}), R2: Point({x: 0, y: 0})}); // point at infinity
        for (uint256 i = 0; i < length;) {
            (aggregatedNonce.R1.x, aggregatedNonce.R1.y) =
                _ecAdd(aggregatedNonce.R1.x, aggregatedNonce.R1.y, _nonces[i].R1.x, _nonces[i].R1.y);
            (aggregatedNonce.R2.x, aggregatedNonce.R2.y) =
                _ecAdd(aggregatedNonce.R2.x, aggregatedNonce.R2.y, _nonces[i].R2.x, _nonces[i].R2.y);
            unchecked {
                ++i;
            }
        }

        // ------------------- Nonce Coefficient Step -------------------
        // Compute the nonce coefficient
        // slither-disable-next-line encode-packed-collision
        bytes memory data = abi.encodePacked(
            _toCompressPubKey(aggregatedNonce.R1),
            _toCompressPubKey(aggregatedNonce.R2),
            xOnlyAggregatedPubKey,
            _message
        );
        bytes32 nonceCoefHash = BtcTaproot.taggedHash(MUSIG_NONCECOEF, data);

        // b = nonce_coefficient
        nonceCoef = _reduceToScalar(nonceCoefHash);
        Point memory aggCoefPoint = Point({x: 0, y: 0});
        (aggCoefPoint.x, aggCoefPoint.y) = _ecMul(aggregatedNonce.R2.x, aggregatedNonce.R2.y, nonceCoef);
        // final nonce
        (adaptedAggregatedNonce.x, adaptedAggregatedNonce.y) =
            _ecAdd(aggregatedNonce.R1.x, aggregatedNonce.R1.y, aggCoefPoint.x, aggCoefPoint.y);

        // If this point winds up at infinity (probably due to a mischevious signer), we
        // instead return the generator point `G`.
        if (adaptedAggregatedNonce.x == 0 && adaptedAggregatedNonce.y == 0) {
            adaptedAggregatedNonce.x = Secp256k1.GX;
            adaptedAggregatedNonce.y = Secp256k1.GY;
        }

        // adapted_nonce = final_nonce + adaptor_point
        // As adaptor point is zero (point at infinity) when verifying the partial signature, we don't need to add it to the final nonce
        return (adaptedAggregatedNonce, nonceCoef);
    }

    /// @notice Compare two compressed public keys for equality
    /// @param a The first compressed public key
    /// @param b The second compressed public key
    /// @return true if the compressed public keys are equal, false otherwiseß
    function _equalCompressedPubKeys(bytes memory a, bytes memory b) internal pure returns (bool) {
        return keccak256(a) == keccak256(b);
    }

    /// @notice Reduce a hash to a scalar that exists in the secp256k1 curve
    /// @param _hash The hash to reduce
    /// @return scalar The reduced scalar
    function _reduceToScalar(bytes32 _hash) internal pure returns (uint256) {
        return uint256(_hash) % Secp256k1.N;
    }

    /// @notice Compare two public keys in lexicographic order
    /// @param a The first public key
    /// @param b The second public key
    /// @return true if a is less than b, false otherwise
    function _isLessThan(Point memory a, Point memory b) internal pure returns (bool) {
        // Musig uses Lexicographic order on compressed pubkeys(0x02/0x03 + x)
        bool isEvenA = a.y % 2 == 0;
        bool isEvenB = b.y % 2 == 0;
        return isEvenA != isEvenB ? isEvenA : a.x < b.x;
    }

    /// @notice Compress a public key to a 33-byte compressed format
    /// @param pubKey The public key to compress
    /// @return compressedPubKey The compressed public key in 0x02/0x03 + x format
    function _toCompressPubKey(Point memory pubKey) internal pure returns (bytes memory) {
        return abi.encodePacked((pubKey.y % 2 == 0) ? bytes1(0x02) : bytes1(0x03), pubKey.x);
    }

    /// @notice Sorts the array of points in-place (ascending)
    /// @dev Uses insertion sort (O(n²)), best for small arrays (<100 elements)
    /// @param points The array of points to sort
    /// @return points The sorted array of points
    function _insertionSort(Point[] memory points) internal pure returns (Point[] memory) {
        uint256 n = points.length;

        for (uint256 i = 1; i < n;) {
            Point memory key = points[i];
            uint256 j = i;

            // Move elements that are greater than key one position ahead
            while (j > 0 && _isLessThan(key, points[j - 1])) {
                points[j] = points[j - 1];
                unchecked {
                    --j;
                }
            }
            points[j] = key;
            unchecked {
                ++i;
            }
        }
        return points;
    }

    /// @notice Call ecMul precompile: input (x,y,scalar) -> returns (x',y')
    /// @dev rskj-core/src/test/resources/dsl/ec_precompiled_contracts/secp256k1_multiplication.txt
    /// @dev https://github.com/rsksmart/rskj/pull/3210/files#diff-1361f673170f1b7be5d13469bfe16cdf0b1548c3a09416c8b071a49ad8704b46R16
    /// @param x The x-coordinate of the point
    /// @param y The y-coordinate of the point
    /// @param scalar The scalar to multiply by
    /// @return rx The x-coordinate of the result
    /// @return ry The y-coordinate of the result
    function _ecMul(uint256 x, uint256 y, uint256 scalar) internal view virtual returns (uint256 rx, uint256 ry) {
        bytes memory data = abi.encode(x, y, scalar);
        (rx, ry) = _secp256k1AssemblyCall(SECP256K1_MULTIPLICATION_ADDR, data);
        if (rx == 0 && ry == 0) {
            revert EcMulPrecompileFailed();
        }
    }

    /// @notice Call ecAdd precompile: input (x1,y1,x2,y2) -> returns (x3,y3)
    /// @dev rskj-core/src/test/resources/dsl/ec_precompiled_contracts/secp256k1_addition.txt
    /// @dev https://github.com/rsksmart/rskj/pull/3210/files#diff-98501e625b566e9397c6eba238c2e7b34decae13b6ddba8645792740bed3665cR17
    /// @param x1 The x-coordinate of the first point
    /// @param y1 The y-coordinate of the first point
    /// @param x2 The x-coordinate of the second point
    /// @param y2 The y-coordinate of the second point
    /// @return rx The x-coordinate of the result
    /// @return ry The y-coordinate of the result
    function _ecAdd(uint256 x1, uint256 y1, uint256 x2, uint256 y2)
        internal
        view
        virtual
        returns (uint256 rx, uint256 ry)
    {
        bytes memory data = abi.encode(x1, y1, x2, y2);
        (rx, ry) = _secp256k1AssemblyCall(SECP256K1_ADDITION_ADDR, data);
        if (rx == 0 && ry == 0) {
            revert EcAddPrecompileFailed();
        }
    }

    /// @notice Call a precompile secp256k1 contract using assembly calls
    /// @param addr The address of the precompile contract to call
    /// @param data The data to send to the precompile contract
    /// @return x The x-coordinate of the result
    /// @return y The y-coordinate of the result
    function _secp256k1AssemblyCall(address addr, bytes memory data) internal view returns (uint256 x, uint256 y) {
        bytes memory out = new bytes(64); // 2 * 32 bytes for x and y
        // we use assembly to call the precompile contract as it does not have an ABI
        // slither-disable-next-line assembly
        assembly {
            let success := staticcall(gas(), addr, add(data, 32), mload(data), add(out, 32), 64)
            // Check if staticcall was successful
            if success {
                // Load the results as uint256
                x := mload(add(out, 32))
                y := mload(add(out, 64))
            }
            // If staticcall fails, x and y will be 0 to indicate failure
        }
    }
}
