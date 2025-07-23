// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {ScriptUtils} from "script/helpers/ScriptUtils.sol";
import {
    ICommitteeRegistry,
    Role,
    Committee,
    Member,
    CommunicationData,
    CommitteeMember,
    COMMUNICATION_DATA_CHUNKS
} from "src/interfaces/ICommitteeRegistry.sol";

contract GetCommunicationDataForOneMemberScript is ScriptUtils {
    ICommitteeRegistry committeeRegistry;

    bytes32 committeePubKey;
    uint16 mnemonicIndex;
    uint64 stream;
    uint256 privKey;
    address user;
    bytes32 comPubKey;

    function setUp(uint16 _mnemonicIndex, uint64 _streamIndex) internal {
        committeeRegistry = ICommitteeRegistry(0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0);

        // Read args from command line / env
        mnemonicIndex = _mnemonicIndex;
        if (mnemonicIndex > 9) {
            revert("mnemonic index must be between 0 and 9");
        }
        stream = _streamIndex;
        if (stream > 4) {
            revert("stream index must be between 0 and 4");
        }

        privKey = getMemberKey(uint32(mnemonicIndex));
        user = vm.addr(privKey);
    }

    function run(uint16 _mnemonicIndex, uint64 _streamIndex) public {
        setUp(_mnemonicIndex, _streamIndex);

        vm.startBroadcast(privKey);
        CommunicationData[] memory memberComData = committeeRegistry.getMemberCommunicationData(stream, user);
        vm.stopBroadcast();

        console.log("=== Got communication data for one member successfully ===");
        console.log("Member Communication Data length:", memberComData.length);

        // console.log("Mnemonic Index:", mnemonicIndex);
        // console.log("User:", user);
        // console.log("Stream:", stream);
        // console.log("Data:");
        // for (uint256 i = 0; i < memberComData.length; i++) {
        //     console.log("Member ", i, ":");
        //     for (uint256 j = 0; j < COMMUNICATION_DATA_CHUNKS; j++) {
        //         console.logBytes32(memberComData[i].data[j]);
        //     }
        // }
    }
}
