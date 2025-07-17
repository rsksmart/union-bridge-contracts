// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {HelperContract} from "test/helpers/HelperContract.sol";
import {SlotState, Slot, Packet, IStreamManager, StreamDenomination} from "src/interfaces/IStreamManager.sol";
import {Constants} from "src/libraries/Constants.sol";
import {BtcHelper} from "src/libraries/BtcHelper.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Role} from "src/interfaces/ICommitteeRegistry.sol";

contract TestStreamManager is Test, HelperContract {
    uint64 internal setupStreamId;

    function setUp() external {
        runTestDeployScript();
        (, setupStreamId) = setup_completeCommittee();
    }

    function test_lockSlot_Success() external {
        // Arrange
        streamManager.setSlotHarness(setupStreamId, 0, hex"00", 0, 0, SlotState.FILLED);

        // Act
        vm.prank(address(pm));
        (Slot memory slot,) = streamManager.lockSlot(setupStreamId);

        // Assert
        assertEq(uint64(slot.state), uint64(SlotState.LOCKED), "Incorrect slot state");
    }

    function test_lockSlot_NonExistentSlot() external {
        // Assert
        vm.expectRevert(abi.encodeWithSelector(IStreamManager.NoFilledSlot.selector, setupStreamId));

        // Act
        vm.prank(address(pm));
        streamManager.lockSlot(setupStreamId);
    }

    function test_lockSlot_NoFilledSlot() external {
        // Arrange
        streamManager.pushSlotsHarness(setupStreamId, 0, 1, SlotState.LOCKED);
        uint256 slotsLength = streamManager.getSlotsLengthHarness(setupStreamId, 0);
        assertEq(slotsLength, 1, "Incorrect slots length");

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IStreamManager.NoFilledSlot.selector, setupStreamId));

        // Act
        vm.prank(address(pm));
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
        vm.prank(address(pm));
        streamManager.reserveSlot(setupStreamId, 0);
    }

    function test_createNewPacket_Success() external {
        // Arrange
        // we expect the packet number to be 1 since the first packet is being created in the test setup function
        uint64 expectedPacketNumber = 1;
        bytes32 committeePubKey = bytes32(uint256(1));

        // Assert
        vm.expectEmit(address(streamManager));
        emit IStreamManager.PacketCreated(setupStreamId, expectedPacketNumber);

        // Act
        vm.prank(address(registry));
        streamManager.createNewPacket(setupStreamId, COMMITTEE_ID_STREAM_1_PACKET_1, committeePubKey);

        // Assert
        Packet memory packet = streamManager.getPacket(setupStreamId, expectedPacketNumber);
        assertEq(packet.packetNumber, expectedPacketNumber, "packetNumber was not set correctly");
        assertEq(packet.committeePubKey, committeePubKey, "committeePubKey was not set correctly");
    }

    function test_setPeginConfirmations_Success() external {
        // Arrange
        uint64 streamId = 0;

        // Assert
        assertEq(streamManager.getStreamById(streamId).peginConfirmations, 2, "Pegin confirmation should be default");

        // set to 7 confirmations
        uint8 peginConfirmations = 7;

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

    function test_setPeginConfirmations_Revert_RequireGreaterThanZero() external {
        // Arrange
        uint64 streamId = 0;
        vm.prank(address(streamManager.owner()));

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IStreamManager.InvalidPeginConfirmations.selector, 0));

        // Act
        streamManager.setPeginConfirmations(streamId, 0);
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

    function test_getAvailablePeginCommitteeId_Success() external {
        // Arrange
        setup_multipleRequestAndAcceptPeginFlows(Constants.SLOTS_PER_PACKET - 1, setupStreamId);

        // Act
        uint256 currentPacketCommitteeId = streamManager.getAvailablePeginCommitteeId(setupStreamId);

        // Assert
        assertEq(currentPacketCommitteeId, COMMITTEE_ID_STREAM_1_PACKET_0, "Current packet committee ID should match");
    }

    function test_getAvailablePeginCommitteeId_Success_NoCommitteeForCurrentPacket() external {
        // Arrange
        setup_multipleRequestAndAcceptPeginFlows(Constants.SLOTS_PER_PACKET, setupStreamId);

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

        for (uint8 i = 0; i <= uint8(StreamDenomination._10BTC); i++) {
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
}
