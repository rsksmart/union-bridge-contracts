// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {console} from "forge-std/console.sol";
import {ScriptUtils} from "script/helpers/ScriptUtils.sol";
import {ContractAddressManager} from "script/helpers/ContractAddressManager.sol";
import {ICommitteeRegistry, Committee} from "src/interfaces/ICommitteeRegistry.sol";
import {IStreamManager, StreamDenomination} from "src/interfaces/IStreamManager.sol";

contract DepositAggregatedKeysScript is ScriptUtils, ContractAddressManager {
    ICommitteeRegistry committeeRegistry;
    IStreamManager streamManager;

    uint256 privKey;
    address user;

    function setUp(
        uint16 _mnemonicIndex,
        uint64 _streamId,
        bytes memory _takeCommitteePubKey,
        bytes memory _disputeCommitteePubKey
    ) internal {
        committeeRegistry = getCommitteeRegistry();
        streamManager = IStreamManager(getStreamManager());

        // Read args from command line / env
        if (_mnemonicIndex > 9) {
            revert("mnemonic index must be between 0 and 9");
        }
        if (_streamId >= uint64(StreamDenomination.LENGTH)) {
            revert("Invalid stream id");
        }
        if (_takeCommitteePubKey.length != 33) {
            revert("take committee pub key must be exactly 33 bytes");
        }
        if (_disputeCommitteePubKey.length != 33) {
            revert("dispute committee pub key must be exactly 33 bytes");
        }

        privKey = getMemberKey(uint32(_mnemonicIndex));
        user = vm.addr(privKey);
    }

    function run(
        uint16 _mnemonicIndex,
        uint64 _streamId,
        bytes memory _takeCommitteePubKey,
        bytes memory _disputeCommitteePubKey
    ) public {
        setUp(_mnemonicIndex, _streamId, _takeCommitteePubKey, _disputeCommitteePubKey);

        // revert if no pending committee found
        Committee memory prevCommittee = committeeRegistry.getPendingCommittee(_streamId);
        uint256 prevMissingData = prevCommittee.missingData;

        uint128 committeeId = committeeRegistry.getPendingCommitteeId(_streamId);
        vm.startBroadcast(privKey);
        committeeRegistry.depositAggregatedKeys(committeeId, _takeCommitteePubKey, _disputeCommitteePubKey);
        vm.stopBroadcast();

        // Check if it's not last member to deposit the aggregated key,
        if (prevMissingData != 1) {
            // If it's not it should check if the pending committee missing data
            Committee memory currentCommittee = committeeRegistry.getPendingCommittee(_streamId);
            uint256 missingData = currentCommittee.missingData;
            if (prevMissingData == missingData - 1) {
                revert("committee did not deposit aggregated key");
            }
        } else {
            // If it does not revert, it means the committee has been created
            committeeRegistry.getCommittee(committeeId);
        }

        console.log("=== Member deposited aggregated key successfully ===");
    }
}
