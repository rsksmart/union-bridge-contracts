// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";

abstract contract ScriptUtils is Script {
    function getDeployerKey() public view returns (uint256) {
        return getMemberKey(uint32(vm.envUint("DEPLOYER_INDEX")));
    }

    function getDeployerAddress() public returns (address) {
        return vm.rememberKey(getDeployerKey());
    }

    function getMemberKey(uint32 index) public view returns (uint256) {
        // The deploy contracts scripts use members from 1 to 10 we map them to 0 to 9
        return vm.deriveKey(vm.envString("MNEMONIC"), index);
    }

    function generatePubKeyKeccak256(uint256 privKey) public pure returns (bytes32) {
        // Generate a deterministic 'public key' from the private key
        return bytes32(keccak256(abi.encodePacked(privKey)));
    }
}
