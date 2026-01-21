// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {HelperContract} from "test/helpers/HelperContract.sol";
import {IAccessManager} from "src/interfaces/IAccessManager.sol";

contract AccessManagerTest is Test, HelperContract {
    address unauthorizedAddress;

    function setUp() external {
        runTestDeployScript();
        unauthorizedAddress = address(0x123);
    }

    // ============ Initialize Tests ============

    function test_initialize_Success() external view {
        // Assert - verify initialization state
        assertTrue(accessManager.owner() != address(0)); // Owner should be set
        assertEq(address(accessManager.peginManager()), address(peginManager));
        assertEq(address(accessManager.pegoutManager()), address(pegoutManager));
        assertEq(address(accessManager.committeeRegistry()), address(registry));
        assertEq(address(accessManager.memberRegistry()), address(memberRegistry));
        assertEq(address(accessManager.challengeManager()), address(challengeManager));
    }

    // ============ requireCanModifyPegStatus Tests ============

    function test_requireCanModifyPegStatus_Success_CallFromPeginManager() external view {
        // Act & Assert - should not revert
        accessManager.requireCanModifyPegStatus(address(peginManager));
    }

    function test_requireCanModifyPegStatus_Success_CallFromPegoutManager() external view {
        // Act & Assert - should not revert
        accessManager.requireCanModifyPegStatus(address(pegoutManager));
    }

    function test_requireCanModifyPegStatus_Success_CallFromChallengeManager() external view {
        // Act & Assert - should not revert
        accessManager.requireCanModifyPegStatus(address(challengeManager));
    }

    function test_requireCanModifyPegStatus_Revert_UnauthorizedAddress() external {
        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(IAccessManager.UnauthorizedToModifyPegStatus.selector, unauthorizedAddress)
        );

        // Act
        accessManager.requireCanModifyPegStatus(unauthorizedAddress);
    }

    function test_requireCanModifyPegStatus_Revert_CallFromCommitteeRegistry() external {
        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(IAccessManager.UnauthorizedToModifyPegStatus.selector, address(registry))
        );

        // Act
        accessManager.requireCanModifyPegStatus(address(registry));
    }

    function test_requireCanModifyPegStatus_Revert_CallFromMemberRegistry() external {
        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(IAccessManager.UnauthorizedToModifyPegStatus.selector, address(memberRegistry))
        );

        // Act
        accessManager.requireCanModifyPegStatus(address(memberRegistry));
    }

    // ============ requireCanCreateCommittee Tests ============

    function test_requireCanCreateCommittee_Success_CallFromPeginManager() external view {
        // Act & Assert - should not revert
        accessManager.requireCanCreateCommittee(address(peginManager));
    }

    function test_requireCanCreateCommittee_Revert_UnauthorizedAddress() external {
        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(IAccessManager.UnauthorizedToCreateCommittee.selector, unauthorizedAddress)
        );

        // Act
        accessManager.requireCanCreateCommittee(unauthorizedAddress);
    }

    function test_requireCanCreateCommittee_Revert_CallFromPegoutManager() external {
        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(IAccessManager.UnauthorizedToCreateCommittee.selector, address(pegoutManager))
        );

        // Act
        accessManager.requireCanCreateCommittee(address(pegoutManager));
    }

    function test_requireCanCreateCommittee_Revert_CallFromCommitteeRegistry() external {
        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(IAccessManager.UnauthorizedToCreateCommittee.selector, address(registry))
        );

        // Act
        accessManager.requireCanCreateCommittee(address(registry));
    }

    // ============ requireCanReleaseCommittee Tests ============

    function test_requireCanReleaseCommittee_Success_CallFromPegoutManager() external view {
        // Act & Assert - should not revert
        accessManager.requireCanReleaseCommittee(address(pegoutManager));
    }

    function test_requireCanReleaseCommittee_Revert_UnauthorizedAddress() external {
        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(IAccessManager.UnauthorizedToReleaseCommittee.selector, unauthorizedAddress)
        );

        // Act
        accessManager.requireCanReleaseCommittee(unauthorizedAddress);
    }

    function test_requireCanReleaseCommittee_Revert_CallFromPeginManager() external {
        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(IAccessManager.UnauthorizedToReleaseCommittee.selector, address(peginManager))
        );

        // Act
        accessManager.requireCanReleaseCommittee(address(peginManager));
    }

    function test_requireCanReleaseCommittee_Revert_CallFromCommitteeRegistry() external {
        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(IAccessManager.UnauthorizedToReleaseCommittee.selector, address(registry))
        );

        // Act
        accessManager.requireCanReleaseCommittee(address(registry));
    }

    // ============ requireCanSelectTakeOperator Tests ============

    function test_requireCanSelectTakeOperator_Success_CallFromPegoutManager() external view {
        // Act & Assert - should not revert
        accessManager.requireCanSelectTakeOperator(address(pegoutManager));
    }

    function test_requireCanSelectTakeOperator_Revert_UnauthorizedAddress() external {
        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(IAccessManager.UnauthorizedToSelectTakeOperator.selector, unauthorizedAddress)
        );

        // Act
        accessManager.requireCanSelectTakeOperator(unauthorizedAddress);
    }

    function test_requireCanSelectTakeOperator_Revert_CallFromPeginManager() external {
        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(IAccessManager.UnauthorizedToSelectTakeOperator.selector, address(peginManager))
        );

        // Act
        accessManager.requireCanSelectTakeOperator(address(peginManager));
    }

    function test_requireCanSelectTakeOperator_Revert_CallFromCommitteeRegistry() external {
        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(IAccessManager.UnauthorizedToSelectTakeOperator.selector, address(registry))
        );

        // Act
        accessManager.requireCanSelectTakeOperator(address(registry));
    }

    // ============ requireCanCreatePacket Tests ============

    function test_requireCanCreatePacket_Success_CallFromCommitteeRegistry() external view {
        // Act & Assert - should not revert
        accessManager.requireCanCreatePacket(address(registry));
    }

    function test_requireCanCreatePacket_Revert_UnauthorizedAddress() external {
        // Assert
        vm.expectRevert(abi.encodeWithSelector(IAccessManager.UnauthorizedToCreatePacket.selector, unauthorizedAddress));

        // Act
        accessManager.requireCanCreatePacket(unauthorizedAddress);
    }

    function test_requireCanCreatePacket_Revert_CallFromPeginManager() external {
        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(IAccessManager.UnauthorizedToCreatePacket.selector, address(peginManager))
        );

        // Act
        accessManager.requireCanCreatePacket(address(peginManager));
    }

    function test_requireCanCreatePacket_Revert_CallFromPegoutManager() external {
        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(IAccessManager.UnauthorizedToCreatePacket.selector, address(pegoutManager))
        );

        // Act
        accessManager.requireCanCreatePacket(address(pegoutManager));
    }

    // ============ requireCanMintRbtc Tests ============

    function test_requireCanMintRbtc_Success_CallFromPeginManager() external view {
        // Act & Assert - should not revert
        accessManager.requireCanMintRbtc(address(peginManager));
    }

    function test_requireCanMintRbtc_Revert_UnauthorizedAddress() external {
        // Assert
        vm.expectRevert(abi.encodeWithSelector(IAccessManager.UnauthorizedToMintRbtc.selector, unauthorizedAddress));

        // Act
        accessManager.requireCanMintRbtc(unauthorizedAddress);
    }

    function test_requireCanMintRbtc_Revert_CallFromPegoutManager() external {
        // Assert
        vm.expectRevert(abi.encodeWithSelector(IAccessManager.UnauthorizedToMintRbtc.selector, address(pegoutManager)));

        // Act
        accessManager.requireCanMintRbtc(address(pegoutManager));
    }

    function test_requireCanMintRbtc_Revert_CallFromCommitteeRegistry() external {
        // Assert
        vm.expectRevert(abi.encodeWithSelector(IAccessManager.UnauthorizedToMintRbtc.selector, address(registry)));

        // Act
        accessManager.requireCanMintRbtc(address(registry));
    }

    // ============ requireCanBurnRbtc Tests ============

    function test_requireCanBurnRbtc_Success_CallFromPegoutManager() external view {
        // Act & Assert - should not revert
        accessManager.requireCanBurnRbtc(address(pegoutManager));
    }

    function test_requireCanBurnRbtc_Revert_UnauthorizedAddress() external {
        // Assert
        vm.expectRevert(abi.encodeWithSelector(IAccessManager.UnauthorizedToBurnRbtc.selector, unauthorizedAddress));

        // Act
        accessManager.requireCanBurnRbtc(unauthorizedAddress);
    }

    function test_requireCanBurnRbtc_Revert_CallFromPeginManager() external {
        // Assert
        vm.expectRevert(abi.encodeWithSelector(IAccessManager.UnauthorizedToBurnRbtc.selector, address(peginManager)));

        // Act
        accessManager.requireCanBurnRbtc(address(peginManager));
    }

    function test_requireCanBurnRbtc_Revert_CallFromCommitteeRegistry() external {
        // Assert
        vm.expectRevert(abi.encodeWithSelector(IAccessManager.UnauthorizedToBurnRbtc.selector, address(registry)));

        // Act
        accessManager.requireCanBurnRbtc(address(registry));
    }

    // ============ requireCanInitSignatures Tests ============

    function test_requireCanInitSignatures_Success_CallFromPeginManager() external view {
        // Act & Assert - should not revert
        accessManager.requireCanInitSignatures(address(peginManager));
    }

    function test_requireCanInitSignatures_Success_CallFromPegoutManager() external view {
        // Act & Assert - should not revert
        accessManager.requireCanInitSignatures(address(pegoutManager));
    }

    function test_requireCanInitSignatures_Revert_UnauthorizedAddress() external {
        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(IAccessManager.UnauthorizedToInitSignatures.selector, unauthorizedAddress)
        );

        // Act
        accessManager.requireCanInitSignatures(unauthorizedAddress);
    }

    function test_requireCanInitSignatures_Revert_CallFromCommitteeRegistry() external {
        // Assert
        vm.expectRevert(abi.encodeWithSelector(IAccessManager.UnauthorizedToInitSignatures.selector, address(registry)));

        // Act
        accessManager.requireCanInitSignatures(address(registry));
    }

    function test_requireCanInitSignatures_Revert_CallFromChallengeManager() external {
        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(IAccessManager.UnauthorizedToInitSignatures.selector, address(challengeManager))
        );

        // Act
        accessManager.requireCanInitSignatures(address(challengeManager));
    }

    // ============ requireCanInitOperatorTakeTxids Tests ============

    function test_requireCanInitOperatorTakeTxids_Success_CallFromPeginManager() external view {
        // Act & Assert - should not revert
        accessManager.requireCanInitOperatorTakeTxids(address(peginManager));
    }

    function test_requireCanInitOperatorTakeTxids_Revert_UnauthorizedAddress() external {
        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(IAccessManager.UnauthorizedToInitOperatorTakeTxids.selector, unauthorizedAddress)
        );

        // Act
        accessManager.requireCanInitOperatorTakeTxids(unauthorizedAddress);
    }

    function test_requireCanInitOperatorTakeTxids_Revert_CallFromPegoutManager() external {
        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(IAccessManager.UnauthorizedToInitOperatorTakeTxids.selector, address(pegoutManager))
        );

        // Act
        accessManager.requireCanInitOperatorTakeTxids(address(pegoutManager));
    }

    function test_requireCanInitOperatorTakeTxids_Revert_CallFromCommitteeRegistry() external {
        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(IAccessManager.UnauthorizedToInitOperatorTakeTxids.selector, address(registry))
        );

        // Act
        accessManager.requireCanInitOperatorTakeTxids(address(registry));
    }

    // ============ requireCanModifyCandidatesForStream Tests ============

    function test_requireCanModifyCandidatesForStream_Success_CallFromCommitteeRegistry() external view {
        // Act & Assert - should not revert
        accessManager.requireCanModifyCandidatesForStream(address(registry));
    }

    function test_requireCanModifyCandidatesForStream_Revert_UnauthorizedAddress() external {
        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(IAccessManager.UnauthorizedToModifyCandidatesForStream.selector, unauthorizedAddress)
        );

        // Act
        accessManager.requireCanModifyCandidatesForStream(unauthorizedAddress);
    }

    function test_requireCanModifyCandidatesForStream_Revert_CallFromPeginManager() external {
        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessManager.UnauthorizedToModifyCandidatesForStream.selector, address(peginManager)
            )
        );

        // Act
        accessManager.requireCanModifyCandidatesForStream(address(peginManager));
    }

    function test_requireCanModifyCandidatesForStream_Revert_CallFromPegoutManager() external {
        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessManager.UnauthorizedToModifyCandidatesForStream.selector, address(pegoutManager)
            )
        );

        // Act
        accessManager.requireCanModifyCandidatesForStream(address(pegoutManager));
    }
}
