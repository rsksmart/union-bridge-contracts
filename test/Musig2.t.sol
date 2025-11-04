// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Point} from "src/Musig2.sol";
import {Musig2Harness} from "test/helpers/Musig2Harness.sol";

contract TestMusig2 is Test {
    Musig2Harness internal musig2;

    function setUp() external {
        musig2 = new Musig2Harness();
    }

    function test_compressPubKey_even_Success() external view {
        // Arrange
        Point memory point = Point({
            x: 0xba5734d8f7091719471e7f7ed6b9df170dc70cc661ca05e688601ad984f068b0,
            y: 0xd67351e5f06073092499336ab0839ef8a521afd334e53807205fa2f08eec74f4
        });

        // Act
        bytes memory compressedPubKey = musig2.compressPubKey(point);

        // Assert
        assertEq(
            compressedPubKey,
            hex"02ba5734d8f7091719471e7f7ed6b9df170dc70cc661ca05e688601ad984f068b0",
            "even compressed pubkey is incorrect"
        );
    }

    function test_compressPubKey_odd_Success() external view {
        // Arrange
        Point memory point = Point({
            x: 0x8318535b54105d4a7aae60c08fc45f9687181b4fdfc625bd1a753fa7397fed75,
            y: 0x3547f11ca8696646f2f3acb08e31016afac23e630c5d11f59f61fef57b0d2aa5
        });

        // Act
        bytes memory compressedPubKey = musig2.compressPubKey(point);

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
        assertEq(rx, 0x8318535b54105d4a7aae60c08fc45f9687181b4fdfc625bd1a753fa7397fed75);
        assertEq(ry, 0x3547f11ca8696646f2f3acb08e31016afac23e630c5d11f59f61fef57b0d2aa5);
    }

    function test_ecMul_scalar_Success() external view {
        // Arrange

        uint256 x = 0xba5734d8f7091719471e7f7ed6b9df170dc70cc661ca05e688601ad984f068b0;
        uint256 y = 0xd67351e5f06073092499336ab0839ef8a521afd334e53807205fa2f08eec74f4;
        uint256 scalar = 0x0eeac18890aa66883ef24811f4f7b1b1dd75c6df68cf62f3c67bc0d247eef57c;

        // Act
        (uint256 rx, uint256 ry) = musig2.ecMul(x, y, scalar);

        // Assert
        assertEq(rx, 0x976e4507187b0c74aa258f5e545a7b5aae452b55caad5c3b6c9fbe8b7caee58c);
        assertEq(ry, 0x6b78bcdbe4c4d5b7837db35a8d517fb67c1aaae664ca41af9bb4b1b6d110d603);
    }

    function test_createAggregatedPubKey_2Keys_Success() external {
        // Arrange
        Point[] memory participantsPubKeys = new Point[](2);
        participantsPubKeys[0] = Point({
            x: 0x8318535b54105d4a7aae60c08fc45f9687181b4fdfc625bd1a753fa7397fed75,
            y: 0x3547f11ca8696646f2f3acb08e31016afac23e630c5d11f59f61fef57b0d2aa5
        });
        participantsPubKeys[1] = Point({
            x: 0xba5734d8f7091719471e7f7ed6b9df170dc70cc661ca05e688601ad984f068b0,
            y: 0xd67351e5f06073092499336ab0839ef8a521afd334e53807205fa2f08eec74f4
        });

        // Act
        Point memory aggregatedPubKey = musig2.createAggregatedPubKey(participantsPubKeys);

        // Assert
        Point memory expectedAggregatedPubKey = Point({
            x: 0x3abe801a953476c13344faf951ce01821236abe92535d1fa0189788056498590,
            y: 0x90582cb79ccc123949a0698119870d136086b4a90e394f12a12b97ef5d6be6b5
        });
        // We convert it to bytes32 for human readability
        assertEq(bytes32(aggregatedPubKey.x), bytes32(expectedAggregatedPubKey.x), "aggregated x pubkey is incorrect");
        assertEq(bytes32(aggregatedPubKey.y), bytes32(expectedAggregatedPubKey.y), "aggregated y pubkey is incorrect");
    }

    function test_createAggregatedPubKey_10Keys_Success() external {
        // Arrange
        Point[] memory participantsPubKeys = new Point[](10);
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

        // Act
        Point memory aggregatedPubKey = musig2.createAggregatedPubKey(participantsPubKeys);

        // Assert

        Point memory expectedAggregatedPubKey = Point({
            x: 0x2424ffdb5f1a9f53836a65135adc04e6573eb3b9db1b5ae6dc3e67036ee5ad6c,
            y: 0xcff398a75d30c0ac665da8bebd4fe6040a382af51a6e950032d90c3c28d80dcd
        });
        // We convert it to bytes32 for human readability
        assertEq(bytes32(aggregatedPubKey.x), bytes32(expectedAggregatedPubKey.x), "aggregated x pubkey is incorrect");
        assertEq(bytes32(aggregatedPubKey.y), bytes32(expectedAggregatedPubKey.y), "aggregated y pubkey is incorrect");
    }
}
