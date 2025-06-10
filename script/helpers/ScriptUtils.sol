// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {Vm} from "forge-std/Vm.sol";
import {
    ICommitteeRegistry,
    PublicKeyRegistration,
    PublicKeyIndex,
    PUBLIC_KEYS_INDEX_LENGTH
} from "src/interfaces/ICommitteeRegistry.sol";

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

    function createWallet(uint256 _privateKey, PublicKeyIndex _pubKeyIndex) public returns (Vm.Wallet memory) {
        return vm.createWallet(uint256(keccak256(abi.encode(_privateKey, _pubKeyIndex))));
    }

    function generatePublicKeyRegistration(uint256 _privateKey, PublicKeyIndex _pubKeyIndex)
        public
        returns (PublicKeyRegistration memory)
    {
        // Generate a deterministic 'public key' from the private key
        Vm.Wallet memory wallet = createWallet(_privateKey, _pubKeyIndex);
        // Hash the uncompressed public key
        bytes32 hash = keccak256(abi.encode(wallet.publicKeyX, wallet.publicKeyY));
        // Sign the public key
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(wallet, hash);
        PublicKeyRegistration memory publicKeyRegistration = PublicKeyRegistration({
            publicKeyX: bytes32(wallet.publicKeyX),
            publicKeyY: bytes32(wallet.publicKeyY),
            v: v,
            r: r,
            s: s
        });
        return publicKeyRegistration;
    }

    function generatePublicKeysRegistration(uint256 _privateKey) public returns (PublicKeyRegistration[] memory) {
        // Generate a deterministic 'public key' from the private key
        PublicKeyRegistration[] memory publicKeysRegistration = new PublicKeyRegistration[](PUBLIC_KEYS_INDEX_LENGTH);
        for (uint8 i = 0; i < PUBLIC_KEYS_INDEX_LENGTH; i++) {
            publicKeysRegistration[i] = generatePublicKeyRegistration(_privateKey, PublicKeyIndex(i));
        }
        return publicKeysRegistration;
    }
}
