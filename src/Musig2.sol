// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {console} from "forge-std/console.sol";
//import {Vm} from "forge-std/Vm.sol";
import {BtcTaproot} from "./libraries/BtcTaproot.sol";
import {Secp256k1} from "./libraries/Secp256k1.sol";
import {IMusig2, Point, Nonce} from "./interfaces/IMusig2.sol";
import {BytesHelper} from "./libraries/BytesHelper.sol";
import {Constants} from "./libraries/Constants.sol";

/// @title Musig2 Library
/// @notice Library for verifying Musig2 signatures
/// @dev MuSig2 is a two-round multi-signature scheme that allows multiple parties to jointly produce a single Schnorr signature. It provides better privacy and efficiency compared to script-based multi-signatures, as the aggregated signature is indistinguishable from a single-party signature.
/// @dev MuSig2 allows groups of mutually distrusting parties to cooperatively sign data and aggregate their signatures into a single aggregated signature which is indistinguishable from a signature made by a single private key. The group collectively controls an aggregated public key which can only create signatures if everyone in the group cooperates (AKA an N-of-N multisignature scheme). MuSig2 is optimized to support secure signature aggregation with only two round-trips of network communication.
/// @dev Specifically, this library [implements BIP-0327](https://en.bitcoin.it/wiki/BIP_0327), for creating and verifying signatures which validate under Bitcoin consensus rules, but the protocol is flexible and can be applied to any N-of-N multisignature use-case.
/// @dev The process of cooperative signing runs like so:
/// @dev 1. All signers share their public keys with one-another. The group computes an aggregated public key which they collectively control.
/// @dev 2. In the first signing round, signers generate and share nonces (random numbers) with one-another. These nonces have both secret and public versions. Only the public nonce (AKA PubNonce) should be shared, while the corresponding secret nonce (AKA SecNonce) must be kept secret.
/// @dev 3. Once every signer has received the public nonces of every other signer, each signer makes a partial signature for a message using their secret key and secret nonce.
/// @dev 4. In the second signing round, signers share their partial signatures with one-another. Partial signatures can be verified to place blame on misbehaving signers (but are not themselves unforgeable).
/// @dev 5. A valid set of partial signatures can be aggregated into a final signature, which is just a normal Schnorr signature, valid under the aggregated public key.
/// @author Fairgate
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

    error InvalidParticipantsLength(uint256 length, uint256 minLength);
    error AllPubkeysAreTheSame();
    error EcAddPrecompileFailed();
    error EcMulPrecompileFailed();

    /// @notice Mapping of aggregated public keys to effective public keys
    /// @dev aggregatedPubKey The aggregated public key
    /// @dev participantPubKey The participant public key
    /// @dev effectivePubKey The effective public key Point structure
    mapping(bytes aggregatedPubKey => mapping(bytes compressedParticipantPubKey => Point effectivePubKey)) public
        effectivePubKeys;

    /// @notice Check if a public key is valid
    /// @param pubKey The public key to check
    /// @return true if the public key is valid, false otherwise
    function isValidPubKey(Point memory pubKey) external pure returns (bool) {
        return Secp256k1.isOnCurve(pubKey.x, pubKey.y);
    }

    /// @notice Create an aggregated public key from a list of public keys
    /// @param _participantsPubKeys The list of public keys to aggregate
    /// @return aggregatedPubKey The aggregated public key
    function createAggregatedPubKey(Point[] memory _participantsPubKeys)
        external
        returns (Point memory aggregatedPubKey)
    {
        // We expect that all public keys are previously validated
        uint256 length = _participantsPubKeys.length;
        if (length < 2) {
            revert InvalidParticipantsLength(length, 2);
        }
        // We limit the number of participants to the maximum number of candidates
        if (length > Constants.MAX_CANDIDATES_SIZE_PER_ROLE) {
            revert InvalidParticipantsLength(length, Constants.MAX_CANDIDATES_SIZE_PER_ROLE);
        }

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
            data = abi.encodePacked(data, compressedPubKeys[i]);
        }
        bytes32 pubKeyListHash = BtcTaproot.taggedHash(KEYAGG_LIST, data);

        // ------------------- Effective Pubkey Step -------------------
        // Compute the effective pubkeys, key coefficients and aggregated public key
        Point[] memory effective_pubkeys = new Point[](length);
        for (uint256 i = 0; i < length; ++i) {
            // Compute the key coefficient
            uint256 key_coefficient = 1;
            if (!_equalCompressedPubKeys(pk2, compressedPubKeys[i])) {
                bytes32 coefficientHash =
                    BtcTaproot.taggedHash(KEYAGG_COEFFICIENT, abi.encodePacked(pubKeyListHash, compressedPubKeys[i]));
                // Reduce from hash to a scalar
                key_coefficient = _reduceToScalar(coefficientHash);
            }

            // Compute the effective pubkey
            (effective_pubkeys[i].x, effective_pubkeys[i].y) =
                _ecMul(_participantsPubKeys[i].x, _participantsPubKeys[i].y, key_coefficient);

            // Compute the aggregated public key
            if (i == 0) {
                aggregatedPubKey = effective_pubkeys[i];
            } else {
                (aggregatedPubKey.x, aggregatedPubKey.y) =
                    _ecAdd(aggregatedPubKey.x, aggregatedPubKey.y, effective_pubkeys[i].x, effective_pubkeys[i].y);
            }
        }

        // Store the effective pubkeys in the mapping
        bytes memory compressedAggregatedPubKey = _toCompressPubKey(aggregatedPubKey);
        for (uint256 i = 0; i < length; ++i) {
            // store a map with the pubkey and the effective pubkey to easily obtain it for verification
            effectivePubKeys[compressedAggregatedPubKey][compressedPubKeys[i]] = effective_pubkeys[i];
        }

        return aggregatedPubKey;
    }

    function calculateAggregatedNonce(uint256 xOnlyAggregatedPubKey, Nonce[] memory _nonces, bytes memory _message)
        external
        view
        returns (Point memory adaptedAggregatedNonce)
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
        bytes memory data = abi.encodePacked(
            _toCompressPubKey(aggregatedNonce.R1),
            _toCompressPubKey(aggregatedNonce.R2),
            xOnlyAggregatedPubKey,
            _message
        );
        bytes32 nonceCoefHash = BtcTaproot.taggedHash(MUSIG_NONCECOEF, data);

        // b = nonce_coefficient
        uint256 b = _reduceToScalar(nonceCoefHash);
        Point memory aggCoefPoint;
        (aggCoefPoint.x, aggCoefPoint.y) = _ecMul(aggregatedNonce.R2.x, aggregatedNonce.R2.y, b);
        // final nonce
        (adaptedAggregatedNonce.x, adaptedAggregatedNonce.y) =
            _ecAdd(aggregatedNonce.R1.x, aggregatedNonce.R1.y, aggCoefPoint.x, aggCoefPoint.y);

        return adaptedAggregatedNonce;
    }

    function verifyPartialSignature(Point memory _aggregatedPubKey, bytes32 _message, bytes memory _partialSignature)
        external
        pure
        returns (bool)
    {
        return true;

        // // get inidividual pubkey and pubnonce
        // let individual_pubkey = pub_key_parts[0].clone();
        // let individual_pubnonce = nonces[0].get(0).unwrap().1.clone();
        // let mut effective_nonce = individual_pubnonce.R1 + b * individual_pubnonce.R2;
        // println!("effective_nonce: {:?}", effective_nonce.clone());

        // // if has odd y use the negative x to get even y
        // if adapted_nonce.has_odd_y() {
        //     effective_nonce = -effective_nonce;
        // }
        // let nonce_x_bytes = adapted_nonce.serialize_xonly();

        // // ------------------- Challenge Hash Tweak and Parity Step -------------------
        // // compute_challenge_hash_tweak
        // let bip0340_challenge_tag_hasher = Sha256::digest("BIP0340/challenge");
        // let hash: [u8; 32] = Sha256::new()
        //     .chain_update(&bip0340_challenge_tag_hasher)
        //     .chain_update(&bip0340_challenge_tag_hasher)
        //     .chain_update(&nonce_x_bytes)
        //     .chain_update(&xonly_aggregated_pub_key.serialize())
        //     .chain_update(message)
        //     .finalize()
        //     .into();
        // let e = MaybeScalar::reduce_from(&hash);

        // let effective_pubkey = effective_pubkeys_map
        //     .get(&individual_pubkey)
        //     .unwrap()
        //     .clone();

        // // s * G == R + (g * gacc * e * a * P)
        // let challenge_parity = aggregated_pub_key_parity;
        // // if there is a tweak, we should use it to calculate the parity
        // // let challenge_parity = aggregated_pub_key_parity ^ key_agg_ctx.parity_acc;
        // let mut challenge_point = e * effective_pubkey;
        // if challenge_parity == bitcoin::secp256k1::Parity::Odd {
        //     challenge_point = -challenge_point;
        // }
        // println!(
        //     "challenge_point: {:?}",
        //     challenge_point.serialize().as_hex().to_string()
        // );
        // println!(
        //     "effective_nonce: {:?}",
        //     effective_nonce.serialize().as_hex().to_string()
        // );

        // // ------------------- Verification Step -------------------
        // let partial_signature = partial_sigs_map
        //     .get(&individual_pubkey)
        //     .unwrap()
        //     .get(0)
        //     .unwrap()
        //     .1;
        // println!(
        //     "partial_signature: {:?}",
        //     partial_signature.serialize().as_hex().to_string()
        // );
        // println!(
        //     "partial_signature * musig2::secp::G: {:?}",
        //     (partial_signature * musig2::secp::G)
        //         .serialize()
        //         .as_hex()
        //         .to_string()
        // );
        // println!(
        //     "effective_nonce + challenge_point: {:?}",
        //     (effective_nonce + challenge_point)
        //         .serialize()
        //         .as_hex()
        //         .to_string()
        // );
        // assert_eq!(
        //     partial_signature * musig2::secp::G,
        //     effective_nonce + challenge_point,
        // );
    }

    /// @notice Compare two compressed public keys for equality
    /// @param a The first compressed public key
    /// @param b The second compressed public key
    /// @return true if the compressed public keys are equal, false otherwiseß
    function _equalCompressedPubKeys(bytes memory a, bytes memory b) internal pure returns (bool) {
        return keccak256(a) == keccak256(b);
    }

    function _toXOnlyPubKey(bytes memory _pubKey) internal pure returns (bytes32) {
        return BytesHelper.bytesToBytes32(_pubKey, 1); // skip the first byte which is the prefix
    }

    /// @notice Reduce a hash to a scalar that exists in the secp256k1 curve
    /// @param _hash The hash to reduce
    /// @return scalar The reduced scalar
    function _reduceToScalar(bytes32 _hash) internal pure returns (uint256) {
        return uint256(_hash) % Secp256k1.N;
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

    /// @notice Compare two public keys in lexicographic order
    /// @param a The first public key
    /// @param b The second public key
    /// @return true if a is less than b, false otherwise
    function _comparePubKeys(Point memory a, Point memory b) internal pure returns (bool) {
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
            while (j > 0 && _comparePubKeys(key, points[j - 1])) {
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
}
