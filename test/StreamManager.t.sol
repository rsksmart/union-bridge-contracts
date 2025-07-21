// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {HelperContract} from "test/helpers/HelperContract.sol";
import {SlotState, Slot, Packet, Stream, IStreamManager, StreamDenomination} from "src/interfaces/IStreamManager.sol";
import {IAccessControl} from "src/interfaces/IAccessControl.sol";
import {StreamPosition, PegStatus} from "src/interfaces/IPegManager.sol";
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
        vm.prank(address(pm));
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
        assertEq(slot.take0Tx, bytes32(0), "take0Tx should be empty initially");
        assertEq(slot.take1Tx, bytes32(0), "take1Tx should be empty initially");

        // Verify stream peginPacketPointer doesn't advance yet (packet not full)
        Stream memory updatedStream = streamManager.getStreamById(streamId);
        assertEq(updatedStream.peginPacketPointer, 0, "peginPacketPointer should not advance until packet is full");
    }

    function test_reserveSlot_Revert_OnlyPegManager() external {
        // Arrange
        uint64 streamId = setupStreamId;
        uint64 packetNumber = 0;

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.UnauthorizedAccount.selector, address(this)));

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
        vm.prank(address(pm));
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
        vm.prank(address(pm));
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
            vm.prank(address(pm));
            streamManager.reserveSlot(streamId, packetNumber);
        }

        // Verify peginPacketPointer is still at original value
        Stream memory midStream = streamManager.getStreamById(streamId);
        assertEq(midStream.peginPacketPointer, 0, "peginPacketPointer should still be 0 before packet is full");

        // Reserve one more slot to fill the packet
        vm.prank(address(pm));
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
        vm.prank(address(pm));
        slotId = streamManager.reserveSlot(streamId, packetNumber);
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
        vm.prank(address(pm));
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
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.UnauthorizedAccount.selector, address(this)));

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
        vm.expectRevert(abi.encodeWithSelector(IStreamManager.SlotNotReserved.selector, streamId, packetNumber, slotId));

        // Act - try to fill slot that's not in RESERVED state
        vm.prank(address(pm));
        streamManager.fillSlot(streamPos, acceptPeginAmount, acceptPeginTx, scriptPubKey);
    }

    function test_fillSlot_Revert_SlotNotReserved_BLOCKED() external {
        // Arrange
        (uint64 streamId, uint64 packetNumber, uint64 slotId) = setup_fillSlot();

        // Block the reserved slot
        vm.prank(streamManager.owner());
        streamManager.blockSlot(streamId, packetNumber, slotId);

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
        vm.expectRevert(abi.encodeWithSelector(IStreamManager.SlotNotReserved.selector, streamId, packetNumber, slotId));

        // Act - try to fill blocked slot
        vm.prank(address(pm));
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
        vm.prank(address(pm));
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

        vm.prank(address(pm));
        streamManager.fillSlot(streamPos, 100000000, bytes32(uint256(0x123)), hex"5120abc123");

        // Verify slot is FILLED
        Slot memory filledSlot = streamManager.getSlot(streamId, packetNumber, slotId);
        assertEq(uint256(filledSlot.state), uint256(SlotState.FILLED), "Slot should be FILLED in setup");
    }

    function setup_blockedSlot() internal returns (uint64 streamId, uint64 packetNumber, uint64 slotId) {
        // Start with a reserved slot
        (streamId, packetNumber, slotId) = setup_fillSlot();

        // Block the slot to have a BLOCKED slot for testing
        vm.prank(streamManager.owner());
        streamManager.blockSlot(streamId, packetNumber, slotId);

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
        bytes32 initialTake0Tx = initialSlot.take0Tx;
        bytes32 initialTake1Tx = initialSlot.take1Tx;

        // Act - call blockSlot as owner
        vm.prank(streamManager.owner());
        streamManager.blockSlot(streamId, packetNumber, slotId);

        // Assert
        Slot memory blockedSlot = streamManager.getSlot(streamId, packetNumber, slotId);
        assertEq(uint256(blockedSlot.state), uint256(SlotState.BLOCKED), "Slot should be BLOCKED after blocking");

        // Verify other slot data remains unchanged
        assertEq(blockedSlot.acceptPeginTx, initialAcceptPeginTx, "acceptPeginTx should remain unchanged");
        assertEq(blockedSlot.acceptPeginAmount, initialAcceptPeginAmount, "acceptPeginAmount should remain unchanged");
        assertEq(blockedSlot.scriptPubKey, initialScriptPubKey, "scriptPubKey should remain unchanged");
        assertEq(blockedSlot.take0Tx, initialTake0Tx, "take0Tx should remain unchanged");
        assertEq(blockedSlot.take1Tx, initialTake1Tx, "take1Tx should remain unchanged");
        assertEq(blockedSlot.slotId, slotId, "slotId should remain unchanged");
    }

    function test_blockSlot_Revert_OnlyOwner() external {
        // Arrange
        (uint64 streamId, uint64 packetNumber, uint64 slotId) = setup_fillSlot();

        // Assert
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));

        // Act - try to call blockSlot from non-owner address (this test contract)
        streamManager.blockSlot(streamId, packetNumber, slotId);
    }

    function test_blockSlot_Revert_SlotNotBlockable_FILLED() external {
        // Arrange
        (uint64 streamId, uint64 packetNumber, uint64 slotId) = setup_filledSlot();

        // Verify slot is FILLED
        Slot memory slot = streamManager.getSlot(streamId, packetNumber, slotId);
        assertEq(uint256(slot.state), uint256(SlotState.FILLED), "Slot should be FILLED");

        // Act - try to block filled slot (should revert)
        vm.prank(streamManager.owner());
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamManager.SlotNotBlockable.selector, streamId, packetNumber, slotId, SlotState.FILLED
            )
        );
        streamManager.blockSlot(streamId, packetNumber, slotId);
    }

    function test_blockSlot_Revert_SlotNotBlockable_LOCKED() external {
        // Arrange
        uint64 streamId = setupStreamId;
        uint64 packetNumber = 0;
        uint64 slotId = 0;

        // Create a slot in LOCKED state using harness
        streamManager.pushSlotsHarness(streamId, packetNumber, 1, SlotState.LOCKED);

        // Verify slot is LOCKED
        Slot memory slot = streamManager.getSlot(streamId, packetNumber, slotId);
        assertEq(uint256(slot.state), uint256(SlotState.LOCKED), "Slot should be LOCKED");

        // Act - try to block locked slot (should revert)
        vm.prank(streamManager.owner());
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamManager.SlotNotBlockable.selector, streamId, packetNumber, slotId, SlotState.LOCKED
            )
        );
        streamManager.blockSlot(streamId, packetNumber, slotId);
    }

    function test_blockSlot_Revert_SlotNotBlockable_COMPLETED() external {
        // Arrange
        uint64 streamId = setupStreamId;
        uint64 packetNumber = 0;
        uint64 slotId = 0;

        // Create a slot in COMPLETED state using harness
        streamManager.pushSlotsHarness(streamId, packetNumber, 1, SlotState.COMPLETED);

        // Verify slot is COMPLETED
        Slot memory slot = streamManager.getSlot(streamId, packetNumber, slotId);
        assertEq(uint256(slot.state), uint256(SlotState.COMPLETED), "Slot should be COMPLETED");

        // Act - try to block completed slot (should revert)
        vm.prank(streamManager.owner());
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamManager.SlotNotBlockable.selector, streamId, packetNumber, slotId, SlotState.COMPLETED
            )
        );
        streamManager.blockSlot(streamId, packetNumber, slotId);
    }

    function test_blockSlot_Revert_SlotNotBlockable_BLOCKED() external {
        // Arrange
        uint64 streamId = setupStreamId;
        uint64 packetNumber = 0;
        uint64 slotId = 0;

        // Create a slot in BLOCKED state using harness
        streamManager.pushSlotsHarness(streamId, packetNumber, 1, SlotState.BLOCKED);

        // Verify slot is BLOCKED
        Slot memory slot = streamManager.getSlot(streamId, packetNumber, slotId);
        assertEq(uint256(slot.state), uint256(SlotState.BLOCKED), "Slot should be BLOCKED");

        // Act - try to block already blocked slot (should revert)
        vm.prank(streamManager.owner());
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamManager.SlotNotBlockable.selector, streamId, packetNumber, slotId, SlotState.BLOCKED
            )
        );
        streamManager.blockSlot(streamId, packetNumber, slotId);
    }

    function test_blockSlot_Revert_NonExistentSlot() external {
        // Arrange
        uint64 streamId = setupStreamId;
        uint64 packetNumber = 0;
        uint64 invalidSlotId = 999; // Non-existent slot

        // Act - try to block non-existent slot (should revert)
        vm.prank(streamManager.owner());
        vm.expectRevert(
            abi.encodeWithSelector(IStreamManager.NonExistentSlot.selector, streamId, packetNumber, invalidSlotId)
        );
        streamManager.blockSlot(streamId, packetNumber, invalidSlotId);
    }

    // ==================== ENHANCED LOCKSLOT TESTS ====================

    function test_lockSlot_Success_SkipBlockedSlot() external {
        // Arrange - Create pattern: BLOCKED, FILLED using setup functions
        (uint64 streamId, uint64 packetNumber, uint64 slotId0) = setup_blockedSlot();
        (,, uint64 slotId1) = setup_filledSlot();

        // Act - First lockSlot call should lock slot 1
        vm.prank(address(pm));
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
        vm.prank(address(pm));
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

    function test_lockSlot_Success_SecondPacket() external {
        uint64 streamId = setupStreamId;
        uint64 firstPacketNumber = 0;
        uint64 secondPacketNumber = 1;

        // Fill first packet with blocked/completed slots
        streamManager.pushSlotsHarness(streamId, firstPacketNumber, Constants.SLOTS_PER_PACKET, SlotState.BLOCKED);

        // Create second packet and add filled slot
        bytes32 committeePubKey = bytes32(uint256(123));
        vm.prank(address(registry));
        streamManager.createNewPacket(streamId, 999, committeePubKey);

        streamManager.pushSlotsHarness(streamId, secondPacketNumber, 1, SlotState.FILLED);

        // Act - lockSlot should skip to second packet
        vm.prank(address(pm));
        (Slot memory lockedSlot, uint64 returnedPacketNumber) = streamManager.lockSlot(streamId);

        // Assert
        assertEq(lockedSlot.slotId, 0, "Should lock first slot in second packet");
        assertEq(uint256(lockedSlot.state), uint256(SlotState.LOCKED), "Slot should be LOCKED");
        assertEq(returnedPacketNumber, secondPacketNumber, "Should return second packet number");
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
        vm.prank(address(pm));
        streamManager.lockSlot(streamId);
    }

    function test_lockSlot_Revert_NoFilledSlot_AllReserved() external {
        _test_lockSlot_Revert_NoFilledSlot(SlotState.RESERVED);
    }

    function test_lockSlot_Revert_NoFilledSlot_AllLocked() external {
        _test_lockSlot_Revert_NoFilledSlot(SlotState.LOCKED);
    }

    function test_lockSlot_Revert_NoFilledSlot_AllAdvanced() external {
        _test_lockSlot_Revert_NoFilledSlot(SlotState.ADVANCED);
    }

    function test_lockSlot_Revert_NoFilledSlot_AllCompleted() external {
        _test_lockSlot_Revert_NoFilledSlot(SlotState.COMPLETED);
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
        vm.prank(address(pm));
        uint64 slotId = streamManager.reserveSlot(streamId, packetNumber);

        // 2. Fill slot
        StreamPosition memory streamPos = StreamPosition({
            streamId: streamId,
            packetNumber: packetNumber,
            slotId: slotId,
            pegStatus: PegStatus.REGISTERED
        });
        vm.prank(address(pm));
        streamManager.fillSlot(streamPos, acceptPeginAmount, acceptPeginTx, scriptPubKey);

        // 3. Lock slot
        vm.prank(address(pm));
        (Slot memory lockedSlot,) = streamManager.lockSlot(streamId);

        // 4. Advance slot
        vm.prank(address(pm));
        streamManager.advanceSlot(streamId, packetNumber, slotId);

        // 5. Complete slot
        vm.prank(address(pm));
        streamManager.completeSlot(streamId, packetNumber, slotId, acceptPeginTx, userTakeTx);

        // Verify final state
        Slot memory completedSlot = streamManager.getSlot(streamId, packetNumber, slotId);
        assertEq(uint256(completedSlot.state), uint256(SlotState.COMPLETED), "Slot should be COMPLETED");
        assertEq(completedSlot.take0Tx, userTakeTx, "userTakeTx should be stored");
    }
}
