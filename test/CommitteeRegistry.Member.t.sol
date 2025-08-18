// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {
    ICommitteeRegistry,
    Role,
    Committee,
    MemberRegistrationKeys,
    PublicKeyType,
    MemberKeys,
    RSAPublicKey,
    UTXO
} from "src/interfaces/ICommitteeRegistry.sol";
import {StreamDenomination} from "src/interfaces/IStreamManager.sol";
import {IPegManager} from "src/interfaces/IPegManager.sol";
import {HelperContract} from "test/helpers/HelperContract.sol";
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
        MemberRegistrationKeys memory memberRegistrationKeys = generateRegistrationPublicKeys(privKey);
        MemberKeys memory pubKeys = getXPublicKeysFromRegistration(memberRegistrationKeys);
        address user = vm.addr(privKey);
        uint256 minimumDeposit = streamManager.getMinimumDeposit(DEFAULT_STREAM, _role);
        vm.deal(user, minimumDeposit);

        uint256 roleCandidatesAmountBefore = registry.getCommitteeCandidates(DEFAULT_STREAM, _role).length;
        uint256 opossiteRoleAmountBefore = registry.getCommitteeCandidates(DEFAULT_STREAM, oppositeRole).length;

        // Check balances before
        uint256 userBalanceBefore = user.balance;
        uint256 contractBalanceBefore = address(registry).balance;

        // Assert member registered
        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.NewMember(user, pubKeys);

        // Assert assert deposited bond
        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.NewSecurityBondDeposit(user, DEFAULT_STREAM, _role, minimumDeposit);

        // Act
        vm.prank(user);
        registry.applyToStream{value: minimumDeposit}(
            DEFAULT_STREAM, _role, memberRegistrationKeys, generateDefaultUTXO()
        );

        // Assert
        MemberKeys memory actualKeys = registry.getMemberPublicKeys(user);
        assertEq(actualKeys.takePubKey, pubKeys.takePubKey, "take public key should match");
        assertEq(actualKeys.covenantPubKey, pubKeys.covenantPubKey, "covenant public key should match");
        assertEq(
            keccak256(abi.encode(actualKeys.communicationPubKey)),
            keccak256(abi.encode(pubKeys.communicationPubKey)),
            "communication public key should match"
        );
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

        // Assert funding UTXO storage for all streams
        {
            UTXO memory defaultUTXO = generateDefaultUTXO();
            UTXO memory emptyUTXO = UTXO({txid: bytes32(0), outputIndex: 0, amount: 0});

            // Check all stream denominations
            for (uint8 i = 0; i <= uint8(StreamDenomination._10BTC); i++) {
                StreamDenomination currentStream = StreamDenomination(i);
                UTXO memory expectedUTXO = (currentStream == DEFAULT_STREAM) ? defaultUTXO : emptyUTXO;
                UTXO memory storedUTXO = registry.getMemberFundingUTXO(uint64(currentStream), user);

                assertEq(storedUTXO.txid, expectedUTXO.txid, "funding UTXO txid should match expectation");
                assertEq(
                    storedUTXO.outputIndex,
                    expectedUTXO.outputIndex,
                    "funding UTXO outputIndex should match expectation"
                );
                assertEq(storedUTXO.amount, expectedUTXO.amount, "funding UTXO amount should match expectation");
            }
        }

        vm.prank(user);
        assertTrue(registry.getReApplyForStream(DEFAULT_STREAM), "reApply should be true by default");

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
        MemberRegistrationKeys memory pubKeysRegistration1 = generateRegistrationPublicKeys(privKey1);
        address user1 = vm.addr(privKey1);
        uint256 privKey2 = uint256(2);
        MemberRegistrationKeys memory pubKeysRegistration2 = generateRegistrationPublicKeys(privKey2);
        address user2 = vm.addr(privKey2);
        setup_applyToStream(user1, pubKeysRegistration1, DEFAULT_STREAM, Role.OPERATOR);
        setup_applyToStream(user2, pubKeysRegistration2, DEFAULT_STREAM, Role.OPERATOR);
    }

    function test_applyToStream_Revert_PublicKeyMismatch_TAKE() external {
        // Arrange
        uint256 privKey = uint256(1);
        MemberRegistrationKeys memory memberRegistrationKeys = generateRegistrationPublicKeys(privKey);
        MemberRegistrationKeys memory differentPubKey = generateRegistrationPublicKeys(privKey + 1);
        address user = vm.addr(privKey);
        Role role = Role.OPERATOR;
        uint256 minimumDeposit = streamManager.getMinimumDeposit(DEFAULT_STREAM, role);
        vm.deal(user, minimumDeposit);

        vm.prank(user);
        registry.applyToStream{value: minimumDeposit}(
            DEFAULT_STREAM, role, memberRegistrationKeys, generateDefaultUTXO()
        );

        vm.deal(user, minimumDeposit);

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                ICommitteeRegistry.PublicKeyMismatch.selector,
                PublicKeyType.TAKE,
                memberRegistrationKeys.takeKey.publicKeyX,
                differentPubKey.takeKey.publicKeyX
            )
        );

        // Act
        vm.prank(user);
        registry.applyToStream{value: minimumDeposit}(
            DEFAULT_STREAM, Role.WATCHTOWER, differentPubKey, generateDefaultUTXO()
        );
    }

    function test_applyToStream_Revert_PublicKeyMismatch_COVENANT() external {
        // Arrange
        uint256 privKey = uint256(1);
        MemberRegistrationKeys memory memberRegistrationKeys = generateRegistrationPublicKeys(privKey);

        // Create fresh keys for second registration with different COVENANT key only
        MemberRegistrationKeys memory differentPubKey;
        differentPubKey.takeKey = memberRegistrationKeys.takeKey; // Same TAKE key
        differentPubKey.covenantKey = generateECDSAPublicKey(privKey + 1, PublicKeyType.COVENANT); // Different COVENANT key
        differentPubKey.communicationKey = memberRegistrationKeys.communicationKey; // Same COMMUNICATION key

        address user = vm.addr(privKey);
        Role role = Role.OPERATOR;
        uint256 minimumDeposit = streamManager.getMinimumDeposit(DEFAULT_STREAM, role);
        vm.deal(user, minimumDeposit);

        vm.prank(user);
        registry.applyToStream{value: minimumDeposit}(
            DEFAULT_STREAM, role, memberRegistrationKeys, generateDefaultUTXO()
        );

        vm.deal(user, minimumDeposit);

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                ICommitteeRegistry.PublicKeyMismatch.selector,
                PublicKeyType.COVENANT,
                memberRegistrationKeys.covenantKey.publicKeyX,
                differentPubKey.covenantKey.publicKeyX
            )
        );

        // Act - use different stream to avoid "already registered" error
        vm.prank(user);
        registry.applyToStream{value: minimumDeposit}(
            StreamDenomination._0_01BTC, Role.WATCHTOWER, differentPubKey, generateDefaultUTXO()
        );
    }

    function test_applyToStream_Revert_PublicKeyMismatch_COMMUNICATION() external {
        // Arrange
        uint256 privKey = uint256(1);
        MemberRegistrationKeys memory memberRegistrationKeys = generateRegistrationPublicKeys(privKey);

        // Create fresh keys for second registration with different COMMUNICATION key only
        MemberRegistrationKeys memory differentPubKey;
        differentPubKey.takeKey = memberRegistrationKeys.takeKey; // Same TAKE key
        differentPubKey.covenantKey = memberRegistrationKeys.covenantKey; // Same COVENANT key
        differentPubKey.communicationKey = generateRSAPublicKey(privKey + 1, PublicKeyType.COMMUNICATION); // Different COMMUNICATION key

        address user = vm.addr(privKey);
        Role role = Role.OPERATOR;
        uint256 minimumDeposit = streamManager.getMinimumDeposit(DEFAULT_STREAM, role);
        vm.deal(user, minimumDeposit);

        vm.prank(user);
        registry.applyToStream{value: minimumDeposit}(
            DEFAULT_STREAM, role, memberRegistrationKeys, generateDefaultUTXO()
        );

        vm.deal(user, minimumDeposit);

        // Create expected hash values for the error
        bytes32 storedComKeyHash = keccak256(abi.encode(memberRegistrationKeys.communicationKey.rsaPublicKey));
        bytes32 newComKeyHash = keccak256(abi.encode(differentPubKey.communicationKey.rsaPublicKey));

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                ICommitteeRegistry.PublicKeyMismatch.selector,
                PublicKeyType.COMMUNICATION,
                storedComKeyHash,
                newComKeyHash
            )
        );

        // Act - use different stream to avoid "already registered" error
        vm.prank(user);
        registry.applyToStream{value: minimumDeposit}(
            StreamDenomination._0_01BTC, Role.WATCHTOWER, differentPubKey, generateDefaultUTXO()
        );
    }

    function test_applyToStream_Revert_memberAlreadyRegisteredForStream() external {
        // Arrange
        uint256 privKey = uint256(1);
        MemberRegistrationKeys memory memberRegistrationKeys = generateRegistrationPublicKeys(privKey);
        address user = vm.addr(privKey);
        Role role = Role.OPERATOR;
        uint256 minimumDeposit = streamManager.getMinimumDeposit(DEFAULT_STREAM, role);
        vm.deal(user, minimumDeposit);

        vm.prank(user);
        registry.applyToStream{value: minimumDeposit}(
            DEFAULT_STREAM, role, memberRegistrationKeys, generateDefaultUTXO()
        );

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
        registry.applyToStream{value: minimumDeposit}(
            DEFAULT_STREAM, Role.WATCHTOWER, memberRegistrationKeys, generateDefaultUTXO()
        );
    }

    function test_applyToStream_Revert_requestedNoneRoleForStream() external {
        // Arrange
        uint256 privKey = uint256(1);
        MemberRegistrationKeys memory memberRegistrationKeys = generateRegistrationPublicKeys(privKey);
        address user = vm.addr(privKey);
        uint256 minimumDeposit = streamManager.getMinimumDeposit(DEFAULT_STREAM, Role.OPERATOR);
        vm.deal(user, minimumDeposit);

        // Assert requested none role for stream
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.RequestedNoneRoleForStream.selector, DEFAULT_STREAM));

        // Act
        vm.prank(user);
        registry.applyToStream{value: minimumDeposit}(
            DEFAULT_STREAM, Role.NONE, memberRegistrationKeys, generateDefaultUTXO()
        );
    }

    function test_applyToStream_Revert_despositBondTooLow() external {
        // Arrange
        uint256 privKey = uint256(1);
        MemberRegistrationKeys memory memberRegistrationKeys = generateRegistrationPublicKeys(privKey);
        address user = vm.addr(privKey);
        uint256 minimumDeposit = streamManager.getMinimumDeposit(DEFAULT_STREAM, DEFAULT_ROLE);
        vm.deal(user, minimumDeposit - 1);

        // Assert deposit bond too low
        vm.expectRevert(
            abi.encodeWithSelector(ICommitteeRegistry.DespositBondTooLow.selector, minimumDeposit - 1, minimumDeposit)
        );

        // Act
        vm.prank(user);
        registry.applyToStream{value: minimumDeposit - 1}(
            DEFAULT_STREAM, DEFAULT_ROLE, memberRegistrationKeys, generateDefaultUTXO()
        );
    }

    function test_applyToStream_Revert_ZeroUTXOTxid() external {
        // Arrange
        uint256 privKey = uint256(1);
        MemberRegistrationKeys memory memberRegistrationKeys = generateRegistrationPublicKeys(privKey);
        address user = vm.addr(privKey);
        uint256 minimumDeposit = streamManager.getMinimumDeposit(DEFAULT_STREAM, DEFAULT_ROLE);
        vm.deal(user, minimumDeposit);

        // Create UTXO with zero txid
        UTXO memory invalidUTXO = UTXO({txid: bytes32(0), outputIndex: 0, amount: 50000});

        // Assert zero UTXO txid error
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.ZeroUTXOTxid.selector, invalidUTXO));

        // Act
        vm.prank(user);
        registry.applyToStream{value: minimumDeposit}(DEFAULT_STREAM, DEFAULT_ROLE, memberRegistrationKeys, invalidUTXO);
    }

    function test_applyToStream_Revert_ZeroUTXOAmount() external {
        // Arrange
        uint256 privKey = uint256(1);
        MemberRegistrationKeys memory memberRegistrationKeys = generateRegistrationPublicKeys(privKey);
        address user = vm.addr(privKey);
        uint256 minimumDeposit = streamManager.getMinimumDeposit(DEFAULT_STREAM, DEFAULT_ROLE);
        vm.deal(user, minimumDeposit);

        // Create UTXO with zero amount
        UTXO memory invalidUTXO =
            UTXO({txid: 0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef, outputIndex: 0, amount: 0});

        // Assert zero UTXO amount error
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.ZeroUTXOAmount.selector, invalidUTXO));

        // Act
        vm.prank(user);
        registry.applyToStream{value: minimumDeposit}(DEFAULT_STREAM, DEFAULT_ROLE, memberRegistrationKeys, invalidUTXO);
    }

    function test_unsubscribeFromStream_Success_Operator() external {
        _test_unsubscribeFromStream_Success(Role.OPERATOR);
    }

    function test_unsubscribeFromStream_Success_Watchtower() external {
        _test_unsubscribeFromStream_Success(Role.WATCHTOWER);
    }

    function test_applyToStream_Revert_InvalidZeroEDCSAPublicKey_X_TAKE() external {
        // Arrange
        uint256 privKey = uint256(1);
        address user = vm.addr(privKey);
        uint256 minimumDeposit = streamManager.getMinimumDeposit(DEFAULT_STREAM, DEFAULT_ROLE);
        vm.deal(user, minimumDeposit);
        MemberRegistrationKeys memory memberRegistrationKeys = generateRegistrationPublicKeys(privKey);

        // Set the public key to 0
        memberRegistrationKeys.takeKey.publicKeyX = bytes32(0);

        // Assert invalid public key X
        vm.expectRevert(
            abi.encodeWithSelector(
                ICommitteeRegistry.InvalidZeroEDCSAPublicKey.selector,
                PublicKeyType.TAKE,
                memberRegistrationKeys.takeKey.publicKeyX,
                memberRegistrationKeys.takeKey.publicKeyY
            )
        );
        // Act
        vm.prank(user);
        registry.applyToStream{value: minimumDeposit}(
            DEFAULT_STREAM, DEFAULT_ROLE, memberRegistrationKeys, generateDefaultUTXO()
        );
    }

    function test_applyToStream_Revert_InvalidZeroEDCSAPublicKey_Y_TAKE() external {
        // Arrange
        uint256 privKey = uint256(1);
        address user = vm.addr(privKey);
        uint256 minimumDeposit = streamManager.getMinimumDeposit(DEFAULT_STREAM, DEFAULT_ROLE);
        vm.deal(user, minimumDeposit);
        MemberRegistrationKeys memory memberRegistrationKeys = generateRegistrationPublicKeys(privKey);

        // Set the public key to 0
        memberRegistrationKeys.takeKey.publicKeyY = bytes32(0);

        // Assert invalid public key Y
        vm.expectRevert(
            abi.encodeWithSelector(
                ICommitteeRegistry.InvalidZeroEDCSAPublicKey.selector,
                PublicKeyType.TAKE,
                memberRegistrationKeys.takeKey.publicKeyX,
                memberRegistrationKeys.takeKey.publicKeyY
            )
        );
        // Act
        vm.prank(user);
        registry.applyToStream{value: minimumDeposit}(
            DEFAULT_STREAM, DEFAULT_ROLE, memberRegistrationKeys, generateDefaultUTXO()
        );
    }

    function test_applyToStream_Revert_InvalidZeroEDCSASignature_V_TAKE() external {
        // Arrange
        uint256 privKey = uint256(1);
        address user = vm.addr(privKey);
        uint256 minimumDeposit = streamManager.getMinimumDeposit(DEFAULT_STREAM, DEFAULT_ROLE);
        vm.deal(user, minimumDeposit);
        MemberRegistrationKeys memory memberRegistrationKeys = generateRegistrationPublicKeys(privKey);

        // Set the signature V to 0
        memberRegistrationKeys.takeKey.v = 0;

        // Assert invalid zero signature
        vm.expectRevert(
            abi.encodeWithSelector(
                ICommitteeRegistry.InvalidZeroEDCSASignature.selector,
                PublicKeyType.TAKE,
                memberRegistrationKeys.takeKey
            )
        );
        // Act
        vm.prank(user);
        registry.applyToStream{value: minimumDeposit}(
            DEFAULT_STREAM, DEFAULT_ROLE, memberRegistrationKeys, generateDefaultUTXO()
        );
    }

    function test_applyToStream_Revert_InvalidZeroEDCSASignature_R_TAKE() external {
        // Arrange
        uint256 privKey = uint256(1);
        address user = vm.addr(privKey);
        uint256 minimumDeposit = streamManager.getMinimumDeposit(DEFAULT_STREAM, DEFAULT_ROLE);
        vm.deal(user, minimumDeposit);
        MemberRegistrationKeys memory memberRegistrationKeys = generateRegistrationPublicKeys(privKey);

        // Set the signature R to 0
        memberRegistrationKeys.takeKey.r = bytes32(0);

        // Assert invalid zero signature
        vm.expectRevert(
            abi.encodeWithSelector(
                ICommitteeRegistry.InvalidZeroEDCSASignature.selector,
                PublicKeyType.TAKE,
                memberRegistrationKeys.takeKey
            )
        );
        // Act
        vm.prank(user);
        registry.applyToStream{value: minimumDeposit}(
            DEFAULT_STREAM, DEFAULT_ROLE, memberRegistrationKeys, generateDefaultUTXO()
        );
    }

    function test_applyToStream_Revert_InvalidZeroEDCSASignature_S_TAKE() external {
        // Arrange
        uint256 privKey = uint256(1);
        address user = vm.addr(privKey);
        uint256 minimumDeposit = streamManager.getMinimumDeposit(DEFAULT_STREAM, DEFAULT_ROLE);
        vm.deal(user, minimumDeposit);
        MemberRegistrationKeys memory memberRegistrationKeys = generateRegistrationPublicKeys(privKey);

        // Set the signature S to 0
        memberRegistrationKeys.takeKey.s = bytes32(0);

        // Assert invalid zero signature
        vm.expectRevert(
            abi.encodeWithSelector(
                ICommitteeRegistry.InvalidZeroEDCSASignature.selector,
                PublicKeyType.TAKE,
                memberRegistrationKeys.takeKey
            )
        );
        // Act
        vm.prank(user);
        registry.applyToStream{value: minimumDeposit}(
            DEFAULT_STREAM, DEFAULT_ROLE, memberRegistrationKeys, generateDefaultUTXO()
        );
    }

    function test_applyToStream_Revert_InvalidZeroRSAPublicKey_COMMUNICATION() external {
        // Arrange
        uint256 privKey = uint256(1);
        address user = vm.addr(privKey);
        uint256 minimumDeposit = streamManager.getMinimumDeposit(DEFAULT_STREAM, DEFAULT_ROLE);
        vm.deal(user, minimumDeposit);
        MemberRegistrationKeys memory memberRegistrationKeys = generateRegistrationPublicKeys(privKey);

        // Set RSA public key to empty (initialized to all zeros)
        RSAPublicKey memory emptyRSAKey;
        memberRegistrationKeys.communicationKey = emptyRSAKey;

        // Assert invalid zero RSA public key
        vm.expectRevert(
            abi.encodeWithSelector(ICommitteeRegistry.InvalidZeroRSAPublicKey.selector, PublicKeyType.COMMUNICATION)
        );
        // Act
        vm.prank(user);
        registry.applyToStream{value: minimumDeposit}(
            DEFAULT_STREAM, DEFAULT_ROLE, memberRegistrationKeys, generateDefaultUTXO()
        );
    }

    function test_applyToStream_Revert_ECDSAInvalidSignature_V_TAKE() external {
        // Arrange
        uint256 privKey = uint256(1);
        address user = vm.addr(privKey);
        uint256 minimumDeposit = streamManager.getMinimumDeposit(DEFAULT_STREAM, DEFAULT_ROLE);
        vm.deal(user, minimumDeposit);
        MemberRegistrationKeys memory incorrectPubKeysRegistration = generateRegistrationPublicKeys(privKey);

        // V can only be 27 or 28, so we set it to 29 to trigger the error
        incorrectPubKeysRegistration.takeKey.v = 29;

        // Assert invalid signature
        vm.expectRevert(abi.encodeWithSelector(ECDSA.ECDSAInvalidSignature.selector));
        // Act
        vm.prank(user);
        registry.applyToStream{value: minimumDeposit}(
            DEFAULT_STREAM, DEFAULT_ROLE, incorrectPubKeysRegistration, generateDefaultUTXO()
        );
    }

    function test_applyToStream_Revert_ECDSAInvalidSignature_S_TAKE() external {
        // Arrange
        uint256 privKey = uint256(1);
        address user = vm.addr(privKey);
        uint256 minimumDeposit = streamManager.getMinimumDeposit(DEFAULT_STREAM, DEFAULT_ROLE);
        vm.deal(user, minimumDeposit);
        MemberRegistrationKeys memory incorrectPubKeysRegistration = generateRegistrationPublicKeys(privKey);

        incorrectPubKeysRegistration.takeKey.s = keccak256(abi.encodePacked(incorrectPubKeysRegistration.takeKey.s));

        // Assert invalid signature
        vm.expectRevert(
            abi.encodeWithSelector(ECDSA.ECDSAInvalidSignatureS.selector, incorrectPubKeysRegistration.takeKey.s)
        );
        // Act
        vm.prank(user);
        registry.applyToStream{value: minimumDeposit}(
            DEFAULT_STREAM, DEFAULT_ROLE, incorrectPubKeysRegistration, generateDefaultUTXO()
        );
    }

    // TODO: Fix this test after RSA key migration - the array indexing approach no longer works
    function test_applyToStream_Revert_InvalidEDCSASignature() external {
        // Arrange
        uint256 privKey = uint256(1);
        address user = vm.addr(privKey);
        uint256 minimumDeposit = streamManager.getMinimumDeposit(DEFAULT_STREAM, DEFAULT_ROLE);
        vm.deal(user, minimumDeposit);
        MemberRegistrationKeys memory memberRegistrationKeys = generateRegistrationPublicKeys(privKey);

        // Set incorrect signature
        memberRegistrationKeys.takeKey.v = memberRegistrationKeys.takeKey.v == 27 ? 28 : 27;

        // Assert invalid signature
        vm.expectRevert(
            abi.encodeWithSelector(
                ICommitteeRegistry.InvalidEDCSASignature.selector,
                PublicKeyType.TAKE,
                memberRegistrationKeys.takeKey,
                0x7Fe3bB705a7B50b5fbcB0055B89707eeb762aF27,
                0x00d83E13A62e8E9F183fDbAa8642EF69192F644E
            )
        );
        // Act
        vm.prank(user);
        registry.applyToStream{value: minimumDeposit}(
            DEFAULT_STREAM, DEFAULT_ROLE, memberRegistrationKeys, generateDefaultUTXO()
        );
    }

    function test_applyToStream_GasConsumptionCheck() external {
        // Results:
        // Constants.MAX_CANDIDATES_SIZE_PER_ROLE = 256: 406933 gas
        // Constants.MAX_CANDIDATES_SIZE_PER_ROLE = 250: 406933 gas

        // Arrange
        Role role = Role.OPERATOR;
        uint256 privKey = uint256(1);
        address user = vm.addr(privKey);
        MemberRegistrationKeys memory memberRegistrationKeys = generateRegistrationPublicKeys(privKey);
        uint256 minimumDeposit = streamManager.getMinimumDeposit(DEFAULT_STREAM, role);
        vm.deal(user, minimumDeposit);

        uint256 gasStart = gasleft();

        // Act
        vm.prank(user);
        registry.applyToStream{value: minimumDeposit}(
            DEFAULT_STREAM, role, memberRegistrationKeys, generateDefaultUTXO()
        );
        uint256 gasUsed = gasStart - gasleft();
        assertLe(gasUsed, 700_000, "gas used should be less than 700_000");
    }

    function _test_unsubscribeFromStream_Success(Role _role) internal {
        // This function unsubscribes a user from DEFAULT_STREAM with `_role` and tests that `oppositeRole` candidates do not change.
        // Arrange
        if (_role == Role.NONE) {
            revert("Role cannot be None for unsubscribe test");
        }
        Role oppositeRole = _role == Role.OPERATOR ? Role.WATCHTOWER : Role.OPERATOR;

        uint256 privKey = uint256(1);
        MemberRegistrationKeys memory memberRegistrationKeys = generateRegistrationPublicKeys(privKey);
        address user = vm.addr(privKey);
        uint256 minimumDeposit = streamManager.getMinimumDeposit(DEFAULT_STREAM, _role);
        vm.deal(user, minimumDeposit);
        vm.prank(user);
        registry.applyToStream{value: minimumDeposit}(
            DEFAULT_STREAM, _role, memberRegistrationKeys, generateDefaultUTXO()
        );

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
        MemberRegistrationKeys memory memberRegistrationKeys = generateRegistrationPublicKeys(privKey);
        address user = vm.addr(privKey);
        Role role = Role.OPERATOR;
        uint256 minimumDeposit = streamManager.getMinimumDeposit(StreamDenomination._0_001BTC, role);
        vm.deal(user, minimumDeposit);
        vm.prank(user);
        registry.applyToStream{value: minimumDeposit}(
            StreamDenomination._0_001BTC, role, memberRegistrationKeys, generateDefaultUTXO()
        );

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
        (Committee memory expectedCommittee,) = setup_pendingCommittee();
        address user = vm.addr(1);

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                ICommitteeRegistry.MemberIsInPendingCommittee.selector,
                user,
                StreamDenomination(expectedCommittee.streamId)
            )
        );

        // Act
        vm.prank(user);
        registry.unsubscribeFromStream(StreamDenomination(expectedCommittee.streamId));
    }

    function test_withdrawAvailableBalance_Success() external {
        // Arrange
        uint256 privKey = uint256(1);
        MemberRegistrationKeys memory memberRegistrationKeys = generateRegistrationPublicKeys(privKey);
        address user = vm.addr(privKey);
        uint256 minimumDeposit = streamManager.getMinimumDeposit(DEFAULT_STREAM, DEFAULT_ROLE);
        vm.deal(user, minimumDeposit);

        vm.startBroadcast(user);
        registry.applyToStream{value: minimumDeposit}(
            DEFAULT_STREAM, DEFAULT_ROLE, memberRegistrationKeys, generateDefaultUTXO()
        );
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
        MemberRegistrationKeys memory memberRegistrationKeys = generateRegistrationPublicKeys(privKey);
        address user = vm.addr(privKey);
        uint256 minimumDeposit = streamManager.getMinimumDeposit(DEFAULT_STREAM, DEFAULT_ROLE);
        vm.deal(user, minimumDeposit);

        vm.startBroadcast(user);
        registry.applyToStream{value: minimumDeposit}(
            DEFAULT_STREAM, DEFAULT_ROLE, memberRegistrationKeys, generateDefaultUTXO()
        );
        registry.unsubscribeFromStream(DEFAULT_STREAM);
        registry.withdrawAvailableBalance();
        vm.stopBroadcast();

        // Assert
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.NoAvailableBalanceToWithdraw.selector, user));

        // Act
        vm.prank(user);
        registry.withdrawAvailableBalance();
    }

    function setup_applyToStream(
        address user,
        MemberRegistrationKeys memory memberRegistrationKeys,
        StreamDenomination stream,
        Role requestedRole
    ) internal returns (uint256) {
        // Arrange
        address[] memory committeesCandidates = registry.getCommitteeCandidates(stream, requestedRole);
        uint256 candidatesAmountBeforeDeposit = committeesCandidates.length;

        // Determine the minimum bond required (getMinimumDeposit(stream))
        uint256 minimumDeposit = streamManager.getMinimumDeposit(stream, requestedRole);
        vm.deal(user, minimumDeposit);

        // Act
        vm.prank(user);
        registry.applyToStream{value: minimumDeposit}(
            stream, requestedRole, memberRegistrationKeys, generateDefaultUTXO()
        );

        // Assert that preStaked[streamIndex] equals the deposited amount
        assertEq(
            registry.getMemberPreStakedBalance(user, stream),
            minimumDeposit,
            "member pre-staked should match the minimum deposit for stream"
        );
        // Assert that requested role is set
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
        // Assert that requested role is NONE
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
        MemberRegistrationKeys memory memberRegistrationKeys = generateRegistrationPublicKeys(privKey);
        address user = vm.addr(privKey);
        uint256 totalDeposited = 0;
        Role requestedRole = Role.OPERATOR;

        // 1. Deposit in All Streams
        for (uint8 i = 0; i <= uint8(StreamDenomination._10BTC); i++) {
            totalDeposited += setup_applyToStream(user, memberRegistrationKeys, StreamDenomination(i), requestedRole);
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
        MemberRegistrationKeys memory memberRegistrationKeys = generateRegistrationPublicKeys(privKey);
        MemberKeys memory pubKeys = getXPublicKeysFromRegistration(memberRegistrationKeys);
        setup_applyToStream(StreamDenomination._0_001BTC, userAddress, memberRegistrationKeys, Role.OPERATOR);

        // Act
        bytes32 pubKey = registry.getMemberTakePubKey(userAddress);

        // Assert
        assertEq(pubKeys.takePubKey, pubKey, "Member take public key by index is not the same as the registered one");
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
        MemberRegistrationKeys memory memberRegistrationKeys = generateRegistrationPublicKeys(privKey);
        MemberKeys memory pubKeys = getXPublicKeysFromRegistration(memberRegistrationKeys);
        address user = vm.addr(privKey);

        // Assert
        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.NewMember(user, pubKeys);

        // Act
        registry.registerMemberHarness(user, memberRegistrationKeys);

        // Assert
        MemberKeys memory actualKeys = registry.getMemberPublicKeys(user);
        assertEq(actualKeys.takePubKey, pubKeys.takePubKey, "take public key should match");
        assertEq(actualKeys.covenantPubKey, pubKeys.covenantPubKey, "covenant public key should match");
        assertEq(
            keccak256(abi.encode(actualKeys.communicationPubKey)),
            keccak256(abi.encode(pubKeys.communicationPubKey)),
            "communication public key should match"
        );
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
        Role role = Role.OPERATOR;
        uint256 minimumDeposit = streamManager.getMinimumDeposit(DEFAULT_STREAM, role);

        // Act
        vm.prank(user);
        registry.registerCandidateToStreamHarness(user, DEFAULT_STREAM, role, minimumDeposit, generateDefaultUTXO());

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
        uint256 minimumDeposit = streamManager.getMinimumDeposit(DEFAULT_STREAM, DEFAULT_ROLE);
        vm.deal(user, minimumDeposit);

        // Assert
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.MemberNotRegistered.selector, user));

        // Act
        vm.prank(user);
        registry.registerCandidateToStreamHarness(
            user, DEFAULT_STREAM, DEFAULT_ROLE, minimumDeposit, generateDefaultUTXO()
        );
    }

    function test_setReApplyForStream_Success() external {
        // Arrange
        uint256 privKey = uint256(1);
        MemberRegistrationKeys memory memberRegistrationKeys = generateRegistrationPublicKeys(privKey);
        address user = vm.addr(privKey);
        setup_applyToStream(user, memberRegistrationKeys, DEFAULT_STREAM, Role.OPERATOR);

        // Set reApply to false
        // Assert
        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.MemberReApplyUpdated(user, DEFAULT_STREAM, false);

        // Act
        vm.prank(user);
        registry.setReApplyForStream(DEFAULT_STREAM, false);

        // Assert
        vm.prank(user);
        assertFalse(registry.getReApplyForStream(DEFAULT_STREAM), "reApply should be false at this point");

        // Set reApply to true
        // Assert
        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.MemberReApplyUpdated(user, DEFAULT_STREAM, true);

        // Act
        vm.prank(user);
        registry.setReApplyForStream(DEFAULT_STREAM, true);

        // Assert
        vm.prank(user);
        assertTrue(registry.getReApplyForStream(DEFAULT_STREAM), "reApply should be true at this point");
    }

    function test_setReApplyForStream_Success_beforeApply() external {
        // Arrange
        uint256 privKey = uint256(1);
        MemberRegistrationKeys memory memberRegistrationKeys = generateRegistrationPublicKeys(privKey);
        address user = vm.addr(privKey);
        StreamDenomination denomination = StreamDenomination._0_001BTC;
        StreamDenomination differentDenomination = StreamDenomination._0_01BTC;

        // Register the user to a different stream to ensure the user is registered
        setup_applyToStream(user, memberRegistrationKeys, differentDenomination, Role.OPERATOR);

        // Assert
        vm.prank(user);
        assertTrue(registry.getReApplyForStream(denomination), "reApply should be true at this point");

        // Arrange
        // Set reApply to false
        vm.prank(user);
        registry.setReApplyForStream(denomination, false);

        // Act
        // Apply to the default stream
        setup_applyToStream(user, memberRegistrationKeys, denomination, Role.OPERATOR);

        // Assert that it hasn't changed after applying to that stream
        vm.prank(user);
        assertFalse(registry.getReApplyForStream(denomination), "reApply should be false at this point");
    }

    function test_setReApplyForStream_Revert_MemberNotRegistered() external {
        // Arrange
        address user = vm.addr(uint256(1));

        // Assert
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.MemberNotRegistered.selector, user));

        // Act
        vm.prank(user);
        registry.setReApplyForStream(DEFAULT_STREAM, true);
    }

    function test_getReApplyForStream_Revert_MemberNotRegistered() external {
        // Arrange
        address user = vm.addr(uint256(1));

        // Assert
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.MemberNotRegistered.selector, user));

        // Act
        vm.prank(user);
        registry.getReApplyForStream(DEFAULT_STREAM);
    }

    function assertCandidateAmount(StreamDenomination denomination, uint256 expectedAmount) internal view {
        uint256 candidatesAmount = registry.getCommitteeCandidates(denomination, Role.OPERATOR).length;
        candidatesAmount += registry.getCommitteeCandidates(denomination, Role.WATCHTOWER).length;
        assertEq(candidatesAmount, expectedAmount, "Candidate amount doesn't match expected amount");
    }

    function test_integration_onPacketClosed_reapplyTrue() external {
        // Arrange
        (Committee memory committee,) = setup_completeCommittee();
        StreamDenomination denomination = StreamDenomination(committee.streamId);

        // Perform peg flow for all slots in the packet except the last one
        setup_multiplePegFlows(Constants.SLOTS_PER_PACKET - 1);

        // Perform peg flow up until try pegout for the last slot
        RegisterUserTakeSetup memory setup = setup_pegout();

        // get the amount of candidates before the packet is closed
        assertCandidateAmount(denomination, 0);

        // Assert
        vm.expectEmit(address(pm));
        emit IPegManager.PacketClosed(uint8(denomination), 0);

        // Act
        pm.registerUserTake(setup.pegoutTxSPVProof);

        // Assert that the amount of candidates after the packet is closed is equal to the committee size
        assertCandidateAmount(denomination, committee.members.length);

        // Assert that member reapplied correctly
        for (uint256 i = 0; i < committee.members.length; i++) {
            address user = committee.members[i].memberAddress;
            uint256 minimumDeposit = streamManager.getMinimumDeposit(denomination, committee.members[i].role);

            // Assert
            vm.prank(user);
            assertTrue(registry.getReApplyForStream(denomination), "reApply should be true at this point");
            assertEq(
                registry.getMemberPreStakedBalance(user, denomination),
                minimumDeposit,
                "member pre-staked should match the minimum deposit"
            );
            assertTrue(
                registry.getMemberRequestedRole(user, denomination) == committee.members[i].role,
                "member requested role should match the requested role"
            );
            assertTrue(
                registry.getMemberRequestedRole(user, denomination) != Role.NONE,
                "member requested role should not be NONE"
            );
            assertEq(registry.getMemberAvailableBalance(user), 0, "member available balance should be 0");
            assertEq(
                registry.getMemberStakedBalance(user, denomination, 0),
                0,
                "member staked balance should be 0 after packet closed"
            );
        }
    }

    function test_integration_onPacketClosed_fullOfCandidates() external {
        // Arrange
        (Committee memory committee,) = setup_completeCommittee();
        StreamDenomination denomination = StreamDenomination(committee.streamId);
        uint256 numWatchtowers = Constants.MAX_CANDIDATES_SIZE_PER_ROLE;
        uint256 numOperators = Constants.MAX_CANDIDATES_SIZE_PER_ROLE;
        // Register max number of candidates for each role
        setup_registerNewMembers(numWatchtowers, numOperators, denomination);

        // Perform peg flow for all slots in the packet except the last one
        setup_multiplePegFlows(Constants.SLOTS_PER_PACKET - 1);
        RegisterUserTakeSetup memory setup = setup_pegout();

        // Assert that the amount of candidates before the packet is closed is equal to the max candidates size
        assertEq(
            registry.getCommitteeCandidates(denomination, Role.OPERATOR).length, Constants.MAX_CANDIDATES_SIZE_PER_ROLE
        );
        assertEq(
            registry.getCommitteeCandidates(denomination, Role.WATCHTOWER).length,
            Constants.MAX_CANDIDATES_SIZE_PER_ROLE
        );

        // Assert
        vm.expectEmit(address(pm));
        emit IPegManager.PacketClosed(uint8(denomination), 0);

        // Act
        pm.registerUserTake(setup.pegoutTxSPVProof);

        // Assert that the amount of candidates after the packet is closed is equal to the max candidates size
        assertEq(
            registry.getCommitteeCandidates(denomination, Role.OPERATOR).length, Constants.MAX_CANDIDATES_SIZE_PER_ROLE
        );
        assertEq(
            registry.getCommitteeCandidates(denomination, Role.WATCHTOWER).length,
            Constants.MAX_CANDIDATES_SIZE_PER_ROLE
        );

        // Assert that member has not reapplied
        for (uint256 i = 0; i < committee.members.length; i++) {
            address user = committee.members[i].memberAddress;
            uint256 minimumDeposit = streamManager.getMinimumDeposit(denomination, committee.members[i].role);

            // Assert
            vm.prank(user);
            assertTrue(registry.getReApplyForStream(denomination), "reApply should be true at this point");
            assertEq(registry.getMemberPreStakedBalance(user, denomination), 0, "member pre-staked should be 0");
            assertTrue(
                registry.getMemberRequestedRole(user, denomination) == Role.NONE,
                "member requested role should NONE because they are not candidates"
            );
            assertEq(
                registry.getMemberAvailableBalance(user),
                minimumDeposit,
                "member available balance should be the minimum deposit"
            );
            assertEq(
                registry.getMemberStakedBalance(user, denomination, 0),
                0,
                "member staked balance should be 0 after packet closed"
            );
        }
    }

    function test_integration_onPacketClosed_reapplyFalse() external {
        // Arrange
        (Committee memory committee,) = setup_completeCommittee();
        StreamDenomination denomination = StreamDenomination(committee.streamId);

        // Perform peg flow for all slots in the packet except the last one
        setup_multiplePegFlows(Constants.SLOTS_PER_PACKET - 1);

        // Perform peg flow up until try pegout for the last slot
        RegisterUserTakeSetup memory setup = setup_pegout();

        for (uint256 i = 0; i < committee.members.length; i++) {
            address user = committee.members[i].memberAddress;
            // Set reApply to false
            vm.prank(user);
            registry.setReApplyForStream(denomination, false);
        }

        // Assert
        vm.expectEmit(address(pm));
        emit IPegManager.PacketClosed(uint8(denomination), 0);

        // Act
        pm.registerUserTake(setup.pegoutTxSPVProof);

        // Assert that the amount of candidates after the packet is closed is equal to 0
        assertCandidateAmount(denomination, 0);

        // Assert that all members reapplied correctly
        for (uint256 i = 0; i < committee.members.length; i++) {
            address user = committee.members[i].memberAddress;
            uint256 minimumDeposit = streamManager.getMinimumDeposit(denomination, committee.members[i].role);

            // Assert
            vm.prank(user);
            assertFalse(registry.getReApplyForStream(denomination), "reApply should be false at this point");
            assertEq(
                registry.getMemberPreStakedBalance(user, denomination),
                0,
                "member pre-staked should be 0 after packet closed"
            );
            assertTrue(
                registry.getMemberRequestedRole(user, denomination) == Role.NONE, "member requested role should be NONE"
            );
            assertEq(
                registry.getMemberAvailableBalance(user),
                minimumDeposit,
                "member available balance should be the minimum deposit"
            );
            assertEq(
                registry.getMemberStakedBalance(user, denomination, 0),
                0,
                "member staked balance should be 0 after packet closed"
            );
        }
    }

    function test_integration_onPacketClosed_alreadyCandidate() external {
        // Arrange
        (Committee memory committee,) = setup_completeCommittee();
        StreamDenomination denomination = StreamDenomination(committee.streamId);

        // Perform peg flow for all slots in the packet except the last one
        setup_multiplePegFlows(Constants.SLOTS_PER_PACKET - 1);

        // Perform peg flow up until try pegout for the last slot
        RegisterUserTakeSetup memory setup = setup_pegout();

        setup_applyToStream_MultipleMembers(denomination, committee.members);

        // Assert that the amount of candidates before the packet is closed is equal to the committee size
        assertCandidateAmount(denomination, committee.members.length);

        // Assert
        vm.expectEmit(address(pm));
        emit IPegManager.PacketClosed(uint8(denomination), 0);

        // Act
        pm.registerUserTake(setup.pegoutTxSPVProof);

        // Assert that the amount of candidates after the packet is closed is equal to the committee size
        assertCandidateAmount(denomination, committee.members.length);

        // Assert that member reapplied correctly
        for (uint256 i = 0; i < committee.members.length; i++) {
            address user = committee.members[i].memberAddress;
            uint256 minimumDeposit = streamManager.getMinimumDeposit(denomination, committee.members[i].role);

            // Assert
            vm.prank(user);
            assertTrue(registry.getReApplyForStream(denomination), "reApply should be true at this point");
            assertEq(
                registry.getMemberPreStakedBalance(user, denomination),
                minimumDeposit,
                "member pre-staked should be the minimum deposit"
            );
            assertTrue(
                registry.getMemberRequestedRole(user, denomination) == committee.members[i].role,
                "member requested role should be the same as before"
            );
            assertEq(
                registry.getMemberAvailableBalance(user),
                minimumDeposit,
                "member available balance should be the minimum deposit"
            );
            assertEq(
                registry.getMemberStakedBalance(user, denomination, 0),
                0,
                "member staked balance should be 0 after packet closed"
            );
        }
    }
}
