// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {CommitteeMember, Committee} from "src/CommitteeRegistry.sol";
import {MemberRegistrationKeys, MemberKeys, PublicKeyType} from "src/interfaces/IMemberRegistry.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {ScriptUtils} from "script/helpers/ScriptUtils.sol";
import {Vm} from "forge-std/Vm.sol";

abstract contract TestUtils is Test, ScriptUtils {
    function assertEqCommittee(
        Committee memory actualCommittee,
        Committee memory expectedCommittee,
        string memory testName
    ) internal pure {
        assertEqCommitteeAggregatedKey(actualCommittee, expectedCommittee);
        assertEqCommitteeMembersSelection(actualCommittee.members, expectedCommittee.members, testName);
        assertEqCommitteeLeaderAddress(actualCommittee, expectedCommittee);
    }

    function assertEqCommitteeMembersSelection(
        CommitteeMember[] memory actualMembers,
        CommitteeMember[] memory expectedMembers,
        string memory testName
    ) internal pure {
        assertEqCommitteeMembersLength(actualMembers, expectedMembers);

        for (uint256 i = 0; i < actualMembers.length; i++) {
            assertEq(
                actualMembers[i].memberAddress,
                expectedMembers[i].memberAddress,
                string(abi.encodePacked("expect", testName, " member[", Strings.toString(i), "] to have same address"))
            );
        }
    }

    function assertEqCommitteeStructure(Committee memory actualCommittee, Committee memory expectedCommittee)
        internal
        pure
    {
        assertEqCommitteeAggregatedKey(actualCommittee, expectedCommittee);
        assertEqCommitteeMembersSet(actualCommittee.members, expectedCommittee.members);
        assertEqCommitteeLeaderAddress(actualCommittee, expectedCommittee);
    }

    function assertEqCommitteeMembersSet(
        CommitteeMember[] memory actualMembers,
        CommitteeMember[] memory expectedMembers
    ) internal pure {
        assertEqCommitteeMembersLength(actualMembers, expectedMembers);

        for (uint256 i = 0; i < expectedMembers.length; i++) {
            address expectedMemberAddress = expectedMembers[i].memberAddress;
            bool found = false;
            for (uint256 j = 0; j < actualMembers.length; j++) {
                address actualMemberAddress = actualMembers[j].memberAddress;
                if (actualMemberAddress == expectedMemberAddress) {
                    found = true;
                    break;
                }
            }
            require(found, string(abi.encodePacked("missing member: ", Strings.toString(i))));
        }
    }

    function assertEqCommitteeAggregatedKey(Committee memory actualCommittee, Committee memory expectedCommittee)
        internal
        pure
    {
        assertEq(
            actualCommittee.takeAggregatedKey,
            expectedCommittee.takeAggregatedKey,
            string(abi.encodePacked("expect committees to have same takeAggregatedKey"))
        );
        assertEq(
            actualCommittee.disputeAggregatedKey,
            expectedCommittee.disputeAggregatedKey,
            string(abi.encodePacked("expect committees to have same disputeAggregatedKey"))
        );
    }

    function assertEqCommitteeLeaderAddress(Committee memory actualCommittee, Committee memory expectedCommittee)
        internal
        pure
    {
        assertEq(
            actualCommittee.leaderAddress,
            expectedCommittee.leaderAddress,
            string(abi.encodePacked("expect committees to have same leader"))
        );
    }

    function assertEqCommitteeMembersLength(
        CommitteeMember[] memory actualMembers,
        CommitteeMember[] memory expectedMembers
    ) internal pure {
        assertEq(
            actualMembers.length,
            expectedMembers.length,
            string(abi.encodePacked("expect committees to have same amount of members"))
        );
    }

    function assertDifferentMembersSelection(
        CommitteeMember[] memory selectedMembers1,
        CommitteeMember[] memory selectedMembers2
    ) internal pure {
        assertEq(selectedMembers1.length, selectedMembers2.length);

        bool isDifferent = false;
        for (uint256 i = 0; i < selectedMembers1.length; i++) {
            if (selectedMembers1[i].memberAddress != selectedMembers2[i].memberAddress) {
                isDifferent = true;
                break;
            }
        }
        assertTrue(isDifferent);
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
        publicKeys.disputePubKey = _registrationKeys.disputeKey.publicKeyX;
        publicKeys.communicationPubKey = _registrationKeys.communicationKey;
    }
}
