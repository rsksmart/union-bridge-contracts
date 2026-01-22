// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {console} from "forge-std/console.sol";
import {ScriptUtils} from "script/helpers/ScriptUtils.sol";
import {ContractAddressManager} from "script/helpers/ContractAddressManager.sol";
import {ICommitteeRegistry} from "src/interfaces/ICommitteeRegistry.sol";

contract WhitelistAddressScript is ScriptUtils, ContractAddressManager {
    ICommitteeRegistry committeeRegistry;
    address addressToWhitelist;

    function setUp(uint16 _mnemonicIndex) internal {
        committeeRegistry = ICommitteeRegistry(getCommitteeRegistry());

        if (_mnemonicIndex > 9) {
            revert("MNEMONIC_INDEX must be between 0 and 9");
        }

        uint256 privKey = getMemberKey(uint32(_mnemonicIndex));
        addressToWhitelist = vm.addr(privKey);
    }

    function run(uint16 _mnemonicIndex) public {
        setUp(_mnemonicIndex);

        console.log("=== Going to whitelist address ", addressToWhitelist, " ===");
        vm.startBroadcast(getWhitelisterKey());
        committeeRegistry.whitelistAddress(addressToWhitelist);
        vm.stopBroadcast();
        console.log("=== Address whitelisted successfully ===");
    }
}
