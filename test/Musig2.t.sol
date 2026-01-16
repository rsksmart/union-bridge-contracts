// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {IMusig2, Point, Nonce} from "src/interfaces/IMusig2.sol";
import {Musig2Harness} from "test/helpers/Musig2Harness.sol";

/// @title Musig2Test
/// @notice Test contract for the Musig2 library
/// @dev All values are obtained from the key manager test for musig2 at test_verify_signatures: https://github.com/FairgateLabs/rust-bitvmx-key-manager/pull/48/files#diff-da35d3b654d6bdc960c0b4e4724a605d564caf7ff4b5ad1468e0a79932e1a1b1R123
/// @dev Point is the x and y coordinates of the public key.
/// @dev it can be obtained from the unncompressed public key removing the 0x04 prefix, first 32 bytes are the x coordinate and the last 32 bytes are the y coordinate.
contract Musig2Test is Test {
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

    function test_aggregatedNonce_2Keys_Success() external view {
        // Arrange
        Point memory aggregatedPubKey = expected_aggregatedKey_2Keys();
        Nonce[] memory nonces = setup_nonces_2();
        bytes memory message = bytes("message_1");

        // Act
        (Point memory adaptedAggregatedNonce, uint256 nonceCoef) =
            musig2.aggregatedNonce(aggregatedPubKey.x, nonces, message);

        // Assert
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

    function test_verifyPartialSignature_2Keys_Success() external view {
        // Arrange
        Point[] memory participantsPubKeys = setup_participantsPubKeys_2Keys();
        Nonce[] memory nonces = setup_nonces_2();

        bytes memory message = bytes("message_1");

        uint256 pubKeyIndex = 0;
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

        bytes memory message = bytes("message_1");

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

        bytes memory message = bytes("message_1");

        uint256 pubKeyIndex = 0;
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

        bytes memory message = bytes("message_1");

        uint256 pubKeyIndex = 0;
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

        bytes memory message = bytes("message_1");

        uint256 pubKeyIndex = 0;
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

        bytes memory message = bytes("message_1");

        uint256 pubKeyIndex = 2;
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

        bytes memory message = bytes("message_1");

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

        bytes memory message = bytes("message_1");

        uint256 pubKeyIndex = 0;
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

        bytes memory message = bytes("message_1");

        uint256 pubKeyIndex = 0;
        uint256 partialSignature = 0x0de1e5b1db27ec285129bd4092785355a4e3967f075e419aceef77581f790f58;

        // Act
        bool isValid =
            musig2.verifyPartialSignature(partialSignature, pubKeyIndex, participantsPubKeys, nonces, message);

        // Assert
        assertTrue(isValid, "partial signature is not valid");
    }

    function expected_aggregatedKey_2Keys() internal pure returns (Point memory resultAggregatedKey) {
        // values are obtained from https://github.com/FairgateLabs/rust-bitvmx-key-manager/pull/48
        resultAggregatedKey = Point({
            x: 0x3abe801a953476c13344faf951ce01821236abe92535d1fa0189788056498590,
            y: 0x90582cb79ccc123949a0698119870d136086b4a90e394f12a12b97ef5d6be6b5
        });
        return resultAggregatedKey;
    }

    function expected_effectiveKey_2Keys() internal pure returns (Point[] memory resultEffectiveKeys) {
        // values are obtained from https://github.com/FairgateLabs/rust-bitvmx-key-manager/pull/48
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
}
