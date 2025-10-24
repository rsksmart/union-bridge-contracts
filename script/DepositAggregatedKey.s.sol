// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {console} from "forge-std/console.sol";
import {ScriptUtils} from "script/helpers/ScriptUtils.sol";
import {ICommitteeRegistry, Committee} from "src/interfaces/ICommitteeRegistry.sol";
import {IStreamManager} from "src/interfaces/IStreamManager.sol";
import {PegManager} from "src/PegManager.sol";

contract DepositAggregatedKeyScript is ScriptUtils {
    ICommitteeRegistry committeeRegistry;
    IStreamManager streamManager;
    PegManager pegManager;

    uint256 privKey;
    address user;

    function setUp(uint16 _mnemonicIndex, uint64 _streamIndex, bytes memory _committeePubKey) internal {
        pegManager = getPegManagerAddress();
        committeeRegistry = pegManager.committeeRegistry();
        streamManager = pegManager.streamManager();

        // Read args from command line / env
        if (_mnemonicIndex > 9) {
            revert("mnemonic index must be between 0 and 9");
        }
        if (_streamIndex > 4) {
            revert("stream index must be between 0 and 4");
        }
        if (_committeePubKey.length != 33) {
            revert("committee pub key must be exactly 33 bytes");
        }

        privKey = getMemberKey(uint32(_mnemonicIndex));
        user = vm.addr(privKey);
    }

    function run(uint16 _mnemonicIndex, uint64 _streamIndex, bytes memory _committeePubKey) public {
        setUp(_mnemonicIndex, _streamIndex, _committeePubKey);

        // revert if no pending committee found
        Committee memory prevCommittee = committeeRegistry.getPendingCommittee(_streamIndex);
        uint256 prevMissingData = prevCommittee.missingData;

        uint128 committeeId = committeeRegistry.getPendingCommitteeId(_streamIndex);
        vm.startBroadcast(privKey);
        committeeRegistry.depositAggregatedKey(committeeId, _committeePubKey);
        vm.stopBroadcast();

        // Check if it's not last member to deposit the aggregated key,
        if (prevMissingData != 1) {
            // If it's not it should check if the pending committee missing data
            Committee memory currentCommittee = committeeRegistry.getPendingCommittee(_streamIndex);
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
