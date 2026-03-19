// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {HelperContract} from "test/helpers/HelperContract.sol";
import {
    SlotState,
    Slot,
    SlotLocation,
    Packet,
    Stream,
    IStreamManager,
    StreamDenomination,
    TimelockSettings,
    StreamManagerSettings,
    StreamSettings
} from "src/interfaces/IStreamManager.sol";
import {IAccessManager} from "src/interfaces/IAccessManager.sol";
import {BtcTransaction, PrevoutData, BitcoinSignatureData} from "src/interfaces/IBitcoinManager.sol";
import {BtcHelper} from "src/libraries/BtcHelper.sol";
import {StreamPosition, PegStatus, BtcTxSPVProof} from "src/interfaces/IPegCommonTypes.sol";
import {Constants} from "src/libraries/Constants.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Committee, Role} from "src/interfaces/ICommitteeRegistry.sol";
import {CompactPubKey} from "src/interfaces/IMemberRegistry.sol";
import {StreamManagerSettingsConfig} from "script/helpers/StreamManagerSettingsConfig.sol";
import {ChainIds} from "src/libraries/Network.sol";
import {StreamManagerHarness} from "test/helpers/StreamManagerHarness.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract StreamManagerTest is Test, HelperContract {
    uint64 internal setupStreamId;

    function setUp() external {
        runTestDeployScript();
        (Committee memory expectedCommittee,) = setup_completeCommittee();

        setupStreamId = expectedCommittee.streamId;
    }

    function setup_cleanStreamManager() internal returns (StreamManagerHarness) {
        StreamManagerSettings memory streamManagerSettings =
            StreamManagerSettingsConfig.getStreamManagerSettings(ChainIds.LOCAL, true);

        address streamManagerImplementation = address(new StreamManagerHarness());
        return StreamManagerHarness(
            address(
                new ERC1967Proxy(
                    streamManagerImplementation,
                    abi.encodeCall(
                        StreamManagerHarness.initialize,
                        (address(this), accessManager, bitcoinManager, streamManagerSettings)
                    )
                )
            )
        );
    }

    function test_lockSlot_Success() external {
        // Arrange
        streamManager.setSlotHarness(setupStreamId, 0, hex"00", 0, 0, SlotState.FILLED);

        // Act
        vm.prank(address(pegoutManager));
        (Slot memory slot,) = streamManager.lockSlot(setupStreamId);

        // Assert
        assertEq(uint64(slot.state), uint64(SlotState.LOCKED), "Incorrect slot state");
    }

    function test_lockSlot_NonExistentSlot() external {
        // Assert
        vm.expectRevert(abi.encodeWithSelector(IStreamManager.NoFilledSlot.selector, setupStreamId));

        // Act
        vm.prank(address(pegoutManager));
        streamManager.lockSlot(setupStreamId);
    }

    function test_lockSlot_PegoutInProcess() external {
        // Arrange
        streamManager.pushSlotsHarness(setupStreamId, 0, 1, SlotState.LOCKED);
        uint256 slotsLength = streamManager.getSlotsLengthHarness(setupStreamId, 0);
        assertEq(slotsLength, 1, "Incorrect slots length");

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IStreamManager.PegoutInProcess.selector, setupStreamId));

        // Act
        vm.prank(address(pegoutManager));
        streamManager.lockSlot(setupStreamId);
    }

    function test_pushSlot_InconsistentSlotsPerPacket() external {
        // Arrange
        streamManager.pushSlotsHarness(setupStreamId, 0, Constants.SLOTS_PER_PACKET, SlotState.FILLED);
        uint256 slotsLength = streamManager.getSlotsLengthHarness(setupStreamId, 0);
        assertEq(slotsLength, Constants.SLOTS_PER_PACKET, "Incorrect slots length");

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(IStreamManager._InconsistentSlotsPerPacket.selector, setupStreamId, 0, 101)
        );

        // Act
        vm.prank(address(peginManager));
        streamManager.reserveSlot(setupStreamId, 0);
    }

    function test_createNewPacket_Success() external {
        // Arrange
        // we expect the packet number to be 1 since the first packet is being created in the test setup function
        uint128 committeeId = COMMITTEE_ID_STREAM_1_COMMITTEE_1;
        uint64 expectedPacketNumber = 1;
        bytes memory committeePubKey = COMMITTEE_TAKE_PUB_KEY();
        CompactPubKey[] memory disputeKeys = registry.getCommitteeDisputeKeys(committeeId);

        // Assert
        vm.expectEmit(address(streamManager));
        emit IStreamManager.PacketCreated(setupStreamId, expectedPacketNumber);

        // Act
        // Use the first committee that was already set up in setUp()
        vm.prank(address(registry));
        streamManager.createNewPacket(setupStreamId, committeeId, committeePubKey, disputeKeys);

        // Assert
        Packet memory packet = streamManager.getPacket(setupStreamId, expectedPacketNumber);
        assertEq(packet.packetNumber, expectedPacketNumber, "packetNumber was not set correctly");
        assertEq(packet.committeeId, committeeId, "committeeId was not set correctly");
        bytes memory expectedEnablerScriptPubKey =
            hex"51201cbeafdb8fa122bf71ea817df2ed9131bfa165952d63ba5841313f918a0f86c9";
        assertEq(packet.enablerScriptPubKey, expectedEnablerScriptPubKey, "enablerScriptPubKey was not set correctly");
    }

    function test_setPeginConfirmations_Success() external {
        // Arrange
        uint64 streamId = 0;

        // Assert
        assertEq(streamManager.getStreamById(streamId).peginConfirmations, 2, "Pegin confirmation should be default");

        // set to 7 confirmations
        uint8 peginConfirmations = 7;

        // Assert

        vm.expectEmit(address(streamManager));
        emit IStreamManager.PeginConfirmationsUpdated(streamId, peginConfirmations);

        // Act

        vm.prank(address(streamManager.owner()));
        streamManager.setPeginConfirmations(streamId, peginConfirmations);

        // Assert
        assertEq(
            streamManager.getStreamById(streamId).peginConfirmations,
            peginConfirmations,
            "peginConfirmations was not set correctly"
        );
    }

    function test_setPeginConfirmations_Rever_InvalidStreamId() external {
        // Arrange
        uint64 streamId = 10;
        vm.prank(address(streamManager.owner()));

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IStreamManager.StreamNotFoundById.selector, streamId));

        // Act
        streamManager.setPeginConfirmations(streamId, 100);
    }

    function test_setPeginConfirmations_Revert_NotOwner() external {
        // Arrange
        uint64 streamId = 0;

        // Assert
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, this));

        // Act
        streamManager.setPeginConfirmations(streamId, 10);
    }

    function test_setPeginConfirmations_Revert_PeginConfirmationsLowerThanRejectPegin() external {
        // Arrange
        uint64 streamId = 0;
        address owner = streamManager.owner();

        // Set rejectPeginConfirmations to 2 so we can try setting peginConfirmations to 1 (below it)
        vm.prank(owner);
        streamManager.setRejectPeginConfirmations(streamId, 2);
        uint8 rejectPeginConfirmations = 2;
        uint8 peginConfirmations = 1;

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamManager.PeginConfirmationsLowerThanRejectPegin.selector,
                peginConfirmations,
                rejectPeginConfirmations
            )
        );

        // Act
        vm.prank(owner);
        streamManager.setPeginConfirmations(streamId, peginConfirmations);
    }

    function test_setRejectPeginConfirmations_Success() external {
        // Arrange
        uint64 streamId = 0;

        // Assert
        assertEq(
            streamManager.getStreamById(streamId).rejectPeginConfirmations,
            1,
            "Reject pegin confirmation should be default"
        );

        uint8 rejectPeginConfirmations = 2;

        vm.expectEmit(address(streamManager));
        emit IStreamManager.RejectPeginConfirmationsUpdated(streamId, rejectPeginConfirmations);

        // Act
        vm.prank(address(streamManager.owner()));
        streamManager.setRejectPeginConfirmations(streamId, rejectPeginConfirmations);

        // Assert
        assertEq(
            streamManager.getStreamById(streamId).rejectPeginConfirmations,
            rejectPeginConfirmations,
            "rejectPeginConfirmations was not set correctly"
        );
    }

    function test_setRejectPeginConfirmations_Revert_StreamNotFoundById() external {
        // Arrange
        uint64 streamId = 10;
        vm.prank(address(streamManager.owner()));

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IStreamManager.StreamNotFoundById.selector, streamId));

        // Act
        streamManager.setRejectPeginConfirmations(streamId, 2);
    }

    function test_setRejectPeginConfirmations_Revert_OwnableUnauthorizedAccount() external {
        // Arrange
        uint64 streamId = 0;

        // Assert
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, this));

        // Act
        streamManager.setRejectPeginConfirmations(streamId, 2);
    }

    function test_setRejectPeginConfirmations_Revert_InvalidRejectPeginConfirmations() external {
        // Arrange
        uint64 streamId = 0;
        uint8 zeroConfirmations = 0;
        address owner = streamManager.owner();

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(IStreamManager.InvalidRejectPeginConfirmations.selector, zeroConfirmations)
        );

        // Act
        vm.prank(owner);
        streamManager.setRejectPeginConfirmations(streamId, zeroConfirmations);
    }

    function test_setRejectPeginConfirmations_Revert_RejectPeginConfirmationsExceedsPegin() external {
        // Arrange - stream has peginConfirmations 2 by default (local test)
        uint64 streamId = 0;
        uint8 peginConfirmations = streamManager.getStreamById(streamId).peginConfirmations;
        uint8 rejectPeginConfirmations = peginConfirmations + 1; // 3 > 2
        address owner = streamManager.owner();

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamManager.RejectPeginConfirmationsExceedsPegin.selector,
                rejectPeginConfirmations,
                peginConfirmations
            )
        );

        // Act
        vm.prank(owner);
        streamManager.setRejectPeginConfirmations(streamId, rejectPeginConfirmations);
    }

    function test_setPegoutConfirmations_Success() external {
        // Arrange
        uint64 streamId = 0;
        uint8 pegoutConfirmations = 5;

        // Assert
        vm.expectEmit(address(streamManager));
        emit IStreamManager.PegoutConfirmationsUpdated(streamId, pegoutConfirmations);

        // Act
        vm.prank(streamManager.owner());
        streamManager.setPegoutConfirmations(streamId, pegoutConfirmations);

        // Assert
        assertEq(
            streamManager.getStreamById(streamId).pegoutConfirmations,
            pegoutConfirmations,
            "pegoutConfirmations was not set correctly"
        );
    }

    function test_setTimelockSettings_Success() external {
        // Arrange
        uint64 streamId = 0;
        TimelockSettings memory newTimelockSettings = TimelockSettings({
            shortTimelock: 8,
            longTimelock: 16,
            requestPeginTimelock: 14,
            opWonTimelock: 200,
            claimGateTimelock: 8,
            inputNotRevealedTimelock: 10,
            opNoCosignTimelock: 14,
            wtNoChallengeTimelock: 14
        });

        // Get initial timelock settings for comparison
        TimelockSettings memory initialSettings = streamManager.getStreamById(streamId).timelockSettings;
        assertEq(initialSettings.shortTimelock, 6, "Initial shortTimelock should be 6");

        // Assert event emission
        vm.expectEmit(address(streamManager));
        emit IStreamManager.TimelockSettingsUpdated(streamId, newTimelockSettings);

        // Act
        vm.prank(streamManager.owner());
        streamManager.setTimelockSettings(streamId, newTimelockSettings);

        // Assert
        TimelockSettings memory updatedSettings = streamManager.getStreamById(streamId).timelockSettings;
        assertEq(
            updatedSettings.shortTimelock, newTimelockSettings.shortTimelock, "shortTimelock was not set correctly"
        );
        assertEq(updatedSettings.longTimelock, newTimelockSettings.longTimelock, "longTimelock was not set correctly");
        assertEq(
            updatedSettings.requestPeginTimelock,
            newTimelockSettings.requestPeginTimelock,
            "requestPeginTimelock was not set correctly"
        );
        assertEq(
            updatedSettings.opWonTimelock, newTimelockSettings.opWonTimelock, "opWonTimelock was not set correctly"
        );
        assertEq(
            updatedSettings.claimGateTimelock,
            newTimelockSettings.claimGateTimelock,
            "claimGateTimelock was not set correctly"
        );
        assertEq(
            updatedSettings.inputNotRevealedTimelock,
            newTimelockSettings.inputNotRevealedTimelock,
            "inputNotRevealedTimelock was not set correctly"
        );
        assertEq(
            updatedSettings.opNoCosignTimelock,
            newTimelockSettings.opNoCosignTimelock,
            "opNoCosignTimelock was not set correctly"
        );
        assertEq(
            updatedSettings.wtNoChallengeTimelock,
            newTimelockSettings.wtNoChallengeTimelock,
            "wtNoChallengeTimelock was not set correctly"
        );
    }

    function test_setTimelockSettings_Revert_InvalidStreamId() external {
        // Arrange
        uint64 invalidStreamId = 10;
        TimelockSettings memory timelockSettings = TimelockSettings({
            shortTimelock: 6,
            longTimelock: 12,
            requestPeginTimelock: 12,
            opWonTimelock: 100,
            claimGateTimelock: 6,
            inputNotRevealedTimelock: 8,
            opNoCosignTimelock: 12,
            wtNoChallengeTimelock: 12
        });

        vm.prank(streamManager.owner());

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IStreamManager.StreamNotFoundById.selector, invalidStreamId));

        // Act
        streamManager.setTimelockSettings(invalidStreamId, timelockSettings);
    }

    function test_setTimelockSettings_Revert_NotOwner() external {
        // Arrange
        uint64 streamId = 0;
        TimelockSettings memory timelockSettings = TimelockSettings({
            shortTimelock: 6,
            longTimelock: 12,
            requestPeginTimelock: 12,
            opWonTimelock: 100,
            claimGateTimelock: 6,
            inputNotRevealedTimelock: 8,
            opNoCosignTimelock: 12,
            wtNoChallengeTimelock: 12
        });

        // Assert
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, this));

        // Act
        streamManager.setTimelockSettings(streamId, timelockSettings);
    }

    function test_setTimelockSettings_Revert_InvalidTimelockSettings() external {
        // Arrange
        uint64 streamId = 0;
        TimelockSettings memory invalidTimelockSettings = TimelockSettings({
            shortTimelock: 0, // Invalid: zero value
            longTimelock: 12,
            requestPeginTimelock: 12,
            opWonTimelock: 100,
            claimGateTimelock: 6,
            inputNotRevealedTimelock: 8,
            opNoCosignTimelock: 12,
            wtNoChallengeTimelock: 12
        });

        vm.prank(streamManager.owner());

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(IStreamManager.InvalidTimelockSettings.selector, invalidTimelockSettings)
        );

        // Act
        streamManager.setTimelockSettings(streamId, invalidTimelockSettings);
    }

    function test_setTimelockSettings_Revert_InvalidTimelockSettings_ZeroRequestPeginTimelock() external {
        // Arrange
        uint64 streamId = 0;
        TimelockSettings memory invalidTimelockSettings = TimelockSettings({
            shortTimelock: 6,
            longTimelock: 12,
            requestPeginTimelock: 0, // Invalid: zero value
            opWonTimelock: 100,
            claimGateTimelock: 6,
            inputNotRevealedTimelock: 8,
            opNoCosignTimelock: 12,
            wtNoChallengeTimelock: 12
        });

        vm.prank(streamManager.owner());

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(IStreamManager.InvalidTimelockSettings.selector, invalidTimelockSettings)
        );

        // Act
        streamManager.setTimelockSettings(streamId, invalidTimelockSettings);
    }

    function test_validateTimelockSettings_Revert_ZeroShortTimelock() external {
        // Arrange - Create invalid timelock settings with zero shortTimelock
        uint64 streamId = 0;
        TimelockSettings memory invalidSettings = TimelockSettings({
            shortTimelock: 0,
            longTimelock: 12,
            requestPeginTimelock: 12,
            opWonTimelock: 100,
            claimGateTimelock: 6,
            inputNotRevealedTimelock: 8,
            opNoCosignTimelock: 12,
            wtNoChallengeTimelock: 12
        });

        vm.prank(streamManager.owner());

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IStreamManager.InvalidTimelockSettings.selector, invalidSettings));

        // Act
        streamManager.setTimelockSettings(streamId, invalidSettings);
    }

    function test_validateTimelockSettings_Revert_ZeroLongTimelock() external {
        // Arrange - Create invalid timelock settings with zero longTimelock
        uint64 streamId = 0;
        TimelockSettings memory invalidSettings = TimelockSettings({
            shortTimelock: 6,
            longTimelock: 0,
            requestPeginTimelock: 12,
            opWonTimelock: 100,
            claimGateTimelock: 6,
            inputNotRevealedTimelock: 8,
            opNoCosignTimelock: 12,
            wtNoChallengeTimelock: 12
        });

        vm.prank(streamManager.owner());

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IStreamManager.InvalidTimelockSettings.selector, invalidSettings));

        // Act
        streamManager.setTimelockSettings(streamId, invalidSettings);
    }

    function test_validateTimelockSettings_Revert_ZeroOpWonTimelock() external {
        // Arrange - Create invalid timelock settings with zero opWonTimelock
        uint64 streamId = 0;
        TimelockSettings memory invalidSettings = TimelockSettings({
            shortTimelock: 6,
            longTimelock: 12,
            requestPeginTimelock: 12,
            opWonTimelock: 0,
            claimGateTimelock: 6,
            inputNotRevealedTimelock: 8,
            opNoCosignTimelock: 12,
            wtNoChallengeTimelock: 12
        });

        vm.prank(streamManager.owner());

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IStreamManager.InvalidTimelockSettings.selector, invalidSettings));

        // Act
        streamManager.setTimelockSettings(streamId, invalidSettings);
    }

    function test_validateTimelockSettings_Revert_ZeroClaimGateTimelock() external {
        // Arrange - Create invalid timelock settings with zero claimGateTimelock
        uint64 streamId = 0;
        TimelockSettings memory invalidSettings = TimelockSettings({
            shortTimelock: 6,
            longTimelock: 12,
            requestPeginTimelock: 12,
            opWonTimelock: 100,
            claimGateTimelock: 0,
            inputNotRevealedTimelock: 8,
            opNoCosignTimelock: 12,
            wtNoChallengeTimelock: 12
        });

        vm.prank(streamManager.owner());

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IStreamManager.InvalidTimelockSettings.selector, invalidSettings));

        // Act
        streamManager.setTimelockSettings(streamId, invalidSettings);
    }

    function test_validateTimelockSettings_Revert_ZeroInputNotRevealedTimelock() external {
        // Arrange - Create invalid timelock settings with zero inputNotRevealedTimelock
        uint64 streamId = 0;
        TimelockSettings memory invalidSettings = TimelockSettings({
            shortTimelock: 6,
            longTimelock: 12,
            requestPeginTimelock: 12,
            opWonTimelock: 100,
            claimGateTimelock: 6,
            inputNotRevealedTimelock: 0,
            opNoCosignTimelock: 12,
            wtNoChallengeTimelock: 12
        });

        vm.prank(streamManager.owner());

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IStreamManager.InvalidTimelockSettings.selector, invalidSettings));

        // Act
        streamManager.setTimelockSettings(streamId, invalidSettings);
    }

    function test_validateTimelockSettings_Revert_ZeroOpNoCosignTimelock() external {
        // Arrange - Create invalid timelock settings with zero opNoCosignTimelock
        uint64 streamId = 0;
        TimelockSettings memory invalidSettings = TimelockSettings({
            shortTimelock: 6,
            longTimelock: 12,
            requestPeginTimelock: 12,
            opWonTimelock: 100,
            claimGateTimelock: 6,
            inputNotRevealedTimelock: 8,
            opNoCosignTimelock: 0,
            wtNoChallengeTimelock: 12
        });

        vm.prank(streamManager.owner());

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IStreamManager.InvalidTimelockSettings.selector, invalidSettings));

        // Act
        streamManager.setTimelockSettings(streamId, invalidSettings);
    }

    function test_validateTimelockSettings_Revert_ZeroWtNoChallengeTimelock() external {
        // Arrange - Create invalid timelock settings with zero wtNoChallengeTimelock
        uint64 streamId = 0;
        TimelockSettings memory invalidSettings = TimelockSettings({
            shortTimelock: 6,
            longTimelock: 12,
            requestPeginTimelock: 12,
            opWonTimelock: 100,
            claimGateTimelock: 6,
            inputNotRevealedTimelock: 8,
            opNoCosignTimelock: 12,
            wtNoChallengeTimelock: 0
        });

        vm.prank(streamManager.owner());

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IStreamManager.InvalidTimelockSettings.selector, invalidSettings));

        // Act
        streamManager.setTimelockSettings(streamId, invalidSettings);
    }

    function test_validateTimelockSettings_Revert_ZeroRequestPeginTimelock() external {
        // Arrange - Create invalid timelock settings with zero requestPeginTimelock
        uint64 streamId = 0;
        TimelockSettings memory invalidSettings = TimelockSettings({
            shortTimelock: 6,
            longTimelock: 12,
            requestPeginTimelock: 0,
            opWonTimelock: 100,
            claimGateTimelock: 6,
            inputNotRevealedTimelock: 8,
            opNoCosignTimelock: 12,
            wtNoChallengeTimelock: 12
        });

        vm.prank(streamManager.owner());

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IStreamManager.InvalidTimelockSettings.selector, invalidSettings));

        // Act
        streamManager.setTimelockSettings(streamId, invalidSettings);
    }

    function test_validateTimelockSettings_Revert_AllZero() external {
        // Arrange - Create invalid timelock settings with all fields set to zero
        uint64 streamId = 0;
        TimelockSettings memory invalidSettings = TimelockSettings({
            shortTimelock: 0,
            longTimelock: 0,
            requestPeginTimelock: 0,
            opWonTimelock: 0,
            claimGateTimelock: 0,
            inputNotRevealedTimelock: 0,
            opNoCosignTimelock: 0,
            wtNoChallengeTimelock: 0
        });

        vm.prank(streamManager.owner());

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IStreamManager.InvalidTimelockSettings.selector, invalidSettings));

        // Act
        streamManager.setTimelockSettings(streamId, invalidSettings);
    }

    function test_validateTimelockSettings_Revert_MultipleZeroFields() external {
        // Arrange - Create invalid timelock settings with multiple zero fields
        uint64 streamId = 0;
        TimelockSettings memory invalidSettings = TimelockSettings({
            shortTimelock: 0,
            longTimelock: 0,
            requestPeginTimelock: 12,
            opWonTimelock: 100,
            claimGateTimelock: 0,
            inputNotRevealedTimelock: 8,
            opNoCosignTimelock: 0,
            wtNoChallengeTimelock: 12
        });

        vm.prank(streamManager.owner());

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IStreamManager.InvalidTimelockSettings.selector, invalidSettings));

        // Act
        streamManager.setTimelockSettings(streamId, invalidSettings);
    }

    function test_StreamCreated_EventEmittedDuringInitialization() external view {
        // This test verifies that StreamCreated events were emitted during contract initialization
        // The streams are created in the constructor/initializer, so we can only verify they exist

        // Assert that streams were created (which means StreamCreated events were emitted)
        uint64 streamsLength = streamManager.getStreamsLength();
        assertTrue(streamsLength > 0, "No streams were created during initialization");

        // Verify the first stream exists and has expected properties
        Stream memory firstStream = streamManager.getStreamById(0);
        assertTrue(firstStream.denomination > 0, "First stream should have a valid denomination");
    }

    function test_getAvailablePeginCommitteeId_Success() external {
        // Arrange
        setup_multipleRequestAndAcceptPeginFlows(Constants.SLOTS_PER_PACKET - 1);

        // Act
        uint256 currentPacketCommitteeId = streamManager.getAvailablePeginCommitteeId(setupStreamId);

        // Assert
        assertEq(
            currentPacketCommitteeId, COMMITTEE_ID_STREAM_1_COMMITTEE_1, "Current packet committee ID should match"
        );
    }

    function test_getAvailablePeginCommitteeId_Success_NoCommitteeForCurrentPacket() external {
        // Arrange
        setup_multipleRequestAndAcceptPeginFlows(Constants.SLOTS_PER_PACKET);

        // Act
        uint256 currentPacketCommitteeId = streamManager.getAvailablePeginCommitteeId(setupStreamId);

        // Assert
        assertEq(currentPacketCommitteeId, 0, "Current packet committee ID should be 0 when no committee exists");
    }

    function test_getMinimumDeposit_Success() external view {
        // Arrange
        uint256[5] memory minDepositsOperator = [
            uint256(25000000 gwei), // 2500 USD to secure 0.001 BTC stream
            uint256(25000000 gwei), // 2500 USD to secure 0.01 BTC stream
            uint256(25000000 gwei), // 2500 USD to secure 0.1 BTC stream
            uint256(100000000 gwei), // 10k USD to secure 1 BTC stream
            uint256(1000000000 gwei) // 100k USD to secure 10 BTC stream
        ];

        uint256[5] memory minDepositsWatchtower = [
            uint256(25000000 gwei), // 2500 USD to secure 0.001 BTC stream
            uint256(25000000 gwei), // 2500 USD to secure 0.01 BTC stream
            uint256(25000000 gwei), // 2500 USD to secure 0.1 BTC stream
            uint256(25000000 gwei), // 2500 USD to secure 1 BTC stream
            uint256(200000000 gwei) // 20k USD to secure 10 BTC stream
        ];

        for (uint8 i = 0; i < uint8(StreamDenomination.LENGTH); i++) {
            // Act
            uint256 minDepositOperator = streamManager.getMinimumDeposit(StreamDenomination(i), Role.OPERATOR);
            uint256 minDepositWatchtower = streamManager.getMinimumDeposit(StreamDenomination(i), Role.WATCHTOWER);

            // Assert
            assertEq(minDepositOperator, minDepositsOperator[i], "Operator min deposit should match default value");
            assertEq(
                minDepositWatchtower, minDepositsWatchtower[i], "Watchtower min deposit should match default value"
            );
        }
    }

    // --- Security Bond Percentage ---
    function test_securityBondPercentage_Defaults() external view {
        // Defaults set in initialize: WATCHTOWER=2, OPERATOR=10
        assertEq(
            streamManager.getSecurityBondPercentage(Role.WATCHTOWER),
            200,
            "Default WATCHTOWER bond should match Constants"
        );
        assertEq(
            streamManager.getSecurityBondPercentage(Role.OPERATOR), 1000, "Default OPERATOR bond should match Constants"
        );
    }

    function test_setSecurityBondPercentage_Operator_Success() external {
        // Arrange
        uint16 newPercentage = 500;
        Role role = Role.OPERATOR;
        address owner = streamManager.owner();

        // Expect event
        vm.expectEmit(address(streamManager));
        emit IStreamManager.SecurityBondPercentageUpdated(role, newPercentage);

        // Act
        vm.prank(owner);
        streamManager.setSecurityBondPercentage(role, newPercentage);

        // Assert
        assertEq(streamManager.getSecurityBondPercentage(role), newPercentage, "Bond percentage should update");
    }

    function test_setSecurityBondPercentage_Watchtower_Success() external {
        // Arrange
        uint16 newPercentage = 500;
        Role role = Role.WATCHTOWER;
        address owner = streamManager.owner();

        // Expect event
        vm.expectEmit(address(streamManager));
        emit IStreamManager.SecurityBondPercentageUpdated(role, newPercentage);

        // Act
        vm.prank(owner);
        streamManager.setSecurityBondPercentage(role, newPercentage);

        // Assert
        assertEq(streamManager.getSecurityBondPercentage(role), newPercentage, "Bond percentage should update");
    }

    function test_setSecurityBondPercentage_Revert_InvalidRole() external {
        // Arrange
        address owner = streamManager.owner();

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IStreamManager.InvalidRole.selector, Role.NONE));

        // Act
        vm.prank(owner);
        streamManager.setSecurityBondPercentage(Role.NONE, 5);
    }

    function test_setSecurityBondPercentage_Revert_InvalidPercentage_Zero() external {
        // Arrange
        address owner = streamManager.owner();

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IStreamManager.InvalidPercentage.selector, 0));

        // Act
        vm.prank(owner);
        streamManager.setSecurityBondPercentage(Role.OPERATOR, 0);
    }

    function test_setSecurityBondPercentage_Revert_InvalidPercentage_GreaterThan100() external {
        // Arrange
        address owner = streamManager.owner();

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IStreamManager.InvalidPercentage.selector, 10001));

        // Act
        vm.prank(owner);
        streamManager.setSecurityBondPercentage(Role.OPERATOR, 10001);
    }

    function test_setSecurityBondPercentage_Revert_OwnableUnauthorizedAccount() external {
        // Assert
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, this));

        // Act
        streamManager.setSecurityBondPercentage(Role.OPERATOR, 5);
    }

    // --- Disabling Slot Cost ---
    function test_disablementPaymentsPerChallenge_Success() external view {
        assertEq(
            streamManager.disablementPaymentsPerChallenge(),
            2500000 gwei,
            "Default disablementPaymentsPerChallenge should match default"
        );
    }

    function test_setDisablementPaymentsPerChallenge_Success() external {
        uint256 newCost = 200 gwei;
        address owner = streamManager.owner();
        vm.expectEmit(address(streamManager));
        emit IStreamManager.DisablementPaymentsPerChallengeUpdated(newCost);
        vm.prank(owner);
        streamManager.setDisablementPaymentsPerChallenge(newCost);
        assertEq(
            streamManager.disablementPaymentsPerChallenge(), newCost, "disablementPaymentsPerChallenge should update"
        );
    }

    function test_setDisablementPaymentsPerChallenge_Revert_InvalidZeroValue() external {
        // Arrange
        address owner = streamManager.owner();

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IStreamManager.InvalidZeroValue.selector));

        // Act
        vm.prank(owner);
        streamManager.setDisablementPaymentsPerChallenge(0);
    }

    function test_setDisablementPaymentsPerChallenge_Revert_OwnableUnauthorizedAccount() external {
        // Assert
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, this));

        // Act
        streamManager.setDisablementPaymentsPerChallenge(100 gwei);
    }

    // --- Operator Challenge Run Cost ---
    function test_minimumSecurityDeposit_Success() external view {
        assertEq(
            streamManager.minimumSecurityDeposit(), 22500000 gwei, "Default minimumSecurityDeposit should match default"
        );
    }

    function test_setMinimumSecurityDeposit_Success() external {
        // Arrange
        uint256 newCost = 200 gwei;
        address owner = streamManager.owner();

        // Assert
        vm.expectEmit(address(streamManager));
        emit IStreamManager.MinimumSecurityDepositUpdated(newCost);

        // Act
        vm.prank(owner);
        streamManager.setMinimumSecurityDeposit(newCost);

        // Assert
        assertEq(streamManager.minimumSecurityDeposit(), newCost, "minimumSecurityDeposit should update");
    }

    function test_setMinimumSecurityDeposit_Revert_InvalidZeroValue() external {
        // Arrange
        address owner = streamManager.owner();

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IStreamManager.InvalidZeroValue.selector));

        // Act
        vm.prank(owner);
        streamManager.setMinimumSecurityDeposit(0);
    }

    function test_setMinimumSecurityDeposit_Revert_OwnableUnauthorizedAccount() external {
        // Assert
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, this));

        // Act
        streamManager.setMinimumSecurityDeposit(100 gwei);
    }

    // ==================== SLOT RESERVATION TESTS ====================

    function test_reserveSlot_Success() external {
        // Arrange
        uint64 streamId = setupStreamId;
        uint64 packetNumber = 0;

        // Verify initial state
        Stream memory stream = streamManager.getStreamById(streamId);
        assertEq(stream.peginPacketPointer, 0, "Initial peginPacketPointer should be 0");
        assertEq(streamManager.getSlotsLengthHarness(streamId, packetNumber), 0, "Initial slot count should be 0");

        // Assert event emission
        vm.expectEmit(address(streamManager));
        emit IStreamManager.SlotReserved(streamId, packetNumber, 0);

        // Act
        vm.prank(address(peginManager));
        uint64 slotId = streamManager.reserveSlot(streamId, packetNumber);

        // Assert
        assertEq(slotId, 0, "First slot should have ID 0");
        assertEq(streamManager.getSlotsLengthHarness(streamId, packetNumber), 1, "Slot count should be 1");

        // Verify slot state
        Slot memory slot = streamManager.getSlot(streamId, packetNumber, slotId);
        assertEq(slot.slotId, 0, "Slot ID should match");
        assertEq(uint256(slot.state), uint256(SlotState.RESERVED), "Slot should be in RESERVED state");
        assertEq(slot.acceptPeginTx, bytes32(0), "acceptPeginTx should be empty initially");
        assertEq(slot.acceptPeginAmount, 0, "acceptPeginAmount should be 0 initially");
        assertEq(slot.scriptPubKey, "", "scriptPubKey should be empty initially");
        assertEq(slot.takeTx, bytes32(0), "takeTx should be empty initially");

        // Verify stream peginPacketPointer doesn't advance yet (packet not full)
        Stream memory updatedStream = streamManager.getStreamById(streamId);
        assertEq(updatedStream.peginPacketPointer, 0, "peginPacketPointer should not advance until packet is full");
    }

    function test_reserveSlot_Revert_OnlyPegManager() external {
        // Arrange
        uint64 streamId = setupStreamId;
        uint64 packetNumber = 0;

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IAccessManager.UnauthorizedToModifyPegStatus.selector, address(this)));

        // Act - try to call reserveSlot from non-PegManager address (this test contract)
        streamManager.reserveSlot(streamId, packetNumber);
    }

    function test_reserveSlot_Revert_InvalidPeginPacketNumber() external {
        // Arrange
        uint64 streamId = setupStreamId;
        uint64 wrongPacketNumber = 1; // Stream starts with peginPacketPointer = 0

        // Verify initial state - peginPacketPointer should be 0
        Stream memory stream = streamManager.getStreamById(streamId);
        assertEq(stream.peginPacketPointer, 0, "Initial peginPacketPointer should be 0");

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(IStreamManager.InvalidPeginPacketNumber.selector, streamId, wrongPacketNumber)
        );

        // Act - try to reserve slot in wrong packet (1 instead of 0)
        vm.prank(address(peginManager));
        streamManager.reserveSlot(streamId, wrongPacketNumber);
    }

    function test_reserveSlot_Revert_InconsistentSlotsPerPacket() external {
        // Arrange
        uint64 streamId = setupStreamId;
        uint64 packetNumber = 0;

        // Use harness to artificially fill packet to the limit
        streamManager.pushSlotsHarness(streamId, packetNumber, Constants.SLOTS_PER_PACKET, SlotState.FILLED);

        // Verify we have exactly SLOTS_PER_PACKET slots
        uint256 slotsLength = streamManager.getSlotsLengthHarness(streamId, packetNumber);
        assertEq(slotsLength, Constants.SLOTS_PER_PACKET, "Packet should be at SLOTS_PER_PACKET limit");

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamManager._InconsistentSlotsPerPacket.selector,
                streamId,
                packetNumber,
                Constants.SLOTS_PER_PACKET + 1
            )
        );

        // Act - try to reserve one more slot in the same packet
        vm.prank(address(peginManager));
        streamManager.reserveSlot(streamId, packetNumber);
    }

    function test_reserveSlot_PacketPointerAdvancement() external {
        // Arrange
        uint64 streamId = setupStreamId;
        uint64 packetNumber = 0;

        // Verify initial state
        Stream memory initialStream = streamManager.getStreamById(streamId);
        assertEq(initialStream.peginPacketPointer, 0, "Initial peginPacketPointer should be 0");

        // Reserve Constants.SLOTS_PER_PACKET - 1 slots
        for (uint64 i = 0; i < Constants.SLOTS_PER_PACKET - 1; i++) {
            vm.prank(address(peginManager));
            streamManager.reserveSlot(streamId, packetNumber);
        }

        // Verify peginPacketPointer is still at original value
        Stream memory midStream = streamManager.getStreamById(streamId);
        assertEq(midStream.peginPacketPointer, 0, "peginPacketPointer should still be 0 before packet is full");

        // Reserve one more slot to fill the packet
        vm.prank(address(peginManager));
        streamManager.reserveSlot(streamId, packetNumber);

        // Verify peginPacketPointer has advanced by 1
        Stream memory finalStream = streamManager.getStreamById(streamId);
        assertEq(finalStream.peginPacketPointer, 1, "peginPacketPointer should advance to 1 after packet is full");

        // Verify we have exactly SLOTS_PER_PACKET slots in the packet
        uint256 slotsLength = streamManager.getSlotsLengthHarness(streamId, packetNumber);
        assertEq(slotsLength, Constants.SLOTS_PER_PACKET, "Packet should have exactly SLOTS_PER_PACKET slots");
    }

    // ==================== SLOT FILLING TESTS ====================

    function setup_fillSlot() internal returns (uint64 streamId, uint64 packetNumber, uint64 slotId) {
        streamId = setupStreamId;
        packetNumber = 0;

        // Reserve a slot for filling
        vm.prank(address(peginManager));
        slotId = streamManager.reserveSlot(streamId, packetNumber);

        // Set up stream position for the default acceptPeginTxid
        vm.prank(address(peginManager));
        streamManager.setStreamPosition(
            DEFAULT_ACCEPT_PEGIN_TXID, StreamPosition(streamId, packetNumber, slotId, PegStatus.REGISTERED)
        );
    }

    function test_fillSlot_Success() external {
        // Arrange
        (uint64 streamId, uint64 packetNumber, uint64 slotId) = setup_fillSlot();

        // Prepare test data
        bytes32 acceptPeginTx = bytes32(uint256(0x123456789abcdef));
        uint64 acceptPeginAmount = 100000000; // 1 BTC in satoshis
        bytes memory scriptPubKey = hex"5120abc123def456789012345678901234567890123456789012345678901234567890";

        // Create StreamPosition struct
        StreamPosition memory streamPos = StreamPosition({
            streamId: streamId,
            packetNumber: packetNumber,
            slotId: slotId,
            pegStatus: PegStatus.REGISTERED // This field is not used in fillSlot but required for struct
        });

        // Assert event emission
        vm.expectEmit(address(streamManager));
        emit IStreamManager.SlotFilled(streamId, packetNumber, slotId, acceptPeginTx, acceptPeginAmount);

        // Act
        vm.prank(address(peginManager));
        streamManager.fillSlot(streamPos, acceptPeginAmount, acceptPeginTx, scriptPubKey);

        // Assert
        Slot memory filledSlot = streamManager.getSlot(streamId, packetNumber, slotId);
        assertEq(uint256(filledSlot.state), uint256(SlotState.FILLED), "Slot should be in FILLED state");
        assertEq(filledSlot.acceptPeginTx, acceptPeginTx, "acceptPeginTx should match");
        assertEq(filledSlot.acceptPeginAmount, acceptPeginAmount, "acceptPeginAmount should match");
        assertEq(filledSlot.scriptPubKey, scriptPubKey, "scriptPubKey should match");
        assertEq(filledSlot.slotId, slotId, "slotId should remain unchanged");
    }

    function test_fillSlot_Revert_OnlyPegManager() external {
        // Arrange
        (uint64 streamId, uint64 packetNumber, uint64 slotId) = setup_fillSlot();

        // Prepare test data
        bytes32 acceptPeginTx = bytes32(uint256(0x123456789abcdef));
        uint64 acceptPeginAmount = 100000000;
        bytes memory scriptPubKey = hex"5120abc123def456789012345678901234567890123456789012345678901234567890";

        // Create StreamPosition struct
        StreamPosition memory streamPos = StreamPosition({
            streamId: streamId,
            packetNumber: packetNumber,
            slotId: slotId,
            pegStatus: PegStatus.REGISTERED
        });

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IAccessManager.UnauthorizedToModifyPegStatus.selector, address(this)));

        // Act - try to call fillSlot from non-PegManager address (this test contract)
        streamManager.fillSlot(streamPos, acceptPeginAmount, acceptPeginTx, scriptPubKey);
    }

    function test_fillSlot_Revert_SlotNotReserved() external {
        // Arrange
        uint64 streamId = setupStreamId;
        uint64 packetNumber = 0;

        // Create a slot in FILLED state using harness
        streamManager.pushSlotsHarness(streamId, packetNumber, 1, SlotState.FILLED);
        uint64 slotId = 0;

        // Prepare test data
        bytes32 acceptPeginTx = bytes32(uint256(0x123456789abcdef));
        uint64 acceptPeginAmount = 100000000;
        bytes memory scriptPubKey = hex"5120abc123def456789012345678901234567890123456789012345678901234567890";

        // Create StreamPosition struct
        StreamPosition memory streamPos = StreamPosition({
            streamId: streamId,
            packetNumber: packetNumber,
            slotId: slotId,
            pegStatus: PegStatus.REGISTERED
        });

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamManager.SlotNotReserved.selector, streamId, packetNumber, slotId, SlotState.FILLED
            )
        );

        // Act - try to fill slot that's not in RESERVED state
        vm.prank(address(peginManager));
        streamManager.fillSlot(streamPos, acceptPeginAmount, acceptPeginTx, scriptPubKey);
    }

    function test_fillSlot_Revert_SlotNotReserved_BLOCKED() external {
        // Arrange
        (uint64 streamId, uint64 packetNumber, uint64 slotId) = setup_fillSlot();

        // Block the reserved slot
        vm.prank(address(peginManager));
        streamManager.blockSlot(DEFAULT_ACCEPT_PEGIN_TXID);

        // Verify slot is blocked
        Slot memory blockedSlot = streamManager.getSlot(streamId, packetNumber, slotId);
        assertEq(uint256(blockedSlot.state), uint256(SlotState.BLOCKED), "Slot should be in BLOCKED state");

        // Prepare test data
        bytes32 acceptPeginTx = bytes32(uint256(0x123456789abcdef));
        uint64 acceptPeginAmount = 100000000;
        bytes memory scriptPubKey = hex"5120abc123def456789012345678901234567890123456789012345678901234567890";

        // Create StreamPosition struct
        StreamPosition memory streamPos = StreamPosition({
            streamId: streamId,
            packetNumber: packetNumber,
            slotId: slotId,
            pegStatus: PegStatus.REGISTERED
        });

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamManager.SlotNotReserved.selector, streamId, packetNumber, slotId, SlotState.BLOCKED
            )
        );

        // Act - try to fill blocked slot
        vm.prank(address(peginManager));
        streamManager.fillSlot(streamPos, acceptPeginAmount, acceptPeginTx, scriptPubKey);
    }

    function test_fillSlot_Revert_NonExistentSlot() external {
        // Arrange
        uint64 streamId = setupStreamId;
        uint64 packetNumber = 0;
        uint64 invalidSlotId = 999; // Non-existent slot

        // Prepare test data
        bytes32 acceptPeginTx = bytes32(uint256(0x123456789abcdef));
        uint64 acceptPeginAmount = 100000000;
        bytes memory scriptPubKey = hex"5120abc123def456789012345678901234567890123456789012345678901234567890";

        // Create StreamPosition struct with invalid slotId
        StreamPosition memory streamPos = StreamPosition({
            streamId: streamId,
            packetNumber: packetNumber,
            slotId: invalidSlotId,
            pegStatus: PegStatus.REGISTERED
        });

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(IStreamManager.NonExistentSlot.selector, streamId, packetNumber, invalidSlotId)
        );

        // Act - try to fill non-existent slot
        vm.prank(address(peginManager));
        streamManager.fillSlot(streamPos, acceptPeginAmount, acceptPeginTx, scriptPubKey);
    }

    // ==================== SLOT BLOCKING TESTS ====================

    function setup_filledSlot() internal returns (uint64 streamId, uint64 packetNumber, uint64 slotId) {
        // Start with a reserved slot
        (streamId, packetNumber, slotId) = setup_fillSlot();

        // Fill the slot to have a FILLED slot for testing
        StreamPosition memory streamPos = StreamPosition({
            streamId: streamId,
            packetNumber: packetNumber,
            slotId: slotId,
            pegStatus: PegStatus.REGISTERED
        });

        vm.prank(address(peginManager));
        streamManager.fillSlot(streamPos, 100000000, bytes32(uint256(0x123)), hex"5120abc123");

        // Verify slot is FILLED
        Slot memory filledSlot = streamManager.getSlot(streamId, packetNumber, slotId);
        assertEq(uint256(filledSlot.state), uint256(SlotState.FILLED), "Slot should be FILLED in setup");
    }

    function setup_blockedSlot() internal returns (uint64 streamId, uint64 packetNumber, uint64 slotId) {
        // Start with a reserved slot
        (streamId, packetNumber, slotId) = setup_fillSlot();

        // Block the slot to have a BLOCKED slot for testing
        vm.prank(address(peginManager));
        streamManager.blockSlot(DEFAULT_ACCEPT_PEGIN_TXID);

        // Verify slot is BLOCKED
        Slot memory blockedSlot = streamManager.getSlot(streamId, packetNumber, slotId);
        assertEq(uint256(blockedSlot.state), uint256(SlotState.BLOCKED), "Slot should be BLOCKED in setup");
    }

    function test_blockSlot_Success() external {
        // Arrange
        (uint64 streamId, uint64 packetNumber, uint64 slotId) = setup_fillSlot();

        // Verify slot is initially RESERVED
        Slot memory initialSlot = streamManager.getSlot(streamId, packetNumber, slotId);
        assertEq(uint256(initialSlot.state), uint256(SlotState.RESERVED), "Slot should be RESERVED initially");

        // Store initial slot data to verify it doesn't change
        bytes32 initialAcceptPeginTx = initialSlot.acceptPeginTx;
        uint64 initialAcceptPeginAmount = initialSlot.acceptPeginAmount;
        bytes memory initialScriptPubKey = initialSlot.scriptPubKey;
        bytes32 initialtakeTx = initialSlot.takeTx;

        // Act - call blockSlot as owner
        vm.prank(address(peginManager));
        streamManager.blockSlot(DEFAULT_ACCEPT_PEGIN_TXID);

        // Assert
        Slot memory blockedSlot = streamManager.getSlot(streamId, packetNumber, slotId);
        assertEq(uint256(blockedSlot.state), uint256(SlotState.BLOCKED), "Slot should be BLOCKED after blocking");

        // Verify other slot data remains unchanged
        assertEq(blockedSlot.acceptPeginTx, initialAcceptPeginTx, "acceptPeginTx should remain unchanged");
        assertEq(blockedSlot.acceptPeginAmount, initialAcceptPeginAmount, "acceptPeginAmount should remain unchanged");
        assertEq(blockedSlot.scriptPubKey, initialScriptPubKey, "scriptPubKey should remain unchanged");
        assertEq(blockedSlot.takeTx, initialtakeTx, "takeTx should remain unchanged");
        assertEq(blockedSlot.slotId, slotId, "slotId should remain unchanged");
    }

    function test_blockSlot_Revert_OnlyPegManager() external {
        // Arrange
        (uint64 streamId, uint64 packetNumber, uint64 slotId) = setup_fillSlot();

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IAccessManager.UnauthorizedToModifyPegStatus.selector, address(this)));

        // Act - try to call blockSlot from non-owner address (this test contract)
        streamManager.blockSlot(DEFAULT_ACCEPT_PEGIN_TXID);
    }

    function test_blockSlot_Revert_SlotNotBlockable_FILLED() external {
        // Arrange
        (uint64 streamId, uint64 packetNumber, uint64 slotId) = setup_filledSlot();

        // Verify slot is FILLED
        Slot memory slot = streamManager.getSlot(streamId, packetNumber, slotId);
        assertEq(uint256(slot.state), uint256(SlotState.FILLED), "Slot should be FILLED");

        // Act - try to block filled slot (should revert)
        vm.prank(address(peginManager));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamManager.SlotNotBlockable.selector, streamId, packetNumber, slotId, SlotState.FILLED
            )
        );
        streamManager.blockSlot(DEFAULT_ACCEPT_PEGIN_TXID);
    }

    function test_blockSlot_Revert_SlotNotBlockable_LOCKED() external {
        // Arrange
        uint64 streamId = setupStreamId;
        uint64 packetNumber = 0;
        (uint64 slotId, bytes32 txid) = setup_slotWithState(streamId, packetNumber, SlotState.LOCKED);

        // Verify slot is LOCKED
        Slot memory slot = streamManager.getSlot(streamId, packetNumber, slotId);
        assertEq(uint256(slot.state), uint256(SlotState.LOCKED), "Slot should be LOCKED");

        // Act - try to block locked slot (should revert)
        vm.prank(address(peginManager));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamManager.SlotNotBlockable.selector, streamId, packetNumber, slotId, SlotState.LOCKED
            )
        );
        streamManager.blockSlot(txid);
    }

    function test_blockSlot_Revert_SlotNotBlockable_COMPLETED() external {
        // Arrange
        uint64 streamId = setupStreamId;
        uint64 packetNumber = 0;
        (uint64 slotId, bytes32 txid) = setup_slotWithState(streamId, packetNumber, SlotState.COMPLETED);

        // Verify slot is COMPLETED
        Slot memory slot = streamManager.getSlot(streamId, packetNumber, slotId);
        assertEq(uint256(slot.state), uint256(SlotState.COMPLETED), "Slot should be COMPLETED");

        // Act - try to block completed slot (should revert)
        vm.prank(address(peginManager));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamManager.SlotNotBlockable.selector, streamId, packetNumber, slotId, SlotState.COMPLETED
            )
        );
        streamManager.blockSlot(txid);
    }

    function test_blockSlot_Revert_SlotNotBlockable_BLOCKED() external {
        // Arrange
        uint64 streamId = setupStreamId;
        uint64 packetNumber = 0;
        (uint64 slotId, bytes32 txid) = setup_slotWithState(streamId, packetNumber, SlotState.BLOCKED);

        // Verify slot is BLOCKED
        Slot memory slot = streamManager.getSlot(streamId, packetNumber, slotId);
        assertEq(uint256(slot.state), uint256(SlotState.BLOCKED), "Slot should be BLOCKED");

        // Act - try to block already blocked slot (should revert)
        vm.prank(address(peginManager));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamManager.SlotNotBlockable.selector, streamId, packetNumber, slotId, SlotState.BLOCKED
            )
        );
        streamManager.blockSlot(txid);
    }

    function test_blockSlot_Revert_NonExistentSlot() external {
        // Arrange
        uint64 streamId = setupStreamId;
        uint64 packetNumber = 0;
        uint64 invalidSlotId = 999; // Non-existent slot

        // Set up stream position pointing to invalid slot
        bytes32 testTxid = bytes32(uint256(0x111));
        vm.prank(address(peginManager));
        streamManager.setStreamPosition(
            testTxid, StreamPosition(streamId, packetNumber, invalidSlotId, PegStatus.REGISTERED)
        );

        // Act - try to block non-existent slot (should revert)
        vm.prank(address(peginManager));
        vm.expectRevert(
            abi.encodeWithSelector(IStreamManager.NonExistentSlot.selector, streamId, packetNumber, invalidSlotId)
        );
        streamManager.blockSlot(testTxid);
    }

    // ==================== ENHANCED LOCKSLOT TESTS ====================

    function test_lockSlot_Success_SkipBlockedSlot() external {
        // Arrange - Create pattern: BLOCKED, FILLED using setup functions
        (uint64 streamId, uint64 packetNumber, uint64 slotId0) = setup_blockedSlot();
        (,, uint64 slotId1) = setup_filledSlot();

        // Act - First lockSlot call should lock slot 1
        vm.prank(address(pegoutManager));
        (Slot memory lockedSlot, uint64 returnedPacketNumber) = streamManager.lockSlot(streamId);

        // Assert first call
        assertEq(lockedSlot.slotId, slotId1, "First locked slot should be slot 1");
        assertEq(uint256(lockedSlot.state), uint256(SlotState.LOCKED), "First locked slot should be LOCKED");
        assertEq(returnedPacketNumber, packetNumber, "Returned packet number should match");

        // Verify slot 1 is now LOCKED
        Slot memory updatedSlot1 = streamManager.getSlot(streamId, packetNumber, slotId1);
        assertEq(uint256(updatedSlot1.state), uint256(SlotState.LOCKED), "Slot 1 should be LOCKED after first call");

        // Verify slot 0 is still BLOCKED (unchanged)
        Slot memory updatedSlot0 = streamManager.getSlot(streamId, packetNumber, slotId0);
        assertEq(uint256(updatedSlot0.state), uint256(SlotState.BLOCKED), "Slot 0 should remain BLOCKED");
    }

    function test_lockSlot_Success_SkipMultipleBlockedSlots() external {
        // TODO: Test lockSlot with multiple consecutive blocked slots
        // Arrange - Create pattern: BLOCKED, BLOCKED, FILLED using setup functions
        (uint64 streamId, uint64 packetNumber, uint64 slotId0) = setup_blockedSlot();
        (,, uint64 slotId1) = setup_blockedSlot();
        (,, uint64 slotId2) = setup_filledSlot();

        // Act - First lockSlot call should lock slot 2
        vm.prank(address(pegoutManager));
        (Slot memory lockedSlot, uint64 returnedPacketNumber) = streamManager.lockSlot(streamId);

        // Assert first call
        assertEq(lockedSlot.slotId, slotId2, "First locked slot should be slot 2");
        assertEq(uint256(lockedSlot.state), uint256(SlotState.LOCKED), "First locked slot should be LOCKED");
        assertEq(returnedPacketNumber, packetNumber, "Returned packet number should match");

        // Verify slot 2 is now LOCKED
        Slot memory updatedSlot2 = streamManager.getSlot(streamId, packetNumber, slotId2);
        assertEq(uint256(updatedSlot2.state), uint256(SlotState.LOCKED), "Slot 2 should be LOCKED after first call");

        // Verify slot 0 is still BLOCKED (unchanged)
        Slot memory updatedSlot0 = streamManager.getSlot(streamId, packetNumber, slotId0);
        assertEq(uint256(updatedSlot0.state), uint256(SlotState.BLOCKED), "Slot 0 should remain BLOCKED");

        // Verify slot 1 is still BLOCKED (unchanged)
        Slot memory updatedSlot1 = streamManager.getSlot(streamId, packetNumber, slotId1);
        assertEq(uint256(updatedSlot1.state), uint256(SlotState.BLOCKED), "Slot 1 should remain BLOCKED");
    }

    function test_lockSlot_Success_ThirdPacket() external {
        uint64 streamId = setupStreamId;

        // Fill first packet with BLOCKED slots
        uint64 firstPacketNumber = 0;
        streamManager.pushSlotsHarness(streamId, firstPacketNumber, Constants.SLOTS_PER_PACKET, SlotState.BLOCKED);
        // Fill second packet with RESERVED slots
        uint64 secondPacketNumber = 1;
        streamManager.pushSlotsHarness(streamId, firstPacketNumber, Constants.SLOTS_PER_PACKET, SlotState.BLOCKED);

        // Create a new packet and add one filled slot
        // For the pourpose of this test we can reuse the existing committee that was created during the setup
        uint128 committeeId = COMMITTEE_ID_STREAM_1_COMMITTEE_1;
        bytes memory committeePubKey = COMMITTEE_TAKE_PUB_KEY();
        CompactPubKey[] memory disputeKeys = registry.getCommitteeDisputeKeys(committeeId);
        vm.prank(address(registry));
        streamManager.createNewPacket(streamId, committeeId, committeePubKey, disputeKeys);
        uint64 thirdPacketNumber = 2;
        streamManager.pushSlotsHarness(streamId, thirdPacketNumber, 1, SlotState.FILLED);

        // Act - lockSlot should skip to second packet
        vm.prank(address(pegoutManager));
        (Slot memory lockedSlot, uint64 returnedPacketNumber) = streamManager.lockSlot(streamId);

        // Assert
        assertEq(returnedPacketNumber, thirdPacketNumber, "Should return third packet number");
        assertEq(lockedSlot.slotId, 0, "Should lock first slot in packet");
        assertEq(uint256(lockedSlot.state), uint256(SlotState.LOCKED), "Slot should be LOCKED");
    }

    function test_lockSlot_Revert_PegoutInProcess() external {
        // Arrange
        uint64 streamId = setupStreamId;
        uint64 packetNumber = 0;
        uint64 slotsAmount = 1;

        streamManager.pushSlotsHarness(streamId, packetNumber, slotsAmount, SlotState.FILLED);
        streamManager.pushSlotsHarness(streamId, packetNumber, slotsAmount, SlotState.LOCKED);

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IStreamManager.PegoutInProcess.selector, streamId));

        // Act
        vm.prank(address(pegoutManager));
        streamManager.lockSlot(streamId);
    }

    function _test_lockSlot_Revert_NoFilledSlot(SlotState slotState) internal {
        // Arrange
        uint64 streamId = setupStreamId;
        uint64 packetNumber = 0;

        // Create multiple blocked slots
        streamManager.pushSlotsHarness(streamId, packetNumber, Constants.SLOTS_PER_PACKET, slotState);

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IStreamManager.NoFilledSlot.selector, streamId));

        // Act
        vm.prank(address(pegoutManager));
        streamManager.lockSlot(streamId);
    }

    function test_lockSlot_Revert_NoFilledSlot_AllReserved() external {
        _test_lockSlot_Revert_NoFilledSlot(SlotState.RESERVED);
    }

    function test_lockSlot_Revert_NoFilledSlot_AllBlocked() external {
        _test_lockSlot_Revert_NoFilledSlot(SlotState.BLOCKED);
    }

    function test_integration_CompleteFlow_RESERVED_to_COMPLETED() external {
        // Test complete slot lifecycle without blocking
        // RESERVED -> FILLED -> LOCKED -> ADVANCED -> COMPLETED

        uint64 streamId = setupStreamId;
        uint64 packetNumber = 0;
        bytes32 acceptPeginTx = bytes32(uint256(0x123));
        uint64 acceptPeginAmount = 100000000;
        bytes memory scriptPubKey = hex"5120abc123";
        bytes32 userTakeTx = bytes32(uint256(0x456));

        // 1. Reserve slot
        vm.prank(address(peginManager));
        uint64 slotId = streamManager.reserveSlot(streamId, packetNumber);

        // 2. Fill slot and set up stream position
        StreamPosition memory streamPos = StreamPosition({
            streamId: streamId,
            packetNumber: packetNumber,
            slotId: slotId,
            pegStatus: PegStatus.REGISTERED
        });
        vm.startPrank(address(peginManager));
        streamManager.setStreamPosition(acceptPeginTx, streamPos);
        streamManager.fillSlot(streamPos, acceptPeginAmount, acceptPeginTx, scriptPubKey);
        vm.stopPrank();

        // 3. Lock slot
        vm.prank(address(pegoutManager));
        streamManager.lockSlot(streamId);

        // 4. Advance slot
        vm.prank(address(pegoutManager));
        streamManager.advanceSlot(acceptPeginTx);

        // 5. Complete slot
        vm.prank(address(pegoutManager));
        streamManager.completeSlot(acceptPeginTx, userTakeTx);

        // Verify final state
        Slot memory completedSlot = streamManager.getSlot(streamId, packetNumber, slotId);
        assertEq(uint256(completedSlot.state), uint256(SlotState.COMPLETED), "Slot should be COMPLETED");
        assertEq(completedSlot.takeTx, userTakeTx, "userTakeTx should be stored");
    }

    function test_completeSlot_ClosePacket_OutOfOrderFills() external {
        // Test to check that packet closes only if all slots are finished (i.e., blocked or completed) and not before
        // This test uses the full pegin/pegout flow (requestPegin -> acceptPegin -> tryPegout -> registerUserTake)

        // Arrange
        // Store all request pegin transactions
        BtcTransaction[] memory requestPeginTxs = new BtcTransaction[](Constants.SLOTS_PER_PACKET);
        // Do 100 request pegins (reserves slots 0-99 in order)
        for (uint64 i = 0; i < Constants.SLOTS_PER_PACKET; i++) {
            (BtcTransaction memory btcTx,) = setup_requestPeginFlow();
            requestPeginTxs[i] = btcTx;
        }
        // Accept pegins out of order: 0-97, then 99, then 98
        // So filledSlots will be [0,1,...,97,99,98]
        uint64 pegoutsInOrder = Constants.SLOTS_PER_PACKET - 2;
        for (uint64 i = 0; i < pegoutsInOrder; i++) {
            setup_acceptPeginFlow(requestPeginTxs[i]);
        }
        setup_acceptPeginFlow(requestPeginTxs[99]);
        setup_acceptPeginFlow(requestPeginTxs[98]);

        bytes memory userPubKey = hex"02d56ad001b55eabf431e602599fcc0d7ed9d676ac93c2be11d0de6e25dd598d8b";
        Stream memory stream = streamManager.getStreamById(setupStreamId);
        uint64 pegoutAmount = stream.denomination;
        uint256 pegoutAmountInWei = BtcHelper.satoshiToWei(pegoutAmount);

        // Do 99 pegouts full flow
        // Order should be: 0, 1, 2, ..., 97, 99, 98 since it depends on filled slots order
        uint64[] memory expectedPegoutOrder = new uint64[](Constants.SLOTS_PER_PACKET);
        for (uint64 i = 0; i < Constants.SLOTS_PER_PACKET - 2; i++) {
            expectedPegoutOrder[i] = i;
        }
        expectedPegoutOrder[98] = 99;
        expectedPegoutOrder[99] = 98;

        uint64 expectedPacketNumber = 0;
        for (uint64 pegoutIndex = 0; pegoutIndex < Constants.SLOTS_PER_PACKET - 1; pegoutIndex++) {
            SlotLocation memory slotLocation = streamManager.getNextPegoutSlotLocation(setupStreamId);
            uint64 returnedPacketNumber = slotLocation.packetId;
            assertEq(returnedPacketNumber, expectedPacketNumber);
            uint64 slotId = slotLocation.slotId;
            assertEq(slotId, expectedPegoutOrder[pegoutIndex]);

            // Prepare and perform a real pegout
            bridgeMock.setWeisTransferredToUnionBridge(pegoutAmountInWei);
            vm.prank(globalUserAddress);
            pegoutManager.tryPegout{value: pegoutAmountInWei}(userPubKey);
            // Build pegout tx SPV proof for this locked slot and register the user take
            Slot memory slot = streamManager.getSlot(stream.streamId, returnedPacketNumber, slotId);
            PrevoutData[] memory prevoutDatas = new PrevoutData[](2);
            prevoutDatas[0] = PrevoutData({value: slot.acceptPeginAmount, scriptPubKey: slot.scriptPubKey});
            prevoutDatas[1] = PrevoutData({
                value: Constants.ENABLER_AMOUNT,
                scriptPubKey: streamManager.getEnablerScriptPubKey(stream.streamId, returnedPacketNumber)
            });
            BitcoinSignatureData memory pegoutSignatureData =
                bitcoinManager.getPegoutTxData(userPubKey, slot.acceptPeginTx, prevoutDatas);
            BtcTxSPVProof memory pegoutProof = createBtcTxSPVProof(pegoutSignatureData.tx);

            pegoutManager.registerUserTake(pegoutProof);
        }

        // last pegout
        SlotLocation memory lastSlotLocation = streamManager.getNextPegoutSlotLocation(setupStreamId);
        assertEq(lastSlotLocation.packetId, expectedPacketNumber);
        assertEq(lastSlotLocation.slotId, expectedPegoutOrder[99]);

        // Prepare and perform a real pegout
        bridgeMock.setWeisTransferredToUnionBridge(pegoutAmountInWei);
        vm.prank(globalUserAddress);
        pegoutManager.tryPegout{value: pegoutAmountInWei}(userPubKey);
        // Build pegout tx SPV proof for this locked slot and register the user take
        Slot memory lastSlot =
            streamManager.getSlot(stream.streamId, lastSlotLocation.packetId, lastSlotLocation.slotId);
        PrevoutData[] memory lastPrevoutDatas = new PrevoutData[](2);
        lastPrevoutDatas[0] = PrevoutData({value: lastSlot.acceptPeginAmount, scriptPubKey: lastSlot.scriptPubKey});
        lastPrevoutDatas[1] = PrevoutData({
            value: Constants.ENABLER_AMOUNT,
            scriptPubKey: streamManager.getEnablerScriptPubKey(stream.streamId, 0)
        });
        BitcoinSignatureData memory lastPegoutSignatureData =
            bitcoinManager.getPegoutTxData(userPubKey, lastSlot.acceptPeginTx, lastPrevoutDatas);
        BtcTxSPVProof memory lastPegoutProof = createBtcTxSPVProof(lastPegoutSignatureData.tx);

        // Assert
        vm.expectEmit(address(streamManager));
        emit IStreamManager.PacketClosed(setupStreamId, lastSlotLocation.packetId);

        // Act
        pegoutManager.registerUserTake(lastPegoutProof);

        // Assert
        Packet memory packet = streamManager.getPacket(setupStreamId, lastSlotLocation.packetId);
        assertEq(packet.finishedSlots, Constants.SLOTS_PER_PACKET);
    }

    function test_getEnablerScriptPubKey_Success() external view {
        // Arrange
        uint64 packetNumber = 0; // First packet created during setUp

        // Act
        bytes memory enablerScriptPubKey = streamManager.getEnablerScriptPubKey(setupStreamId, packetNumber);

        // Assert
        bytes memory expectedEnablerScriptPubKey =
            hex"51201cbeafdb8fa122bf71ea817df2ed9131bfa165952d63ba5841313f918a0f86c9";
        assertEq(enablerScriptPubKey, expectedEnablerScriptPubKey, "enablerScriptPubKey should match expected value");
    }

    function test_getEnablerScriptPubKey_Revert_StreamNotFound() external {
        // Arrange
        uint64 invalidStreamId = 999;
        uint64 packetNumber = 0;

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IStreamManager.StreamNotFoundById.selector, invalidStreamId));

        // Act
        streamManager.getEnablerScriptPubKey(invalidStreamId, packetNumber);
    }

    function test_getEnablerScriptPubKey_Revert_PacketOutOfBound() external {
        // Arrange
        uint64 invalidPacketNumber = 999;

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IStreamManager.PacketOutOfBound.selector, invalidPacketNumber));

        // Act
        streamManager.getEnablerScriptPubKey(setupStreamId, invalidPacketNumber);
    }

    // ==================== INITIALIZE STREAMS TESTS ====================

    function test_initializeStreams_Success() external {
        // Arrange
        StreamManagerHarness cleanStreamManager = setup_cleanStreamManager();
        StreamSettings[] memory streamSettings = setup_streamSettings();
        uint256 expectedLength = uint256(StreamDenomination.LENGTH);

        //Act
        cleanStreamManager.initializeStreams(streamSettings);

        //Assert
        assertEq(
            cleanStreamManager.getStreamsLength(),
            expectedLength,
            "Streams length should be equal to the number of denominations"
        );
        for (uint64 i = 0; i < expectedLength; i++) {
            Stream memory stream = cleanStreamManager.getStreamById(i);
            assertEq(
                stream.denomination,
                streamSettings[i].denomination,
                "Stream denomination should be equal to the denomination"
            );
            assertEq(
                stream.peginConfirmations,
                streamSettings[i].peginConfirmations,
                "Pegin confirmations should be equal to the pegin confirmations"
            );
            assertEq(
                stream.rejectPeginConfirmations,
                streamSettings[i].rejectPeginConfirmations,
                "Reject pegin confirmations should be equal to the reject pegin confirmations"
            );
            assertEq(
                stream.pegoutConfirmations,
                streamSettings[i].pegoutConfirmations,
                "Pegout confirmations should be equal to the pegout confirmations"
            );
        }
    }

    function test_initializeStreams_Revert_NotOwner() external {
        // Arrange
        StreamManagerHarness cleanStreamManager = setup_cleanStreamManager();
        StreamSettings[] memory streamSettings = setup_streamSettings();

        // Assert
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(0x123)));

        // Act - Try to call as non-owner
        vm.prank(address(0x123));
        cleanStreamManager.initializeStreams(streamSettings);
    }

    function test_initializeStreams_Revert_EmptyArray() external {
        // Arrange
        StreamManagerHarness cleanStreamManager = setup_cleanStreamManager();
        StreamSettings[] memory streamSettings = new StreamSettings[](0);

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamManager.InvalidStreamSettingsLength.selector, 0, uint256(StreamDenomination.LENGTH)
            )
        );

        // Act
        cleanStreamManager.initializeStreams(streamSettings);
    }

    function test_initializeStreams_Revert_TooManyDenominations() external {
        // Arrange
        StreamManagerHarness cleanStreamManager = setup_cleanStreamManager();
        uint64[] memory denominations = StreamManagerSettingsConfig.getDenominations();
        uint256 arraySize = uint256(StreamDenomination.LENGTH) + 1;
        StreamSettings[] memory streamSettings = new StreamSettings[](arraySize);
        for (uint256 i = 0; i < arraySize; i++) {
            // Use valid streamId (modulo to stay within valid range)
            uint64 streamId = uint64(i % uint256(StreamDenomination.LENGTH));
            streamSettings[i] =
                StreamManagerSettingsConfig.getStreamSettings(ChainIds.LOCAL, streamId, denominations[streamId], true);
        }

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamManager.InvalidStreamSettingsLength.selector, arraySize, uint256(StreamDenomination.LENGTH)
            )
        );

        // Act
        cleanStreamManager.initializeStreams(streamSettings);
    }

    function test_initializeStreams_Revert_ZeroDenomination() external {
        // Arrange
        StreamManagerHarness cleanStreamManager = setup_cleanStreamManager();
        StreamSettings[] memory streamSettings = setup_streamSettings();
        streamSettings[0].denomination = 0; // Invalid

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamManager.InvalidStreamSettings.selector,
                0,
                0,
                streamSettings[0].peginConfirmations,
                streamSettings[0].pegoutConfirmations
            )
        );

        // Act
        cleanStreamManager.initializeStreams(streamSettings);
    }

    function test_initializeStreams_Revert_ZeroPeginConfirmations() external {
        // Arrange
        StreamManagerHarness cleanStreamManager = setup_cleanStreamManager();
        StreamSettings[] memory streamSettings = setup_streamSettings();
        streamSettings[0].peginConfirmations = 0; // Invalid

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamManager.InvalidStreamSettings.selector,
                0,
                streamSettings[0].denomination,
                0,
                streamSettings[0].pegoutConfirmations
            )
        );

        // Act
        cleanStreamManager.initializeStreams(streamSettings);
    }

    function test_initializeStreams_Revert_ZeroPegoutConfirmations() external {
        // Arrange
        StreamManagerHarness cleanStreamManager = setup_cleanStreamManager();
        StreamSettings[] memory streamSettings = setup_streamSettings();
        streamSettings[0].pegoutConfirmations = 0; // Invalid

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamManager.InvalidStreamSettings.selector,
                0,
                streamSettings[0].denomination,
                streamSettings[0].peginConfirmations,
                0
            )
        );

        // Act
        cleanStreamManager.initializeStreams(streamSettings);
    }

    function test_initializeStreams_Revert_InvalidRejectPeginConfirmations() external {
        // Arrange
        StreamManagerHarness cleanStreamManager = setup_cleanStreamManager();
        StreamSettings[] memory streamSettings = setup_streamSettings();
        streamSettings[0].rejectPeginConfirmations = 0; // Invalid

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IStreamManager.InvalidRejectPeginConfirmations.selector, uint8(0)));

        // Act
        cleanStreamManager.initializeStreams(streamSettings);
    }

    function test_initializeStreams_Revert_RejectPeginConfirmationsExceedsPegin() external {
        // Arrange - setup has peginConfirmations 2, rejectPeginConfirmations 2; set reject > pegin
        StreamManagerHarness cleanStreamManager = setup_cleanStreamManager();
        StreamSettings[] memory streamSettings = setup_streamSettings();
        streamSettings[0].peginConfirmations = 2;
        streamSettings[0].rejectPeginConfirmations = 5; // Invalid: 5 > 2

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(IStreamManager.RejectPeginConfirmationsExceedsPegin.selector, uint8(5), uint8(2))
        );

        // Act
        cleanStreamManager.initializeStreams(streamSettings);
    }

    function test_initializeStreams_Revert_InvalidTimelockSettings_ZeroShortTimelock() external {
        // Arrange
        StreamManagerHarness cleanStreamManager = setup_cleanStreamManager();
        StreamSettings[] memory streamSettings = setup_streamSettings();
        streamSettings[0].timelockSettings.shortTimelock = 0; // Invalid

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(IStreamManager.InvalidTimelockSettings.selector, streamSettings[0].timelockSettings)
        );

        // Act
        cleanStreamManager.initializeStreams(streamSettings);
    }

    function test_initializeStreams_Revert_InvalidTimelockSettings_ZeroLongTimelock() external {
        // Arrange
        StreamManagerHarness cleanStreamManager = setup_cleanStreamManager();
        StreamSettings[] memory streamSettings = setup_streamSettings();
        streamSettings[0].timelockSettings.longTimelock = 0; // Invalid

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(IStreamManager.InvalidTimelockSettings.selector, streamSettings[0].timelockSettings)
        );

        // Act
        cleanStreamManager.initializeStreams(streamSettings);
    }

    function test_initializeStreams_Revert_InvalidTimelockSettings_ZeroRequestPeginTimelock() external {
        // Arrange
        StreamManagerHarness cleanStreamManager = setup_cleanStreamManager();
        StreamSettings[] memory streamSettings = setup_streamSettings();
        streamSettings[0].timelockSettings.requestPeginTimelock = 0; // Invalid

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(IStreamManager.InvalidTimelockSettings.selector, streamSettings[0].timelockSettings)
        );

        // Act
        cleanStreamManager.initializeStreams(streamSettings);
    }

    function test_initializeStreams_Revert_InvalidTimelockSettings_ZeroOpWonTimelock() external {
        // Arrange
        StreamManagerHarness cleanStreamManager = setup_cleanStreamManager();
        StreamSettings[] memory streamSettings = setup_streamSettings();
        streamSettings[0].timelockSettings.opWonTimelock = 0; // Invalid

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(IStreamManager.InvalidTimelockSettings.selector, streamSettings[0].timelockSettings)
        );

        // Act
        cleanStreamManager.initializeStreams(streamSettings);
    }

    function test_initializeStreams_Revert_InvalidTimelockSettings_ZeroClaimGateTimelock() external {
        // Arrange
        StreamManagerHarness cleanStreamManager = setup_cleanStreamManager();
        StreamSettings[] memory streamSettings = setup_streamSettings();
        streamSettings[0].timelockSettings.claimGateTimelock = 0; // Invalid

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(IStreamManager.InvalidTimelockSettings.selector, streamSettings[0].timelockSettings)
        );

        // Act
        cleanStreamManager.initializeStreams(streamSettings);
    }

    function test_initializeStreams_Revert_InvalidTimelockSettings_ZeroInputNotRevealedTimelock() external {
        // Arrange
        StreamManagerHarness cleanStreamManager = setup_cleanStreamManager();
        StreamSettings[] memory streamSettings = setup_streamSettings();
        streamSettings[0].timelockSettings.inputNotRevealedTimelock = 0; // Invalid

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(IStreamManager.InvalidTimelockSettings.selector, streamSettings[0].timelockSettings)
        );

        // Act
        cleanStreamManager.initializeStreams(streamSettings);
    }

    function test_initializeStreams_Revert_InvalidTimelockSettings_ZeroOpNoCosignTimelock() external {
        // Arrange
        StreamManagerHarness cleanStreamManager = setup_cleanStreamManager();
        StreamSettings[] memory streamSettings = setup_streamSettings();
        streamSettings[0].timelockSettings.opNoCosignTimelock = 0; // Invalid

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(IStreamManager.InvalidTimelockSettings.selector, streamSettings[0].timelockSettings)
        );

        // Act
        cleanStreamManager.initializeStreams(streamSettings);
    }

    function test_initializeStreams_Revert_InvalidTimelockSettings_ZeroWtNoChallengeTimelock() external {
        // Arrange
        StreamManagerHarness cleanStreamManager = setup_cleanStreamManager();
        StreamSettings[] memory streamSettings = setup_streamSettings();
        streamSettings[0].timelockSettings.wtNoChallengeTimelock = 0; // Invalid

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(IStreamManager.InvalidTimelockSettings.selector, streamSettings[0].timelockSettings)
        );

        // Act
        cleanStreamManager.initializeStreams(streamSettings);
    }

    function test_initializeStreams_Revert_StreamsAlreadyInitialized() external {
        // Arrange - Streams are already initialized in setUp, so try to initialize streams again
        StreamSettings[] memory streamSettings = setup_streamSettings();
        address owner = streamManager.owner();

        // Assert - Should revert because streams are already initialized
        vm.expectRevert(abi.encodeWithSelector(IStreamManager.StreamsAlreadyInitialized.selector));

        // Act
        vm.prank(owner);
        streamManager.initializeStreams(streamSettings);
    }

    function setup_streamSettings() internal view returns (StreamSettings[] memory streamSettings) {
        uint64[] memory denominations = StreamManagerSettingsConfig.getDenominations();
        uint256 length = uint256(StreamDenomination.LENGTH);
        streamSettings = new StreamSettings[](length);
        for (uint64 i = 0; i < length; i++) {
            streamSettings[i] = StreamManagerSettingsConfig.getStreamSettings(ChainIds.LOCAL, i, denominations[i], true);
        }
        return streamSettings;
    }

    function test_getFilledSlotsCount_Success() external {
        // Arrange
        bytes memory userPubKey = hex"02d56ad001b55eabf431e602599fcc0d7ed9d676ac93c2be11d0de6e25dd598d8b";
        uint64 amount = VALUE;
        Stream memory stream = streamManager.getStream(amount);
        uint256 amountInWei = BtcHelper.satoshiToWei(amount);

        // Act & Assert - Initially 0 filled slots
        assertEq(streamManager.getFilledSlotsCount(stream.streamId), 0, "Filled slot count should be 0");

        // Arrange
        setup_multipleRequestAndAcceptPeginFlows(1);

        // Act & Assert - After one filled slot
        assertEq(streamManager.getFilledSlotsCount(stream.streamId), 1, "Filled slot count should be 1");
    }

    // ==================== TESTNET ONLY FUNCTION TESTS ====================

    function test_restartStreamPointers_TESTNET_Revert_OwnableUnauthorizedAccount() external {
        // Arrange
        address unauthorizedAccount = address(0x1234);

        // Assert
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, unauthorizedAccount));

        // Act
        vm.prank(unauthorizedAccount);
        streamManager.restartStreamPointers_TESTNET(setupStreamId);
    }

    function test_restartStreamPointers_TESTNET_Revert_TestnetOnlyFunction() external {
        // Arrange
        address owner = streamManager.owner();

        // Simulate RSK mainnet (chain ID 30)
        vm.chainId(30);

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IAccessManager.TestnetOnlyFunction.selector));

        // Act
        vm.prank(owner);
        streamManager.restartStreamPointers_TESTNET(setupStreamId);
    }
    // ==================== END TESTNET ONLY FUNCTION TESTS ====================
}
