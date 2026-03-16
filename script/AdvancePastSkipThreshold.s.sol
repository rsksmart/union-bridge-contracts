// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {console} from "forge-std/console.sol";
import {StreamPosition} from "src/interfaces/IPegCommonTypes.sol";
import {ScriptUtils} from "script/helpers/ScriptUtils.sol";
import {ContractAddressManager} from "script/helpers/ContractAddressManager.sol";
import {Stream, IStreamManager} from "src/interfaces/IStreamManager.sol";
import {IChallengeManager, ChallengeInfo} from "src/interfaces/IChallengeManager.sol";
import {BridgeMock} from "test/helpers/BridgeMock.sol";

contract AdvancePastSkipThresholdScript is ScriptUtils, ContractAddressManager {
    IChallengeManager challengeManager;
    IStreamManager streamManager;

    function setUp() internal {
        challengeManager = getChallengeManager();
        streamManager = IStreamManager(getStreamManager());
    }

    function run(bytes32 _acceptPeginTxid) public {
        setUp();

        console.log("=== Advance Past Skip Threshold ===");

        ChallengeInfo memory info = challengeManager.getChallengeInfo(_acceptPeginTxid);
        StreamPosition memory streamPosition = streamManager.getStreamPosition(_acceptPeginTxid);
        Stream memory stream = streamManager.getStreamById(streamPosition.streamId);

        uint256 skipThreshold = uint256(stream.timelockSettings.opWonTimelock) + 2 * uint256(stream.pegoutConfirmations);
        int256 targetHeight = info.revealBtcBlockNumber + int256(skipThreshold);

        console.log("Reveal block number:");
        console.logInt(info.revealBtcBlockNumber);
        console.log("Skip threshold:");
        console.log(skipThreshold);
        console.log("Target height:");
        console.logInt(targetHeight);

        BridgeMock bridgeMock = BridgeMock(payable(address(getBridge())));
        vm.startBroadcast(getDeployerKey());
        bridgeMock.setBtcBlockchainBestChainHeight(targetHeight);
        vm.stopBroadcast();

        console.log("=== Bitcoin blocks advanced past skip threshold ===");
    }
}
