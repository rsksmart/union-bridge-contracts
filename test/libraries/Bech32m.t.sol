// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {Bech32m} from "src/libraries/Bech32m.sol";
import {BtcNetwork} from "src/libraries/Network.sol";

contract TestBech32m is Test {
    function test_encodeTaprootAddress_testnet() public pure {
        // Obtained from https://blockstream.info/testnet/address/tb1pn3q7tv78u5sqyu6ngr7w82krtdfuf4a5tv3udkgy4ners2znxehsse5urx
        // ScriptPubKey without the 5120 prefix
        string memory p2trAddress = Bech32m.encodeTaprootAddress(
            hex"9c41e5b3c7e52002735340fce3aac35b53c4d7b45b23c6d904acf2382853366f", BtcNetwork.TESTNET
        );
        console.log(p2trAddress);
        assertEq(p2trAddress, "tb1pn3q7tv78u5sqyu6ngr7w82krtdfuf4a5tv3udkgy4ners2znxehsse5urx");
    }

    function test_encodeTaprootAddress_mainnet() public pure {
        // Obtained from https://learnmeabitcoin.com/technical/upgrades/taproot/#address
        // ScriptPubKey without the 5120 prefix
        string memory p2trAddress = Bech32m.encodeTaprootAddress(
            hex"562529047f476b9a833a5a780a75845ec32980330d76d1ac9f351dc76bce5d72", BtcNetwork.MAINNET
        );
        console.log(p2trAddress);
        assertEq(p2trAddress, "bc1p2cjjjprlga4e4qe6tfuq5avytmpjnqpnp4mdrtylx5wuw67wt4eqg9jscq");
    }
}
