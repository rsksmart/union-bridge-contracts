// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {
    CommitteeMember,
    Committee,
    PublicKeyRegistration,
    PublicKeyIndex,
    PUBLIC_KEYS_INDEX_LENGTH
} from "src/CommitteeRegistry.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

abstract contract TestUtils is Test {
    function assertEqCommittee(
        Committee memory actualCommittee,
        Committee memory expectedCommittee,
        string memory testName
    ) internal pure {
        assertEq(
            actualCommittee.aggregatedKey,
            expectedCommittee.aggregatedKey,
            string(abi.encodePacked("expect ", testName, " to have  same aggregatedKey"))
        );

        assertEq(
            actualCommittee.memberIndexesAndRoles.length,
            expectedCommittee.memberIndexesAndRoles.length,
            string(abi.encodePacked("expect ", testName, " to have  same memberIndices length"))
        );

        for (uint256 i = 0; i < actualCommittee.memberIndexesAndRoles.length; i++) {
            assertEq(
                actualCommittee.memberIndexesAndRoles[i].index,
                expectedCommittee.memberIndexesAndRoles[i].index,
                string(abi.encodePacked("expect ", testName, " to have  same memberIndices[", Strings.toString(i), "]"))
            );
        }
        assertEq(
            actualCommittee.leaderIndex,
            expectedCommittee.leaderIndex,
            string(abi.encodePacked("expect ", testName, " to have same leader"))
        );
    }

    function assertEqCommitteeMembers(
        CommitteeMember[] memory actualMembers,
        CommitteeMember[] memory expectedMembers,
        string memory testName
    ) internal pure {
        assertEq(
            actualMembers.length,
            expectedMembers.length,
            string(abi.encodePacked("expect", testName, "to have same amount of members"))
        );
        for (uint256 i = 0; i < actualMembers.length; i++) {
            assertEq(
                actualMembers[i].index,
                expectedMembers[i].index,
                string(abi.encodePacked("expect", testName, " member[", Strings.toString(i), "] to have same address"))
            );
        }
    }

    function uintToAddress(uint256 i) internal pure returns (address) {
        return bytes32ToAddress(uintToBytes32(i));
    }

    function bytes32ToAddress(bytes32 word) internal pure returns (address) {
        return address(bytes20(word));
    }

    function uintToBytes32(uint256 i) internal pure returns (bytes32) {
        return keccak256(abi.encode(i));
    }

    function createWallet(uint256 _privateKey, PublicKeyIndex _pubKeyIndex) public returns (Vm.Wallet memory) {
        return vm.createWallet(uint256(keccak256(abi.encode(_privateKey, _pubKeyIndex))));
    }

    function generatePubKey(uint256 _privateKey) internal returns (bytes32) {
        Vm.Wallet memory wallet = createWallet(_privateKey, PublicKeyIndex.TAKE);
        return bytes32(wallet.publicKeyX);
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

    function getXPublicKeysFromRegistration(PublicKeyRegistration[] memory _publicKeysRegistration)
        public
        pure
        returns (bytes32[] memory)
    {
        bytes32[] memory publicKeys = new bytes32[](_publicKeysRegistration.length);
        for (uint8 i = 0; i < _publicKeysRegistration.length; i++) {
            publicKeys[i] = _publicKeysRegistration[i].publicKeyX;
        }
        return publicKeys;
    }
}
