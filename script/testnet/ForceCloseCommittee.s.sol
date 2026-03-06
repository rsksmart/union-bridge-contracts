// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {console} from "forge-std/console.sol";
import {ScriptUtils} from "script/helpers/ScriptUtils.sol";
import {ContractAddressManager} from "script/helpers/ContractAddressManager.sol";
import {Committee, ICommitteeRegistry} from "src/interfaces/ICommitteeRegistry.sol";
import {StreamManager} from "src/StreamManager.sol";
import {Packet, StreamDenomination} from "src/interfaces/IStreamManager.sol";
import {IMemberRegistry} from "src/interfaces/IMemberRegistry.sol";
import {AccessManager} from "src/AccessManager.sol";

contract ForceCloseCommitteeScript is ScriptUtils, ContractAddressManager {
    ICommitteeRegistry committeeRegistry;
    IMemberRegistry memberRegistry;
    StreamManager streamManager;
    AccessManager accessManager;
    //helper array to store member addresses
    address[] memberAddresses;

    function setUp() internal {
        committeeRegistry = getCommitteeRegistry();
        memberRegistry = getMemberRegistry();
        streamManager = getStreamManager();
        accessManager = getAccessManager();
    }

    function run(uint64 _streamId) public {
        setUp();

        console.log("=== Force Close Committee for TESTING only ===");
        console.log("Stream ID:", _streamId);

        // make sure we are in testnet
        accessManager.revertIfNotTestnet();

        console.log("Is a testnet environment");

        // pause all contracts to prevent any other transactions from being processed
        vm.startBroadcast(getDeployerKey());
        accessManager.pause();
        vm.stopBroadcast();

        console.log("Contracts paused");

        uint64 packetsLength = streamManager.getPacketsLength(_streamId);
        console.log("Packets Length:", packetsLength);
        uint64 committeeReleased = 0;
        for (uint64 packetNumber = 0; packetNumber < packetsLength; packetNumber++) {
            Packet memory packet = streamManager.getPacket(_streamId, packetNumber);
            console.log("Packet Number:", packet.packetNumber);
            console.log("Committee ID:", packet.committeeId);

            Committee memory committee = committeeRegistry.getCommittee(packet.committeeId);

            delete memberAddresses;
            for (uint64 memberIndex = 0; memberIndex < committee.members.length; memberIndex++) {
                uint256 balanceToReturn = memberRegistry.getMemberStakedBalance(
                    committee.members[memberIndex].memberAddress, StreamDenomination(_streamId), packetNumber
                );
                if (balanceToReturn > 0) {
                    memberAddresses.push(committee.members[memberIndex].memberAddress);
                    console.log("Member Address:", committee.members[memberIndex].memberAddress);
                    console.log("Balance to release for this packet:", balanceToReturn);
                }
            }
            // if balance is not zero, return the balance to the members (release committee)
            if (memberAddresses.length > 0) {
                vm.startBroadcast(getDeployerKey());
                memberRegistry.forceReleaseCommitteeMembers_TESTNET(_streamId, packetNumber, memberAddresses);
                vm.stopBroadcast();
                console.log("Committee release, balance is now available for the members to withdraw");
                committeeReleased++;
            }
            console.log("--------------------------------");
        }
        if (committeeReleased == 0) {
            console.log("No active committees to release");
        }

        console.log("--------------------------------");

        // force discard pending committee
        console.log("Discard pending committee if there is one");
        vm.startBroadcast(getDeployerKey());
        committeeRegistry.forceDiscardPendingCommittee_TESTNET(_streamId);
        vm.stopBroadcast();
        console.log("--------------------------------");

        // Once all committees are released, restart stream pointers
        console.log("Restarting stream pointers");
        vm.startBroadcast(getDeployerKey());
        // restart stream pointers
        streamManager.restartStreamPointers_TESTNET(_streamId);
        vm.stopBroadcast();
        console.log("Stream pointers restarted");
        console.log("--------------------------------");

        // unpause all contracts
        vm.startBroadcast(getDeployerKey());
        accessManager.unpause();
        vm.stopBroadcast();

        console.log("Contracts unpaused");
    }
}
