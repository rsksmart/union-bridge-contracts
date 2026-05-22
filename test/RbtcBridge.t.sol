// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {HelperContract} from "test/helpers/HelperContract.sol";
import {IRbtcBridge} from "src/interfaces/IRbtcBridge.sol";
import {IAccessManager} from "src/interfaces/IAccessManager.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

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
        assertEq(address(rbtcBridge.accessManager()), address(accessManager));
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
        vm.expectRevert(abi.encodeWithSelector(IAccessManager.UnauthorizedToMintRbtc.selector, notPeginManager));

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

    function test_mintRbtc_Revert_EnforcedPause_PausedContract() external {
        // Arrange
        pauseContracts();
        uint256 amount = 1 ether;

        // Assert
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);

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
        vm.expectRevert(abi.encodeWithSelector(IAccessManager.UnauthorizedToBurnRbtc.selector, notPegoutManager));

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

    function test_burnRbtc_Revert_EnforcedPause_PausedContract() external {
        // Arrange
        pauseContracts();
        uint256 amount = 1 ether;

        // Set up mock (even though this test reverts early)
        bridgeMock.setWeisTransferredToUnionBridge(amount);

        // Fund pegoutManager to send RBTC
        vm.deal(address(pegoutManager), amount);

        // Assert
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);

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

    // ============ getUnionBridgeLockingCap() Tests ============

    function test_getUnionBridgeLockingCap_Success_ReturnsDefaultValue() external view {
        // Arrange - default locking cap is 400 ether
        uint256 expectedLockingCap = 400 ether;

        // Act
        uint256 lockingCap = rbtcBridge.getUnionBridgeLockingCap();

        // Assert
        assertEq(lockingCap, expectedLockingCap, "Locking cap should match default value");
    }

    function test_getUnionBridgeLockingCap_Success_PausedContract() external {
        // Arrange
        pauseContracts();
        uint256 expectedLockingCap = 400 ether;

        // Act - view function should work even when paused
        uint256 lockingCap = rbtcBridge.getUnionBridgeLockingCap();

        // Assert
        assertEq(lockingCap, expectedLockingCap, "Locking cap should be accessible when paused");
    }

    function test_getUnionBridgeLockingCap_Success_ReturnsUpdatedValueAfterTransfers() external {
        // Arrange
        uint256 transferAmount = 100 ether;
        uint256 expectedLockingCap = 400 ether - transferAmount; // 300 ether

        // Act - simulate transfers by updating the bridge mock state
        bridgeMock.setWeisTransferredToUnionBridge(transferAmount);
        uint256 lockingCap = rbtcBridge.getUnionBridgeLockingCap();

        // Assert
        assertEq(lockingCap, expectedLockingCap, "Locking cap should decrease after transfers");
    }

    function test_getUnionBridgeLockingCap_Success_ReturnsZeroWhenCapExhausted() external {
        // Arrange
        uint256 transferAmount = 400 ether; // Exhaust all capacity
        uint256 expectedLockingCap = 0;

        // Act - simulate that all capacity has been used
        bridgeMock.setWeisTransferredToUnionBridge(transferAmount);
        uint256 lockingCap = rbtcBridge.getUnionBridgeLockingCap();

        // Assert
        assertEq(lockingCap, expectedLockingCap, "Locking cap should be zero when exhausted");
    }

    function test_getUnionBridgeLockingCap_Success_ReturnsCorrectValueAfterMultipleTransfers() external {
        // Arrange
        uint256 firstTransfer = 50 ether;
        uint256 secondTransfer = 75 ether;
        uint256 totalTransferred = firstTransfer + secondTransfer;
        uint256 expectedLockingCap = 400 ether - totalTransferred; // 275 ether

        // Act - simulate multiple transfers
        bridgeMock.setWeisTransferredToUnionBridge(firstTransfer);
        bridgeMock.setWeisTransferredToUnionBridge(totalTransferred);
        uint256 lockingCap = rbtcBridge.getUnionBridgeLockingCap();

        // Assert
        assertEq(lockingCap, expectedLockingCap, "Locking cap should reflect cumulative transfers");
    }

    // ============ verifyTxConfirmations Tests ============

    function test_verifyTxConfirmation_Success_EqualMinConfirmation() external {
        // Arrange
        int256 actualConfirmations = 10;
        // Set Mock Bridge state
        bridgeMock.setBtcTransactionConfirmations(actualConfirmations);
        // Proof arguments
        uint256 minConfirmations = 10;
        bytes32 txid = 0xc00e989a80847a9e2d3e605904ae24c097b1e5abcfa6805434ab802abfcfd079;
        bytes32 blockHash = 0x0000000000000000000282fa21665766e58eb6cb94e458c3ef6d4af1121e38d9;
        uint256 merkleBranchPath = 4285202432;
        bytes32[] memory merkleBranchHashes = new bytes32[](13);
        merkleBranchHashes[0] = 0x3fcef4a1ddf759a858190b89ecbd1ff3dffb49704e110b68baf5b5de7021910f;
        merkleBranchHashes[1] = 0x481a71c0478c28b68a698b8e9be317e9a0d9d153b0b2db417a45b5773ef6a0f2;
        merkleBranchHashes[2] = 0xc00e989a80847a9e2d3e605904ae24c097b1e5abcfa6805434ab802abfcfd079;
        merkleBranchHashes[3] = 0x1780d0b717e2782046036f3a876037b3fe590834aa5da0b9a09b269d29856660;
        merkleBranchHashes[4] = 0x649272353930bb551a61ca491844128dcd33900872bd9387224bbfd3da9906e5;
        merkleBranchHashes[5] = 0x9617e6383b72d518449fc2c5a18cc24d1e1b3a59e7f8dce6dbf7e822275d382b;
        merkleBranchHashes[6] = 0xa07d3b738d7b280b296cd9a11821c375b600c3524849822925f5c11a39878886;
        merkleBranchHashes[7] = 0x9dd03a4e5358ca5c78c1aea47a944dee59a5153e87330c85c218e81f34e46839;
        merkleBranchHashes[8] = 0x8c4a0c760fafa20c98217d482f85f297dcab25facbe8d5eccb3666a75ac7da37;
        merkleBranchHashes[9] = 0x35d4bf31bdcb1dae3fc659536487c492abae0addcdcfe3e9434c0e9b8f552f8c;
        merkleBranchHashes[10] = 0xae229406e25c7c52450f31b8a106f9cf5e5f8ae688ca7a25408e6bb339251221;
        merkleBranchHashes[11] = 0x8d84f7110e788ec0591feb5c30f83c9bd326a88c2388d6c6ea10b886e360fffe;
        merkleBranchHashes[12] = 0x5f05f1da73fc3498a59a4245e41b52b0a80dbaa3426fbd541c14327c9a362487;

        // Act
        rbtcBridge.verifyTxConfirmations(minConfirmations, txid, blockHash, merkleBranchPath, merkleBranchHashes);
    }

    function test_verifyTxConfirmation_Success_BiggerMinConfirmation() external {
        // Arrange
        int256 actualConfirmations = 100;
        // Set Mock Bridge state
        bridgeMock.setBtcTransactionConfirmations(actualConfirmations);
        // Proof arguments
        uint256 minConfirmations = 10;
        bytes32 txid = 0xc00e989a80847a9e2d3e605904ae24c097b1e5abcfa6805434ab802abfcfd079;
        bytes32 blockHash = 0x0000000000000000000282fa21665766e58eb6cb94e458c3ef6d4af1121e38d9;
        uint256 merkleBranchPath = 4285202432;
        bytes32[] memory merkleBranchHashes = new bytes32[](13);
        merkleBranchHashes[0] = 0x3fcef4a1ddf759a858190b89ecbd1ff3dffb49704e110b68baf5b5de7021910f;

        // Act
        rbtcBridge.verifyTxConfirmations(minConfirmations, txid, blockHash, merkleBranchPath, merkleBranchHashes);
    }

    function test_verifyTxConfirmation_Revert_BridgeBtcInexistantBlockHash() external {
        // Arrange
        int256 actualConfirmations = -1;
        // Set Mock Bridge state
        bridgeMock.setBtcTransactionConfirmations(actualConfirmations);
        // Proof arguments
        uint256 minConfirmations = 10;
        bytes32 txid = 0xc00e989a80847a9e2d3e605904ae24c097b1e5abcfa6805434ab802abfcfd079;
        bytes32 blockHash = 0x0000000000000000000282fa21665766e58eb6cb94e458c3ef6d4af1121e38d9;
        uint256 merkleBranchPath = 4285202432;
        bytes32[] memory merkleBranchHashes = new bytes32[](1);
        merkleBranchHashes[0] = 0x3fcef4a1ddf759a858190b89ecbd1ff3dffb49704e110b68baf5b5de7021910f;

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IRbtcBridge.BridgeBtcInexistantBlockHash.selector, blockHash));
        // Act
        rbtcBridge.verifyTxConfirmations(minConfirmations, txid, blockHash, merkleBranchPath, merkleBranchHashes);
    }

    function test_verifyTxConfirmation_Revert_BridgeBtcBlockNotInBestChain() external {
        // Arrange
        int256 actualConfirmations = -2;
        // Set Mock Bridge state
        bridgeMock.setBtcTransactionConfirmations(actualConfirmations);
        // Proof arguments
        uint256 minConfirmations = 10;
        bytes32 txid = 0xc00e989a80847a9e2d3e605904ae24c097b1e5abcfa6805434ab802abfcfd079;
        bytes32 blockHash = 0x0000000000000000000282fa21665766e58eb6cb94e458c3ef6d4af1121e38d9;
        uint256 merkleBranchPath = 4285202432;
        bytes32[] memory merkleBranchHashes = new bytes32[](1);
        merkleBranchHashes[0] = 0x3fcef4a1ddf759a858190b89ecbd1ff3dffb49704e110b68baf5b5de7021910f;

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IRbtcBridge.BridgeBtcBlockNotInBestChain.selector, blockHash));
        // Act
        rbtcBridge.verifyTxConfirmations(minConfirmations, txid, blockHash, merkleBranchPath, merkleBranchHashes);
    }

    function test_verifyTxConfirmation_Revert_BridgeBtcInconsistentBlock() external {
        // Arrange
        int256 actualConfirmations = -3;
        // Set Mock Bridge state
        bridgeMock.setBtcTransactionConfirmations(actualConfirmations);
        // Proof arguments
        uint256 minConfirmations = 10;
        bytes32 txid = 0xc00e989a80847a9e2d3e605904ae24c097b1e5abcfa6805434ab802abfcfd079;
        bytes32 blockHash = 0x0000000000000000000282fa21665766e58eb6cb94e458c3ef6d4af1121e38d9;
        uint256 merkleBranchPath = 4285202432;
        bytes32[] memory merkleBranchHashes = new bytes32[](1);
        merkleBranchHashes[0] = 0x3fcef4a1ddf759a858190b89ecbd1ff3dffb49704e110b68baf5b5de7021910f;

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IRbtcBridge.BridgeBtcInconsistentBlock.selector, blockHash));
        // Act
        rbtcBridge.verifyTxConfirmations(minConfirmations, txid, blockHash, merkleBranchPath, merkleBranchHashes);
    }

    function test_verifyTxConfirmation_Revert_BridgeBtcBlockTooOld() external {
        // Arrange
        int256 actualConfirmations = -4;
        // Set Mock Bridge state
        bridgeMock.setBtcTransactionConfirmations(actualConfirmations);
        // Proof arguments
        uint256 minConfirmations = 10;
        bytes32 txid = 0xc00e989a80847a9e2d3e605904ae24c097b1e5abcfa6805434ab802abfcfd079;
        bytes32 blockHash = 0x0000000000000000000282fa21665766e58eb6cb94e458c3ef6d4af1121e38d9;
        uint256 merkleBranchPath = 4285202432;
        bytes32[] memory merkleBranchHashes = new bytes32[](1);
        merkleBranchHashes[0] = 0x3fcef4a1ddf759a858190b89ecbd1ff3dffb49704e110b68baf5b5de7021910f;

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IRbtcBridge.BridgeBtcBlockTooOld.selector, 4320));
        // Act
        rbtcBridge.verifyTxConfirmations(minConfirmations, txid, blockHash, merkleBranchPath, merkleBranchHashes);
    }

    function test_verifyTxConfirmation_Revert_BridgeBtcTxInvalidMerkleBranch() external {
        // Arrange
        int256 actualConfirmations = -5;
        // Set Mock Bridge state
        bridgeMock.setBtcTransactionConfirmations(actualConfirmations);
        // Proof arguments
        uint256 minConfirmations = 10;
        bytes32 txid = 0xc00e989a80847a9e2d3e605904ae24c097b1e5abcfa6805434ab802abfcfd079;
        bytes32 blockHash = 0x0000000000000000000282fa21665766e58eb6cb94e458c3ef6d4af1121e38d9;
        uint256 merkleBranchPath = 4285202432;
        bytes32[] memory merkleBranchHashes = new bytes32[](1);
        merkleBranchHashes[0] = 0x3fcef4a1ddf759a858190b89ecbd1ff3dffb49704e110b68baf5b5de7021910f;

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                IRbtcBridge.BridgeBtcTxInvalidMerkleBranch.selector, txid, merkleBranchPath, merkleBranchHashes
            )
        );
        // Act
        rbtcBridge.verifyTxConfirmations(minConfirmations, txid, blockHash, merkleBranchPath, merkleBranchHashes);
    }

    function test_verifyTxConfirmation_Revert_BridgeBtcUnknownError() external {
        // Arrange
        int256 actualConfirmations = -11;
        // Set Mock Bridge state
        bridgeMock.setBtcTransactionConfirmations(actualConfirmations);
        // Proof arguments
        uint256 minConfirmations = 10;
        bytes32 txid = 0xc00e989a80847a9e2d3e605904ae24c097b1e5abcfa6805434ab802abfcfd079;
        bytes32 blockHash = 0x0000000000000000000282fa21665766e58eb6cb94e458c3ef6d4af1121e38d9;
        uint256 merkleBranchPath = 4285202432;
        bytes32[] memory merkleBranchHashes = new bytes32[](1);
        merkleBranchHashes[0] = 0x3fcef4a1ddf759a858190b89ecbd1ff3dffb49704e110b68baf5b5de7021910f;

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IRbtcBridge.BridgeBtcUnknownError.selector, actualConfirmations));
        // Act
        rbtcBridge.verifyTxConfirmations(minConfirmations, txid, blockHash, merkleBranchPath, merkleBranchHashes);
    }

    function test_verifyTxConfirmation_Revert_NotEnoughConfirmations() external {
        // Arrange
        int256 actualConfirmations = 9;
        // Set Mock Bridge state
        bridgeMock.setBtcTransactionConfirmations(actualConfirmations);
        // Proof arguments
        uint256 minConfirmations = 10;
        bytes32 txid = 0xc00e989a80847a9e2d3e605904ae24c097b1e5abcfa6805434ab802abfcfd079;
        bytes32 blockHash = 0x0000000000000000000282fa21665766e58eb6cb94e458c3ef6d4af1121e38d9;
        uint256 merkleBranchPath = 4285202432;
        bytes32[] memory merkleBranchHashes = new bytes32[](1);
        merkleBranchHashes[0] = 0x3fcef4a1ddf759a858190b89ecbd1ff3dffb49704e110b68baf5b5de7021910f;

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(IRbtcBridge.NotEnoughConfirmations.selector, actualConfirmations, minConfirmations)
        );
        // Act
        rbtcBridge.verifyTxConfirmations(minConfirmations, txid, blockHash, merkleBranchPath, merkleBranchHashes);
    }

    // ============ getTxBlockNumberAndVerifyConfirmations Tests ============

    function test_getTxBlockNumberAndVerifyConfirmations_Success() external {
        // Arrange
        int256 actualConfirmations = 10;
        int256 bestChainHeight = 100;
        int256 expectedBlockNumber = bestChainHeight - actualConfirmations; // 90

        // Set Mock Bridge state
        bridgeMock.setBtcTransactionConfirmations(actualConfirmations);
        bridgeMock.setBtcBlockchainBestChainHeight(bestChainHeight);

        // Proof arguments
        uint256 minConfirmations = 10;
        bytes32 txid = 0xc00e989a80847a9e2d3e605904ae24c097b1e5abcfa6805434ab802abfcfd079;
        bytes32 blockHash = 0x0000000000000000000282fa21665766e58eb6cb94e458c3ef6d4af1121e38d9;
        uint256 merkleBranchPath = 4285202432;
        bytes32[] memory merkleBranchHashes = new bytes32[](13);
        merkleBranchHashes[0] = 0x3fcef4a1ddf759a858190b89ecbd1ff3dffb49704e110b68baf5b5de7021910f;
        merkleBranchHashes[1] = 0x481a71c0478c28b68a698b8e9be317e9a0d9d153b0b2db417a45b5773ef6a0f2;
        merkleBranchHashes[2] = 0xc00e989a80847a9e2d3e605904ae24c097b1e5abcfa6805434ab802abfcfd079;
        merkleBranchHashes[3] = 0x1780d0b717e2782046036f3a876037b3fe590834aa5da0b9a09b269d29856660;
        merkleBranchHashes[4] = 0x649272353930bb551a61ca491844128dcd33900872bd9387224bbfd3da9906e5;
        merkleBranchHashes[5] = 0x9617e6383b72d518449fc2c5a18cc24d1e1b3a59e7f8dce6dbf7e822275d382b;
        merkleBranchHashes[6] = 0xa07d3b738d7b280b296cd9a11821c375b600c3524849822925f5c11a39878886;
        merkleBranchHashes[7] = 0x9dd03a4e5358ca5c78c1aea47a944dee59a5153e87330c85c218e81f34e46839;
        merkleBranchHashes[8] = 0x8c4a0c760fafa20c98217d482f85f297dcab25facbe8d5eccb3666a75ac7da37;
        merkleBranchHashes[9] = 0x35d4bf31bdcb1dae3fc659536487c492abae0addcdcfe3e9434c0e9b8f552f8c;
        merkleBranchHashes[10] = 0xae229406e25c7c52450f31b8a106f9cf5e5f8ae688ca7a25408e6bb339251221;
        merkleBranchHashes[11] = 0x8d84f7110e788ec0591feb5c30f83c9bd326a88c2388d6c6ea10b886e360fffe;
        merkleBranchHashes[12] = 0x5f05f1da73fc3498a59a4245e41b52b0a80dbaa3426fbd541c14327c9a362487;

        // Act
        int256 blockNumber = rbtcBridge.getTxBlockNumberAndVerifyConfirmations(
            minConfirmations, txid, blockHash, merkleBranchPath, merkleBranchHashes
        );

        // Assert
        assertEq(blockNumber, expectedBlockNumber, "Block number should equal best chain height minus confirmations");
    }

    // ============ getBestBlockHash Tests ============

    function test_getBestBlockHash_Success() external {
        // Arrange
        // Using a known Bitcoin block header from block 879_500
        // This is the same header used in BtcHelper.t.sol test_hash256_Success_BlockHash
        bytes memory blockHeader =
            hex"00600022bd414202c86f2e80aca72283aa584d6ee2b7597b1d6d02000000000000000000f6f5a9ccc718288b2af0c6695fec614550b3a5f4ef4c04d4116faaaa64ece1e0ac0f8967618c02173e6999e2";
        bytes32 expectedHash = 0x0000000000000000000282fa21665766e58eb6cb94e458c3ef6d4af1121e38d9;

        // Set the header for the current block number
        bridgeMock.setHeader(block.number, blockHeader);

        // Act
        bytes32 blockHash = rbtcBridge.getBestBlockHash();

        // Assert
        assertEq(blockHash, expectedHash, "Block hash should match hash256 of the best block header");
    }

    // ============ setBaseEvent Tests ============

    function test_setBaseEvent_Success_CallFromChallengeManager() external {
        // Arrange
        bridgeMock.setStoreEvents(true);
        bytes memory baseEvent = "test base event";

        // Assert - expect event
        vm.expectEmit(address(rbtcBridge));
        emit IRbtcBridge.BaseEventSet(baseEvent);

        // Act
        vm.prank(address(operatorTakeManager));
        rbtcBridge.setBaseEvent(baseEvent);

        // Assert - verify base event was set in bridge
        bytes memory retrievedBaseEvent = bridgeMock.getBaseEvent();
        assertEq(retrievedBaseEvent.length, baseEvent.length, "Base event length should match");
        assertEq(keccak256(retrievedBaseEvent), keccak256(baseEvent), "Base event content should match");
    }

    function test_setBaseEvent_Success_MaxLength() external {
        // Arrange
        bridgeMock.setStoreEvents(true);
        // Create a base event with 128 bytes (max allowed)
        bytes memory baseEvent = new bytes(128);
        for (uint256 i = 0; i < 128; i++) {
            baseEvent[i] = 0xAF;
        }

        // Assert - expect event
        vm.expectEmit(address(rbtcBridge));
        emit IRbtcBridge.BaseEventSet(baseEvent);

        // Act
        vm.prank(address(operatorTakeManager));
        rbtcBridge.setBaseEvent(baseEvent);

        // Assert - verify base event was set
        bytes memory retrievedBaseEvent = bridgeMock.getBaseEvent();
        assertEq(retrievedBaseEvent.length, 128, "Base event length should be 128 bytes");
    }

    function test_setBaseEvent_Revert_UnauthorizedCaller_CallFromNotPegoutManager() external {
        // Arrange
        bridgeMock.setStoreEvents(true);
        address notPegoutManager = address(0x123);
        bytes memory baseEvent = "test base event";

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IAccessManager.UnauthorizedToSetBaseEvent.selector, notPegoutManager));

        // Act
        vm.prank(notPegoutManager);
        rbtcBridge.setBaseEvent(baseEvent);
    }

    function test_setBaseEvent_Revert_UnauthorizedCaller_CallFromPeginManager() external {
        // Arrange
        bridgeMock.setStoreEvents(true);
        bytes memory baseEvent = "test base event";

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(IAccessManager.UnauthorizedToSetBaseEvent.selector, address(peginManager))
        );

        // Act
        vm.prank(address(peginManager));
        rbtcBridge.setBaseEvent(baseEvent);
    }

    function test_setBaseEvent_Revert_BaseEventEmpty() external {
        // Arrange
        bridgeMock.setStoreEvents(true);
        bytes memory emptyBaseEvent = "";

        // Assert
        vm.expectRevert(IRbtcBridge.BaseEventEmpty.selector);

        // Act
        vm.prank(address(operatorTakeManager));
        rbtcBridge.setBaseEvent(emptyBaseEvent);
    }

    function test_setBaseEvent_Revert_BaseEventTooLong() external {
        // Arrange
        bridgeMock.setStoreEvents(true);
        // Create a base event with 129 bytes (exceeds max of 128)
        bytes memory tooLongBaseEvent = new bytes(129);
        for (uint256 i = 0; i < 129; i++) {
            tooLongBaseEvent[i] = bytes1(uint8(i % 256));
        }

        // Assert
        vm.expectRevert(IRbtcBridge.BaseEventTooLong.selector);

        // Act
        vm.prank(address(operatorTakeManager));
        rbtcBridge.setBaseEvent(tooLongBaseEvent);
    }

    function test_setBaseEvent_Revert_BaseEventAlreadySet() external {
        // Arrange
        bridgeMock.setStoreEvents(true);
        bytes memory baseEvent = "second base event";

        // Set first base event directly on bridge mock
        vm.prank(address(pegoutManager));
        rbtcBridge.setBaseEvent("first base event");

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IRbtcBridge.BaseEventAlreadySet.selector));

        // Act - try to set another base event
        vm.prank(address(operatorTakeManager));
        rbtcBridge.setBaseEvent(baseEvent);
    }

    function test_setBaseEvent_Success_SetInNextBlock() external {
        // Arrange
        bridgeMock.setStoreEvents(true);
        bytes memory firstBaseEvent = "first base event";
        bytes memory secondBaseEvent = "second base event";

        // Act - set base event in current block
        vm.prank(address(pegoutManager));
        rbtcBridge.setBaseEvent(firstBaseEvent);

        // Move to next block and set a new base event
        vm.roll(block.number + 1);
        vm.prank(address(pegoutManager));
        rbtcBridge.setBaseEvent(secondBaseEvent);

        // Assert
        bytes memory retrievedBaseEvent = bridgeMock.getBaseEvent();
        assertEq(retrievedBaseEvent.length, secondBaseEvent.length, "Base event length should match");
        assertEq(keccak256(retrievedBaseEvent), keccak256(secondBaseEvent), "Base event content should match");
        assertEq(rbtcBridge.latestBaseEventBlock(), block.number, "Latest base event block should be current block");
    }

    function test_setBaseEvent_Revert_EnforcedPause_PausedContract() external {
        // Arrange
        bridgeMock.setStoreEvents(true);
        pauseContracts();
        bytes memory baseEvent = "test base event";

        // Assert
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);

        // Act
        vm.prank(address(pegoutManager));
        rbtcBridge.setBaseEvent(baseEvent);
    }
}
