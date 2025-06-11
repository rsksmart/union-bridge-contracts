// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {HelperContract} from "test/helpers/HelperContract.sol";
import {
    ICommitteeRegistry,
    StreamDenomination,
    Role,
    CommitteeMember,
    PublicKeyRegistration
} from "src/interfaces/ICommitteeRegistry.sol";
import {IAccessControl} from "src/interfaces/IAccessControl.sol";
import {Signatures, SignatureData, ISignatureManager} from "src/interfaces/ISignatureManager.sol";
import {Constants} from "src/libraries/Constants.sol";

contract TestSignatureManager is Test, HelperContract {
    uint64 internal setupStreamId;

    function setUp() external {
        runTestDeployScript();
        (, setupStreamId) = setup_completeCommittee();
    }

    // we only check the revert case since the success cases are being checked in the _addMemberSignaturePegout tests
    function test_checkAllSignaturesReady_Revert_PegoutRequestNotFound() external {
        // Arrange
        bytes32 hashToSign = 0x0000000000000000000000000000000000000000000000000000000000000001;

        // Assert
        vm.expectRevert(abi.encodeWithSelector(ISignatureManager.HashToSignNotFound.selector, hashToSign));

        // Act
        signatureManager.checkAllSignaturesReady(hashToSign);
    }

    function test_addMemberNonce_Success() external {
        // Arrange
        bytes32 hashToSign = setup_initSignatures();
        // The nonce values are dummy values
        bytes memory nonce =
            hex"f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a00000";
        bytes32 committeeMember0Pubkey = generatePubKey(1);
        address committeeMember0adr = vm.addr(1);

        // Assert
        // We emit the event we expect to see.
        vm.expectEmit(address(signatureManager));
        emit ISignatureManager.NonceAdded(hashToSign, committeeMember0Pubkey, nonce);

        // Act
        vm.prank(committeeMember0adr);
        bool allNoncesReady = signatureManager.addMemberNonce(hashToSign, nonce);

        // Assert
        assertEq(allNoncesReady, false, "Not all nonces should be ready at this point");
    }

    function test_addMemberNonce_Success_AllNoncesReady() external {
        // Arrange
        bytes32 hashToSign = setup_initSignatures();
        // The nonce values are dummy values
        bytes memory nonce =
            hex"f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a00000";
        setup_membersNonces(hashToSign, 0, registry.minCommitteeMembers() - 2);
        (hashToSign);
        uint256 lastMemberIndex = registry.minCommitteeMembers() - 1;
        bytes32 lastMemberPubkey = generatePubKey(lastMemberIndex + 1);
        address lastMemberAddress = vm.addr(lastMemberIndex + 1);

        // Assert
        // We emit the event we expect to see.
        vm.expectEmit(address(signatureManager));
        emit ISignatureManager.NonceAdded(hashToSign, lastMemberPubkey, nonce);

        // We emit the event we expect to see.
        vm.expectEmit(address(signatureManager));
        emit ISignatureManager.AllNoncesReady(hashToSign);

        // Act
        vm.prank(lastMemberAddress);
        bool allNoncesReady = signatureManager.addMemberNonce(hashToSign, nonce);

        // Assert
        assertEq(allNoncesReady, true, "Not all nonces should be ready at this point");
    }

    function test_addMemberSignature_Success() external {
        // Arrange
        // Init signatures and add all nonces
        bytes32 hashToSign = setup_initSignatures();
        setup_addAllNonces(hashToSign);
        // The signature an nonce values are dummy values
        bytes32 signature = hex"f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0";
        uint256 memberIndex = 0;
        bytes32 memberPubKey = generatePubKey(memberIndex + 1);
        address committeeMember0adr = vm.addr(memberIndex + 1);

        // We emit the event we expect to see.
        // Assert
        vm.expectEmit(address(signatureManager));
        emit ISignatureManager.SignatureAdded(hashToSign, memberPubKey, signature);

        // Act
        vm.prank(committeeMember0adr);
        bool allSignaturesReady = signatureManager.addMemberSignature(hashToSign, signature);

        // Assert
        assertEq(allSignaturesReady, false, "Not all signatures should be ready at this point");
        (uint8 missingSignatures, uint8 missingNonces, uint256 committeeId) =
            signatureManager.getSignaturesStatus(hashToSign);
        assertEq(missingSignatures, registry.minCommitteeMembers() - 1, "missingSignatures should be equal to 1");
        assertEq(missingNonces, 0, "missingNonces should be equal to 1");
        assertEq(
            committeeId,
            COMMITTEE_ID_STREAM_1_PACKET_0,
            "committeeId should be equal to the committee id that was created initially"
        );

        SignatureData[] memory signatures = signatureManager.getPartialSignatures(hashToSign);
        assertEq(
            signatures.length,
            registry.minCommitteeMembers(),
            "signatures length should be equal to registry.minCommitteeMembers()"
        );

        CommitteeMember[] memory members = registry.getCommitteeMembers(committeeId);
        for (uint256 i = 0; i < members.length; i++) {
            assertEq(
                signatures[i].memberPublicKey,
                generatePubKey(members[i].index + 1),
                "signatures[i].memberPublicKey should be equal to the committee member key"
            );

            if (members[i].index != memberIndex) {
                assertEq(
                    signatures[i].signature,
                    bytes32(0),
                    "signatures[i].signature should be empty for members other than the one who signed"
                );
            } else {
                assertEq(
                    signatures[i].signature,
                    signature,
                    "signatures[i].signature should be equal to the signature added by the member"
                );
            }
        }
    }

    function test_addMemberSignature_Success_AllSignaturesReady() external {
        // Arrange
        // Init signatures and add all nonces
        bytes32 hashToSign = setup_initSignatures();
        setup_addAllNonces(hashToSign);
        // The signature an nonce values are dummy values
        bytes32 signature = hex"f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0";
        uint256 lastMemberIndex = registry.minCommitteeMembers() - 1;
        setup_membersSignatures(hashToSign, 0, lastMemberIndex - 1);
        // Pub key and address are generated based on the member index + 1
        bytes32 lastMemberPubKey = generatePubKey(lastMemberIndex + 1);
        address lastMemberAddress = vm.addr(lastMemberIndex + 1);

        // Assert
        // We emit the event we expect to see.
        vm.expectEmit(address(signatureManager));
        emit ISignatureManager.SignatureAdded(hashToSign, lastMemberPubKey, signature);

        // We emit the event we expect to see.
        vm.expectEmit(address(signatureManager));
        emit ISignatureManager.AllSignaturesReady(hashToSign);

        // Act
        vm.prank(lastMemberAddress);
        bool allSignaturesReady = signatureManager.addMemberSignature(hashToSign, signature);

        // Assert
        assertEq(allSignaturesReady, true, "Not all signatures should be ready at this point");
        (uint8 missingSignatures, uint8 missingNonces, uint256 committeeId) =
            signatureManager.getSignaturesStatus(hashToSign);
        assertEq(missingSignatures, 0, "missingSignatures should be equal to 0");
        assertEq(missingNonces, 0, "missingNonces should be equal to 0");
        assertEq(committeeId, COMMITTEE_ID_STREAM_1_PACKET_0, "aggregatedKey should be equal to the committee key");
        SignatureData[] memory signatures = signatureManager.getPartialSignatures(hashToSign);
        assertEq(
            signatures.length,
            registry.minCommitteeMembers(),
            "signatures length should be equal to registry.minCommitteeMembers()"
        );

        CommitteeMember[] memory members = registry.getCommitteeMembers(committeeId);
        for (uint256 i = 0; i < members.length; i++) {
            assertEq(
                signatures[i].memberPublicKey,
                generatePubKey(members[i].index + 1),
                "signatures[i].memberPublicKey should be equal to the committee member key"
            );
            assertNotEq(signatures[i].signature, bytes32(0), "signatures[i].signature should not be empty");
        }
    }

    function test_addMemberNonce_Revert_HashToSignNotFound() external {
        // Arrange
        bytes32 hashToSign = 0x0000000000000000000000000000000000000000000000000000000000000001;

        // The signature an nonce values are dummy values
        bytes memory nonce =
            hex"f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a00000";

        // Assert
        vm.expectRevert(abi.encodeWithSelector(ISignatureManager.HashToSignNotFound.selector, hashToSign));

        // Act
        vm.prank(vm.addr(1));
        signatureManager.addMemberNonce(hashToSign, nonce);
    }

    function test_addMemberSignature_Revert_HashToSignNotFound() external {
        // Arrange
        bytes32 hashToSign = 0x0000000000000000000000000000000000000000000000000000000000000001;
        address memberAddress = vm.addr(registry.minCommitteeMembers() + 1);
        // The signature an nonce values are dummy values
        bytes32 signature = hex"f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0";

        // Assert
        vm.expectRevert(abi.encodeWithSelector(ISignatureManager.HashToSignNotFound.selector, hashToSign));

        // Act
        vm.prank(memberAddress);
        signatureManager.addMemberSignature(hashToSign, signature);
    }

    function test_addMemberNonce_Revert_MemberNotRegistered() external {
        bytes32 hashToSign = setup_initSignatures();

        // The nonce values are dummy values
        bytes memory nonce =
            hex"f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a00000";

        // Assert
        address memberAddress = address(0);
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.MemberNotRegistered.selector, memberAddress));

        vm.prank(memberAddress);
        signatureManager.addMemberNonce(hashToSign, nonce);
    }

    function test_addMemberSignature_Revert_MemberNotRegistered() external {
        // Init signatures and add all nonces
        bytes32 hashToSign = setup_initSignatures();
        setup_addAllNonces(hashToSign);

        // The signature values are dummy values
        bytes32 signature = hex"f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0";

        // Assert
        address memberAddress = vm.addr(registry.minCommitteeMembers() + 1);
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.MemberNotRegistered.selector, memberAddress));

        vm.prank(memberAddress);
        signatureManager.addMemberSignature(hashToSign, signature);
    }

    function test_addMemberNonce_Revert_MemberHasAlreadySigned() external {
        // Arrange
        // Init signatures
        bytes32 hashToSign = setup_initSignatures();
        // The nonce values are dummy values
        bytes memory nonce =
            hex"f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a00000";
        bytes32 committeeMember0Pubkey = generatePubKey(1);
        address committeeMember0adr = vm.addr(1);

        // First time adding the nonce
        vm.prank(committeeMember0adr);
        signatureManager.addMemberNonce(hashToSign, nonce);

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                ISignatureManager.MemberAlreadyAddedNonce.selector, committeeMember0Pubkey, committeeMember0adr, nonce
            )
        );

        // MemberAlreadyAddedNonce(0x0000000000000000000000000000000000000000000000000000000000000001, 0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf, 0xf8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a00000) !=
        // MemberAlreadyAddedNonce(0x0000000000000000000000000000000000000000000000000000000000000002, 0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf, 0xf8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a00000)]
        // Act add nonce a second time with the same committee member
        vm.prank(committeeMember0adr);
        signatureManager.addMemberNonce(hashToSign, nonce);
    }

    function test_addMemberSignature_Revert_MemberHasAlreadySigned() external {
        // Init signatures and add all nonces
        bytes32 hashToSign = setup_initSignatures();
        setup_addAllNonces(hashToSign);
        // Arrange
        // The signature values are dummy values
        bytes32 signature = hex"f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0";
        bytes32 committeeMember0Pubkey = generatePubKey(1);
        address committeeMember0adr = vm.addr(1);

        // Sign the first time
        vm.prank(committeeMember0adr);
        signatureManager.addMemberSignature(hashToSign, signature);

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                ISignatureManager.MemberHasAlreadySigned.selector,
                committeeMember0Pubkey,
                committeeMember0adr,
                hashToSign
            )
        );

        // Act sign a second time with the same committee member
        vm.prank(committeeMember0adr);
        signatureManager.addMemberSignature(hashToSign, signature);
    }

    function test_addMemberNonce_Revert_MemberNotFoundInCommittee() external {
        // Arrange
        bytes32 hashToSign = setup_initSignatures();
        address nonCommitteeMember = vm.addr(registry.minCommitteeMembers() + 1);
        PublicKeyRegistration[] memory nonCommitteeMemberPubKeysRegistration =
            generatePublicKeysRegistration(registry.minCommitteeMembers() + 1);
        setup_applyToStream(
            StreamDenomination._0_01BTC, nonCommitteeMember, nonCommitteeMemberPubKeysRegistration, Role.Operator
        );
        // The nonce values are dummy values
        bytes memory nonce =
            hex"f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a00000";

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                ISignatureManager.MemberNotFoundInCommittee.selector,
                nonCommitteeMemberPubKeysRegistration[0].publicKeyX,
                nonCommitteeMember,
                hashToSign
            )
        );

        // Act
        vm.prank(nonCommitteeMember);
        signatureManager.addMemberNonce(hashToSign, nonce);
    }

    function test_addMemberSignature_Revert_MemberNotFoundInCommittee() external {
        // Arrange
        // Init signatures and add all nonces
        bytes32 hashToSign = setup_initSignatures();
        setup_addAllNonces(hashToSign);

        address nonCommitteeMember = vm.addr(registry.minCommitteeMembers() + 1);
        PublicKeyRegistration[] memory nonCommitteeMemberPubKeysRegistration =
            generatePublicKeysRegistration(registry.minCommitteeMembers() + 1);
        setup_applyToStream(
            StreamDenomination._0_01BTC, nonCommitteeMember, nonCommitteeMemberPubKeysRegistration, Role.Operator
        );
        bytes32 signature = hex"f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0";

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                ISignatureManager.MemberNotFoundInCommittee.selector,
                nonCommitteeMemberPubKeysRegistration[0].publicKeyX,
                nonCommitteeMember,
                hashToSign
            )
        );

        // Act
        vm.prank(nonCommitteeMember);
        signatureManager.addMemberSignature(hashToSign, signature);
    }

    function test_addMemberSignature_Revert_InvalidNonceLength() external {
        bytes32 hashToSign = setup_initSignatures();

        // Arrange
        // The signature an nonce values are dummy values
        bytes memory nonce =
            hex"fff8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a00000";

        address memberAddress = vm.addr(1);

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                ISignatureManager.InvalidNonceLength.selector, nonce.length, Constants.SIGNATURE_NONCE_LENGTH
            )
        );

        // Act
        vm.prank(memberAddress);
        signatureManager.addMemberNonce(hashToSign, nonce);
    }

    function test_initSignatures_Success() external {
        // Arrange
        uint8 committeeMemberCount = uint8(registry.minCommitteeMembers());
        bytes32 hashToSign = 0x1000000000000000000000000000000000000000000000000000000000000001;
        CommitteeMember[] memory members = registry.getCommitteeMembers(COMMITTEE_ID_STREAM_1_PACKET_0);

        // Act
        vm.prank(address(pm));
        signatureManager.initSignatures(hashToSign, COMMITTEE_ID_STREAM_1_PACKET_0);

        // Assert
        (uint8 missingSignatures, uint8 missingNonces,) = signatureManager.getSignaturesStatus(hashToSign);
        assertEq(
            missingSignatures, committeeMemberCount, "missingSignatures should be equal to the committee member count"
        );
        assertEq(missingNonces, committeeMemberCount, "missingNonces should be equal to the committee member count");
        // assertEq(aggregatedKey, committeeKey, "aggregatedKey should be equal to the committee key");

        SignatureData[] memory signatures = signatureManager.getPartialSignatures(hashToSign);
        assertEq(
            signatures.length, committeeMemberCount, "signatures length should be equal to the committee member count"
        );

        for (uint256 i = 0; i < signatures.length; i++) {
            assertEq(
                signatures[i].memberPublicKey,
                generatePubKey(members[i].index + 1),
                "signatures[i].memberPublicKey should be equal to the committee member key"
            );
            assertEq(signatures[i].signature, bytes32(0), "signatures[i].signature should be empty");
            assertEq(signatures[i].nonce.length, 0, "signatures[i].nonce should be empty");
        }
    }

    function test_initSignatures_Revert_InvalidHashToSign() external {
        // Arrange
        bytes32 hashToSign = 0x0000000000000000000000000000000000000000000000000000000000000000;

        // Assert
        vm.expectRevert(abi.encodeWithSelector(ISignatureManager.InvalidHashToSign.selector, hashToSign));

        // Act
        vm.prank(address(pm));
        signatureManager.initSignatures(hashToSign, COMMITTEE_ID_STREAM_1_PACKET_0);
    }

    function test_initSignatures_Revert_SignaturesAlreadyInitialized() external {
        // Arrange
        uint256 committeeId = COMMITTEE_ID_STREAM_1_PACKET_0;
        bytes32 hashToSign = 0x1000000000000000000000000000000000000000000000000000000000000001;

        // First time initializing the signatures
        vm.prank(address(pm));
        signatureManager.initSignatures(hashToSign, committeeId);

        // Assert
        vm.expectRevert(abi.encodeWithSelector(ISignatureManager.SignaturesAlreadyInitialized.selector, hashToSign));

        // Act second time initializing the signatures
        vm.prank(address(pm));
        signatureManager.initSignatures(hashToSign, committeeId);
    }

    function test_initSignatures_Revert_CommitteeNotFound() external {
        // Arrange
        uint256 committeeId = 1;
        bytes32 hashToSign = 0x1000000000000000000000000000000000000000000000000000000000000001;

        // Assert
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.CommitteeNotFound.selector, committeeId));

        // Act
        vm.prank(address(pm));
        signatureManager.initSignatures(hashToSign, committeeId);
    }

    function test_initSignatures_Revert_Unauthorized() external {
        // Arrange
        bytes32 hashToSign = 0x1000000000000000000000000000000000000000000000000000000000000001;

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.UnauthorizedAccount.selector, address(this)));

        // Act
        signatureManager.initSignatures(hashToSign, COMMITTEE_ID_STREAM_1_PACKET_0);
    }

    function setup_initSignatures() internal returns (bytes32) {
        bytes32 hashToSign = 0x1200000000000000000000000000000000000000000000000000000000000001;

        // Act
        vm.prank(address(pm));
        signatureManager.initSignatures(hashToSign, COMMITTEE_ID_STREAM_1_PACKET_0);

        return hashToSign;
    }

    function setup_membersNonces(bytes32 hashToSign, uint256 memberIndexStart, uint256 memberIndexEnd) internal {
        for (uint256 i = memberIndexStart; i <= memberIndexEnd; i++) {
            // The nonce values are dummy values
            bytes memory nonce =
                hex"f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a00000";
            address memberAddress = vm.addr(i + 1);
            vm.prank(memberAddress);
            signatureManager.addMemberNonce(hashToSign, nonce);
        }
    }

    function setup_membersSignatures(bytes32 hashToSign, uint256 memberIndexStart, uint256 memberIndexEnd) internal {
        for (uint256 i = memberIndexStart; i <= memberIndexEnd; i++) {
            // The signarture values are dummy values
            bytes32 signature = hex"f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0";
            address memberAddress = vm.addr(i + 1);
            vm.prank(memberAddress);
            signatureManager.addMemberSignature(hashToSign, signature);
        }
    }

    function setup_addAllNonces(bytes32 hashToSign) internal {
        setup_membersNonces(hashToSign, 0, registry.minCommitteeMembers() - 1);
    }
}
