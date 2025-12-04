// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {IMusig2, Point, Nonce} from "src/interfaces/IMusig2.sol";
import {Musig2Harness} from "test/helpers/Musig2Harness.sol";

/// @title TestMusig2
/// @notice Test contract for the Musig2 library
/// @dev All values are obtained from the key manager test for musig2 at test_verify_signatures: https://github.com/FairgateLabs/rust-bitvmx-key-manager/pull/48/files#diff-da35d3b654d6bdc960c0b4e4724a605d564caf7ff4b5ad1468e0a79932e1a1b1R123
/// @dev Point is the x and y coordinates of the public key.
/// @dev it can be obtained from the unncompressed public key removing the 0x04 prefix, first 32 bytes are the x coordinate and the last 32 bytes are the y coordinate.
contract TestMusig2 is Test {
    Musig2Harness internal musig2;

    function setUp() external {
        musig2 = new Musig2Harness();
    }

    function test_toCompressPubKey_even_Success() external view {
        // Arrange
        Point memory point = Point({
            x: 0xba5734d8f7091719471e7f7ed6b9df170dc70cc661ca05e688601ad984f068b0,
            y: 0xd67351e5f06073092499336ab0839ef8a521afd334e53807205fa2f08eec74f4
        });

        // Act
        bytes memory compressedPubKey = musig2.toCompressPubKey(point);

        // Assert
        assertEq(
            compressedPubKey,
            hex"02ba5734d8f7091719471e7f7ed6b9df170dc70cc661ca05e688601ad984f068b0",
            "even compressed pubkey is incorrect"
        );
    }

    function test_toCompressPubKey_odd_Success() external view {
        // Arrange
        Point memory point = Point({
            x: 0x8318535b54105d4a7aae60c08fc45f9687181b4fdfc625bd1a753fa7397fed75,
            y: 0x3547f11ca8696646f2f3acb08e31016afac23e630c5d11f59f61fef57b0d2aa5
        });

        // Act
        bytes memory compressedPubKey = musig2.toCompressPubKey(point);

        // Assert
        assertEq(
            compressedPubKey,
            hex"038318535b54105d4a7aae60c08fc45f9687181b4fdfc625bd1a753fa7397fed75",
            "odd compressed pubkey is incorrect"
        );
    }

    function test_ecMul_1_Success() external view {
        // Arrange
        uint256 x = 0x8318535b54105d4a7aae60c08fc45f9687181b4fdfc625bd1a753fa7397fed75;
        uint256 y = 0x3547f11ca8696646f2f3acb08e31016afac23e630c5d11f59f61fef57b0d2aa5;
        uint256 scalar = 0x0000000000000000000000000000000000000000000000000000000000000001;

        // Act
        (uint256 rx, uint256 ry) = musig2.ecMul(x, y, scalar);

        // Assert
        assertEq(rx, 0x8318535b54105d4a7aae60c08fc45f9687181b4fdfc625bd1a753fa7397fed75, "ecMul x 1 is incorrect");
        assertEq(ry, 0x3547f11ca8696646f2f3acb08e31016afac23e630c5d11f59f61fef57b0d2aa5, "ecMul y 1 is incorrect");
    }

    function test_ecMul_scalar_Success() external view {
        // Arrange
        uint256 x = 0xba5734d8f7091719471e7f7ed6b9df170dc70cc661ca05e688601ad984f068b0;
        uint256 y = 0xd67351e5f06073092499336ab0839ef8a521afd334e53807205fa2f08eec74f4;
        uint256 scalar = 0x0eeac18890aa66883ef24811f4f7b1b1dd75c6df68cf62f3c67bc0d247eef57c;

        // Act
        (uint256 rx, uint256 ry) = musig2.ecMul(x, y, scalar);

        // Assert
        assertEq(rx, 0x976e4507187b0c74aa258f5e545a7b5aae452b55caad5c3b6c9fbe8b7caee58c, "ecMul x scalar is incorrect");
        assertEq(ry, 0x6b78bcdbe4c4d5b7837db35a8d517fb67c1aaae664ca41af9bb4b1b6d110d603, "ecMul y scalar is incorrect");
    }

    function test_ecAdd_Success() external view {
        // Arrange
        uint256 x = 0x8318535b54105d4a7aae60c08fc45f9687181b4fdfc625bd1a753fa7397fed75;
        uint256 y = 0x3547f11ca8696646f2f3acb08e31016afac23e630c5d11f59f61fef57b0d2aa5;
        uint256 x2 = 0x9d9031e97dd78ff8c15aa86939de9b1e791066a0224e331bc962a2099a7b1f04;
        uint256 y2 = 0x64b8bbafe1535f2301c72c2cb3535b172da30b02686ab0393d348614f157fbdb;

        // Act
        (uint256 rx, uint256 ry) = musig2.ecAdd(x, y, x2, y2);

        // Assert
        // We convert it to bytes32 for human readability
        assertEq(
            bytes32(rx), 0x8f1f5508de6309606d94529cff928483eab194167e62eff2cc29c4d9db16a559, "ecAdd x is incorrect"
        );
        assertEq(
            bytes32(ry), 0x2ab1b7857429992d9388ebec7212d4c7f4a187d0015da33fc452eb9e267729e9, "ecAdd y is incorrect"
        );
    }

    function test_aggregatedAndEffectivePubKeys_2Keys_Success() external view {
        // Arrange
        Point[] memory participantsPubKeys = setup_participantsPubKeys_2Keys();
        uint256 pubKeyIndex0 = 0;
        uint256 pubKeyIndex1 = 1;

        // Act
        (Point memory aggregatedPubKey0, Point memory effectivePubkey0) =
            musig2.aggregatedAndEffectivePubKeys(participantsPubKeys, pubKeyIndex0);

        (Point memory aggregatedPubKey1, Point memory effectivePubKey1) =
            musig2.aggregatedAndEffectivePubKeys(participantsPubKeys, pubKeyIndex1);

        // Assert
        Point memory expectedAggregatedPubKey = expected_aggregatedKey_2Keys();
        // We convert it to bytes32 for human readability
        assertEq(
            bytes32(aggregatedPubKey0.x), bytes32(expectedAggregatedPubKey.x), "first aggregated x pubkey is incorrect"
        );
        assertEq(
            bytes32(aggregatedPubKey0.y), bytes32(expectedAggregatedPubKey.y), "first aggregated y pubkey is incorrect"
        );
        // Both aggregated pubkeys should be the same
        assertEq(
            bytes32(aggregatedPubKey1.x), bytes32(expectedAggregatedPubKey.x), "second aggregated x pubkey is incorrect"
        );
        assertEq(
            bytes32(aggregatedPubKey1.y), bytes32(expectedAggregatedPubKey.y), "second aggregated y pubkey is incorrect"
        );

        Point[] memory expectedEffectivePubkeys = expected_effectiveKey_2Keys();
        // Effective pubkey for pubKeyIndex 0 is the second effective pubkey because of the sorting
        assertEq(
            bytes32(effectivePubkey0.x),
            bytes32(expectedEffectivePubkeys[1].x),
            "first effective x pubkey 0 is incorrect"
        );
        assertEq(
            bytes32(effectivePubkey0.y),
            bytes32(expectedEffectivePubkeys[1].y),
            "first effective y pubkey 0 is incorrect"
        );
        // Effective pubkey for pubKeyIndex 1 is the first effective pubkey because of the sorting
        assertEq(
            bytes32(effectivePubKey1.x),
            bytes32(expectedEffectivePubkeys[0].x),
            "second effective x pubkey is incorrect"
        );
        assertEq(
            bytes32(effectivePubKey1.y),
            bytes32(expectedEffectivePubkeys[0].y),
            "second effective y pubkey is incorrect"
        );
    }

    function test_aggregatedAndEffectivePubKeys_10Keys_Success() external view {
        // Arrange
        Point[] memory participantsPubKeys = setup_participantsPubKeys_10Keys();
        uint256 pubKeyIndex = 7; // index of the pubkey to test we could use any index

        // Act
        (Point memory aggregatedPubKey, Point memory effectivePubKey) =
            musig2.aggregatedAndEffectivePubKeys(participantsPubKeys, pubKeyIndex);

        // Assert
        // Values are obtained by key manager test test_verify_signatures:
        // https://github.com/FairgateLabs/rust-bitvmx-key-manager/pull/48

        // Compressed aggregated pubkey: 022424ffdb5f1a9f53836a65135adc04e6573eb3b9db1b5ae6dc3e67036ee5ad6c
        Point memory expectedAggregatedPubKey = Point({
            x: 0x2424ffdb5f1a9f53836a65135adc04e6573eb3b9db1b5ae6dc3e67036ee5ad6c,
            y: 0xcff398a75d30c0ac665da8bebd4fe6040a382af51a6e950032d90c3c28d80dcd
        });
        // We convert it to bytes32 for human readability
        assertEq(bytes32(aggregatedPubKey.x), bytes32(expectedAggregatedPubKey.x), "aggregated x pubkey is incorrect");
        assertEq(bytes32(aggregatedPubKey.y), bytes32(expectedAggregatedPubKey.y), "aggregated y pubkey is incorrect");

        // Expected effective pubkey
        Point memory expectedEffectivePubKey = Point({
            x: 0x4d5c89b151d4bbf2815b8f45ad97e6eaeca193dccf9dcc94818b7a2e3e0c4789,
            y: 0xc9cad80e354a47497053ee0eae1a0035c20b4c36a3cae9c98713bf875fe24672
        });
        assertEq(bytes32(effectivePubKey.x), bytes32(expectedEffectivePubKey.x), "effective x pubkey is incorrect");
        assertEq(bytes32(effectivePubKey.y), bytes32(expectedEffectivePubKey.y), "effective y pubkey is incorrect");
    }

    /// @notice Test the aggregated and effective pubkeys used later on with a tweaked nonce
    /// @dev The data is obtained by running the bitvmx-client example union accept_pegin: https://github.com/FairgateLabs/rust-bitvmx-client/blob/main/examples/union/main.rs#L224
    /// @dev RUST_BACKTRACE=1 cargo run --release --example union accept_pegin
    function test_aggregatedAndEffectivePubKeys_4Keys_Tweaked_Success() external view {
        // Arrange
        Point[] memory participantsPubKeys = setup_participantsPubKeys_4Keys();
        uint256 pubKeyIndex = 0; // index of the pubkey to test we could use any index

        // Act
        (Point memory aggregatedPubKey, Point memory effectivePubKey) =
            musig2.aggregatedAndEffectivePubKeys(participantsPubKeys, pubKeyIndex);

        // Assert
        // Values are obtained by key manager test test_verify_signatures:
        // https://github.com/FairgateLabs/rust-bitvmx-key-manager/pull/48

        // Compressed aggregated pubkey: 02cdc6b4ed2e0a57d05f0702f6a32cf11da5d54e3642e01545b36d361aa83cea6a
        Point memory expectedAggregatedPubKey = expected_aggregatedKey_4Keys();
        // We convert it to bytes32 for human readability
        assertEq(bytes32(aggregatedPubKey.x), bytes32(expectedAggregatedPubKey.x), "aggregated x pubkey is incorrect");
        assertEq(bytes32(aggregatedPubKey.y), bytes32(expectedAggregatedPubKey.y), "aggregated y pubkey is incorrect");

        // Expected effective pubkey
        // Compressed effective pubkey: 0204cb44495c2abc544f2f7d10b6987b9360ec8eba93d87ff5ce9b557714d1a2fb
        Point memory expectedEffectivePubKey = Point({
            x: 0x04cb44495c2abc544f2f7d10b6987b9360ec8eba93d87ff5ce9b557714d1a2fb,
            y: 0x115b28d9620ad25158d88b1c4f77b3618023d506a7c39d658ad9c80105b8a5b0
        });
        assertEq(bytes32(effectivePubKey.x), bytes32(expectedEffectivePubKey.x), "effective x pubkey is incorrect");
        assertEq(bytes32(effectivePubKey.y), bytes32(expectedEffectivePubKey.y), "effective y pubkey is incorrect");
    }

    function test_aggregatedNonce_2Keys_Success() external view {
        // Arrange
        Point memory aggregatedPubKey = expected_aggregatedKey_2Keys();
        Nonce[] memory nonces = setup_nonces_2();
        bytes memory message = setup_message_2Keys();

        // Act
        (Point memory adaptedAggregatedNonce, uint256 nonceCoef) =
            musig2.aggregatedNonce(aggregatedPubKey.x, nonces, message);

        // Assert
        // Values are obtained by key manager test test_verify_signatures:
        // https://github.com/FairgateLabs/rust-bitvmx-key-manager/pull/48

        // Expected adapted aggregated nonce
        Point memory expectedAdaptedAggregatedNonce = Point({
            x: 0x724d3c05a4570ef8787779667373dbe7658a65c53a6144cc6abf6856280ea4f4,
            y: 0x52b8fa2ab5670b161f77443af97f0f927c3fe228726b01f8981d8e7959f8e3da
        });
        assertEq(
            bytes32(adaptedAggregatedNonce.x),
            bytes32(expectedAdaptedAggregatedNonce.x),
            "aggregated nonce x is incorrect"
        );
        assertEq(
            bytes32(adaptedAggregatedNonce.y),
            bytes32(expectedAdaptedAggregatedNonce.y),
            "aggregated nonce y is incorrect"
        );

        // Expected nonce coefficient
        assertEq(
            bytes32(nonceCoef),
            bytes32(0x668ca4e2734f176bb4e650cf519d0940c07c483c9303015a6fc8af9f54d232bc),
            "nonce coef is incorrect"
        );
    }

    function test_aggregatedNonce_4Keys_Tweaked_Success() external view {
        // Arrange
        Point memory aggregatedPubKey = expected_aggregatedKey_4Keys();
        Nonce[] memory nonces = setup_nonces_4_tweaked();
        bytes memory message = setup_message_4Keys_Tweaked();

        // Act
        (Point memory adaptedAggregatedNonce, uint256 nonceCoef) =
            musig2.aggregatedNonce(aggregatedPubKey.x, nonces, message);

        // Assert
        // Values are obtained by running the bitvmx-client example union accept_pegin:
        // https://github.com/FairgateLabs/rust-bitvmx-client/blob/main/examples/union/main.rs#L224
        // And adding custom logs for the nonces

        // Expected adapted aggregated nonce
        //
        Point memory expectedAdaptedAggregatedNonce = Point({
            x: 0x07ffd268025e865a9cc41874cc57b1813c888a6c72db265b54bdfd3369584468,
            y: 0x1947c175794eafdb3be418973fbf1242b86285e29090570c100f6067c075adeb
        });
        assertEq(
            bytes32(adaptedAggregatedNonce.x),
            bytes32(expectedAdaptedAggregatedNonce.x),
            "aggregated nonce x is incorrect"
        );
        assertEq(
            bytes32(adaptedAggregatedNonce.y),
            bytes32(expectedAdaptedAggregatedNonce.y),
            "aggregated nonce y is incorrect"
        );

        // Expected nonce coefficient
        assertEq(
            bytes32(nonceCoef),
            bytes32(0x668ca4e2734f176bb4e650cf519d0940c07c483c9303015a6fc8af9f54d232bc),
            "nonce coef is incorrect"
        );

        // get_my_partial_signature sec_nonce: SecNonce { k1: Scalar(#bd2a2feb897c3fe3), k2: Scalar(#c04a0fb4d816a325) }
        // get_my_partial_signature tweak: Some(Scalar(55f74f9672f67bbf54edb0afa7963a844c49a13ef9ccd693a346f2a005fcaedc))
        // get_my_partial_signature aggregated_nonce: AggNonce { R1: Valid(Point(0307ffd268025e865a9cc41874cc57b1813c888a6c72db265b54bdfd3369584468)), R2: Valid(Point(03de66ebc2102f20f8909b498f8554a9eeb09b6e6dbd59818404c0068175e40251)) }
    }

    function test_verifyPartialSignature_2Keys_Success() external view {
        // Arrange
        Point[] memory participantsPubKeys = setup_participantsPubKeys_2Keys();
        Nonce[] memory nonces = setup_nonces_2();

        bytes memory message = setup_message_2Keys();

        uint256 pubKeyIndex = 0;
        // Values are obtained by key manager test test_verify_signatures:
        // https://github.com/FairgateLabs/rust-bitvmx-key-manager/pull/48
        uint256 partialSignature = 0x451b38a20d0517986de2f2f4542c2757da62624697871dce626df08bf5b52ba4;

        // Act
        bool isValid =
            musig2.verifyPartialSignature(partialSignature, pubKeyIndex, participantsPubKeys, nonces, message);

        // Assert
        assertTrue(isValid, "partial signature is not valid");
    }

    function test_verifyPartialSignature_2Keys_One_IncorrectPartialSignature() external view {
        // Arrange
        Point[] memory participantsPubKeys = setup_participantsPubKeys_2Keys();
        Nonce[] memory nonces = setup_nonces_2();

        bytes memory message = setup_message_2Keys();

        uint256 pubKeyIndex = 0;
        uint256 partialSignature = 1;

        // Act
        bool isValid =
            musig2.verifyPartialSignature(partialSignature, pubKeyIndex, participantsPubKeys, nonces, message);

        // Assert
        assertFalse(isValid, "partial signature is not valid");
    }

    function test_verifyPartialSignature_2Keys_Random_IncorrectPartialSignature() external view {
        // Arrange
        Point[] memory participantsPubKeys = setup_participantsPubKeys_2Keys();
        Nonce[] memory nonces = setup_nonces_2();

        bytes memory message = setup_message_2Keys();

        uint256 pubKeyIndex = 0;
        // Values are obtained by key manager test test_verify_signatures:
        // https://github.com/FairgateLabs/rust-bitvmx-key-manager/pull/48
        uint256 partialSignature = 0x551b38a20d0517986de2f2f4542c2757da62624697871dce626df08bf5b52ba4;

        // Act
        bool isValid =
            musig2.verifyPartialSignature(partialSignature, pubKeyIndex, participantsPubKeys, nonces, message);

        // Assert
        assertFalse(isValid, "partial signature is not valid");
    }

    function test_verifyPartialSignature_2Keys_InvalidParticipantsLength() external {
        // Arrange
        Point[] memory participantsPubKeys = new Point[](1);
        participantsPubKeys[0] = setup_participantsPubKeys_2Keys()[0];
        Nonce[] memory nonces = new Nonce[](1);
        nonces[0] = setup_nonces_2()[0];

        bytes memory message = setup_message_2Keys();

        uint256 pubKeyIndex = 0;
        // Values are obtained by key manager test test_verify_signatures:
        // https://github.com/FairgateLabs/rust-bitvmx-key-manager/pull/48
        uint256 partialSignature = 0x451b38a20d0517986de2f2f4542c2757da62624697871dce626df08bf5b52ba4;

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(IMusig2.InvalidParticipantsLength.selector, participantsPubKeys.length, 2)
        );

        // Act
        musig2.verifyPartialSignature(partialSignature, pubKeyIndex, participantsPubKeys, nonces, message);
    }

    function test_verifyPartialSignature_2Keys_InvalidNoncesLength() external {
        // Arrange
        Point[] memory participantsPubKeys = setup_participantsPubKeys_2Keys();
        Nonce[] memory nonces = new Nonce[](1);
        nonces[0] = setup_nonces_2()[0];

        bytes memory message = setup_message_2Keys();

        uint256 pubKeyIndex = 0;
        // Values are obtained by key manager test test_verify_signatures:
        // https://github.com/FairgateLabs/rust-bitvmx-key-manager/pull/48
        uint256 partialSignature = 0x451b38a20d0517986de2f2f4542c2757da62624697871dce626df08bf5b52ba4;

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(IMusig2.InvalidNoncesLength.selector, nonces.length, participantsPubKeys.length)
        );

        // Act
        musig2.verifyPartialSignature(partialSignature, pubKeyIndex, participantsPubKeys, nonces, message);
    }

    function test_verifyPartialSignature_2Keys_InvalidPubKeyIndex() external {
        // Arrange
        Point[] memory participantsPubKeys = setup_participantsPubKeys_2Keys();
        Nonce[] memory nonces = setup_nonces_2();

        bytes memory message = setup_message_2Keys();

        uint256 pubKeyIndex = 2;
        // Values are obtained by key manager test test_verify_signatures:
        // https://github.com/FairgateLabs/rust-bitvmx-key-manager/pull/48
        uint256 partialSignature = 0x451b38a20d0517986de2f2f4542c2757da62624697871dce626df08bf5b52ba4;

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(IMusig2.InvalidPubKeyIndex.selector, pubKeyIndex, participantsPubKeys.length)
        );

        // Act
        musig2.verifyPartialSignature(partialSignature, pubKeyIndex, participantsPubKeys, nonces, message);
    }

    function test_verifyPartialSignature_2Keys_InvalidPartialSignature() external {
        // Arrange
        Point[] memory participantsPubKeys = setup_participantsPubKeys_2Keys();
        Nonce[] memory nonces = setup_nonces_2();

        bytes memory message = setup_message_2Keys();

        uint256 pubKeyIndex = 0;
        uint256 partialSignature = 0x0000000000000000000000000000000000000000000000000000000000000000;

        // Assert invalid partial signature
        vm.expectRevert(abi.encodeWithSelector(IMusig2.InvalidPartialSignature.selector));

        // Act
        musig2.verifyPartialSignature(partialSignature, pubKeyIndex, participantsPubKeys, nonces, message);
    }

    function test_verifyPartialSignature_2Keys_AllPubkeysAreTheSame() external {
        // Arrange
        Point[] memory participantsPubKeys = setup_participantsPubKeys_2Keys();
        participantsPubKeys[1].x = participantsPubKeys[0].x;
        participantsPubKeys[1].y = participantsPubKeys[0].y;
        Nonce[] memory nonces = setup_nonces_2();

        bytes memory message = setup_message_2Keys();

        uint256 pubKeyIndex = 0;
        // Values are obtained by key manager test test_verify_signatures:
        // https://github.com/FairgateLabs/rust-bitvmx-key-manager/pull/48
        uint256 partialSignature = 0x451b38a20d0517986de2f2f4542c2757da62624697871dce626df08bf5b52ba4;

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IMusig2.AllPubkeysAreTheSame.selector));

        // Act
        musig2.verifyPartialSignature(partialSignature, pubKeyIndex, participantsPubKeys, nonces, message);
    }

    function test_verifyPartialSignature_2Keys_InvalidMessage() external {
        // Arrange
        Point[] memory participantsPubKeys = setup_participantsPubKeys_2Keys();
        Nonce[] memory nonces = setup_nonces_2();

        bytes memory message = bytes("");

        uint256 pubKeyIndex = 0;
        // Values are obtained by key manager test test_verify_signatures:
        // https://github.com/FairgateLabs/rust-bitvmx-key-manager/pull/48
        uint256 partialSignature = 0x451b38a20d0517986de2f2f4542c2757da62624697871dce626df08bf5b52ba4;

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IMusig2.InvalidMessage.selector));

        // Act
        musig2.verifyPartialSignature(partialSignature, pubKeyIndex, participantsPubKeys, nonces, message);
    }

    function test_verifyPartialSignature_10Keys_Success() external view {
        // Arrange
        Point[] memory participantsPubKeys = setup_participantsPubKeys_10Keys();
        Nonce[] memory nonces = setup_nonces_10();

        bytes memory message = setup_message_10Keys();

        uint256 pubKeyIndex = 0;
        // Values are obtained by key manager test test_verify_signatures:
        // https://github.com/FairgateLabs/rust-bitvmx-key-manager/pull/48
        uint256 partialSignature = 0x0de1e5b1db27ec285129bd4092785355a4e3967f075e419aceef77581f790f58;

        // Act
        bool isValid =
            musig2.verifyPartialSignature(partialSignature, pubKeyIndex, participantsPubKeys, nonces, message);

        // Assert
        assertTrue(isValid, "partial signature is not valid");
    }

    function test_verifyPartialSignature_4Keys_Tweaked_Success() external view {
        // Arrange
        Point[] memory participantsPubKeys = setup_participantsPubKeys_4Keys();
        Nonce[] memory nonces = setup_nonces_4_tweaked();

        bytes memory message = setup_message_4Keys_Tweaked();

        uint256 pubKeyIndex = 0;
        // Values are obtained by
        uint256 partialSignature = 0x0de1e5b1db27ec285129bd4092785355a4e3967f075e419aceef77581f790f58;

        // Act
        bool isValid =
            musig2.verifyPartialSignature(partialSignature, pubKeyIndex, participantsPubKeys, nonces, message);

        // Assert
        assertTrue(isValid, "partial signature is not valid");
    }

    /// @notice The data is obtained by key manager test test_verify_signatures:
    /// @dev https://github.com/FairgateLabs/rust-bitvmx-key-manager/pull/48
    function expected_aggregatedKey_2Keys() internal pure returns (Point memory resultAggregatedKey) {
        resultAggregatedKey = Point({
            x: 0x3abe801a953476c13344faf951ce01821236abe92535d1fa0189788056498590,
            y: 0x90582cb79ccc123949a0698119870d136086b4a90e394f12a12b97ef5d6be6b5
        });
        return resultAggregatedKey;
    }

    /// @notice The data is obtained by key manager test test_verify_signatures:
    /// @dev https://github.com/FairgateLabs/rust-bitvmx-key-manager/pull/48
    function expected_effectiveKey_2Keys() internal pure returns (Point[] memory resultEffectiveKeys) {
        resultEffectiveKeys = new Point[](2);
        resultEffectiveKeys[0] = Point({
            x: 0x976e4507187b0c74aa258f5e545a7b5aae452b55caad5c3b6c9fbe8b7caee58c,
            y: 0x6b78bcdbe4c4d5b7837db35a8d517fb67c1aaae664ca41af9bb4b1b6d110d603
        });
        resultEffectiveKeys[1] = Point({
            x: 0x8318535b54105d4a7aae60c08fc45f9687181b4fdfc625bd1a753fa7397fed75,
            y: 0x3547f11ca8696646f2f3acb08e31016afac23e630c5d11f59f61fef57b0d2aa5
        });
        return resultEffectiveKeys;
    }

    /// @notice The data is obtained by key manager test test_verify_signatures:
    /// @dev https://github.com/FairgateLabs/rust-bitvmx-key-manager/pull/48
    function expected_aggregatedKey_4Keys() internal pure returns (Point memory resultAggregatedKey) {
        resultAggregatedKey = Point({
            x: 0xcdc6b4ed2e0a57d05f0702f6a32cf11da5d54e3642e01545b36d361aa83cea6a,
            y: 0xa3acfbb0a0407c2c5ec524d6bbaec32d06d1806983059752a75d5bf9aa3a173c
        });
        return resultAggregatedKey;
    }

    /// @notice The data is obtained by key manager test test_verify_signatures:
    /// @dev Obtained from https://github.com/FairgateLabs/rust-bitvmx-key-manager/pull/48/files#diff-da35d3b654d6bdc960c0b4e4724a605d564caf7ff4b5ad1468e0a79932e1a1b1R123
    function setup_participantsPubKeys_2Keys() internal pure returns (Point[] memory participantsPubKeys) {
        participantsPubKeys = new Point[](2);
        participantsPubKeys[0] = Point({
            x: 0x8318535b54105d4a7aae60c08fc45f9687181b4fdfc625bd1a753fa7397fed75,
            y: 0x3547f11ca8696646f2f3acb08e31016afac23e630c5d11f59f61fef57b0d2aa5
        });
        participantsPubKeys[1] = Point({
            x: 0xba5734d8f7091719471e7f7ed6b9df170dc70cc661ca05e688601ad984f068b0,
            y: 0xd67351e5f06073092499336ab0839ef8a521afd334e53807205fa2f08eec74f4
        });

        return participantsPubKeys;
    }

    /// @notice The data is obtained by key manager test test_verify_signatures:
    /// @dev https://github.com/FairgateLabs/rust-bitvmx-key-manager/pull/48
    function setup_participantsPubKeys_10Keys() internal pure returns (Point[] memory participantsPubKeys) {
        participantsPubKeys = new Point[](10);
        participantsPubKeys[0] = Point({
            x: 0x8318535b54105d4a7aae60c08fc45f9687181b4fdfc625bd1a753fa7397fed75,
            y: 0x3547f11ca8696646f2f3acb08e31016afac23e630c5d11f59f61fef57b0d2aa5
        });
        participantsPubKeys[1] = Point({
            x: 0xba5734d8f7091719471e7f7ed6b9df170dc70cc661ca05e688601ad984f068b0,
            y: 0xd67351e5f06073092499336ab0839ef8a521afd334e53807205fa2f08eec74f4
        });
        participantsPubKeys[2] = Point({
            x: 0x9d9031e97dd78ff8c15aa86939de9b1e791066a0224e331bc962a2099a7b1f04,
            y: 0x64b8bbafe1535f2301c72c2cb3535b172da30b02686ab0393d348614f157fbdb
        });
        participantsPubKeys[3] = Point({
            x: 0x20b871f3ced029e14472ec4ebc3c0448164942b123aa6af91a3386c1c403e0eb,
            y: 0xd3b4a5752a2b6c49e574619e6aa0549eb9ccd036b9bbc507e1f7f9712a236092
        });
        participantsPubKeys[4] = Point({
            x: 0xbf6ee64a8d2fdc551ec8bb9ef862ef6b4bcb1805cdc520c3aa5866c0575fd3b5,
            y: 0x14c5562c3caae7aec5cd6f144b57135c75b6f6cea059c3d08d1f39a9c227219d
        });
        participantsPubKeys[5] = Point({
            x: 0x37b84de6947b243626cc8b977bb1f1632610614842468dfa8f35dcbbc55a515e,
            y: 0x47f6fe259cffc671a719eaef444a0d689b16a90051985a13661840cf5e221503
        });
        participantsPubKeys[6] = Point({
            x: 0x9a4ab212cb92775d227af4237c20b81f4221e9361d29007dfc16c79186b577cb,
            y: 0x6ba3f1b582ad0b5572c93f47e7506d66df7f2af05fa1828de0e511aac7b97828
        });
        participantsPubKeys[7] = Point({
            x: 0x01f2bf1fa920e77a43c7aec2587d0b3814093420cc59a9b3ad66dd5734dda7be,
            y: 0x6f8b7de790eac3a720fd8e4bcb9eae9434f843d3cec111d9e07adeddeae090f2
        });
        participantsPubKeys[8] = Point({
            x: 0x931e7fda8da226f799f791eefc9afebcd7ae2b1b19a03c5eaa8d72122d9fe74d,
            y: 0x887a3962ff861190b531ab31ee82f0d7f255dfe3ab73ca627bd70ab3d1cbb417
        });
        participantsPubKeys[9] = Point({
            x: 0x3255458e24278e31d5940f304b16300fdff3f6efd3e2a030b5818310ac67af45,
            y: 0xe28d057e6a332d07e0c5ab09d6947fd4eed1a646edbf224e2d2fec6f49f90abc
        });

        return participantsPubKeys;
    }

    /// @notice The data is obtained by running the bitvmx-client example union accept_pegin:
    /// @dev RUST_BACKTRACE=1 cargo run --release --example union accept_pegin
    /// @dev https://github.com/FairgateLabs/rust-bitvmx-client/blob/main/examples/union/main.rs#L224
    /// @dev And adding custom logs for the public keys
    function setup_participantsPubKeys_4Keys() internal pure returns (Point[] memory participantsPubKeys) {
        participantsPubKeys = new Point[](4);

        // Compressed pub key 0232dfefc702386c0c580d82238c5f365295fd6fa8bd62ca7813b28c2a88dae16a
        // index 0
        participantsPubKeys[0] = Point({
            x: 0x32dfefc702386c0c580d82238c5f365295fd6fa8bd62ca7813b28c2a88dae16a,
            y: 0x1f9b7920d8292ede5fcd8cb033215b64f0ca1631303b610b5e6f3d5245fe328e
        });
        // Compressed pub key 02a1d105494bcaf38c355450c44d0ecdb6acef72a18480803b29069b08e2835a5e
        // index 2
        participantsPubKeys[1] = Point({
            x: 0xa1d105494bcaf38c355450c44d0ecdb6acef72a18480803b29069b08e2835a5e,
            y: 0x2efd683120bc1def62f18a5e006a5db8024667285345e5070f00b1220d8ec11a
        });
        // Compressed pub key 02d874c66f7cf953ee00e4d952d580b6b4ee7ef696f98f5f359f6aa2d4b2b4218b
        // index 3
        participantsPubKeys[2] = Point({
            x: 0xd874c66f7cf953ee00e4d952d580b6b4ee7ef696f98f5f359f6aa2d4b2b4218b,
            y: 0x42cdc31cfb323e14ad14ee887ca318a793eeabae68e144833ec727f08570002e
        });
        // Compressed pub key 02a1468aca1b5dd974ce6837d6e0cf5a0d4181f4ebc14f98a9cb378d650d8f8935
        // index 1
        participantsPubKeys[3] = Point({
            x: 0xa1468aca1b5dd974ce6837d6e0cf5a0d4181f4ebc14f98a9cb378d650d8f8935,
            y: 0x17e57a8b0641b725f7c756cc69d6a289c6388a542c909353ba77cb39f4fd4866
        });
        // sign_partial_message key_aggregation_context: KeyAggContext { pubkey: Point(03d0b0a875133accc7194b636d20d859a31b4c640315470778e237c76606ecf3ab), ordered_pubkeys: [Point(0232dfefc702386c0c580d82238c5f365295fd6fa8bd62ca7813b28c2a88dae16a), Point(02a1468aca1b5dd974ce6837d6e0cf5a0d4181f4ebc14f98a9cb378d650d8f8935), Point(02a1d105494bcaf38c355450c44d0ecdb6acef72a18480803b29069b08e2835a5e), Point(02d874c66f7cf953ee00e4d952d580b6b4ee7ef696f98f5f359f6aa2d4b2b4218b)], pubkey_indexes: {Point(0232dfefc702386c0c580d82238c5f365295fd6fa8bd62ca7813b28c2a88dae16a): 0, Point(02a1d105494bcaf38c355450c44d0ecdb6acef72a18480803b29069b08e2835a5e): 2, Point(02d874c66f7cf953ee00e4d952d580b6b4ee7ef696f98f5f359f6aa2d4b2b4218b): 3, Point(02a1468aca1b5dd974ce6837d6e0cf5a0d4181f4ebc14f98a9cb378d650d8f8935): 1}, key_coefficients: [Valid(Scalar(#f1da0a272e2d318e)), Valid(Scalar(#2518682f7819fb2d)), Valid(Scalar(#d43e96e7ddd1913a)), Valid(Scalar(#a448803f5d8800d8))], effective_pubkeys: [Valid(Point(0204cb44495c2abc544f2f7d10b6987b9360ec8eba93d87ff5ce9b557714d1a2fb)), Valid(Point(02a1468aca1b5dd974ce6837d6e0cf5a0d4181f4ebc14f98a9cb378d650d8f8935)), Valid(Point(028fda443a3974bf998d37f4fe695d12235dafd56762279d50c9ed2955f11126c1)), Valid(Point(025707ffdeaefcf01ad9c99cdd8a986a4080054466d65bf791201e72fdcffa8bbf))], parity_acc: Choice(0), tweak_acc: Valid(Scalar(#11c6b9cf4bab4fb1)) }
        return participantsPubKeys;
    }

    function setup_message_2Keys() internal pure returns (bytes memory message) {
        message = bytes("message_1");
    }

    function setup_message_4Keys_Tweaked() internal pure returns (bytes memory message) {
        //generate_nonce id: "accept_pegin_74db3ee2-06a0-e40a-bab5-08ae4fec8b0b"
        // generate_nonce message_id: "tx:ACCEPT_PEGIN_TX_ix:0_sx:2"
        // generate_nonce message: "53725553c757cd8a8606a6bf9b3001f6286c8e8812a353727fd2936ca6b8004b"
        // generate_nonce tweak: Some(Scalar(9090c5cb2893517e4664c7d153d6ff3d448289e97b4b2b476e3513e739ccaceb))
        // generate_nonce aggregated_pubkey: "02df98af63332bbded5fa23d2f6f3ba4cc0138556bec558bc63d09f9041b110430"
        // generate_nonce my_public_key: compressed "02da80cff650d0fda99bc94c5bcb4c85e439508aeb1d5f753991a32c007aefa825", uncompressed "04da80cff650d0fda99bc94c5bcb4c85e439508aeb1d5f753991a32c007aefa8258e5bc9c869b5d84a6b3f711a5dc9b5453d0adf5a1b8349e1d5075a0d929837b6"
        // generate_nonce nonce_seed: "5b64a6871cbea1985bf5729e060831fb95c504d5fe7081436ed8a32a96498a0d"
        message = bytes("53725553c757cd8a8606a6bf9b3001f6286c8e8812a353727fd2936ca6b8004b");
    }

    function setup_message_10Keys() internal pure returns (bytes memory message) {
        message = bytes("message_1");
    }

    function setup_tweak_4Keys() internal pure returns (bytes32 tweak) {
        tweak = bytes32(0x55f74f9672f67bbf54edb0afa7963a844c49a13ef9ccd693a346f2a005fcaedc);
    }

    /// @notice The data is obtained by key manager test test_verify_signatures:
    /// @dev https://github.com/FairgateLabs/rust-bitvmx-key-manager/pull/48
    function setup_nonces_2() internal pure returns (Nonce[] memory nonces) {
        nonces = new Nonce[](2);
        nonces[0] = Nonce({
            R1: Point({
                x: 0x82a69d1f52710195f6b2c87a16613650910624d8738210c782fad41d5a5964b2,
                y: 0x16cbfd6421e92d0fc4ad04c95615c937b55fa6489d48c6d8eefce8d390f87620
            }),
            R2: Point({
                x: 0x61b06b4b058806c901dd6279cf3e73d5f48c96b0b93e73b8e5f0da23aaa4c4cd,
                y: 0x7b883afc953d09741ac863bf618768ee1c30fda9276d88ff3215a6bd5dc14601
            })
        });
        nonces[1] = Nonce({
            R1: Point({
                x: 0x6dfe3fb94651600f1a25cb7c247b29bda7a4de9eddf72055f7f1ebfe08c19f15,
                y: 0xceeb2800ba505464aff0a39c1cf31ba3246f7bcedeecdf346963fde9dcf4bccf
            }),
            R2: Point({
                x: 0xb91ea55f94ad105fde44de06cb11923249e72bf21c23bbde39232e39351ae308,
                y: 0x8e076b4f56efe73dd033ba5d2c15ebfe72b9074295b17fe430a66fd3811917da
            })
        });
    }

    /// @notice The data is obtained by key manager test test_verify_signatures:
    /// @dev https://github.com/FairgateLabs/rust-bitvmx-key-manager/pull/48
    /// @dev And uncommenting the public kets
    function setup_nonces_10() internal pure returns (Nonce[] memory nonces) {
        nonces = new Nonce[](10);
        nonces[0] = Nonce({
            R1: Point({
                x: 0x43088f6d82652d30a02a2a27eb148c2d76d7415522325c186f29575ca0a9b2ed,
                y: 0x961fc0a5d641825051f554b9df91bf307cf59d5fe9f87d62a2bc1e47086c42bd
            }),
            R2: Point({
                x: 0xb5b513194cdd8dc462e89d72e140c0739a0d04b2504b4e4bed11193ce10990da,
                y: 0xce18658c96daf9ad2a0856cea87e57c8769d3a181cf4b1b211d19837bde7381c
            })
        });
        nonces[1] = Nonce({
            R1: Point({
                x: 0x87b1446bc07c8cdd0b550b6431249eba84bfd7894aca17b4a58ab35acf074194,
                y: 0x70972a09cac83b1e3bfc918f49ecb128a54188c2a464522080923e9192772a34
            }),
            R2: Point({
                x: 0x6bd85799b89064383011075120fcef3c881685e905250f989617d592d8376267,
                y: 0x63ed3c2fdaf979a38f8a7425db0f9692b28d4be688506c85b019c50c03314c35
            })
        });
        nonces[2] = Nonce({
            R1: Point({
                x: 0x21e928da6fbda6bd3a8d4a0d6424b5258d5c97e0687800514c671794405f2188,
                y: 0x2bbcf8f713abc95ab93bc83d1d53ae852023edd528a7dbdb2463d45fea4f8495
            }),
            R2: Point({
                x: 0x8cbb9f94fb641a232717142ac4a5b2e7bc881bff55e5d2feeaab0f47750a1e19,
                y: 0x241f1e5065dcb426c5c9dcaf484ede5372becf6f369f6647f19bc250221e8ea4
            })
        });
        nonces[3] = Nonce({
            R1: Point({
                x: 0x4be4d2fb4b4ae81f39628b89c0905515c85c59a226d34f38d121c85ffa205c52,
                y: 0xda669e816263cd3ed224e9b689a4bcb76962961daae62eca1db47828d0a416bf
            }),
            R2: Point({
                x: 0x06f01ed2275bd663bc99325f967bdde6008ce9b059b299a02d373c276a51c854,
                y: 0xaf4d2bb17f0dc91eb6d854c11cfe14569eefc78045d30a305d9c4333d6cfa92f
            })
        });
        nonces[4] = Nonce({
            R1: Point({
                x: 0xfe2e9ebb0cb2c883a087e4b14beb4adb3b737699e279b5df5cd62d50c7060ead,
                y: 0x65c8c877d49ca6151cfdd14f865c80b32b80eba1676778c1e91d069de545df40
            }),
            R2: Point({
                x: 0xc3e4183bb0dcdfd61fca7c9a4d052cff63fc0bc48e1edaed4e04c1c89515b36c,
                y: 0x9549118f44027fe115d2ab92dd208be2b9204bf7ca606bf442bd7f7d101b3454
            })
        });
        nonces[5] = Nonce({
            R1: Point({
                x: 0xd640107efc8493d2592a905affba97138b7e0b9f2f920ad2a91c530aa7a379c4,
                y: 0xf9f8e895ffa724a15177b9e8590adace8d9fe661d3a454a633baa8e46637f39e
            }),
            R2: Point({
                x: 0x9c39556603a66f106ac4f4d07785d0de5e6d1c7f971a173cae286c4a3fe30ed4,
                y: 0xd6e8a9df4040ba73919d20f9565e7c5195debfcee0b848ff7b0b61f7e69fa90f
            })
        });
        nonces[6] = Nonce({
            R1: Point({
                x: 0xf05c69d99cd9b20a726ffc70557fd74d5a15f0e48972c2f0125a9600f2360053,
                y: 0x0ab91e1a5136bea3c47004efda70748bad069ce8134c1147a8745cd513ffcfb0
            }),
            R2: Point({
                x: 0xa58d69f94c9da38f7788708082ce337599ab51ee14eb1f38dc1206ac4d1a8027,
                y: 0xa913efeca9737714d0707fbc5abbe562eb5b8f21d0363be8305e447da259a05d
            })
        });
        nonces[7] = Nonce({
            R1: Point({
                x: 0xbaa9fb4498d47bca90c59dbc4e2cf8d7d8e8fbb59870a8aa5c1ab90bab784165,
                y: 0xc72b2837fdfd4f995e3aa636265639f57b93ba5d876f859dbe351a0da4f950be
            }),
            R2: Point({
                x: 0x601570539ab66936c1a543020512568edff716915f348a4aee06d9697be0171b,
                y: 0xf0edfd884281918086fd8687417a1864d8ff074424c3dbbff2a3823b250b30c8
            })
        });
        nonces[8] = Nonce({
            R1: Point({
                x: 0x53d03495ac51f121935d482527089e3ec38c95009f7184ab257c64283ce659b9,
                y: 0x3b4805c00ccc5085a717572acfedd195a8365419232dfa7274bd59381a6cb8ba
            }),
            R2: Point({
                x: 0x297c83f4edca3c793fdedb12715f638144e28b2fd132d6894d7059f1e65c3adf,
                y: 0x69b7aef91f4ee059ca9a5421c6d01e9f01899cc567346dbb6019e189a7afafd9
            })
        });
        nonces[9] = Nonce({
            R1: Point({
                x: 0x654f7512a927751b606e52d3dbb63dfb5ed5e4101436f35e2ed7670d3248273b,
                y: 0xddb88eab4bd3e0a616f1394d0a2511b3fdd457d5df2f82302f5d079370d8b70c
            }),
            R2: Point({
                x: 0x554c09f1457e0cf5cfd07103826c06a08789b6879003fd2b5797ac4ab5977d95,
                y: 0x2e969d7e71a3cae88e4d991944b5b76609316cf1e997163b143197f2d332fe41
            })
        });
    }

    /// @notice Get the tweaked nonces created by 4 keys using musig2 for message "40bb65b7323cd1ceeda01a5e87d9224c057968caa088d2499d8e434419a48d68" and tweak "55f74f9672f67bbf54edb0afa7963a844c49a13ef9ccd693a346f2a005fcaedc"
    /// @dev The data is obtained by running the bitvmx-client example union accept_pegin:
    /// @dev RUST_BACKTRACE=1 cargo run --release --example union accept_pegin
    /// @dev https://github.com/FairgateLabs/rust-bitvmx-client/blob/main/examples/union/main.rs#L224
    /// @dev And adding custom logs for the nonces
    /// @dev Compressed public keys from comments are decompressed to get x and y coordinates
    function setup_nonces_4_tweaked() internal pure returns (Nonce[] memory nonces) {
        nonces = new Nonce[](4);
        // Ordered by public key: [02788044fb6efa6b2cbb4a9e992959e062ccd4ec7b2d3b751cc4b53e9e46e5575f, 02d7a9540a8876f9b5b63c03afa4e1bc77a674461c5485bb5d90c3b211fbabe0a1, 02da80cff650d0fda99bc94c5bcb4c85e439508aeb1d5f753991a32c007aefa825, 02fc1e25763291a697e3b38e7c03d310159631f6c92b400a6b57f94d37923f3448]

        // aggregate_nonces public_key: "02788044fb6efa6b2cbb4a9e992959e062ccd4ec7b2d3b751cc4b53e9e46e5575f"
        // aggregate_nonces pub_nonce: PubNonce { R1: Point(03b9623937e83e3cdebba6d6afd4aef12ee1193e43a0a74f585dd34e21adde183e), R2: Point(032b9dd11f34fd2939c42f8219815f927f89d9390b517e128082b96902c9ab692b) }
        nonces[0] = Nonce({
            R1: Point({
                x: 0xb9623937e83e3cdebba6d6afd4aef12ee1193e43a0a74f585dd34e21adde183e,
                y: 0xe4333057de29852409d5d9b9c9e48c77954187142fecd411df79cc7a3d7018a1
            }),
            R2: Point({
                x: 0x2b9dd11f34fd2939c42f8219815f927f89d9390b517e128082b96902c9ab692b,
                y: 0xcb6a2050d231f7db8a6baa4f021d047a9fec7070d9812902ea4c75d6b47cbd2d
            })
        });
        // aggregate_nonces public_key: "02d7a9540a8876f9b5b63c03afa4e1bc77a674461c5485bb5d90c3b211fbabe0a1"
        // aggregate_nonces pub_nonce: PubNonce { R1: Point(0294093d3edbf0e135f00aade59c38583a45a1651e8c1fec5b731665e0f98fa9e2), R2: Point(0216837865b2942d6497a41147128e1bfef8239a1cb5230d36ed2b1c99d975377a) }
        nonces[1] = Nonce({
            R1: Point({
                x: 0x94093d3edbf0e135f00aade59c38583a45a1651e8c1fec5b731665e0f98fa9e2,
                y: 0x17b9e903728bc31a5c5bc278a15be87b1cde3e30bebf68d59a5396d765ad43ae
            }),
            R2: Point({
                x: 0x16837865b2942d6497a41147128e1bfef8239a1cb5230d36ed2b1c99d975377a,
                y: 0x5213fab2b889d0142cbb65858f2f4136a0108764a5d20a84412cba13c34fbba6
            })
        });
        // aggregate_nonces my_pub_key: "02da80cff650d0fda99bc94c5bcb4c85e439508aeb1d5f753991a32c007aefa825"
        // aggregate_nonces my_pub_nonces: PubNonce { R1: Point(03e80d736db0f2a2c45bd6c595e001e440d521db549e5d52a70b63723a77c3cd29), R2: Point(0271d4afe197b64e794458ac504816599e7cc0632d254d3efb0891f88f85c5beb4) }
        nonces[2] = Nonce({
            R1: Point({
                x: 0xe80d736db0f2a2c45bd6c595e001e440d521db549e5d52a70b63723a77c3cd29,
                y: 0x13fab73fcd285507ceaf662e65afc31e6722c76ff4bd3799ec3a19a4827bcbc5
            }),
            R2: Point({
                x: 0x71d4afe197b64e794458ac504816599e7cc0632d254d3efb0891f88f85c5beb4,
                y: 0xe29541027ce66bbf21646fed3b10c41617dbf694c2b8940f50e9763188353d38
            })
        });
        // aggregate_nonces public_key: "02fc1e25763291a697e3b38e7c03d310159631f6c92b400a6b57f94d37923f3448"
        // aggregate_nonces pub_nonce: PubNonce { R1: Point(03c66535dcb24f2ab122935d917c1af5042e1135d05fa15c8f78b70364aadc5d0d), R2: Point(03ce331a32972c73a4fd1b399f918bf9fa30b3b79b2d37345ac93be53eb4a36d16) }
        nonces[3] = Nonce({
            R1: Point({
                x: 0xc66535dcb24f2ab122935d917c1af5042e1135d05fa15c8f78b70364aadc5d0d,
                y: 0x985c038b156e451a322672060af6d7388e74a081b069438660c26c8f296bd8e1
            }),
            R2: Point({
                x: 0xce331a32972c73a4fd1b399f918bf9fa30b3b79b2d37345ac93be53eb4a36d16,
                y: 0x2068746b86527ecbb931226a504d57ffad8367d0461bd43da6f0968c2d726d49
            })
        });
    }
}
