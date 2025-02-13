// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {StreamDenomination, Role, CommitteeMember, Committee, CommitteeRegistry} from "src/CommitteeRegistry.sol";
import {TestUtils} from "test/helpers/TestUtils.sol";

struct RegisterCommitteeParams {
    Committee committee;
}

struct RegisterMemberParams {
    bytes32 publicKey;
    StreamDenomination[] requestedStreams;
    Role[] requestedRoles;
}

contract SetUpCommittees is Script, TestUtils {
    /// @notice parameters for each chain
    /// like https://github.com/defi-wonderland/solidity-foundry-boilerplate/blob/main/script/Deploy.sol
    RegisterCommitteeParams[] public committeesParams;
    RegisterMemberParams[] public membersParams;

    function setUp() internal {
        StreamDenomination[] memory requestedStreams = new StreamDenomination[](1);
        Role[] memory requestedRoles = new Role[](1);
        requestedStreams[0] = StreamDenomination._0_001BTC;
        requestedRoles[0] = Role.Operator;
        // RSK Mainnet
        if (block.chainid == 30) {
            // Members setup
            membersParams.push(RegisterMemberParams(generatePubKey(0), requestedStreams, requestedRoles));
            membersParams.push(RegisterMemberParams(generatePubKey(1), requestedStreams, requestedRoles));
            // Map memebers to comittee
            CommitteeMember[] memory members = new CommitteeMember[](2);
            members[0] = CommitteeMember({index: 0, role: Role.Operator});
            members[1] = CommitteeMember({index: 1, role: Role.Operator});
            // Committee setup
            committeesParams.push();
            committeesParams[0].committee.internalKey =
                0x0908421cb37d204b0c68660d093534d50d01fa791a3313e5fd9c21da137785eb;
            committeesParams[0].committee.memberIndexesAndRoles.push(members[0]);
            committeesParams[0].committee.memberIndexesAndRoles.push(members[1]);
            committeesParams[0].committee.leaderIndex = 0;
        } else if (block.chainid == 31) {
            // RSK Testnet
            // Members setup
            membersParams.push(RegisterMemberParams(generatePubKey(0), requestedStreams, requestedRoles));
            membersParams.push(RegisterMemberParams(generatePubKey(1), requestedStreams, requestedRoles));
            // Map memebers to comittee
            CommitteeMember[] memory members = new CommitteeMember[](2);
            members[0] = CommitteeMember({index: 0, role: Role.Operator});
            members[1] = CommitteeMember({index: 1, role: Role.Operator});
            // Committee setup
            committeesParams.push();
            committeesParams[0].committee.internalKey =
                0x0908421cb37d204b0c68660d093534d50d01fa791a3313e5fd9c21da137785eb;
            committeesParams[0].committee.memberIndexesAndRoles.push(members[0]);
            committeesParams[0].committee.memberIndexesAndRoles.push(members[1]);
            committeesParams[0].committee.leaderIndex = 0;
        } else if (block.chainid == 31337 || block.chainid == 1337) {
            // Foundry local chainid
            // Members setup
            membersParams.push(RegisterMemberParams(generatePubKey(0), requestedStreams, requestedRoles));
            membersParams.push(RegisterMemberParams(generatePubKey(1), requestedStreams, requestedRoles));
            membersParams.push(RegisterMemberParams(generatePubKey(2), requestedStreams, requestedRoles));
            membersParams.push(RegisterMemberParams(generatePubKey(3), requestedStreams, requestedRoles));
            membersParams.push(RegisterMemberParams(generatePubKey(4), requestedStreams, requestedRoles));
            membersParams.push(RegisterMemberParams(generatePubKey(5), requestedStreams, requestedRoles));
            // Map memebers to comittee
            CommitteeMember[] memory members = new CommitteeMember[](2);
            members[0] = CommitteeMember({index: 0, role: Role.Operator});
            members[1] = CommitteeMember({index: 1, role: Role.Operator});
            // Committee setup
            committeesParams.push();
            committeesParams[0].committee.internalKey =
                0x0908421cb37d204b0c68660d093534d50d01fa791a3313e5fd9c21da137785eb;
            committeesParams[0].committee.memberIndexesAndRoles.push(members[0]);
            committeesParams[0].committee.memberIndexesAndRoles.push(members[1]);
            committeesParams[0].committee.leaderIndex = 0;
        } else {
            revert("Blockchain is not RSK");
        }
    }

    function run(CommitteeRegistry _committeeRegistry) public {
        setUp();
        registerMembers(_committeeRegistry, membersParams);
        registerCommittees(_committeeRegistry, committeesParams);
    }

    function registerMembers(CommitteeRegistry _committeeRegistry, RegisterMemberParams[] memory _registerMembersParams)
        public
    {
        for (uint256 i = 0; i < _registerMembersParams.length; i++) {
            registerMember(_committeeRegistry, _registerMembersParams[i]);
        }
    }

    function registerMember(CommitteeRegistry _committeeRegistry, RegisterMemberParams memory _registerMemberParams)
        public
    {
        vm.startBroadcast();
        _committeeRegistry.registerMember(
            _registerMemberParams.publicKey,
            _registerMemberParams.requestedStreams,
            _registerMemberParams.requestedRoles
        );
        vm.stopBroadcast();
    }

    function registerCommittees(
        CommitteeRegistry _committeeRegistry,
        RegisterCommitteeParams[] memory _registerCommitteesParams
    ) public {
        for (uint256 i = 0; i < _registerCommitteesParams.length; i++) {
            registerCommittee(_committeeRegistry, _registerCommitteesParams[i].committee);
        }
    }

    function registerCommittee(CommitteeRegistry _committeeRegistry, Committee memory _commitee) public {
        vm.startBroadcast();
        _committeeRegistry.registerCommittee(_commitee);
        vm.stopBroadcast();
    }
}
