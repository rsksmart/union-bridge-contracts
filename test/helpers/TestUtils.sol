// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {CommitteeMember, Committee, MemberRegistrationKeys} from "src/CommitteeRegistry.sol";
import {MemberKeys, PublicKeyType} from "src/interfaces/ICommitteeRegistry.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {ScriptUtils} from "script/helpers/ScriptUtils.sol";
import {Vm} from "forge-std/Vm.sol";

abstract contract TestUtils is Test, ScriptUtils {
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
            actualCommittee.members.length,
            expectedCommittee.members.length,
            string(abi.encodePacked("expect ", testName, " to have  same memberIndices length"))
        );

        for (uint256 i = 0; i < actualCommittee.members.length; i++) {
            assertEq(
                actualCommittee.members[i].memberAddress,
                expectedCommittee.members[i].memberAddress,
                string(abi.encodePacked("expect ", testName, " to have  same memberIndices[", Strings.toString(i), "]"))
            );
        }
        assertEq(
            actualCommittee.leaderAddress,
            expectedCommittee.leaderAddress,
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
                actualMembers[i].memberAddress,
                expectedMembers[i].memberAddress,
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

    function generatePubKey(uint256 _privateKey) internal returns (bytes32) {
        Vm.Wallet memory wallet = createWallet(_privateKey, PublicKeyType.TAKE);
        return bytes32(wallet.publicKeyX);
    }

    //TODO: consider changing name
    function getXPublicKeysFromRegistration(MemberRegistrationKeys memory _registrationKeys)
        internal
        pure
        returns (MemberKeys memory publicKeys)
    {
        publicKeys.takePubKey = _registrationKeys.takeKey.publicKeyX;
        publicKeys.covenantPubKey = _registrationKeys.covenantKey.publicKeyX;
        publicKeys.communicationPubKey = _registrationKeys.communicationKey;
    }
}
