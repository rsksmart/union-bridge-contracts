// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {CommitteeMember, Committee} from "src/CommitteeRegistry.sol";
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
            string(abi.encodePacked("expect", testName, "to have  same aggregatedKey"))
        );

        assertEq(
            actualCommittee.memberIndexesAndRoles.length,
            expectedCommittee.memberIndexesAndRoles.length,
            string(abi.encodePacked("expect", testName, "to have  same memberIndices length"))
        );

        for (uint256 i = 0; i < actualCommittee.memberIndexesAndRoles.length; i++) {
            assertEq(
                actualCommittee.memberIndexesAndRoles[i].index,
                expectedCommittee.memberIndexesAndRoles[i].index,
                string(abi.encodePacked("expect", testName, "to have  same memberIndices[", Strings.toString(i), "]"))
            );
        }
        assertEq(
            actualCommittee.leaderIndex,
            expectedCommittee.leaderIndex,
            string(abi.encodePacked("expect", testName, "to have same leader"))
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
                string(abi.encodePacked("expect", testName, " memeber[", Strings.toString(i), "] to have same address"))
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

    function generatePubKey(uint256 i) internal pure returns (bytes32) {
        return bytes32(i + 1);
    }
}
