// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {CommitteeRegistry} from "src/CommitteeRegistry.sol";
import {
    ICommitteeRegistry,
    PendingCommitteeStatus,
    PublicKeyRegistration,
    PublicKeyIndex,
    PUBLIC_KEYS_INDEX_LENGTH,
    Role,
    Member,
    CommitteeMember,
    Committee,
    PendingCommittee
} from "src/interfaces/ICommitteeRegistry.sol";
import {StreamDenomination, IStreamManager, Stream} from "src/interfaces/IStreamManager.sol";
import {HelperContract} from "test/helpers/HelperContract.sol";
import {BtcHelper} from "src/libraries/BtcHelper.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Constants} from "src/libraries/Constants.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract TestCommitteeRegistry is Test, HelperContract {
    function setUp() external {
        runTestDeployScript();
    }

    function test_shouldCreateCommittee_AfterInit() external view {
        for (uint64 i = 0; i <= uint64(StreamDenomination._10BTC); i++) {
            assertTrue(
                registry.shouldCreateCommitteeHarness(i), "shouldCreateCommittee should be true after initialization"
            );
        }
    }

    function test_getCommittee_Success() external {
        // Arrange
        (Committee memory expectedCommittee, uint64 streamId) = setup_completeCommittee();

        // Act
        Committee memory committee = registry.getCommittee(COMMITTEE_ID_STREAM_1_PACKET_0);
        // Assert
        assertEqCommittee(expectedCommittee, committee, "Committees are not equal");
        assertFalse(
            registry.shouldCreateCommitteeHarness(streamId),
            "shouldCreateCommittee should be false after setup completeCommittee call"
        );

        for (uint64 i = 0; i <= uint64(StreamDenomination._10BTC); i++) {
            if (i != streamId) {
                assertTrue(
                    registry.shouldCreateCommitteeHarness(i),
                    "shouldCreateCommittee should be true after initialization"
                );
            }
        }
    }

    function test_getCommitteeMembers_Success() external {
        // Arrange
        (Committee memory expectedCommittee,) = setup_completeCommittee();

        // Act
        CommitteeMember[] memory members = registry.getCommitteeMembers(COMMITTEE_ID_STREAM_1_PACKET_0);
        // Assert
        assertEqCommitteeMembers(expectedCommittee.memberIndexesAndRoles, members, "Member list are not equal");
    }

    function test_applyToStream_Revert_TooManyMembers() external {
        // Arrange
        uint256 MAX_MEMBERS_SIZE = registry.MAX_MEMBERS_SIZE();
        uint256 minimumDeposit = registry.getMinimumDeposit(DEFAULT_STREAM);
        for (uint16 i = 0; i < MAX_MEMBERS_SIZE; i++) {
            // Add balance to the user
            address user = vm.addr(i + 1);
            PublicKeyRegistration[] memory pubKeysRegistration = generatePublicKeysRegistration(i + 1);
            vm.deal(user, minimumDeposit);

            vm.prank(user);
            registry.applyToStream{value: minimumDeposit}(DEFAULT_STREAM, DEFAULT_ROLE, pubKeysRegistration);
        }

        // Assert
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.TooManyMembers.selector, MAX_MEMBERS_SIZE));
        // Act
        registry.applyToStream{value: minimumDeposit}(
            DEFAULT_STREAM, DEFAULT_ROLE, generatePublicKeysRegistration(MAX_MEMBERS_SIZE)
        );
    }

    function test_applyToStream_Success_Operator() external {
        _test_applyToStream_Success(Role.Operator);
    }

    function test_applyToStream_Success_Watchtower() external {
        _test_applyToStream_Success(Role.Watchtower);
    }

    function _test_applyToStream_Success(Role _role) internal {
        // This function applies to the DEFAULT_STREAM with `_role` and check that `_oppositeRole` candidates does not change.
        // Arrange
        if (_role == Role.None) {
            revert("Role cannot be None for unsubscribe test");
        }
        Role oppositeRole = _role == Role.Operator ? Role.Watchtower : Role.Operator;

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

        uint16[] memory roleCandidates = registry.getCommitteeCandidates(DEFAULT_STREAM, _role);
        uint16[] memory oppositeRoleCandidates = registry.getCommitteeCandidates(DEFAULT_STREAM, oppositeRole);
        uint256 roleCandidatesAmountAfter = roleCandidates.length;
        uint256 opossiteRoleAmountAfter = oppositeRoleCandidates.length;
        assertEq(roleCandidatesAmountBefore + 1, roleCandidatesAmountAfter, "candidates amount should increase by 1");
        assertEq(opossiteRoleAmountBefore, opossiteRoleAmountAfter, "opposite role candidates amount should not change");

        // Look up candidate in candidates array
        uint256 memberIndex = registry.getMemberIndexByAddress(user);
        assertEq(
            roleCandidates[roleCandidatesAmountAfter - 1], memberIndex, "last candidate index should match member index"
        );

        for (uint256 i = 0; i < roleCandidatesAmountAfter - 1; i++) {
            assertNotEq(
                roleCandidates[i], memberIndex, "candidate index should not match member index until last candidate"
            );
        }

        for (uint256 i = 0; i < opossiteRoleAmountAfter; i++) {
            assertNotEq(
                oppositeRoleCandidates[i], memberIndex, "opposite role candidate index should not match member index"
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
        step_applyToStreamForStream(user1, pubKeysRegistration1, DEFAULT_STREAM, Role.Operator);
        step_applyToStreamForStream(user2, pubKeysRegistration2, DEFAULT_STREAM, Role.Operator);
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
        registry.applyToStream{value: minimumDeposit}(DEFAULT_STREAM, Role.Operator, pubKeysRegistration);

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
        registry.applyToStream{value: minimumDeposit}(DEFAULT_STREAM, Role.Watchtower, differentPubKey);
    }

    function test_applyToStream_Revert_memberAlreadyRegisteredForStream() external {
        // Arrange
        uint256 privKey = uint256(1);
        PublicKeyRegistration[] memory pubKeysRegistration = generatePublicKeysRegistration(privKey);
        address user = vm.addr(privKey);
        uint256 minimumDeposit = registry.getMinimumDeposit(DEFAULT_STREAM);
        vm.deal(user, minimumDeposit);

        vm.prank(user);
        registry.applyToStream{value: minimumDeposit}(DEFAULT_STREAM, Role.Operator, pubKeysRegistration);

        vm.deal(user, minimumDeposit);

        // Assert member already registered for stream
        vm.expectRevert(
            abi.encodeWithSelector(
                ICommitteeRegistry.MemberAlreadyRegisteredForStream.selector,
                user,
                DEFAULT_STREAM,
                Role.Watchtower,
                Role.Operator
            )
        );

        // Act
        vm.prank(user);
        registry.applyToStream{value: minimumDeposit}(DEFAULT_STREAM, Role.Watchtower, pubKeysRegistration);
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
        registry.applyToStream{value: minimumDeposit}(DEFAULT_STREAM, Role.None, pubKeysRegistration);
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
        _test_unsubscribeFromStream_Success(Role.Operator);
    }

    function test_unsubscribeFromStream_Success_Watchtower() external {
        _test_unsubscribeFromStream_Success(Role.Watchtower);
    }

    function test_applyToStream_Revert_InvalidPublicKeysLength() external {
        // Arrange
        uint256 privKey = uint256(1);
        PublicKeyRegistration[] memory incorrectPubKeysRegistration = new PublicKeyRegistration[](1);
        PublicKeyIndex pubKeyIndex = PublicKeyIndex.Take;
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
        _test_applyToStream_Revert_RepeatedPublicKeys(uint8(PublicKeyIndex.Take), uint8(PublicKeyIndex.Covenant));
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
        _test_applyToStream_Revert_RepeatedPublicKeys(uint8(PublicKeyIndex.Take), uint8(PublicKeyIndex.Communication));
    }

    function test_applyToStream_Revert_RepeatedPublicKeys_Covenant_Communication() external {
        _test_applyToStream_Revert_RepeatedPublicKeys(
            uint8(PublicKeyIndex.Covenant), uint8(PublicKeyIndex.Communication)
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
        if (_role == Role.None) {
            revert("Role cannot be None for unsubscribe test");
        }
        Role oppositeRole = _role == Role.Operator ? Role.Watchtower : Role.Operator;

        uint256 privKey = uint256(1);
        PublicKeyRegistration[] memory pubKeysRegistration = generatePublicKeysRegistration(privKey);
        bytes32 pubKey = pubKeysRegistration[uint8(PublicKeyIndex.Take)].publicKeyX;
        address user = vm.addr(privKey);
        uint256 minimumDeposit = registry.getMinimumDeposit(DEFAULT_STREAM);
        vm.deal(user, minimumDeposit);
        vm.prank(user);
        registry.applyToStream{value: minimumDeposit}(DEFAULT_STREAM, _role, pubKeysRegistration);

        uint16[] memory roleCandidates = registry.getCommitteeCandidates(DEFAULT_STREAM, _role);
        uint16[] memory oppositeRoleCandidates = registry.getCommitteeCandidates(DEFAULT_STREAM, oppositeRole);
        uint256 roleCandidatesAmountBefore = roleCandidates.length;
        uint256 oppositeRoleAmountBefore = oppositeRoleCandidates.length;

        // Assert
        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.MemberUnsubscribedFromStream(user, DEFAULT_STREAM);
        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.NewAvailableBalance(pubKey, minimumDeposit, minimumDeposit);

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
            registry.getMemberRequestedRole(user, DEFAULT_STREAM) == Role.None,
            "member requested role should be None after unsuscribe"
        );
        roleCandidates = registry.getCommitteeCandidates(DEFAULT_STREAM, _role);
        oppositeRoleCandidates = registry.getCommitteeCandidates(DEFAULT_STREAM, oppositeRole);
        uint256 roleCandidatesAmountAfter = roleCandidates.length;
        uint256 opossiteRoleAmountAfter = oppositeRoleCandidates.length;
        assertEq(roleCandidatesAmountBefore - 1, roleCandidatesAmountAfter, "candidates amount should decrease by 1");
        assertEq(oppositeRoleAmountBefore, opossiteRoleAmountAfter, "opposite role candidates amount should not change");
        uint256 memberIndex = registry.getMemberIndexByAddress(user);
        for (uint256 i = 0; i < roleCandidatesAmountAfter; i++) {
            assertNotEq(roleCandidates[i], memberIndex, "candidate index should not match member index");
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
        registry.applyToStream{value: minimumDeposit}(StreamDenomination._0_001BTC, Role.Operator, pubKeysRegistration);

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

    function test_unsubscribeFromStream_Revert_nonRegisteredMember() external {
        // Arrange
        uint256 privKey = uint256(1);
        address user = vm.addr(privKey);

        // Assert
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.NonRegisteredMember.selector, user));

        // Act
        vm.prank(user);
        registry.unsubscribeFromStream(DEFAULT_STREAM);
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
        uint16[] memory committeesCandidates = registry.getCommitteeCandidates(stream, requestedRole);
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
            committeesCandidates[committeesCandidates.length - 1],
            registry.getMemberIndexByAddress(user),
            "candidate index should match member index"
        );
        return minimumDeposit;
    }

    function step_unsubscribeFromStream(address user, StreamDenomination stream) internal {
        // Arrange
        Role role = registry.getMemberRequestedRole(user, stream);
        uint256 lastAvailableBalance = registry.getMemberAvailableBalance(user);
        uint256 moneyToBecomeAvailable = registry.getMemberPreStakedBalance(user, stream);
        uint16[] memory committeesCandidates = registry.getCommitteeCandidates(stream, role);
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
        // Assert that requestedRoles[stream] == Role.None
        assertTrue(
            registry.getMemberRequestedRole(user, stream) == Role.None,
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
        Role requestedRole = Role.Operator;

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

    function test_selectCommittee_Success_3OP_7WT() external {
        // Arrange
        StreamDenomination denomination = StreamDenomination._0_01BTC;
        uint64 streamId = 1;
        setup_registerNewMembers(
            registry.MIN_COMMITTEE_MEMBERS() - registry.MIN_OPERATORS(), registry.MIN_OPERATORS(), denomination
        );

        // Act
        (CommitteeMember[] memory selectedMembers, PendingCommitteeStatus status) = registry.selectCommittee(streamId);

        // Assert - Verify status and committee has correct size
        assertTrue(status == PendingCommitteeStatus.Success, "Committee selection should be successful");
        assertEq(selectedMembers.length, registry.MIN_COMMITTEE_MEMBERS(), "Committee should have 10 members");

        // Count roles in selection
        uint256 watchtowerCount = 0;
        uint256 operatorCount = 0;
        for (uint256 i = 0; i < selectedMembers.length; i++) {
            if (selectedMembers[i].role == Role.Watchtower) watchtowerCount++;
            else if (selectedMembers[i].role == Role.Operator) operatorCount++;
        }

        // Verify correct role distribution
        assertEq(
            watchtowerCount,
            registry.MIN_COMMITTEE_MEMBERS() - registry.MIN_OPERATORS(),
            "Committee should have 7 watchtowers"
        );
        assertEq(operatorCount, registry.MIN_OPERATORS(), "Committee should have 7 operators");

        assertUniqueMembers(selectedMembers);
    }

    function assertUniqueMembers(CommitteeMember[] memory selectedMembers) internal pure {
        for (uint256 i = 0; i < selectedMembers.length; i++) {
            for (uint256 j = i + 1; j < selectedMembers.length; j++) {
                assertNotEq(
                    selectedMembers[i].index, selectedMembers[j].index, "There is a repeated member in selected members"
                );
            }
        }
    }

    function test_selectCommittee_Success_7OP_3WT() external {
        // Arrange
        StreamDenomination denomination = StreamDenomination._0_01BTC;
        uint64 streamId = 1;
        setup_registerNewMembers(
            registry.MIN_WATCHTOWERS(), registry.MIN_COMMITTEE_MEMBERS() - registry.MIN_WATCHTOWERS(), denomination
        );

        // Act
        (CommitteeMember[] memory selectedMembers, PendingCommitteeStatus status) = registry.selectCommittee(streamId);

        // Assert - Verify status and committee has correct size
        assertTrue(status == PendingCommitteeStatus.Success, "Committee selection should be successful");
        assertEq(selectedMembers.length, registry.MIN_COMMITTEE_MEMBERS(), "Committee should have 10 members");

        // Count roles in selection
        uint256 watchtowerCount = 0;
        uint256 operatorCount = 0;
        for (uint256 i = 0; i < selectedMembers.length; i++) {
            if (selectedMembers[i].role == Role.Watchtower) watchtowerCount++;
            else if (selectedMembers[i].role == Role.Operator) operatorCount++;
        }

        // Verify correct role distribution
        assertEq(watchtowerCount, registry.MIN_WATCHTOWERS(), "Committee should have 3 watchtowers");
        assertEq(
            operatorCount,
            registry.MIN_COMMITTEE_MEMBERS() - registry.MIN_WATCHTOWERS(),
            "Committee should have 7 operators"
        );

        assertUniqueMembers(selectedMembers);
    }

    function test_selectCommittee_ReturnsDifferentCommittees() external {
        // Arrange
        StreamDenomination denomination = StreamDenomination._0_01BTC;
        uint64 streamId = 1;
        setup_registerNewMembers(registry.MIN_COMMITTEE_MEMBERS(), registry.MIN_COMMITTEE_MEMBERS(), denomination);

        // First selection with timestamp 1
        vm.warp(1);
        (CommitteeMember[] memory selectedMembers1, PendingCommitteeStatus status1) = registry.selectCommittee(streamId);
        assertTrue(status1 == PendingCommitteeStatus.Success, "Committee selection should be successful");
        assertUniqueMembers(selectedMembers1);

        // Second selection with different timestamp
        vm.warp(1000);
        (CommitteeMember[] memory selectedMembers2, PendingCommitteeStatus status2) = registry.selectCommittee(streamId);
        assertTrue(status2 == PendingCommitteeStatus.Success, "Committee selection should be successful");
        assertUniqueMembers(selectedMembers2);

        // Verify both selections have correct size
        assertEq(selectedMembers1.length, registry.MIN_COMMITTEE_MEMBERS(), "First committee should have 10 members");
        assertEq(selectedMembers2.length, registry.MIN_COMMITTEE_MEMBERS(), "Second committee should have 10 members");

        // Verify selections are different (at least one member is in a different position)
        bool isDifferent = false;
        for (uint256 i = 0; i < selectedMembers1.length; i++) {
            if (selectedMembers1[i].index != selectedMembers2[i].index) {
                isDifferent = true;
                break;
            }
        }
        assertTrue(isDifferent, "Selections should be different with different timestamps");
    }

    function test_selectCommittee_Revert_NotEnoughWatchtowers() external {
        // Arrange
        StreamDenomination denomination = StreamDenomination._0_01BTC;
        uint64 streamId = 1;
        setup_registerNewMembers(
            registry.MIN_WATCHTOWERS() - 1,
            registry.MIN_COMMITTEE_MEMBERS() - registry.MIN_WATCHTOWERS() + 1,
            denomination
        );

        // Assert that selectCommittee reverts with MissingWatchtowers event
        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.MissingWatchtowers(denomination, registry.MIN_WATCHTOWERS(), 1);

        // Act
        (CommitteeMember[] memory members, PendingCommitteeStatus status) = registry.selectCommittee(streamId);
        // Assert
        assertTrue(
            status == PendingCommitteeStatus.NotEnoughWatchtowers,
            "Committee selection should fail due to not enough watchtowers"
        );
        assertEq(members.length, 0, "No members should be selected due to not enough members");
        assertTrue(
            registry.shouldCreateCommitteeHarness(streamId),
            "Should be able to create committee after not enough watchtowers"
        );
    }

    function test_selectCommittee_Revert_NotEnoughOperators() external {
        // Arrange
        StreamDenomination denomination = StreamDenomination._0_01BTC;
        uint64 streamId = 1;
        setup_registerNewMembers(
            registry.MIN_COMMITTEE_MEMBERS() - registry.MIN_OPERATORS() + 1, registry.MIN_OPERATORS() - 1, denomination
        );

        // Assert that selectCommittee reverts with MissingOperators event
        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.MissingOperators(denomination, registry.MIN_OPERATORS(), 1);

        // Act
        (CommitteeMember[] memory members, PendingCommitteeStatus status) = registry.selectCommittee(streamId);
        // Assert
        assertTrue(
            status == PendingCommitteeStatus.NotEnoughOperators,
            "Committee selection should fail due to not enough operators"
        );
        assertEq(members.length, 0, "No members should be selected due to not enough members");
        assertTrue(
            registry.shouldCreateCommitteeHarness(streamId),
            "Should be able to create committee after not enough watchtowers"
        );
    }

    function test_selectCommittee_Revert_NotEnoughMembers() external {
        // Arrange
        StreamDenomination denomination = StreamDenomination._0_01BTC;
        uint64 streamId = 1;
        setup_registerNewMembers(registry.MIN_WATCHTOWERS(), registry.MIN_OPERATORS(), denomination);

        // Assert
        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.MissingMembers(
            denomination,
            registry.MIN_COMMITTEE_MEMBERS(),
            registry.MIN_COMMITTEE_MEMBERS() - registry.MIN_OPERATORS() - registry.MIN_WATCHTOWERS()
        );

        // Act
        (CommitteeMember[] memory members, PendingCommitteeStatus status) = registry.selectCommittee(streamId);
        // Assert
        assertTrue(
            status == PendingCommitteeStatus.NotEnoughMembers,
            "Committee selection should fail due to not enough members"
        );
        assertEq(members.length, 0, "No members should be selected due to not enough members");
        assertTrue(
            registry.shouldCreateCommitteeHarness(streamId),
            "Should be able to create committee after not enough watchtowers"
        );
    }

    function test_getMemberTakePubKeyByIndex_Revert_MemberIndexNotFound() external {
        // Assert
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.MemberIndexNotFound.selector, 3));
        // Act
        registry.getMemberTakePubKeyByIndex(3);
    }

    function test_getMemberTakePubKeyByIndex_Success() external {
        // Arrange
        uint256 privKey = uint256(1);
        address userAddress = vm.addr(privKey);
        PublicKeyRegistration[] memory pubKeysRegistration = generatePublicKeysRegistration(privKey);
        bytes32[] memory pubKeys = getXPublicKeysFromRegistration(pubKeysRegistration);
        setup_applyToStream(StreamDenomination._0_001BTC, userAddress, pubKeysRegistration, Role.Operator);
        uint16 memberIndex = registry.getMemberIndexByAddress(userAddress);

        // Act
        bytes32 pubKey = registry.getMemberTakePubKeyByIndex(memberIndex);

        // Assert
        assertEq(
            pubKeys[uint8(PublicKeyIndex.Take)],
            pubKey,
            "Member take public key by index is not the same as the registered one"
        );
    }

    function test_getMemberIndexByAddress_Success() external {
        // Arrange
        address userAddress = vm.addr(1);
        PublicKeyRegistration[] memory pubKeysRegistration = generatePublicKeysRegistration(1);

        setup_applyToStream(StreamDenomination._0_001BTC, userAddress, pubKeysRegistration, Role.Operator);

        // Act
        uint16 memberIndex = registry.getMemberIndexByAddress(userAddress);

        // Assert
        assertEq(memberIndex, 0, "Member index should be 0 for address vm.addr(1)");
    }

    function test_getMemberIndexByAddress_Revert_MemberNotRegistered() external {
        // Arrange
        address memberAddress = vm.addr(registry.MIN_COMMITTEE_MEMBERS() + 1);

        // Assert
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.MemberNotRegistered.selector, memberAddress));

        // Act
        registry.getMemberIndexByAddress(memberAddress);
    }

    function test_getPendingCommittee_Revert_CommitteeIsNotPending() external {
        // Assert
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.CommitteeIsNotPending.selector, 0));
        // Act
        registry.getPendingCommittee(0);
    }

    function test_createCommittee_Success_WithNewMembers() external {
        // This test should register all the members for a committee. This will trigger the creation of a pending committee.
        // We should complete that committee and then, with all the new members registered, we should be able to create a committee.
        // Arrange
        (, Committee memory expectedCommittee, uint64 streamId) = setup_completeCommitteeAndNewMembers();
        expectedCommittee.aggregatedKey = bytes32(0);

        // Assert
        assertFalse(
            registry.shouldCreateCommitteeHarness(streamId),
            "Flag should be false before createCommittee call from pegManager"
        );
        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.NewPendingCommittee(streamId, expectedCommittee);

        // Act
        // This should create a committee as pending
        vm.prank(address(pm));
        registry.createCommittee(streamId);

        (Committee memory committee, uint256 createdAt, uint256 missingData) = registry.getPendingCommittee(streamId);
        // Assert
        assertEqCommittee(expectedCommittee, committee, "Committee should be equeals");
        assertNotEq(createdAt, 0, "Created at should not be 0");
        assertEq(missingData, registry.MIN_COMMITTEE_MEMBERS(), "Missing data should be equal to MIN_COMMITTEE_MEMBERS");
        assertFalse(
            registry.shouldCreateCommitteeHarness(streamId), "Should not create committee after committee created"
        );
        for (uint256 i = 0; i < committee.memberIndexesAndRoles.length; i++) {
            uint64 index = committee.memberIndexesAndRoles[i].index;
            assertTrue(
                index >= registry.MIN_COMMITTEE_MEMBERS() && index < registry.MIN_COMMITTEE_MEMBERS() * 2,
                "Member index should be within the second 10 members"
            );
        }
    }

    function test_createCommittee_Success_SameMembersAfterReApply() external {
        // After first committee is ready all the members apply again to the stream and create a new committee.
        // Arrange
        (, uint64 streamId) = setup_completeCommittee();

        assertEq(0, registry.getCommitteeCandidates(StreamDenomination(streamId), Role.Operator).length);
        assertEq(0, registry.getCommitteeCandidates(StreamDenomination(streamId), Role.Watchtower).length);

        setup_applyToStream_MultipleMembers(
            StreamDenomination(streamId), registry.MIN_COMMITTEE_MEMBERS() / 2, registry.MIN_COMMITTEE_MEMBERS() / 2, 0
        );
        Committee memory expectedCommittee = setup_getExpectedCommitteeBeforeExpire();
        expectedCommittee.aggregatedKey = bytes32(0);

        // Assert
        assertFalse(
            registry.shouldCreateCommitteeHarness(streamId),
            "Flag should be false before createCommittee call from pegManager"
        );
        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.NewPendingCommittee(streamId, expectedCommittee);

        // Act
        // This should create a committee as pending
        vm.prank(address(pm));
        registry.createCommittee(streamId);

        (Committee memory committee, uint256 createdAt, uint256 missingData) = registry.getPendingCommittee(streamId);
        // Assert
        assertEqCommittee(expectedCommittee, committee, "Committee should be equeals");
        assertNotEq(createdAt, 0, "Created at should not be 0");
        assertEq(missingData, registry.MIN_COMMITTEE_MEMBERS(), "Missing data should be equal to MIN_COMMITTEE_MEMBERS");
        assertFalse(
            registry.shouldCreateCommitteeHarness(streamId), "Should not create committee after committee created"
        );
        for (uint256 i = 0; i < committee.memberIndexesAndRoles.length; i++) {
            uint64 index = committee.memberIndexesAndRoles[i].index;
            assertTrue(
                index >= 0 && index < registry.MIN_COMMITTEE_MEMBERS(),
                "Member index should be within the first 10 members"
            );
        }
    }

    function test_createCommittee_Success_AlreadyPendingButNotExpired() external {
        // Arrange
        (, uint64 streamId) = setup_pendingCommittee();
        (Committee memory pendingCommittee, uint256 createdAt, uint256 missingData) =
            registry.getPendingCommittee(streamId);
        vm.recordLogs();

        // Assert
        assertFalse(
            registry.shouldCreateCommitteeHarness(streamId),
            "Flag should be false before createCommittee call from pegManager"
        );

        // createCommittee called by pegManager should do nothing if pending committee is not expired
        // Act
        vm.prank(address(pm));
        registry.createCommittee(streamId);

        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(logs.length, 0, "Expected no events to be emitted");

        (Committee memory pendingCommitteeAfterCall, uint256 createdAtAfterCall, uint256 missingDataAfterCall) =
            registry.getPendingCommittee(streamId);

        assertEq(createdAt, createdAtAfterCall, "Pending committee should not change");
        assertEq(missingData, missingDataAfterCall, "Pending committee should not change");
        assertEq(
            pendingCommittee.aggregatedKey,
            pendingCommitteeAfterCall.aggregatedKey,
            "Pending committee should not change"
        );
        assertEqCommitteeMembers(
            pendingCommittee.memberIndexesAndRoles,
            pendingCommitteeAfterCall.memberIndexesAndRoles,
            "Create committee should not change members"
        );
        assertFalse(
            registry.shouldCreateCommitteeHarness(streamId), "Flag should be false after createCommittee call success"
        );
    }

    function test_getPendingCommittee_Success() external {
        // Arrange
        (Committee memory expectedCommittee, uint64 streamId) = setup_pendingCommittee();

        // Act
        (Committee memory committee, uint256 createdAt, uint256 missingData) = registry.getPendingCommittee(streamId);

        // Assert
        assertEqCommittee(committee, expectedCommittee, "get pending committee");
        assertNotEq(createdAt, 0);
        assertEq(missingData, registry.MIN_COMMITTEE_MEMBERS());
    }

    function test_depositMemberInfoForCommittee_Success() external {
        // Arrange
        (Committee memory expectedCommittee, uint64 streamId) = setup_pendingCommittee();
        expectedCommittee.aggregatedKey = COMMITTEE_PUB_KEY_STREAM_1_PACKET_0;

        // Act
        vm.prank(vm.addr(1));
        registry.depositMemberInfoForCommittee(streamId, COMMITTEE_PUB_KEY_STREAM_1_PACKET_0);

        // Assert
        (Committee memory committee, uint256 createdAt, uint256 missingData) = registry.getPendingCommittee(streamId);
        assertEqCommittee(committee, expectedCommittee, "get pending committee");
        assertNotEq(createdAt, 0);
        assertEq(missingData, registry.MIN_COMMITTEE_MEMBERS() - 1);
    }

    function test_depositMemberInfoForCommittee_Revert_InvalidAgregatedKey() external {
        // Arrange
        (, uint64 streamId) = setup_pendingCommittee();

        // Assert
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.InvalidAgregatedKey.selector));

        // Act
        vm.prank(vm.addr(1));
        registry.depositMemberInfoForCommittee(streamId, bytes32(0));
    }

    function test_depositMemberInfoForCommittee_WrongCommitteeKey() external {
        // Arrange
        (Committee memory expectedCommittee, uint64 streamId) = setup_pendingCommittee();
        setup_depositMemberInfo(streamId, vm.addr(1));
        bytes32 wrongPubKey = 0x1908421cb37d204b0c68660d093534d50d01fa791a3313e5fd9c21da137785ec;

        // Assert
        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.NewPendingCommittee(streamId, expectedCommittee);

        // Act
        // Second member deposit wrong committee aggregated key, so discard current pending committee a create a new one.
        vm.prank(vm.addr(2));
        registry.depositMemberInfoForCommittee(streamId, wrongPubKey);

        // Assert
        (Committee memory committee, uint256 createdAt, uint256 missingData) = registry.getPendingCommittee(streamId);
        assertEqCommittee(committee, expectedCommittee, "get pending committee");
        assertNotEq(createdAt, 0);
        assertEq(missingData, registry.MIN_COMMITTEE_MEMBERS());
    }

    function test_depositMemberInfoForCommittee_Success_CompleteCommittee() external {
        // Arrange
        (Committee memory expectedCommittee, uint64 streamId) = setup_pendingCommittee();
        expectedCommittee.aggregatedKey = COMMITTEE_PUB_KEY_STREAM_1_PACKET_0;
        uint256 memberIndexStart = 0;
        uint256 memberCount = registry.MIN_COMMITTEE_MEMBERS() - 1;
        setup_depositMemberInfo_MultipleMembers(streamId, memberIndexStart, memberCount);

        // Assert
        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.NewCommittee(COMMITTEE_ID_STREAM_1_PACKET_0, expectedCommittee);

        // Act
        // Member address is vm.address(memberIndex + 1);
        vm.prank(vm.addr(registry.MIN_COMMITTEE_MEMBERS()));
        registry.depositMemberInfoForCommittee(streamId, COMMITTEE_PUB_KEY_STREAM_1_PACKET_0);

        assertEq(
            registry.getCommitteeCandidates(StreamDenomination(streamId), Role.Operator).length,
            0,
            "Should not have candidates after committee created"
        );
        assertEq(
            registry.getCommitteeCandidates(StreamDenomination(streamId), Role.Watchtower).length,
            0,
            "Should not have candidates after committee created"
        );
    }

    function test_getPendingCommittee_Revert_CommitteeIsNotPending_AfterCompleteCommittee() external {
        // Arrange
        (, uint64 streamId) = setup_pendingCommittee();
        uint256 memberIndexStart = 0;
        uint256 memberCount = registry.MIN_COMMITTEE_MEMBERS();
        setup_depositMemberInfo_MultipleMembers(streamId, memberIndexStart, memberCount);

        // Assert
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.CommitteeIsNotPending.selector, streamId));
        // Act
        registry.getPendingCommittee(streamId);
    }

    function test_isPendingCommitteeExpired_False_BeforeCreateCommittee() external view {
        // Act
        bool isCommitteePendingExpired = registry.isPendingCommitteeExpired(0);
        // Assert
        // There is no pending committee so it's not expired
        assertFalse(isCommitteePendingExpired, "pending committee is expired");
    }

    function test_isPendingCommitteeExpired_False_AfterCreateCommittee() external {
        // Arrange
        (Committee memory expectedCommittee, uint64 streamId) = setup_pendingCommittee();
        expectedCommittee.aggregatedKey = COMMITTEE_PUB_KEY_STREAM_1_PACKET_0;
        setup_depositMemberInfo(streamId, vm.addr(1));

        // Act
        bool isCommitteePendingExpired = registry.isPendingCommitteeExpired(streamId);

        // Assert
        // There is pending committee and it's not expired
        assertFalse(isCommitteePendingExpired, "pending committee is expired");
    }

    function test_isPendingCommitteeExpired_False_AfterSomeSeconds() external {
        // Arrange
        (Committee memory expectedCommittee, uint64 streamId) = setup_pendingCommittee();
        expectedCommittee.aggregatedKey = COMMITTEE_PUB_KEY_STREAM_1_PACKET_0;
        setup_depositMemberInfo(streamId, vm.addr(1));
        vm.warp(block.timestamp + 60 seconds); // warp time but amount of time is not enough to expire the committee

        // Act
        bool isCommitteePendingExpired = registry.isPendingCommitteeExpired(streamId);

        // Assert
        // There is pending committee and it's not expired
        assertFalse(isCommitteePendingExpired, "pending committee is expired");
    }

    function test_isPendingCommitteeExpired_True_ChangingTimeout() external {
        // Arrange
        (, uint64 streamId) = setup_pendingCommittee();
        vm.warp(block.timestamp + 60 seconds); // warp time to make committee expired

        // Act
        vm.prank(address(registry.owner()));
        registry.setPendingCommitteeTimeout(30 seconds);

        // Assert
        bool isCommitteePendingExpired = registry.isPendingCommitteeExpired(streamId);
        assertTrue(isCommitteePendingExpired, "pending committee is not expired");
    }

    function test_isPendingCommitteeExpired_True_AfterTimeout() external {
        // Arrange
        (, uint64 streamId) = setup_pendingCommittee();
        uint256 timeout = registry.pendingCommitteeTimeout();
        vm.warp(block.timestamp + timeout + 1 seconds); // warp time to make committee expired

        // Act
        bool isCommitteePendingExpired = registry.isPendingCommitteeExpired(streamId);

        // Assert
        // There is pending committee and it's expired
        assertTrue(isCommitteePendingExpired, "pending committee is not expired");
    }

    function test_createCommittee_Success_AfterExpiredCommittee() external {
        // Arrange
        (Committee memory expectedCommittee, uint64 streamId) = setup_pendingCommitteeAndExpire();

        // Assert
        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.NewPendingCommittee(streamId, expectedCommittee);

        // Act
        vm.prank(address(pm));
        registry.createCommittee(streamId);

        // Assert
        (Committee memory committee, uint256 createdAt, uint256 missingData) = registry.getPendingCommittee(streamId);
        assertEqCommittee(committee, expectedCommittee, "get pending committee");
        assertNotEq(createdAt, 0);
        assertEq(missingData, registry.MIN_COMMITTEE_MEMBERS());
    }

    function test_depositMemberInfoForCommittee_Success_CompleteCommitteeOnExpiredCommittee() external {
        // Having an expired committee does not prevent members to still deposit their data
        // Arrange
        (Committee memory expectedCommittee, uint64 streamId) = setup_pendingCommittee();
        uint256 timeout = registry.pendingCommitteeTimeout();
        vm.warp(block.timestamp + timeout + 1 seconds); // warp time to make committee expired
        expectedCommittee.aggregatedKey = COMMITTEE_PUB_KEY_STREAM_1_PACKET_0;
        uint256 memberIndexStart = 0;
        uint256 memberCount = registry.MIN_COMMITTEE_MEMBERS() - 1;
        setup_depositMemberInfo_MultipleMembers(streamId, memberIndexStart, memberCount);

        // Assert
        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.NewCommittee(COMMITTEE_ID_STREAM_1_PACKET_0, expectedCommittee);

        // Act
        // Member address is vm.address(memberIndex + 1);
        vm.prank(vm.addr(registry.MIN_COMMITTEE_MEMBERS()));
        registry.depositMemberInfoForCommittee(streamId, COMMITTEE_PUB_KEY_STREAM_1_PACKET_0);

        // Assert
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.CommitteeIsNotPending.selector, streamId));
        // Act
        registry.getPendingCommittee(streamId);

        assertEq(
            registry.getCommitteeCandidates(StreamDenomination(streamId), Role.Operator).length,
            0,
            "Should not have candidates after committee created"
        );
        assertEq(
            registry.getCommitteeCandidates(StreamDenomination(streamId), Role.Watchtower).length,
            0,
            "Should not have candidates after committee created"
        );
    }

    function test_setPendingCommitteeTimeout_Success() external {
        // Arrange
        uint256 newTimeout = registry.pendingCommitteeTimeout() / 2;

        // Act
        vm.prank(address(registry.owner()));
        registry.setPendingCommitteeTimeout(newTimeout);

        // Assert
        assertEq(registry.pendingCommitteeTimeout(), newTimeout, "Pending committee timeout should be updated");
    }

    function test_setPendingCommitteeTimeout_Revert_OwnableUnauthorizedAccount() external {
        // Arrange
        uint256 newTimeout = registry.pendingCommitteeTimeout() / 2;

        // Assert
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));

        // Act
        registry.setPendingCommitteeTimeout(newTimeout);
    }

    function test_setPendingCommitteeTimeout_Revert_InvalidZeroTimeout() external {
        address owner = registry.owner();

        // Assert
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.InvalidZeroTimeout.selector));

        // Act
        vm.prank(address(owner));
        registry.setPendingCommitteeTimeout(0);
    }

    function test_createCommittee_UnauthorizedAccount() external {
        // Assert
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.UnauthorizedAccount.selector, address(this)));

        // Act
        registry.createCommittee(0);
    }

    function test_getMemberPublicKey_Revert_NonRegisteredMember() external {
        // Arrange
        address user = vm.addr(uint256(100));

        // Assert
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.NonRegisteredMember.selector, user));

        // Act
        registry.getMemberPublicKeys(user);
    }

    function test_getMemberRequestedRole_Revert_NonRegisteredMember() external {
        // Arrange
        address user = vm.addr(uint256(100));

        // Assert
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.NonRegisteredMember.selector, user));

        // Act
        registry.getMemberRequestedRole(user, DEFAULT_STREAM);
    }

    function test_getMemberAvailableBalance_Revert_NonRegisteredMember() external {
        // Arrange
        address user = vm.addr(uint256(100));

        // Assert
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.NonRegisteredMember.selector, user));

        // Act
        registry.getMemberAvailableBalance(user);
    }

    function test_getMemberPreStakedBalance_Revert_NonRegisteredMember() external {
        // Arrange
        address user = vm.addr(uint256(100));

        // Assert
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.NonRegisteredMember.selector, user));

        // Act
        registry.getMemberPreStakedBalance(user, DEFAULT_STREAM);
    }

    function test_getMemberStakedBalance_Revert_NonRegisteredMember() external {
        // Arrange
        address user = vm.addr(uint256(100));

        // Assert
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.NonRegisteredMember.selector, user));

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
        vm.prank(user);
        registry.registerMemberHarness(pubKeysRegistration);

        // Assert
        assertEq(registry.getMemberPublicKeys(user), pubKeys, "member public key should match the registered key");
        assertEq(registry.getMemberIndexByAddress(user), 0, "member index should be 0 after registration");
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
                registry.getMemberRequestedRole(user, StreamDenomination(i)) == Role.None,
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
        Role role = Role.Operator;

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
                    registry.getMemberRequestedRole(user, StreamDenomination(i)) == Role.None,
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
        uint16[] memory committeesCandidates = registry.getCommitteeCandidates(DEFAULT_STREAM, role);
        assertEq(
            committeesCandidates[committeesCandidates.length - 1],
            registry.getMemberIndexByAddress(user),
            "candidate index should match member index"
        );
    }

    function test_registerCandidateToStream_Revert_NonRegisteredMember() external {
        // Arrange
        uint256 privKey = uint256(1);
        address user = vm.addr(privKey);
        uint256 minimumDeposit = registry.getMinimumDeposit(DEFAULT_STREAM);
        vm.deal(user, minimumDeposit);

        // Assert
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.NonRegisteredMember.selector, user));

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

    function test_restartPendingCommittee_Revert_CommitteeIsNotPending() external {
        // Assert
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.CommitteeIsNotPending.selector, 0));

        // Act
        registry.restartPendingCommittee(0);
    }

    function test_restartPendingCommittee_Revert_PendingCommitteeNotExpired() external {
        // Arrange
        (, uint64 streamId) = setup_pendingCommittee();
        setup_depositMemberInfo(streamId, vm.addr(1));

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(ICommitteeRegistry.PendingCommitteeNotExpired.selector, streamId, 1000, 87400)
        );

        // Act
        registry.restartPendingCommittee(streamId);
    }

    function test_restartPendingCommittee_Success() external {
        // Arrange
        (Committee memory expectedCommittee, uint64 streamId) = setup_pendingCommitteeAndExpire();

        // Assert
        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.NewPendingCommittee(streamId, expectedCommittee);

        // Act
        registry.restartPendingCommittee(streamId);

        // Assert
        (Committee memory committee, uint256 createdAt, uint256 missingData) = registry.getPendingCommittee(streamId);
        assertEqCommittee(committee, expectedCommittee, "get pending committee after restart");
        assertNotEq(createdAt, 0);
        assertEq(missingData, registry.MIN_COMMITTEE_MEMBERS(), "missing data should be equal to min committee members");
        assertFalse(
            registry.shouldCreateCommitteeHarness(streamId), "Should not create committee after committee created"
        );
    }

    function test_setup_pendingCommitteeAndExpire() internal {
        // Test helper function to setup a pending committee and then expire it

        // Arrange
        // This function sets up a pending committee and then expires it
        (Committee memory expectedCommittee, uint64 streamId) = setup_pendingCommitteeAndExpire();
        // We ask for current pending committee
        (Committee memory currentPendingCommittee, uint256 createdAt,) = registry.getPendingCommittee(streamId);

        assertEq(
            expectedCommittee.memberIndexesAndRoles.length,
            currentPendingCommittee.memberIndexesAndRoles.length,
            "Pending committee length should match. They are always the MIN_MEMBERS_COMMITTEE"
        );
        for (uint256 i = 0; i < expectedCommittee.memberIndexesAndRoles.length; i++) {
            assertNotEq(
                expectedCommittee.memberIndexesAndRoles[i].index,
                currentPendingCommittee.memberIndexesAndRoles[i].index,
                "Pending committee member should not match"
            );
        }
        assertFalse(
            registry.shouldCreateCommitteeHarness(streamId),
            "Flag shouldCreateCommittee should be false before it's called by PegManager"
        );

        // Act
        vm.prank(address(pm));
        registry.createCommitteeHarness(streamId);

        (Committee memory pendingCommitteeAfterCall, uint256 createdAtAfterCall, uint256 missingDataAfterCall) =
            registry.getPendingCommittee(streamId);
        assertNotEq(createdAt, createdAtAfterCall, "Pending committee should change");
        assertEq(0, missingDataAfterCall, "Missing data should be 0 after committee creation");
        assertEq(
            bytes32(0),
            pendingCommitteeAfterCall.aggregatedKey,
            "Pending committee aggregated key should be empty after committee creation"
        );
        assertEqCommittee(
            expectedCommittee,
            pendingCommitteeAfterCall,
            "New pending committee should match that one returned by setup_pendingCommitteeAndExpire"
        );
        assertFalse(
            registry.shouldCreateCommitteeHarness(streamId), "Should not create committee after committee created"
        );
    }

    function test_createCommitteeAfterApplyToStream_Success_NotExpiredPendingCommittee() external {
        // Arrange
        (Committee memory expectedCommittee, uint64 streamId) = setup_pendingCommittee();
        StreamDenomination denomination = StreamDenomination(streamId);
        (, uint256 createdAt, uint256 missingData) = registry.getPendingCommittee(streamId);
        vm.recordLogs();

        // createCommitteeAfterApplyToStream called should do nothing if pending committee is not expired
        // Act
        registry.createCommitteeAfterApplyToStreamHarness(denomination);

        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(logs.length, 0, "Expected no events to be emitted");

        (Committee memory pendingCommitteeAfterCall, uint256 createdAtAfterCall, uint256 missingDataAfterCall) =
            registry.getPendingCommittee(streamId);
        assertEq(createdAtAfterCall, createdAt, "Pending committee should not change");
        assertEq(missingDataAfterCall, missingData, "Pending committee should not change");
        assertEq(
            pendingCommitteeAfterCall.aggregatedKey,
            expectedCommittee.aggregatedKey,
            "Pending committee should not change"
        );
        assertEqCommitteeMembers(
            pendingCommitteeAfterCall.memberIndexesAndRoles,
            expectedCommittee.memberIndexesAndRoles,
            "Create committee should not change members"
        );
    }

    function test_createCommitteeAfterApplyToStream_Success_ExpiredPendingCommittee() external {
        // Arrange
        (Committee memory expectedCommittee, uint64 streamId) = setup_pendingCommitteeAndExpire();
        StreamDenomination denomination = StreamDenomination(streamId);
        (, uint256 createdAt,) = registry.getPendingCommittee(streamId);

        // Assert
        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.NewPendingCommittee(streamId, expectedCommittee);

        // createCommitteeAfterApplyToStream called should create a new pending committee if the previous one is expired
        // Act
        registry.createCommitteeAfterApplyToStreamHarness(denomination);

        (Committee memory pendingCommitteeAfterCall, uint256 createdAtAfterCall, uint256 missingDataAfterCall) =
            registry.getPendingCommittee(streamId);
        assertEq(
            missingDataAfterCall, expectedCommittee.memberIndexesAndRoles.length, "Pending committee should not change"
        );
        assertNotEq(createdAt, createdAtAfterCall, "Pending committee should change");
        assertEq(
            pendingCommitteeAfterCall.aggregatedKey,
            expectedCommittee.aggregatedKey,
            "Pending committee should not change"
        );
        assertEqCommitteeMembers(
            pendingCommitteeAfterCall.memberIndexesAndRoles,
            expectedCommittee.memberIndexesAndRoles,
            "Create committee should not change members"
        );
    }

    function test_createCommitteeAfterApplyToStream_Success_NoCommitteeForCurrentPacket() external {
        // In this case we want to test the case where we run out of slots from current packet without being ables to create a new pending committee.
        // This is a edge case where we had the minimum of members to create first packet but one of the members decided to unsubscribe from the stream for next packet
        // So pending committee wont be created in each of the last pegins of current packet. Resulting in no pending committee for next packet.
        // applyToStream call internally to `createCommitteeAfterApplyToStream`

        // ===== Arrange start =====
        // Create a complete committee for initial packet
        (,, uint64 streamId) = setup_completeCommitteeAndNewMembers();
        StreamDenomination denomination = StreamDenomination(streamId);
        // Need to use last member in the committee to unsubscribe and subscribe to keep same random committee member order
        uint256 userIndex = registry.MIN_COMMITTEE_MEMBERS() * 2 - 1;
        Role userRole = Role.Operator;
        address userAddress = vm.addr(userIndex + 1);
        PublicKeyRegistration[] memory pubKeysRegistration = generatePublicKeysRegistration(userIndex + 1);

        // Unsubscribe one of the members
        vm.prank(userAddress);
        registry.unsubscribeFromStream(denomination);

        // Use all the slots in the packet
        setup_multipleRequestAndAcceptPeginFlows(Constants.SLOTS_PER_PACKET, streamId);

        Stream memory stream = streamManager.getStreamById(streamId);
        assertEq(stream.peginPacketPointer, 1, "Stream pegin packet pointer should be 1 after filling all slots");

        // Check that current packet does not have a committee
        uint256 currentPacketCommitteeId = streamManager.getCurrentPacketCommitteeId(streamId);
        assertEq(currentPacketCommitteeId, 0, "Current packet committee ID should be 0 when no committee exists");

        // Check there is no pending committee
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.CommitteeIsNotPending.selector, streamId));
        registry.getPendingCommittee(streamId);

        uint256 minimumDeposit = registry.getMinimumDeposit(denomination);
        vm.deal(userAddress, minimumDeposit);
        Committee memory expectedCommittee = setup_getExpectedSecondCommittee();
        vm.warp(BLOCK_TIMESTAMP_FOR_DETERMINISTIC_COMMITTEE);
        assertTrue(
            registry.shouldCreateCommitteeHarness(streamId),
            "Flag should be true because there is no pending committee and need one to new packet"
        );
        // ===== Arrange end =====

        // Assert
        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.NewPendingCommittee(streamId, expectedCommittee);

        // Act
        vm.prank(userAddress);
        registry.applyToStream{value: minimumDeposit}(denomination, userRole, pubKeysRegistration);

        // Assert
        (Committee memory pendingCommittee, uint256 createdAt, uint256 missingData) =
            registry.getPendingCommittee(streamId);
        assertEqCommittee(pendingCommittee, expectedCommittee, "get pending committee after apply to stream");
        assertNotEq(createdAt, 0, "Created at should not be 0 after apply to stream");
        assertEq(missingData, registry.MIN_COMMITTEE_MEMBERS(), "Missing data should be equal to min committee members");
        assertFalse(registry.shouldCreateCommitteeHarness(streamId), "Flag should be false before createCommittee call");
    }
}
