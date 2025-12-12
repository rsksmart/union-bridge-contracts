// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Bech32m} from "src/libraries/Bech32m.sol";
import {BtcNetwork} from "src/libraries/Network.sol";

contract TestBech32m is Test {
    function test_encodeTaprootAddress_testnet() public pure {
        // Obtained from https://blockstream.info/testnet/address/tb1pn3q7tv78u5sqyu6ngr7w82krtdfuf4a5tv3udkgy4ners2znxehsse5urx
        // ScriptPubKey without the 5120 prefix
        string memory p2trAddress = Bech32m.encodeTaprootAddress(
            hex"9c41e5b3c7e52002735340fce3aac35b53c4d7b45b23c6d904acf2382853366f", BtcNetwork.TESTNET
        );
        assertEq(p2trAddress, "tb1pn3q7tv78u5sqyu6ngr7w82krtdfuf4a5tv3udkgy4ners2znxehsse5urx");
    }

    function test_encodeTaprootAddress_mainnet() public pure {
        // Obtained from https://learnmeabitcoin.com/technical/upgrades/taproot/#address
        // ScriptPubKey without the 5120 prefix
        string memory p2trAddress = Bech32m.encodeTaprootAddress(
            hex"562529047f476b9a833a5a780a75845ec32980330d76d1ac9f351dc76bce5d72", BtcNetwork.MAINNET
        );
        assertEq(p2trAddress, "bc1p2cjjjprlga4e4qe6tfuq5avytmpjnqpnp4mdrtylx5wuw67wt4eqg9jscq");
    }

    function test_encodeTaprootAddress_InvalidTweakedPublicKeyLength_LessThan32Bytes_Reverts() external {
        // Arrange - Create a tweaked public key with 31 bytes (less than required 32 bytes)
        bytes memory invalidTweakedPubKey = hex"9c41e5b3c7e52002735340fce3aac35b53c4d7b45b23c6d904acf238285336";

        // Act & Assert
        vm.expectRevert(abi.encodeWithSelector(Bech32m.InvalidTweakedPublicKeyLength.selector, 31, 32));
        Bech32m.encodeTaprootAddress(invalidTweakedPubKey, BtcNetwork.TESTNET);
    }

    function test_encodeTaprootAddress_InvalidTweakedPublicKeyLength_MoreThan32Bytes_Reverts() external {
        // Arrange - Create a tweaked public key with 33 bytes (more than required 32 bytes)
        bytes memory invalidTweakedPubKey = hex"9c41e5b3c7e52002735340fce3aac35b53c4d7b45b23c6d904acf2382853366ff0";

        // Act & Assert
        vm.expectRevert(abi.encodeWithSelector(Bech32m.InvalidTweakedPublicKeyLength.selector, 33, 32));
        Bech32m.encodeTaprootAddress(invalidTweakedPubKey, BtcNetwork.TESTNET);
    }
}
