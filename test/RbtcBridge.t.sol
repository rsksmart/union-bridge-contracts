// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {HelperContract} from "test/helpers/HelperContract.sol";
import {IRbtcBridge} from "src/interfaces/IRbtcBridge.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";

// Helper contract that rejects RBTC (no receive/fallback function)
contract RejectRBTC {
// No receive() or fallback() - will reject any RBTC sent
}

// Helper contract that consumes excessive gas
contract GasConsumer {
    uint256 public counter;

    receive() external payable {
        // Consume a lot of gas by doing expensive operations
        // This will exceed the 100k gas limit
        for (uint256 i = 0; i < 10000; i++) {
            counter = i * i; // Expensive operation
        }
    }
}

contract RbtcBridgeTest is HelperContract {
    address payable testRecipient;

    function setUp() external {
        runTestDeployScript();
        testRecipient = payable(address(0x1234));
    }

    // ============ Initialization Tests ============

    function test_initialize_Success() external view {
        // Assert - verify initialization state
        assertTrue(rbtcBridge.owner() != address(0)); // Owner should be set
        assertEq(address(rbtcBridge.bridge()), address(bridgeMock));
        assertEq(rbtcBridge.peginManager(), address(peginManager));
        assertEq(rbtcBridge.pegoutManager(), address(pegoutManager));
    }

    // ============ setPeginManager Tests ============

    function test_setPeginManager_Success_CallFromOwner() external {
        // Arrange
        address newPeginManager = address(0x5678);
        address owner = rbtcBridge.owner();

        // Act
        vm.prank(owner);
        rbtcBridge.setPeginManager(newPeginManager);

        // Assert
        assertEq(rbtcBridge.peginManager(), newPeginManager);
    }

    function test_setPeginManager_Revert_UnauthorizedAccount_CallFromNotOwner() external {
        // Arrange
        address notOwner = address(0x123);
        address newPeginManager = address(0x5678);

        // Assert
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, notOwner));

        // Act
        vm.prank(notOwner);
        rbtcBridge.setPeginManager(newPeginManager);
    }

    function test_setPeginManager_Revert_PeginManagerAddressZero() external {
        // Arrange
        address owner = rbtcBridge.owner();

        // Assert
        vm.expectRevert(IRbtcBridge.PeginManagerAddressZero.selector);

        // Act
        vm.prank(owner);
        rbtcBridge.setPeginManager(address(0));
    }

    // ============ setPegoutManager Tests ============

    function test_setPegoutManager_Success_CallFromOwner() external {
        // Arrange
        address newPegoutManager = address(0x9ABC);
        address owner = rbtcBridge.owner();

        // Act
        vm.prank(owner);
        rbtcBridge.setPegoutManager(newPegoutManager);

        // Assert
        assertEq(rbtcBridge.pegoutManager(), newPegoutManager);
    }

    function test_setPegoutManager_Revert_UnauthorizedAccount_CallFromNotOwner() external {
        // Arrange
        address notOwner = address(0x123);
        address newPegoutManager = address(0x9ABC);

        // Assert
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, notOwner));

        // Act
        vm.prank(notOwner);
        rbtcBridge.setPegoutManager(newPegoutManager);
    }

    function test_setPegoutManager_Revert_PegoutManagerAddressZero() external {
        // Arrange
        address owner = rbtcBridge.owner();

        // Assert
        vm.expectRevert(IRbtcBridge.PegoutManagerAddressZero.selector);

        // Act
        vm.prank(owner);
        rbtcBridge.setPegoutManager(address(0));
    }

    // ============ mintRbtc Tests ============

    function test_mintRbtc_Success_CallFromPeginManager() external {
        // Arrange
        uint256 amount = 1 ether;
        uint256 recipientBalanceBefore = testRecipient.balance;

        // Ensure bridge mock has enough RBTC to mint
        vm.deal(address(bridgeMock), amount);

        // Assert - expect event
        vm.expectEmit(address(rbtcBridge));
        emit IRbtcBridge.RbtcMinted(testRecipient, amount);

        // Act
        vm.prank(address(peginManager));
        rbtcBridge.mintRbtc(testRecipient, amount);

        // Assert
        assertEq(testRecipient.balance, recipientBalanceBefore + amount);
    }

    function test_mintRbtc_Revert_UnauthorizedCaller_CallFromNotPeginManager() external {
        // Arrange
        address notPeginManager = address(0x123);
        uint256 amount = 1 ether;

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IRbtcBridge.UnauthorizedCaller.selector, notPeginManager));

        // Act
        vm.prank(notPeginManager);
        rbtcBridge.mintRbtc(testRecipient, amount);
    }

    function test_mintRbtc_Revert_BridgeExceededLockingCap() external {
        // Arrange
        uint256 amount = 500 ether; // Exceeds default 400 ether cap

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IRbtcBridge.BridgeExceededLockingCap.selector, amount));

        // Act
        vm.prank(address(peginManager));
        rbtcBridge.mintRbtc(testRecipient, amount);
    }

    function test_mintRbtc_Revert_BridgeTransfersDisabled() external {
        // Arrange
        uint256 amount = 1 ether;
        bridgeMock.setTransfersDisabled(true);

        // Assert
        vm.expectRevert(IRbtcBridge.BridgeTransfersDisabled.selector);

        // Act
        vm.prank(address(peginManager));
        rbtcBridge.mintRbtc(testRecipient, amount);
    }

    function test_mintRbtc_Revert_BridgeUnauthorizedCaller() external {
        // Arrange
        uint256 amount = 1 ether;

        // Temporarily change the union bridge address so the bridge returns -1 (unauthorized)
        bridgeMock.setUnionBridgeContractAddressForTestnet(address(0x9999));

        // Assert
        vm.expectRevert(IRbtcBridge.BridgeUnauthorizedCaller.selector);

        // Act
        vm.prank(address(peginManager));
        rbtcBridge.mintRbtc(testRecipient, amount);
    }

    function test_mintRbtc_Revert_FailedToSendRBTC_ReceiverCannotAcceptRBTC() external {
        // Arrange
        uint256 amount = 1 ether;

        // Deploy a contract that cannot receive RBTC
        RejectRBTC rejectContract = new RejectRBTC();
        address payable rejectRecipient = payable(address(rejectContract));

        // Ensure bridge mock has enough RBTC to mint
        vm.deal(address(bridgeMock), amount);

        // Assert - should revert with FailedToSendRBTC
        vm.expectRevert(abi.encodeWithSelector(IRbtcBridge.FailedToSendRBTC.selector, rejectRecipient, amount));

        // Act
        vm.prank(address(peginManager));
        rbtcBridge.mintRbtc(rejectRecipient, amount);
    }

    function test_mintRbtc_Revert_FailedToSendRBTC_GasLimitEnforcement() external {
        // Arrange
        uint256 amount = 1 ether;

        // Deploy a contract that consumes excessive gas (more than 100k)
        GasConsumer gasConsumer = new GasConsumer();
        address payable gasConsumerAddress = payable(address(gasConsumer));

        // Ensure bridge mock has enough RBTC to mint
        vm.deal(address(bridgeMock), amount);

        // Assert - should revert with FailedToSendRBTC due to gas limit
        vm.expectRevert(abi.encodeWithSelector(IRbtcBridge.FailedToSendRBTC.selector, gasConsumerAddress, amount));

        // Act
        vm.prank(address(peginManager));
        rbtcBridge.mintRbtc(gasConsumerAddress, amount);
    }

    // ============ burnRbtc Tests ============

    function test_burnRbtc_Success_CallFromPegoutManager() external {
        // Arrange
        uint256 amount = 1 ether;

        // First mint some RBTC to the bridge so it can burn it
        vm.deal(address(bridgeMock), amount);

        vm.prank(address(peginManager));
        rbtcBridge.mintRbtc(testRecipient, amount);

        // Now fund the pegoutManager with RBTC to send to RbtcBridge for burning
        vm.deal(address(pegoutManager), amount);

        // Set up mock to allow burning this amount
        bridgeMock.setWeisTransferredToUnionBridge(amount);

        uint256 bridgeBalanceBefore = address(bridgeMock).balance;

        // Assert - expect event
        vm.expectEmit(address(rbtcBridge));
        emit IRbtcBridge.RbtcBurned(amount);

        // Act
        vm.prank(address(pegoutManager));
        rbtcBridge.burnRbtc{value: amount}();
        // Assert - bridge received the RBTC
        assertEq(address(bridgeMock).balance, bridgeBalanceBefore + amount);
    }

    function test_burnRbtc_Revert_UnauthorizedCaller_CallFromNotPegoutManager() external {
        // Arrange
        address notPegoutManager = address(0x123);
        uint256 amount = 1 ether;

        // Fund the caller
        vm.deal(notPegoutManager, amount);

        // Set up mock (even though this test reverts early)
        bridgeMock.setWeisTransferredToUnionBridge(amount);

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IRbtcBridge.UnauthorizedCaller.selector, notPegoutManager));

        // Act
        vm.prank(notPegoutManager);
        rbtcBridge.burnRbtc{value: amount}();
    }

    function test_burnRbtc_Revert_BridgeReleaseInvalidValue() external {
        // Arrange
        uint256 amount = 1 ether;

        // Set up mock with 0 capacity to test error condition
        bridgeMock.setWeisTransferredToUnionBridge(0);

        // Fund pegoutManager to send RBTC
        vm.deal(address(pegoutManager), amount);

        // Assert - trying to burn more than was minted should fail
        vm.expectRevert(abi.encodeWithSelector(IRbtcBridge.BridgeReleaseInvalidValue.selector, amount));

        // Act
        vm.prank(address(pegoutManager));
        rbtcBridge.burnRbtc{value: amount}();
    }

    function test_burnRbtc_Revert_BridgeTransfersDisabled() external {
        // Arrange
        uint256 amount = 1 ether;

        // First mint some RBTC so we have capacity to burn
        vm.deal(address(bridgeMock), amount);
        vm.prank(address(peginManager));
        rbtcBridge.mintRbtc(testRecipient, amount);

        // Set up mock to allow burning this amount
        bridgeMock.setWeisTransferredToUnionBridge(amount);

        // Disable transfers
        bridgeMock.setTransfersDisabled(true);

        // Fund pegoutManager to send RBTC
        vm.deal(address(pegoutManager), amount);

        // Assert
        vm.expectRevert(IRbtcBridge.BridgeTransfersDisabled.selector);

        // Act
        vm.prank(address(pegoutManager));
        rbtcBridge.burnRbtc{value: amount}();
    }

    function test_burnRbtc_Revert_BridgeUnauthorizedCaller() external {
        // Arrange
        uint256 amount = 1 ether;

        // First mint some RBTC so we have capacity to burn
        vm.deal(address(bridgeMock), amount);
        vm.prank(address(peginManager));
        rbtcBridge.mintRbtc(testRecipient, amount);

        // Set up mock to allow burning this amount
        bridgeMock.setWeisTransferredToUnionBridge(amount);

        // Fund pegoutManager to send RBTC
        vm.deal(address(pegoutManager), amount);

        // Temporarily change the union bridge address so the bridge returns -1 (unauthorized)
        bridgeMock.setUnionBridgeContractAddressForTestnet(address(0x9999));

        // Assert
        vm.expectRevert(IRbtcBridge.BridgeUnauthorizedCaller.selector);

        // Act
        vm.prank(address(pegoutManager));
        rbtcBridge.burnRbtc{value: amount}();
    }

    // ============ receive() Tests ============

    function test_receive_Success_AcceptsRBTC() external {
        // Arrange
        uint256 amount = 1 ether;
        uint256 balanceBefore = address(rbtcBridge).balance;

        // Act
        vm.deal(address(this), amount);
        (bool sent,) = address(rbtcBridge).call{value: amount}("");

        // Assert
        assertTrue(sent);
        assertEq(address(rbtcBridge).balance, balanceBefore + amount);
    }
}
