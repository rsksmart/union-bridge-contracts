// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {CommitteeRegistry} from "src/CommitteeRegistry.sol";
import {
    ICommitteeRegistry,
    PublicKeyRegistration,
    PublicKeyIndex,
    PUBLIC_KEYS_INDEX_LENGTH,
    Role,
    Member
} from "src/interfaces/ICommitteeRegistry.sol";
import {StreamDenomination, IStreamManager, Stream} from "src/interfaces/IStreamManager.sol";
import {HelperContract} from "test/helpers/HelperContract.sol";
import {BtcHelper} from "src/libraries/BtcHelper.sol";
import {Constants} from "src/libraries/Constants.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract TestCommitteeRegistry is Test, HelperContract {
    function setUp() external {
        runTestDeployScript();
    }

    function test_applyToStream_Success_Operator() external {
        _test_applyToStream_Success(Role.OPERATOR);
    }

    function test_applyToStream_Success_Watchtower() external {
        _test_applyToStream_Success(Role.WATCHTOWER);
    }

    function _test_applyToStream_Success(Role _role) internal {
        // This function applies to the DEFAULT_STREAM with `_role` and check that `_oppositeRole` candidates does not change.
        // Arrange
        if (_role == Role.NONE) {
            revert("Role cannot be None for unsubscribe test");
        }
        Role oppositeRole = _role == Role.OPERATOR ? Role.WATCHTOWER : Role.OPERATOR;

        uint256 privKey = uint256(1);
        PublicKeyRegistration[] memory pubKeysRegistration = generatePublicKeysRegistration(privKey);
        bytes32[] memory pubKeys = getXPublicKeysFromRegistration(pubKeysRegistration);
        address user = vm.addr(privKey);
        uint256 minimumDeposit = registry.getMinimumDeposit(DEFAULT_STREAM);
        vm.deal(user, minimumDeposit);

        uint256 roleCandidatesAmountBefore = registry.getCommitteeCandidates(DEFAULT_STREAM, _role).length;
        uint256 opossiteRoleAmountBefore = registry.getCommitteeCandidates(DEFAULT_STREAM, oppositeRole).length;

        // Check balances before
        uint256 userBalanceBefore = user.balance;
        uint256 contractBalanceBefore = address(registry).balance;

        // Assert member registered
        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.NewMember(pubKeys);

        // Assert assert deposited bond
        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.NewSecurityBondDeposit(user, DEFAULT_STREAM, _role, minimumDeposit);

        // Act
        vm.prank(user);
        registry.applyToStream{value: minimumDeposit}(DEFAULT_STREAM, _role, pubKeysRegistration);

        // Assert
        assertEq(registry.getMemberPublicKeys(user), pubKeys, "member public key should match the deposited key");
        assertTrue(
            registry.getMemberRequestedRole(user, DEFAULT_STREAM) == _role,
            "member requested role should match the requested role"
        );
        assertEq(registry.getMemberAvailableBalance(user), 0, "member available balance should be 0");
        assertEq(
            registry.getMemberPreStakedBalance(user, DEFAULT_STREAM),
            minimumDeposit,
            "member pre-staked should match the minimum deposit"
        );

        address[] memory roleCandidates = registry.getCommitteeCandidates(DEFAULT_STREAM, _role);
        address[] memory oppositeRoleCandidates = registry.getCommitteeCandidates(DEFAULT_STREAM, oppositeRole);
        uint256 roleCandidatesAmountAfter = roleCandidates.length;
        uint256 opossiteRoleAmountAfter = oppositeRoleCandidates.length;
        assertEq(roleCandidatesAmountBefore + 1, roleCandidatesAmountAfter, "candidates amount should increase by 1");
        assertEq(opossiteRoleAmountBefore, opossiteRoleAmountAfter, "opposite role candidates amount should not change");

        // Look up candidate in candidates array
        assertEq(
            roleCandidates[roleCandidatesAmountAfter - 1], user, "last candidate address should match member address"
        );

        for (uint256 i = 0; i < roleCandidatesAmountAfter - 1; i++) {
            assertNotEq(
                roleCandidates[i], user, "candidate address should not match member address until last candidate"
            );
        }

        for (uint256 i = 0; i < opossiteRoleAmountAfter; i++) {
            assertNotEq(
                oppositeRoleCandidates[i], user, "opposite role candidate addresses should not match member address"
            );
        }

        // Check balances after
        uint256 userBalanceAfter = user.balance;
        uint256 contractBalanceAfter = address(registry).balance;
        assertEq(userBalanceBefore - userBalanceAfter, minimumDeposit, "user balance should decrease by deposit");
        assertEq(
            contractBalanceAfter - contractBalanceBefore, minimumDeposit, "contract balance should increase by deposit"
        );
    }

    function test_applyToStream_Success_two_users() external {
        uint256 privKey1 = uint256(1);
        PublicKeyRegistration[] memory pubKeysRegistration1 = generatePublicKeysRegistration(privKey1);
        address user1 = vm.addr(privKey1);
        uint256 privKey2 = uint256(2);
        PublicKeyRegistration[] memory pubKeysRegistration2 = generatePublicKeysRegistration(privKey2);
        address user2 = vm.addr(privKey2);
        step_applyToStreamForStream(user1, pubKeysRegistration1, DEFAULT_STREAM, Role.OPERATOR);
        step_applyToStreamForStream(user2, pubKeysRegistration2, DEFAULT_STREAM, Role.OPERATOR);
    }

    function test_applyToStream_Revert_PublicKeyMismatch() external {
        // Arrange
        uint256 privKey = uint256(1);
        PublicKeyRegistration[] memory pubKeysRegistration = generatePublicKeysRegistration(privKey);
        PublicKeyRegistration[] memory differentPubKey = generatePublicKeysRegistration(privKey + 1);
        address user = vm.addr(privKey);
        uint256 minimumDeposit = registry.getMinimumDeposit(DEFAULT_STREAM);
        vm.deal(user, minimumDeposit);

        vm.prank(user);
        registry.applyToStream{value: minimumDeposit}(DEFAULT_STREAM, Role.OPERATOR, pubKeysRegistration);

        vm.deal(user, minimumDeposit);

        // Assert member already registered for stream
        vm.expectRevert(
            abi.encodeWithSelector(
                ICommitteeRegistry.PublicKeyMismatch.selector,
                0,
                pubKeysRegistration[0].publicKeyX,
                differentPubKey[0].publicKeyX
            )
        );

        // Act
        vm.prank(user);
        registry.applyToStream{value: minimumDeposit}(DEFAULT_STREAM, Role.WATCHTOWER, differentPubKey);
    }

    function test_applyToStream_Revert_memberAlreadyRegisteredForStream() external {
        // Arrange
        uint256 privKey = uint256(1);
        PublicKeyRegistration[] memory pubKeysRegistration = generatePublicKeysRegistration(privKey);
        address user = vm.addr(privKey);
        uint256 minimumDeposit = registry.getMinimumDeposit(DEFAULT_STREAM);
        vm.deal(user, minimumDeposit);

        vm.prank(user);
        registry.applyToStream{value: minimumDeposit}(DEFAULT_STREAM, Role.OPERATOR, pubKeysRegistration);

        vm.deal(user, minimumDeposit);

        // Assert member already registered for stream
        vm.expectRevert(
            abi.encodeWithSelector(
                ICommitteeRegistry.MemberAlreadyRegisteredForStream.selector,
                user,
                DEFAULT_STREAM,
                Role.WATCHTOWER,
                Role.OPERATOR
            )
        );

        // Act
        vm.prank(user);
        registry.applyToStream{value: minimumDeposit}(DEFAULT_STREAM, Role.WATCHTOWER, pubKeysRegistration);
    }

    function test_applyToStream_Revert_requestedNoneRoleForStream() external {
        // Arrange
        uint256 privKey = uint256(1);
        PublicKeyRegistration[] memory pubKeysRegistration = generatePublicKeysRegistration(privKey);
        address user = vm.addr(privKey);
        uint256 minimumDeposit = registry.getMinimumDeposit(DEFAULT_STREAM);
        vm.deal(user, minimumDeposit);

        // Assert requested none role for stream
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.RequestedNoneRoleForStream.selector, DEFAULT_STREAM));

        // Act
        vm.prank(user);
        registry.applyToStream{value: minimumDeposit}(DEFAULT_STREAM, Role.NONE, pubKeysRegistration);
    }

    function test_applyToStream_Revert_despositBondTooLow() external {
        // Arrange
        uint256 privKey = uint256(1);
        PublicKeyRegistration[] memory pubKeysRegistration = generatePublicKeysRegistration(privKey);
        address user = vm.addr(privKey);
        uint256 minimumDeposit = registry.getMinimumDeposit(DEFAULT_STREAM);
        vm.deal(user, minimumDeposit - 1);

        // Assert deposit bond too low
        vm.expectRevert(
            abi.encodeWithSelector(ICommitteeRegistry.DespositBondTooLow.selector, minimumDeposit - 1, minimumDeposit)
        );

        // Act
        vm.prank(user);
        registry.applyToStream{value: minimumDeposit - 1}(DEFAULT_STREAM, DEFAULT_ROLE, pubKeysRegistration);
    }

    function test_unsubscribeFromStream_Success_Operator() external {
        _test_unsubscribeFromStream_Success(Role.OPERATOR);
    }

    function test_unsubscribeFromStream_Success_Watchtower() external {
        _test_unsubscribeFromStream_Success(Role.WATCHTOWER);
    }

    function test_applyToStream_Revert_InvalidPublicKeysLength() external {
        // Arrange
        uint256 privKey = uint256(1);
        PublicKeyRegistration[] memory incorrectPubKeysRegistration = new PublicKeyRegistration[](1);
        PublicKeyIndex pubKeyIndex = PublicKeyIndex.TAKE;
        incorrectPubKeysRegistration[uint8(pubKeyIndex)] = generatePublicKeyRegistration(privKey, pubKeyIndex);
        address user = vm.addr(privKey);
        uint256 minimumDeposit = registry.getMinimumDeposit(DEFAULT_STREAM);
        vm.deal(user, minimumDeposit);

        // Assert invalid public keys length
        vm.expectRevert(
            abi.encodeWithSelector(
                ICommitteeRegistry.InvalidPublicKeysLength.selector,
                incorrectPubKeysRegistration.length,
                PUBLIC_KEYS_INDEX_LENGTH
            )
        );

        // Act
        vm.prank(user);
        registry.applyToStream{value: minimumDeposit}(DEFAULT_STREAM, DEFAULT_ROLE, incorrectPubKeysRegistration);
    }

    function test_applyToStream_Revert_RepeatedPublicKeys_Take_Covenant() external {
        _test_applyToStream_Revert_RepeatedPublicKeys(uint8(PublicKeyIndex.TAKE), uint8(PublicKeyIndex.COVENANT));
    }

    function _test_applyToStream_Revert_RepeatedPublicKeys(uint8 pubKeyIndex1, uint8 pubKeyIndex2) internal {
        // Arrange
        uint256 privKey = uint256(1);
        address user = vm.addr(privKey);
        uint256 minimumDeposit = registry.getMinimumDeposit(DEFAULT_STREAM);
        vm.deal(user, minimumDeposit);
        PublicKeyRegistration[] memory incorrectPubKeysRegistration = generatePublicKeysRegistration(privKey);
        incorrectPubKeysRegistration[pubKeyIndex1] = incorrectPubKeysRegistration[pubKeyIndex2];

        // Assert invalid public keys length
        vm.expectRevert(
            abi.encodeWithSelector(
                ICommitteeRegistry.RepeatedPublicKeys.selector,
                pubKeyIndex1,
                incorrectPubKeysRegistration[pubKeyIndex1].publicKeyX,
                pubKeyIndex2,
                incorrectPubKeysRegistration[pubKeyIndex2].publicKeyX
            )
        );

        // Act
        vm.prank(user);
        registry.applyToStream{value: minimumDeposit}(DEFAULT_STREAM, DEFAULT_ROLE, incorrectPubKeysRegistration);
    }

    function test_applyToStream_Revert_RepeatedPublicKeys_Take_Communication() external {
        _test_applyToStream_Revert_RepeatedPublicKeys(uint8(PublicKeyIndex.TAKE), uint8(PublicKeyIndex.COMMUNICATION));
    }

    function test_applyToStream_Revert_RepeatedPublicKeys_Covenant_Communication() external {
        _test_applyToStream_Revert_RepeatedPublicKeys(
            uint8(PublicKeyIndex.COVENANT), uint8(PublicKeyIndex.COMMUNICATION)
        );
    }

    function _executeAndAssertInvalidZeroPublicKey(
        uint256 i,
        uint256 privKey,
        PublicKeyRegistration[] memory _incorrectPubKeysRegistration
    ) internal {
        // Arrange
        address user = vm.addr(privKey);
        uint256 minimumDeposit = registry.getMinimumDeposit(DEFAULT_STREAM);
        vm.deal(user, minimumDeposit);

        // Assert invalid public key
        vm.expectRevert(
            abi.encodeWithSelector(
                ICommitteeRegistry.InvalidZeroPublicKey.selector,
                i,
                _incorrectPubKeysRegistration[i].publicKeyX,
                _incorrectPubKeysRegistration[i].publicKeyY
            )
        );
        // Act
        vm.prank(user);
        registry.applyToStream{value: minimumDeposit}(DEFAULT_STREAM, DEFAULT_ROLE, _incorrectPubKeysRegistration);
    }

    function test_applyToStream_Revert_InvalidZeroPublicKey_X_Y() external {
        // Arrange
        uint256 privKey = uint256(1);
        PublicKeyRegistration[] memory pubKeysRegistration = generatePublicKeysRegistration(privKey);

        for (uint8 i = 0; i < PUBLIC_KEYS_INDEX_LENGTH; i++) {
            // Store the original public key
            bytes32 originalPublicKeyX = pubKeysRegistration[i].publicKeyX;
            // Set the public key to 0
            pubKeysRegistration[i].publicKeyX = bytes32(0);
            // Assert invalid public key X
            _executeAndAssertInvalidZeroPublicKey(i, privKey, pubKeysRegistration);
            // Restore the original X public key
            pubKeysRegistration[i].publicKeyX = originalPublicKeyX;

            // Store the original public key
            bytes32 originalPublicKeyY = pubKeysRegistration[i].publicKeyY;
            // Set the public key Y to 0
            pubKeysRegistration[i].publicKeyY = bytes32(0);
            // Assert invalid public key Y
            _executeAndAssertInvalidZeroPublicKey(i, privKey, pubKeysRegistration);
            // Restore the original Y public key
            pubKeysRegistration[i].publicKeyY = originalPublicKeyY;
        }
    }

    function _executeAndAssertInvalidZeroSignature(
        uint256 i,
        uint256 privKey,
        PublicKeyRegistration[] memory _incorrectPubKeysRegistration
    ) internal {
        // Arrange
        address user = vm.addr(privKey);
        uint256 minimumDeposit = registry.getMinimumDeposit(DEFAULT_STREAM);
        vm.deal(user, minimumDeposit);

        // Assert invalid public key
        vm.expectRevert(
            abi.encodeWithSelector(
                ICommitteeRegistry.InvalidZeroSignature.selector, i, _incorrectPubKeysRegistration[i]
            )
        );
        // Act
        vm.prank(user);
        registry.applyToStream{value: minimumDeposit}(DEFAULT_STREAM, DEFAULT_ROLE, _incorrectPubKeysRegistration);
    }

    function test_applyToStream_Revert_InvalidZeroSignature_V() external {
        // Arrange
        uint256 privKey = uint256(1);
        PublicKeyRegistration[] memory pubKeysRegistration = generatePublicKeysRegistration(privKey);

        for (uint8 i = 0; i < PUBLIC_KEYS_INDEX_LENGTH; i++) {
            // Store the original signature
            uint8 originalV = pubKeysRegistration[i].v;
            // Set the signature to 0
            pubKeysRegistration[i].v = 0;
            // Assert invalid zero signature
            _executeAndAssertInvalidZeroSignature(i, privKey, pubKeysRegistration);
            // Restore the original signature
            pubKeysRegistration[i].v = originalV;
        }
    }

    function test_applyToStream_Revert_InvalidZeroSignature_R() external {
        // Arrange
        uint256 privKey = uint256(1);
        PublicKeyRegistration[] memory pubKeysRegistration = generatePublicKeysRegistration(privKey);

        for (uint8 i = 0; i < PUBLIC_KEYS_INDEX_LENGTH; i++) {
            // Store the original signature
            bytes32 originalR = pubKeysRegistration[i].r;
            // Set the signature to 0
            pubKeysRegistration[i].r = bytes32(0);
            // Assert invalid zero signature
            _executeAndAssertInvalidZeroSignature(i, privKey, pubKeysRegistration);
            // Restore the original signature
            pubKeysRegistration[i].r = originalR;
        }
    }

    function test_applyToStream_Revert_InvalidZeroSignature_S() external {
        // Arrange
        uint256 privKey = uint256(1);
        PublicKeyRegistration[] memory pubKeysRegistration = generatePublicKeysRegistration(privKey);

        for (uint8 i = 0; i < PUBLIC_KEYS_INDEX_LENGTH; i++) {
            // Store the original signature
            bytes32 originalS = pubKeysRegistration[i].s;
            // Set the signature to 0
            pubKeysRegistration[i].s = bytes32(0);
            // Assert invalid zero signature
            _executeAndAssertInvalidZeroSignature(i, privKey, pubKeysRegistration);
            // Restore the original signature
            pubKeysRegistration[i].s = originalS;
        }
    }

    function test_applyToStream_Revert_ECDSAInvalidSignature() external {
        // Arrange
        uint256 privKey = uint256(1);
        address user = vm.addr(privKey);
        uint256 minimumDeposit = registry.getMinimumDeposit(DEFAULT_STREAM);
        vm.deal(user, minimumDeposit);
        PublicKeyRegistration[] memory _incorrectPubKeysRegistration = generatePublicKeysRegistration(privKey);

        // V can only be 27 or 28, so we set it to 29 to trigger the error
        _incorrectPubKeysRegistration[0].v = 29;

        // Assert invalid signature
        vm.expectRevert(abi.encodeWithSelector(ECDSA.ECDSAInvalidSignature.selector));
        // Act
        vm.prank(user);
        registry.applyToStream{value: minimumDeposit}(DEFAULT_STREAM, DEFAULT_ROLE, _incorrectPubKeysRegistration);
    }

    function test_applyToStream_Revert_ECDSAInvalidSignature_S() external {
        // Arrange
        uint256 privKey = uint256(1);
        address user = vm.addr(privKey);
        uint256 minimumDeposit = registry.getMinimumDeposit(DEFAULT_STREAM);
        vm.deal(user, minimumDeposit);
        PublicKeyRegistration[] memory _incorrectPubKeysRegistration = generatePublicKeysRegistration(privKey);

        _incorrectPubKeysRegistration[0].s = keccak256(abi.encodePacked(_incorrectPubKeysRegistration[0].s));

        // Assert invalid signature
        vm.expectRevert(
            abi.encodeWithSelector(ECDSA.ECDSAInvalidSignatureS.selector, _incorrectPubKeysRegistration[0].s)
        );
        // Act
        vm.prank(user);
        registry.applyToStream{value: minimumDeposit}(DEFAULT_STREAM, DEFAULT_ROLE, _incorrectPubKeysRegistration);
    }

    function test_applyToStream_Revert_InvalidSignature() external {
        // Arrange
        uint256 privKey = uint256(1);
        address user = vm.addr(privKey);
        uint256 minimumDeposit = registry.getMinimumDeposit(DEFAULT_STREAM);
        vm.deal(user, minimumDeposit);
        PublicKeyRegistration[] memory pubKeysRegistration = generatePublicKeysRegistration(privKey);

        // Set incorrect signature
        uint8 index = 0;
        pubKeysRegistration[index].v = pubKeysRegistration[index].v == 27 ? 28 : 27;

        // Assert invalid signature
        vm.expectRevert(
            abi.encodeWithSelector(
                ICommitteeRegistry.InvalidSignature.selector,
                index,
                pubKeysRegistration[index],
                0x7Fe3bB705a7B50b5fbcB0055B89707eeb762aF27,
                0x00d83E13A62e8E9F183fDbAa8642EF69192F644E
            )
        );
        // Act
        vm.prank(user);
        registry.applyToStream{value: minimumDeposit}(DEFAULT_STREAM, DEFAULT_ROLE, pubKeysRegistration);
    }

    function _test_unsubscribeFromStream_Success(Role _role) internal {
        // This function unsubscribes a user from DEFAULT_STREAM with `_role` and tests that `oppositeRole` candidates do not change.
        // Arrange
        if (_role == Role.NONE) {
            revert("Role cannot be None for unsubscribe test");
        }
        Role oppositeRole = _role == Role.OPERATOR ? Role.WATCHTOWER : Role.OPERATOR;

        uint256 privKey = uint256(1);
        PublicKeyRegistration[] memory pubKeysRegistration = generatePublicKeysRegistration(privKey);
        address user = vm.addr(privKey);
        uint256 minimumDeposit = registry.getMinimumDeposit(DEFAULT_STREAM);
        vm.deal(user, minimumDeposit);
        vm.prank(user);
        registry.applyToStream{value: minimumDeposit}(DEFAULT_STREAM, _role, pubKeysRegistration);

        address[] memory roleCandidates = registry.getCommitteeCandidates(DEFAULT_STREAM, _role);
        address[] memory oppositeRoleCandidates = registry.getCommitteeCandidates(DEFAULT_STREAM, oppositeRole);
        uint256 roleCandidatesAmountBefore = roleCandidates.length;
        uint256 oppositeRoleAmountBefore = oppositeRoleCandidates.length;

        // Assert
        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.NewAvailableBalance(user, minimumDeposit, minimumDeposit);
        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.MemberUnsubscribedFromStream(user, DEFAULT_STREAM);

        // Act
        vm.prank(user);
        registry.unsubscribeFromStream(DEFAULT_STREAM);

        // Assert
        assertEq(
            registry.getMemberAvailableBalance(user),
            minimumDeposit,
            "member available balance should match the minimum deposit"
        );
        assertEq(
            registry.getMemberPreStakedBalance(user, DEFAULT_STREAM),
            0,
            "member pre-staked should be 0 after unsuscribe"
        );
        assertTrue(
            registry.getMemberRequestedRole(user, DEFAULT_STREAM) == Role.NONE,
            "member requested role should be None after unsuscribe"
        );
        roleCandidates = registry.getCommitteeCandidates(DEFAULT_STREAM, _role);
        oppositeRoleCandidates = registry.getCommitteeCandidates(DEFAULT_STREAM, oppositeRole);
        uint256 roleCandidatesAmountAfter = roleCandidates.length;
        uint256 opossiteRoleAmountAfter = oppositeRoleCandidates.length;
        assertEq(roleCandidatesAmountBefore - 1, roleCandidatesAmountAfter, "candidates amount should decrease by 1");
        assertEq(oppositeRoleAmountBefore, opossiteRoleAmountAfter, "opposite role candidates amount should not change");
        for (uint256 i = 0; i < roleCandidatesAmountAfter; i++) {
            assertNotEq(roleCandidates[i], user, "candidate addresses should not match member address");
        }
    }

    function test_unsubscribeFromStream_Revert_memberIsNotCandidateForStream() external {
        // Arrange
        uint256 privKey = uint256(1);
        PublicKeyRegistration[] memory pubKeysRegistration = generatePublicKeysRegistration(privKey);
        address user = vm.addr(privKey);
        uint256 minimumDeposit = registry.getMinimumDeposit(StreamDenomination._0_001BTC);
        vm.deal(user, minimumDeposit);
        vm.prank(user);
        registry.applyToStream{value: minimumDeposit}(StreamDenomination._0_001BTC, Role.OPERATOR, pubKeysRegistration);

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                ICommitteeRegistry.MemberIsNotCandidateForStream.selector, user, StreamDenomination._0_01BTC
            )
        );

        // Act
        vm.prank(user);
        registry.unsubscribeFromStream(StreamDenomination._0_01BTC);
    }

    function test_unsubscribeFromStream_Revert_MemberNotRegistered() external {
        // Arrange
        uint256 privKey = uint256(1);
        address user = vm.addr(privKey);

        // Assert
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.MemberNotRegistered.selector, user));

        // Act
        vm.prank(user);
        registry.unsubscribeFromStream(DEFAULT_STREAM);
    }

    function test_unsubscribeFromStream_Revert_MemberIsInPendingCommittee() external {
        // Arrange
        (, uint64 streamId) = setup_pendingCommittee();
        address user = vm.addr(1);

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                ICommitteeRegistry.MemberIsInPendingCommittee.selector, user, StreamDenomination(streamId)
            )
        );

        // Act
        vm.prank(user);
        registry.unsubscribeFromStream(StreamDenomination(streamId));
    }

    function test_withdrawAvailableBalance_Success() external {
        // Arrange
        uint256 privKey = uint256(1);
        PublicKeyRegistration[] memory pubKeysRegistration = generatePublicKeysRegistration(privKey);
        address user = vm.addr(privKey);
        uint256 minimumDeposit = registry.getMinimumDeposit(DEFAULT_STREAM);
        vm.deal(user, minimumDeposit);

        vm.startBroadcast(user);
        registry.applyToStream{value: minimumDeposit}(DEFAULT_STREAM, DEFAULT_ROLE, pubKeysRegistration);
        registry.unsubscribeFromStream(DEFAULT_STREAM);
        vm.stopBroadcast();

        uint256 amount = registry.getMemberAvailableBalance(user);

        uint256 beforeWithdrawBalance = address(user).balance;
        uint256 contractBalanceBefore = address(registry).balance;

        // Assert
        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.AvailableBalanceRetrieved(user, amount);

        // Act
        vm.prank(user);
        registry.withdrawAvailableBalance();

        // Assert
        assertEq(registry.getMemberAvailableBalance(user), 0, "member available balance should be 0 after withdraw");
        assertEq(
            address(user).balance,
            beforeWithdrawBalance + amount,
            "contract balance should increase by the withdrawn amount"
        );
        assertEq(
            address(registry).balance,
            contractBalanceBefore - amount,
            "user balance should decrease by the withdrawn amount"
        );
    }

    function test_withdrawAvailableBalance_Revert_noAvailableBalanceToWithdraw() external {
        // Arrange
        uint256 privKey = uint256(1);
        PublicKeyRegistration[] memory pubKeysRegistration = generatePublicKeysRegistration(privKey);
        address user = vm.addr(privKey);
        uint256 minimumDeposit = registry.getMinimumDeposit(DEFAULT_STREAM);
        vm.deal(user, minimumDeposit);

        vm.startBroadcast(user);
        registry.applyToStream{value: minimumDeposit}(DEFAULT_STREAM, DEFAULT_ROLE, pubKeysRegistration);
        registry.unsubscribeFromStream(DEFAULT_STREAM);
        registry.withdrawAvailableBalance();
        vm.stopBroadcast();

        // Assert
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.NoAvailableBalanceToWithdraw.selector, user));

        // Act
        vm.prank(user);
        registry.withdrawAvailableBalance();
    }

    function step_applyToStreamForStream(
        address user,
        PublicKeyRegistration[] memory pubKeysRegistration,
        StreamDenomination stream,
        Role requestedRole
    ) internal returns (uint256) {
        // Arrange
        address[] memory committeesCandidates = registry.getCommitteeCandidates(stream, requestedRole);
        uint256 candidatesAmountBeforeDeposit = committeesCandidates.length;

        // Determine the minimum bond required (getMinimumDeposit(stream))
        uint256 minimumDeposit = registry.getMinimumDeposit(stream);
        vm.deal(user, minimumDeposit);

        // Act
        vm.prank(user);
        registry.applyToStream{value: minimumDeposit}(stream, requestedRole, pubKeysRegistration);

        // Assert that preStaked[streamIndex] equals the deposited amount
        assertEq(
            registry.getMemberPreStakedBalance(user, stream),
            minimumDeposit,
            "member pre-staked should match the minimum deposit for stream"
        );
        // Assert that requestedRoles[stream] is set
        assertTrue(
            registry.getMemberRequestedRole(user, stream) == requestedRole,
            "member requested role should match the requested role for stream"
        );
        // Assert that available is still 0
        assertEq(
            registry.getMemberAvailableBalance(user), 0, "member available balance should be 0 after deposit for stream"
        );
        // Assert that the member is listed in committeesCandidates[stream]
        committeesCandidates = registry.getCommitteeCandidates(stream, requestedRole);
        assertEq(
            candidatesAmountBeforeDeposit + 1,
            committeesCandidates.length,
            "candidates amount should increase by 1 after deposit for stream"
        );
        assertEq(
            committeesCandidates[committeesCandidates.length - 1], user, "candidate address should match member address"
        );
        return minimumDeposit;
    }

    function step_unsubscribeFromStream(address user, StreamDenomination stream) internal {
        // Arrange
        Role role = registry.getMemberRequestedRole(user, stream);
        uint256 lastAvailableBalance = registry.getMemberAvailableBalance(user);
        uint256 moneyToBecomeAvailable = registry.getMemberPreStakedBalance(user, stream);
        address[] memory committeesCandidates = registry.getCommitteeCandidates(stream, role);
        uint256 candidatesAmountBeforeUnsuscribe = committeesCandidates.length;

        // Act
        vm.prank(user);
        registry.unsubscribeFromStream(stream);

        // Assert that preStaked[streamIndex] is now 0
        assertEq(
            registry.getMemberPreStakedBalance(user, stream),
            0,
            "member pre-staked should be 0 after unsuscribing for stream"
        );
        // Assert that requestedRoles[stream] == Role.NONE
        assertTrue(
            registry.getMemberRequestedRole(user, stream) == Role.NONE,
            "member requested role should be None after unsuscribing for stream"
        );
        // Assert that available increased by the correct bond amount
        assertEq(
            registry.getMemberAvailableBalance(user),
            lastAvailableBalance + moneyToBecomeAvailable,
            "member available balance should increase by the pre-staked amount after unsuscribing for stream"
        );
        // Assert that the user is removed from committeesCandidates[stream]
        committeesCandidates = registry.getCommitteeCandidates(stream, role);
        assertEq(
            candidatesAmountBeforeUnsuscribe - 1,
            committeesCandidates.length,
            "candidates amount should increase by 1 after deposit for stream"
        );
    }

    // The following test checks the integration of applyToStream, unsubscribeFromStream, and withdrawAvailableBalance
    function test_Integration_applyToStream_unsubscribeFromStream_withdrawAvailableBalance_every_stream() external {
        // Arrange
        uint256 privKey = uint256(1);
        PublicKeyRegistration[] memory pubKeysRegistration = generatePublicKeysRegistration(privKey);
        address user = vm.addr(privKey);
        uint256 totalDeposited = 0;
        Role requestedRole = Role.OPERATOR;

        // 1. Deposit in All Streams
        for (uint8 i = 0; i <= uint8(StreamDenomination._10BTC); i++) {
            totalDeposited +=
                step_applyToStreamForStream(user, pubKeysRegistration, StreamDenomination(i), requestedRole);
        }

        // 2. Unsubscribe from All Streams
        for (uint8 i = 0; i <= uint8(StreamDenomination._10BTC); i++) {
            step_unsubscribeFromStream(user, StreamDenomination(i));
        }

        // 3. Withdraw Available Balance
        //Arrange
        // Record the user’s balance before calling withdrawAvailable
        uint256 beforeWithdrawBalance = address(user).balance;

        // Assert that available now equals the sum of all deposits
        assertEq(
            registry.getMemberAvailableBalance(user),
            totalDeposited,
            "member available balance should be equal to the total deposited amount"
        );

        // Act
        vm.prank(user);
        registry.withdrawAvailableBalance();

        // Assert that the user's available == 0
        assertEq(registry.getMemberAvailableBalance(user), 0, "member available balance should be 0 after withdraw");

        // Assert that the user’s balance increased accordingly
        assertEq(
            address(user).balance,
            beforeWithdrawBalance + totalDeposited,
            "user balance should increase by the total deposited amount"
        );
    }

    function test_getMemberTakePubKey_Revert_MemberNotRegistered() external {
        // Arrange
        address memberAddress = vm.addr(1);

        // Assert
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.MemberNotRegistered.selector, memberAddress));
        // Act
        registry.getMemberTakePubKey(memberAddress);
    }

    function test_getMemberTakePubKey_Success() external {
        // Arrange
        uint256 privKey = uint256(1);
        address userAddress = vm.addr(privKey);
        PublicKeyRegistration[] memory pubKeysRegistration = generatePublicKeysRegistration(privKey);
        bytes32[] memory pubKeys = getXPublicKeysFromRegistration(pubKeysRegistration);
        setup_applyToStream(StreamDenomination._0_001BTC, userAddress, pubKeysRegistration, Role.OPERATOR);

        // Act
        bytes32 pubKey = registry.getMemberTakePubKey(userAddress);

        // Assert
        assertEq(
            pubKeys[uint8(PublicKeyIndex.TAKE)],
            pubKey,
            "Member take public key by index is not the same as the registered one"
        );
    }

    function test_getMemberPublicKey_Revert_MemberNotRegistered() external {
        // Arrange
        address user = vm.addr(uint256(100));

        // Assert
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.MemberNotRegistered.selector, user));

        // Act
        registry.getMemberPublicKeys(user);
    }

    function test_getMemberRequestedRole_Revert_MemberNotRegistered() external {
        // Arrange
        address user = vm.addr(uint256(100));

        // Assert
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.MemberNotRegistered.selector, user));

        // Act
        registry.getMemberRequestedRole(user, DEFAULT_STREAM);
    }

    function test_getMemberAvailableBalance_Revert_MemberNotRegistered() external {
        // Arrange
        address user = vm.addr(uint256(100));

        // Assert
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.MemberNotRegistered.selector, user));

        // Act
        registry.getMemberAvailableBalance(user);
    }

    function test_getMemberPreStakedBalance_Revert_MemberNotRegistered() external {
        // Arrange
        address user = vm.addr(uint256(100));

        // Assert
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.MemberNotRegistered.selector, user));

        // Act
        registry.getMemberPreStakedBalance(user, DEFAULT_STREAM);
    }

    function test_getMemberStakedBalance_Revert_MemberNotRegistered() external {
        // Arrange
        address user = vm.addr(uint256(100));

        // Assert
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.MemberNotRegistered.selector, user));

        // Act
        registry.getMemberStakedBalance(user, DEFAULT_STREAM, 0);
    }

    function test_registerMember_Success() external {
        // Arrange
        uint256 privKey = uint256(1);
        PublicKeyRegistration[] memory pubKeysRegistration = generatePublicKeysRegistration(privKey);
        bytes32[] memory pubKeys = getXPublicKeysFromRegistration(pubKeysRegistration);
        address user = vm.addr(privKey);

        // Assert
        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.NewMember(pubKeys);

        // Act
        registry.registerMemberHarness(user, pubKeysRegistration);

        // Assert
        assertEq(registry.getMemberPublicKeys(user), pubKeys, "member public key should match the registered key");
        assertEq(registry.getMemberAvailableBalance(user), 0, "member available balance should be 0 after registration");
        for (uint64 i = 0; i <= uint8(StreamDenomination._10BTC); i++) {
            assertEq(
                registry.getMemberPreStakedBalance(user, StreamDenomination(i)),
                0,
                "member pre-staked should be 0 after registration for stream"
            );
            assertEq(
                registry.getMemberStakedBalance(user, StreamDenomination(i), 0),
                0,
                "member staked balance should be 0 after registration for stream"
            );
            assertTrue(
                registry.getMemberRequestedRole(user, StreamDenomination(i)) == Role.NONE,
                "member requested role should be None after registration for stream"
            );
        }
    }

    function test_registerCandidateToStream_Success() external {
        // Arrange
        uint256 privKey = uint256(1);
        setup_registerMember(privKey);
        address user = vm.addr(privKey);
        uint256 minimumDeposit = registry.getMinimumDeposit(DEFAULT_STREAM);
        Role role = Role.OPERATOR;

        // Act
        vm.prank(user);
        registry.registerCandidateToStreamHarness(user, DEFAULT_STREAM, role, minimumDeposit);

        // Assert
        assertEq(registry.getMemberAvailableBalance(user), 0, "member available balance should be 0 after registration");
        assertEq(
            registry.getMemberPreStakedBalance(user, DEFAULT_STREAM),
            minimumDeposit,
            "member pre-staked should match the minimum deposit for stream"
        );
        for (uint64 i = 0; i <= uint8(StreamDenomination._10BTC); i++) {
            if (i == uint8(DEFAULT_STREAM)) {
                assertTrue(
                    registry.getMemberRequestedRole(user, StreamDenomination(i)) == role,
                    "member requested role should match the requested role for stream"
                );
            } else {
                assertTrue(
                    registry.getMemberRequestedRole(user, StreamDenomination(i)) == Role.NONE,
                    "member requested role should be None for other streams"
                );
                uint256 preStakedBalance = registry.getMemberPreStakedBalance(user, StreamDenomination(i));
                assertEq(preStakedBalance, 0, "member pre-staked should be 0 for other streams");
            }
            assertEq(
                registry.getMemberStakedBalance(user, StreamDenomination(i), 0),
                0,
                "member staked balance should be 0 for all streams after registration for a stream"
            );
        }
        address[] memory committeesCandidates = registry.getCommitteeCandidates(DEFAULT_STREAM, role);
        assertEq(
            committeesCandidates[committeesCandidates.length - 1], user, "candidate address should match member address"
        );
    }

    function test_registerCandidateToStream_Revert_MemberNotRegistered() external {
        // Arrange
        uint256 privKey = uint256(1);
        address user = vm.addr(privKey);
        uint256 minimumDeposit = registry.getMinimumDeposit(DEFAULT_STREAM);
        vm.deal(user, minimumDeposit);

        // Assert
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.MemberNotRegistered.selector, user));

        // Act
        vm.prank(user);
        registry.registerCandidateToStreamHarness(user, DEFAULT_STREAM, DEFAULT_ROLE, minimumDeposit);
    }

    function test_getMinimumDeposit_Success() external view {
        // Arrange
        uint64[5] memory denominations = [
            uint64(100_000), // 0.001 BTC
            uint64(1_000_000), // 0.01 BTC
            uint64(10_000_000), // 0.1 BTC
            uint64(100_000_000), // 1 BTC
            uint64(1_000_000_000) // 10 BTC
        ];

        for (uint8 i = 0; i <= uint8(StreamDenomination._10BTC); i++) {
            // Act
            uint256 minDeposit = registry.getMinimumDeposit(StreamDenomination(i));

            // Assert
            uint64 denomination = denominations[i];
            assertEq(
                minDeposit,
                BtcHelper.satoshiToWei(denomination) / 10,
                "Error SecurityBond min deposit should be equal to the denomination"
            );
        }
    }
}
