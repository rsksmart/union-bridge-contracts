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

    // ============ canModifyPegStatus Tests ============

    function test_canModifyPegStatus_Success_CallFromPeginManager() external view {
        // Act & Assert - should not revert
        accessManager.canModifyPegStatus(address(peginManager));
    }

    function test_canModifyPegStatus_Success_CallFromPegoutManager() external view {
        // Act & Assert - should not revert
        accessManager.canModifyPegStatus(address(pegoutManager));
    }

    function test_canModifyPegStatus_Success_CallFromChallengeManager() external view {
        // Act & Assert - should not revert
        accessManager.canModifyPegStatus(address(challengeManager));
    }

    function test_canModifyPegStatus_Revert_UnauthorizedAddress() external {
        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(IAccessManager.UnauthorizedToModifyPegStatus.selector, unauthorizedAddress)
        );

        // Act
        accessManager.canModifyPegStatus(unauthorizedAddress);
    }

    function test_canModifyPegStatus_Revert_CallFromCommitteeRegistry() external {
        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(IAccessManager.UnauthorizedToModifyPegStatus.selector, address(registry))
        );

        // Act
        accessManager.canModifyPegStatus(address(registry));
    }

    function test_canModifyPegStatus_Revert_CallFromMemberRegistry() external {
        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(IAccessManager.UnauthorizedToModifyPegStatus.selector, address(memberRegistry))
        );

        // Act
        accessManager.canModifyPegStatus(address(memberRegistry));
    }

    // ============ canCreateCommittee Tests ============

    function test_canCreateCommittee_Success_CallFromPeginManager() external view {
        // Act & Assert - should not revert
        accessManager.canCreateCommittee(address(peginManager));
    }

    function test_canCreateCommittee_Revert_UnauthorizedAddress() external {
        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(IAccessManager.UnauthorizedToCreateCommittee.selector, unauthorizedAddress)
        );

        // Act
        accessManager.canCreateCommittee(unauthorizedAddress);
    }

    function test_canCreateCommittee_Revert_CallFromPegoutManager() external {
        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(IAccessManager.UnauthorizedToCreateCommittee.selector, address(pegoutManager))
        );

        // Act
        accessManager.canCreateCommittee(address(pegoutManager));
    }

    function test_canCreateCommittee_Revert_CallFromCommitteeRegistry() external {
        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(IAccessManager.UnauthorizedToCreateCommittee.selector, address(registry))
        );

        // Act
        accessManager.canCreateCommittee(address(registry));
    }

    function test_canCreateCommittee_Revert_CallFromMemberRegistry() external {
        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(IAccessManager.UnauthorizedToCreateCommittee.selector, address(memberRegistry))
        );

        // Act
        accessManager.canCreateCommittee(address(memberRegistry));
    }

    // ============ canReleaseCommittee Tests ============

    function test_canReleaseCommittee_Success_CallFromPegoutManager() external view {
        // Act & Assert - should not revert
        accessManager.canReleaseCommittee(address(pegoutManager));
    }

    function test_canReleaseCommittee_Success_CallFromPeginManager() external view {
        // Act & Assert - should not revert
        accessManager.canReleaseCommittee(address(peginManager));
    }

    function test_canReleaseCommittee_Revert_UnauthorizedAddress() external {
        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(IAccessManager.UnauthorizedToReleaseCommittee.selector, unauthorizedAddress)
        );

        // Act
        accessManager.canReleaseCommittee(unauthorizedAddress);
    }

    function test_canReleaseCommittee_Revert_CallFromCommitteeRegistry() external {
        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(IAccessManager.UnauthorizedToReleaseCommittee.selector, address(registry))
        );

        // Act
        accessManager.canReleaseCommittee(address(registry));
    }

    function test_canReleaseCommittee_Revert_CallFromMemberRegistry() external {
        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(IAccessManager.UnauthorizedToReleaseCommittee.selector, address(memberRegistry))
        );

        // Act
        accessManager.canReleaseCommittee(address(memberRegistry));
    }

    // ============ canSelectTakeOperator Tests ============

    function test_canSelectTakeOperator_Success_CallFromPegoutManager() external view {
        // Act & Assert - should not revert
        accessManager.canSelectTakeOperator(address(pegoutManager));
    }

    function test_canSelectTakeOperator_Revert_UnauthorizedAddress() external {
        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(IAccessManager.UnauthorizedToSelectTakeOperator.selector, unauthorizedAddress)
        );

        // Act
        accessManager.canSelectTakeOperator(unauthorizedAddress);
    }

    function test_canSelectTakeOperator_Revert_CallFromPeginManager() external {
        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(IAccessManager.UnauthorizedToSelectTakeOperator.selector, address(peginManager))
        );

        // Act
        accessManager.canSelectTakeOperator(address(peginManager));
    }

    function test_canSelectTakeOperator_Revert_CallFromCommitteeRegistry() external {
        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(IAccessManager.UnauthorizedToSelectTakeOperator.selector, address(registry))
        );

        // Act
        accessManager.canSelectTakeOperator(address(registry));
    }

    function test_canSelectTakeOperator_Revert_CallFromMemberRegistry() external {
        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(IAccessManager.UnauthorizedToSelectTakeOperator.selector, address(memberRegistry))
        );

        // Act
        accessManager.canSelectTakeOperator(address(memberRegistry));
    }

    // ============ canCreatePacket Tests ============

    function test_canCreatePacket_Success_CallFromCommitteeRegistry() external view {
        // Act & Assert - should not revert
        accessManager.canCreatePacket(address(registry));
    }

    function test_canCreatePacket_Revert_UnauthorizedAddress() external {
        // Assert
        vm.expectRevert(abi.encodeWithSelector(IAccessManager.UnauthorizedToCreatePacket.selector, unauthorizedAddress));

        // Act
        accessManager.canCreatePacket(unauthorizedAddress);
    }

    function test_canCreatePacket_Revert_CallFromPeginManager() external {
        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(IAccessManager.UnauthorizedToCreatePacket.selector, address(peginManager))
        );

        // Act
        accessManager.canCreatePacket(address(peginManager));
    }

    function test_canCreatePacket_Revert_CallFromPegoutManager() external {
        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(IAccessManager.UnauthorizedToCreatePacket.selector, address(pegoutManager))
        );

        // Act
        accessManager.canCreatePacket(address(pegoutManager));
    }

    function test_canCreatePacket_Revert_CallFromMemberRegistry() external {
        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(IAccessManager.UnauthorizedToCreatePacket.selector, address(memberRegistry))
        );

        // Act
        accessManager.canCreatePacket(address(memberRegistry));
    }

    // ============ canMintRbtc Tests ============

    function test_canMintRbtc_Success_CallFromPeginManager() external view {
        // Act & Assert - should not revert
        accessManager.canMintRbtc(address(peginManager));
    }

    function test_canMintRbtc_Revert_UnauthorizedAddress() external {
        // Assert
        vm.expectRevert(abi.encodeWithSelector(IAccessManager.UnauthorizedToMintRbtc.selector, unauthorizedAddress));

        // Act
        accessManager.canMintRbtc(unauthorizedAddress);
    }

    function test_canMintRbtc_Revert_CallFromPegoutManager() external {
        // Assert
        vm.expectRevert(abi.encodeWithSelector(IAccessManager.UnauthorizedToMintRbtc.selector, address(pegoutManager)));

        // Act
        accessManager.canMintRbtc(address(pegoutManager));
    }

    function test_canMintRbtc_Revert_CallFromCommitteeRegistry() external {
        // Assert
        vm.expectRevert(abi.encodeWithSelector(IAccessManager.UnauthorizedToMintRbtc.selector, address(registry)));

        // Act
        accessManager.canMintRbtc(address(registry));
    }

    function test_canMintRbtc_Revert_CallFromMemberRegistry() external {
        // Assert
        vm.expectRevert(abi.encodeWithSelector(IAccessManager.UnauthorizedToMintRbtc.selector, address(memberRegistry)));

        // Act
        accessManager.canMintRbtc(address(memberRegistry));
    }

    // ============ canBurnRbtc Tests ============

    function test_canBurnRbtc_Success_CallFromPegoutManager() external view {
        // Act & Assert - should not revert
        accessManager.canBurnRbtc(address(pegoutManager));
    }

    function test_canBurnRbtc_Revert_UnauthorizedAddress() external {
        // Assert
        vm.expectRevert(abi.encodeWithSelector(IAccessManager.UnauthorizedToBurnRbtc.selector, unauthorizedAddress));

        // Act
        accessManager.canBurnRbtc(unauthorizedAddress);
    }

    function test_canBurnRbtc_Revert_CallFromPeginManager() external {
        // Assert
        vm.expectRevert(abi.encodeWithSelector(IAccessManager.UnauthorizedToBurnRbtc.selector, address(peginManager)));

        // Act
        accessManager.canBurnRbtc(address(peginManager));
    }

    function test_canBurnRbtc_Revert_CallFromMemberRegistry() external {
        // Assert
        vm.expectRevert(abi.encodeWithSelector(IAccessManager.UnauthorizedToBurnRbtc.selector, address(memberRegistry)));

        // Act
        accessManager.canBurnRbtc(address(memberRegistry));
    }

    function test_canBurnRbtc_Revert_CallFromCommitteeRegistry() external {
        // Assert
        vm.expectRevert(abi.encodeWithSelector(IAccessManager.UnauthorizedToBurnRbtc.selector, address(registry)));

        // Act
        accessManager.canBurnRbtc(address(registry));
    }

    // ============ canInitSignatures Tests ============

    function test_canInitSignatures_Success_CallFromPeginManager() external view {
        // Act & Assert - should not revert
        accessManager.canInitSignatures(address(peginManager));
    }

    function test_canInitSignatures_Success_CallFromPegoutManager() external view {
        // Act & Assert - should not revert
        accessManager.canInitSignatures(address(pegoutManager));
    }

    function test_canInitSignatures_Revert_UnauthorizedAddress() external {
        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(IAccessManager.UnauthorizedToInitSignatures.selector, unauthorizedAddress)
        );

        // Act
        accessManager.canInitSignatures(unauthorizedAddress);
    }

    function test_canInitSignatures_Revert_CallFromCommitteeRegistry() external {
        // Assert
        vm.expectRevert(abi.encodeWithSelector(IAccessManager.UnauthorizedToInitSignatures.selector, address(registry)));

        // Act
        accessManager.canInitSignatures(address(registry));
    }

    function test_canInitSignatures_Revert_CallFromChallengeManager() external {
        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(IAccessManager.UnauthorizedToInitSignatures.selector, address(challengeManager))
        );

        // Act
        accessManager.canInitSignatures(address(challengeManager));
    }

    function test_canInitSignatures_Revert_CallFromMemberRegistry() external {
        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(IAccessManager.UnauthorizedToInitSignatures.selector, address(memberRegistry))
        );

        // Act
        accessManager.canInitSignatures(address(memberRegistry));
    }

    // ============ canInitOperatorTakeTxids Tests ============

    function test_canInitOperatorTakeTxids_Success_CallFromPeginManager() external view {
        // Act & Assert - should not revert
        accessManager.canInitOperatorTakeTxids(address(peginManager));
    }

    function test_canInitOperatorTakeTxids_Revert_UnauthorizedAddress() external {
        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(IAccessManager.UnauthorizedToInitOperatorTakeTxids.selector, unauthorizedAddress)
        );

        // Act
        accessManager.canInitOperatorTakeTxids(unauthorizedAddress);
    }

    function test_canInitOperatorTakeTxids_Revert_CallFromPegoutManager() external {
        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(IAccessManager.UnauthorizedToInitOperatorTakeTxids.selector, address(pegoutManager))
        );

        // Act
        accessManager.canInitOperatorTakeTxids(address(pegoutManager));
    }

    function test_canInitOperatorTakeTxids_Revert_CallFromCommitteeRegistry() external {
        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(IAccessManager.UnauthorizedToInitOperatorTakeTxids.selector, address(registry))
        );

        // Act
        accessManager.canInitOperatorTakeTxids(address(registry));
    }

    function test_canInitOperatorTakeTxids_Revert_CallFromMemberRegistry() external {
        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(IAccessManager.UnauthorizedToInitOperatorTakeTxids.selector, address(memberRegistry))
        );

        // Act
        accessManager.canInitOperatorTakeTxids(address(memberRegistry));
    }

    // ============ canModifyCandidatesForStream Tests ============

    function test_canModifyCandidatesForStream_Success_CallFromCommitteeRegistry() external view {
        // Act & Assert - should not revert
        accessManager.canModifyCandidatesForStream(address(registry));
    }

    function test_canModifyCandidatesForStream_Revert_UnauthorizedAddress() external {
        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(IAccessManager.UnauthorizedToModifyCandidatesForStream.selector, unauthorizedAddress)
        );

        // Act
        accessManager.canModifyCandidatesForStream(unauthorizedAddress);
    }

    function test_canModifyCandidatesForStream_Revert_CallFromPeginManager() external {
        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessManager.UnauthorizedToModifyCandidatesForStream.selector, address(peginManager)
            )
        );

        // Act
        accessManager.canModifyCandidatesForStream(address(peginManager));
    }

    function test_canModifyCandidatesForStream_Revert_CallFromPegoutManager() external {
        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessManager.UnauthorizedToModifyCandidatesForStream.selector, address(pegoutManager)
            )
        );

        // Act
        accessManager.canModifyCandidatesForStream(address(pegoutManager));
    }

    function test_canModifyCandidatesForStream_Revert_CallFromMemberRegistry() external {
        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessManager.UnauthorizedToModifyCandidatesForStream.selector, address(memberRegistry)
            )
        );

        // Act
        accessManager.canModifyCandidatesForStream(address(memberRegistry));
    }
}
