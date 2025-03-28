// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {ProofValidatorHarness} from "./helpers/ProofValidatorHarness.sol";
import {HelperContract} from "./helpers/HelperContract.sol";
import {ProofValidator} from "src/ProofValidator.sol";

contract TestProofValidator is Test, HelperContract {
    ProofValidatorHarness proofValidator;

    function setUp() external {
        runTestDeployScript();
        proofValidator = new ProofValidatorHarness();
        proofValidator.__ProofValidator_init(payable(address(bridgeMock)));
    }

    function test_verifyTxConfirmation_Success_EqualMinConfirmation() external {
        // Arrange
        int256 actualConfirmations = 10;
        // Set Mock Bridge state
        bridgeMock.setBtcTransactionConfirmations(actualConfirmations);
        // Proof arguments
        uint256 minConfirmations = 10;
        bytes32 txHash = 0xc00e989a80847a9e2d3e605904ae24c097b1e5abcfa6805434ab802abfcfd079;
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
        proofValidator.verifyTxConfirmationsHarness(
            minConfirmations, txHash, blockHash, merkleBranchPath, merkleBranchHashes
        );
    }

    function test_verifyTxConfirmation_Success_BiggerMinConfirmation() external {
        // Arrange
        int256 actualConfirmations = 100;
        // Set Mock Bridge state
        bridgeMock.setBtcTransactionConfirmations(actualConfirmations);
        // Proof arguments
        uint256 minConfirmations = 10;
        bytes32 txHash = 0xc00e989a80847a9e2d3e605904ae24c097b1e5abcfa6805434ab802abfcfd079;
        bytes32 blockHash = 0x0000000000000000000282fa21665766e58eb6cb94e458c3ef6d4af1121e38d9;
        uint256 merkleBranchPath = 4285202432;
        bytes32[] memory merkleBranchHashes = new bytes32[](13);
        merkleBranchHashes[0] = 0x3fcef4a1ddf759a858190b89ecbd1ff3dffb49704e110b68baf5b5de7021910f;

        // Act
        proofValidator.verifyTxConfirmationsHarness(
            minConfirmations, txHash, blockHash, merkleBranchPath, merkleBranchHashes
        );
    }

    function test_verifyTxConfirmation_Revert_BridgeBtcInexistantBlockHash() external {
        // Arrange
        int256 actualConfirmations = -1;
        // Set Mock Bridge state
        bridgeMock.setBtcTransactionConfirmations(actualConfirmations);
        // Proof arguments
        uint256 minConfirmations = 10;
        bytes32 txHash = 0xc00e989a80847a9e2d3e605904ae24c097b1e5abcfa6805434ab802abfcfd079;
        bytes32 blockHash = 0x0000000000000000000282fa21665766e58eb6cb94e458c3ef6d4af1121e38d9;
        uint256 merkleBranchPath = 4285202432;
        bytes32[] memory merkleBranchHashes = new bytes32[](1);
        merkleBranchHashes[0] = 0x3fcef4a1ddf759a858190b89ecbd1ff3dffb49704e110b68baf5b5de7021910f;

        // Assert
        vm.expectRevert(abi.encodeWithSelector(ProofValidator.BridgeBtcInexistantBlockHash.selector, blockHash));
        // Act
        proofValidator.verifyTxConfirmationsHarness(
            minConfirmations, txHash, blockHash, merkleBranchPath, merkleBranchHashes
        );
    }

    function test_verifyTxConfirmation_Revert_BridgeBtcBlockNotInBestChain() external {
        // Arrange
        int256 actualConfirmations = -2;
        // Set Mock Bridge state
        bridgeMock.setBtcTransactionConfirmations(actualConfirmations);
        // Proof arguments
        uint256 minConfirmations = 10;
        bytes32 txHash = 0xc00e989a80847a9e2d3e605904ae24c097b1e5abcfa6805434ab802abfcfd079;
        bytes32 blockHash = 0x0000000000000000000282fa21665766e58eb6cb94e458c3ef6d4af1121e38d9;
        uint256 merkleBranchPath = 4285202432;
        bytes32[] memory merkleBranchHashes = new bytes32[](1);
        merkleBranchHashes[0] = 0x3fcef4a1ddf759a858190b89ecbd1ff3dffb49704e110b68baf5b5de7021910f;

        // Assert
        vm.expectRevert(abi.encodeWithSelector(ProofValidator.BridgeBtcBlockNotInBestChain.selector, blockHash));
        // Act
        proofValidator.verifyTxConfirmationsHarness(
            minConfirmations, txHash, blockHash, merkleBranchPath, merkleBranchHashes
        );
    }

    function test_verifyTxConfirmation_Revert_BridgeBtcInconsistentBlock() external {
        // Arrange
        int256 actualConfirmations = -3;
        // Set Mock Bridge state
        bridgeMock.setBtcTransactionConfirmations(actualConfirmations);
        // Proof arguments
        uint256 minConfirmations = 10;
        bytes32 txHash = 0xc00e989a80847a9e2d3e605904ae24c097b1e5abcfa6805434ab802abfcfd079;
        bytes32 blockHash = 0x0000000000000000000282fa21665766e58eb6cb94e458c3ef6d4af1121e38d9;
        uint256 merkleBranchPath = 4285202432;
        bytes32[] memory merkleBranchHashes = new bytes32[](1);
        merkleBranchHashes[0] = 0x3fcef4a1ddf759a858190b89ecbd1ff3dffb49704e110b68baf5b5de7021910f;

        // Assert
        vm.expectRevert(abi.encodeWithSelector(ProofValidator.BridgeBtcInconsistentBlock.selector, blockHash));
        // Act
        proofValidator.verifyTxConfirmationsHarness(
            minConfirmations, txHash, blockHash, merkleBranchPath, merkleBranchHashes
        );
    }

    function test_verifyTxConfirmation_Revert_BridgeBtcBlockTooOld() external {
        // Arrange
        int256 actualConfirmations = -4;
        // Set Mock Bridge state
        bridgeMock.setBtcTransactionConfirmations(actualConfirmations);
        // Proof arguments
        uint256 minConfirmations = 10;
        bytes32 txHash = 0xc00e989a80847a9e2d3e605904ae24c097b1e5abcfa6805434ab802abfcfd079;
        bytes32 blockHash = 0x0000000000000000000282fa21665766e58eb6cb94e458c3ef6d4af1121e38d9;
        uint256 merkleBranchPath = 4285202432;
        bytes32[] memory merkleBranchHashes = new bytes32[](1);
        merkleBranchHashes[0] = 0x3fcef4a1ddf759a858190b89ecbd1ff3dffb49704e110b68baf5b5de7021910f;

        // Assert
        vm.expectRevert(abi.encodeWithSelector(ProofValidator.BridgeBtcBlockTooOld.selector, 4320));
        // Act
        proofValidator.verifyTxConfirmationsHarness(
            minConfirmations, txHash, blockHash, merkleBranchPath, merkleBranchHashes
        );
    }

    function test_verifyTxConfirmation_Revert_BridgeBtcTxInvalidMerkleBranch() external {
        // Arrange
        int256 actualConfirmations = -5;
        // Set Mock Bridge state
        bridgeMock.setBtcTransactionConfirmations(actualConfirmations);
        // Proof arguments
        uint256 minConfirmations = 10;
        bytes32 txHash = 0xc00e989a80847a9e2d3e605904ae24c097b1e5abcfa6805434ab802abfcfd079;
        bytes32 blockHash = 0x0000000000000000000282fa21665766e58eb6cb94e458c3ef6d4af1121e38d9;
        uint256 merkleBranchPath = 4285202432;
        bytes32[] memory merkleBranchHashes = new bytes32[](1);
        merkleBranchHashes[0] = 0x3fcef4a1ddf759a858190b89ecbd1ff3dffb49704e110b68baf5b5de7021910f;

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                ProofValidator.BridgeBtcTxInvalidMerkleBranch.selector, txHash, merkleBranchPath, merkleBranchHashes
            )
        );
        // Act
        proofValidator.verifyTxConfirmationsHarness(
            minConfirmations, txHash, blockHash, merkleBranchPath, merkleBranchHashes
        );
    }

    function test_verifyTxConfirmation_Revert_BridgeBtcUnknownError() external {
        // Arrange
        int256 actualConfirmations = -11;
        // Set Mock Bridge state
        bridgeMock.setBtcTransactionConfirmations(actualConfirmations);
        // Proof arguments
        uint256 minConfirmations = 10;
        bytes32 txHash = 0xc00e989a80847a9e2d3e605904ae24c097b1e5abcfa6805434ab802abfcfd079;
        bytes32 blockHash = 0x0000000000000000000282fa21665766e58eb6cb94e458c3ef6d4af1121e38d9;
        uint256 merkleBranchPath = 4285202432;
        bytes32[] memory merkleBranchHashes = new bytes32[](1);
        merkleBranchHashes[0] = 0x3fcef4a1ddf759a858190b89ecbd1ff3dffb49704e110b68baf5b5de7021910f;

        // Assert
        vm.expectRevert(abi.encodeWithSelector(ProofValidator.BridgeBtcUnknownError.selector, actualConfirmations));
        // Act
        proofValidator.verifyTxConfirmationsHarness(
            minConfirmations, txHash, blockHash, merkleBranchPath, merkleBranchHashes
        );
    }

    function test_verifyTxConfirmation_Revert_NotEnoughConfirmations() external {
        // Arrange
        int256 actualConfirmations = 9;
        // Set Mock Bridge state
        bridgeMock.setBtcTransactionConfirmations(actualConfirmations);
        // Proof arguments
        uint256 minConfirmations = 10;
        bytes32 txHash = 0xc00e989a80847a9e2d3e605904ae24c097b1e5abcfa6805434ab802abfcfd079;
        bytes32 blockHash = 0x0000000000000000000282fa21665766e58eb6cb94e458c3ef6d4af1121e38d9;
        uint256 merkleBranchPath = 4285202432;
        bytes32[] memory merkleBranchHashes = new bytes32[](1);
        merkleBranchHashes[0] = 0x3fcef4a1ddf759a858190b89ecbd1ff3dffb49704e110b68baf5b5de7021910f;

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                ProofValidator.NotEnoughConfirmations.selector, actualConfirmations, minConfirmations
            )
        );
        // Act
        proofValidator.verifyTxConfirmationsHarness(
            minConfirmations, txHash, blockHash, merkleBranchPath, merkleBranchHashes
        );
    }
}
