// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {HelperContract} from "test/helpers/HelperContract.sol";
import {ICommitteeRegistry} from "src/interfaces/ICommitteeRegistry.sol";
import {IAccessControl} from "src/interfaces/IAccessControl.sol";
import {Signatures, SignatureData, ISignatureManager} from "src/interfaces/ISignatureManager.sol";
import {Constants} from "src/libraries/Constants.sol";

contract TestSignatureManager is Test, HelperContract {
    function setUp() public {
        runTestDeployScript();
    }

    // we only check the revert case since the success cases are being checked in the _addMemberSignaturePegout tests
    function test_checkAllSignaturesReady_Revert_PegOutRequestNotFound() external {
        // Arrange
        bytes32 signatureHash = 0x0000000000000000000000000000000000000000000000000000000000000001;

        // Assert
        vm.expectRevert(abi.encodeWithSelector(ISignatureManager.SignatureHashNotFound.selector, signatureHash));

        // Act
        signatureManager.checkAllSignaturesReady(signatureHash);
    }

    function test_addMemberNonce_Success() external {
        bytes32 signatureHash = setup_initSignatures();

        // Arrange
        // The nonce values are dummy values
        bytes memory nonce =
            hex"f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a00000";

        // Assert
        // We emit the event we expect to see.
        bytes32 committeeMember0Pubkey = MEMBER_0_PUBKEY;
        vm.expectEmit(address(signatureManager));
        emit ISignatureManager.NonceAdded(signatureHash, committeeMember0Pubkey, nonce);

        // Act
        address committeeMember0adr = MEMBER_0_ADDRESS;
        vm.prank(committeeMember0adr);
        bool allNoncesReady = signatureManager.addMemberNonce(signatureHash, nonce);

        // Assert
        assertEq(allNoncesReady, false, "Not all nonces should be ready at this point");

        // Assert
        // We emit the event we expect to see.
        bytes32 committeeMember1Pubkey = MEMBER_1_PUBKEY;
        vm.expectEmit(address(signatureManager));
        emit ISignatureManager.NonceAdded(signatureHash, committeeMember1Pubkey, nonce);

        // We emit the event we expect to see.
        vm.expectEmit(address(signatureManager));
        emit ISignatureManager.AllNoncesReady(signatureHash);

        // Act
        address committeeMember2adr = MEMBER_1_ADDRESS;
        vm.prank(committeeMember2adr);
        allNoncesReady = signatureManager.addMemberNonce(signatureHash, nonce);

        // Assert
        assertEq(allNoncesReady, true, "Not all nonces should be ready at this point");
    }

    function test_addMemberSignature_Success() external {
        // Init signatures and add all nonces
        bytes32 signatureHash = setup_initSignatures();
        setup_addAllNonces(signatureHash);
        // Arrange
        // The signature an nonce values are dummy values
        bytes32 signature = hex"f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0";

        // Assert
        // We emit the event we expect to see.
        bytes32 committeeMember0Pubkey = MEMBER_0_PUBKEY;
        vm.expectEmit(address(signatureManager));
        emit ISignatureManager.SignatureAdded(signatureHash, committeeMember0Pubkey, signature);

        // Act
        address committeeMember0adr = MEMBER_0_ADDRESS;
        vm.prank(committeeMember0adr);
        bool allSignaturesReady = signatureManager.addMemberSignature(signatureHash, signature);

        // Assert
        assertEq(allSignaturesReady, false, "Not all signatures should be ready at this point");
        (uint8 missingSignatures, uint8 missingNonces, bytes32 aggregatedKey) =
            signatureManager.getSignaturesStatus(signatureHash);
        assertEq(missingSignatures, 1, "missingSignatures should be equal to 1");
        assertEq(missingNonces, 0, "missingNonces should be equal to 1");
        assertEq(aggregatedKey, COMMITEE_1_PUB_KEY, "aggregatedKey should be equal to the committee key");
        SignatureData[] memory signatures = signatureManager.getPartialSignatures(signatureHash);
        assertEq(signatures.length, 2, "signatures length should be equal to 2");
        assertEq(
            signatures[0].memberPublicKey,
            committeeMember0Pubkey,
            "signatures[0].memberPublicKey should be equal to the committee member key"
        );
        assertEq(signatures[0].signature, signature, "signatures[0].signature should be equal to the signature");

        // Assert
        // We emit the event we expect to see.
        bytes32 committeeMember1Pubkey = MEMBER_1_PUBKEY;
        vm.expectEmit(address(signatureManager));
        emit ISignatureManager.SignatureAdded(signatureHash, committeeMember1Pubkey, signature);

        // We emit the event we expect to see.
        vm.expectEmit(address(signatureManager));
        emit ISignatureManager.AllSignaturesReady(signatureHash);

        // Act
        address committeeMember2adr = MEMBER_1_ADDRESS;
        vm.prank(committeeMember2adr);
        allSignaturesReady = signatureManager.addMemberSignature(signatureHash, signature);

        // Assert
        assertEq(allSignaturesReady, true, "Not all signatures should be ready at this point");
        (missingSignatures, missingNonces, aggregatedKey) = signatureManager.getSignaturesStatus(signatureHash);
        assertEq(missingSignatures, 0, "missingSignatures should be equal to 0");
        assertEq(missingNonces, 0, "missingNonces should be equal to 0");
        assertEq(aggregatedKey, COMMITEE_1_PUB_KEY, "aggregatedKey should be equal to the committee key");
        signatures = signatureManager.getPartialSignatures(signatureHash);
        assertEq(signatures.length, 2, "signatures length should be equal to 2");
        assertEq(
            signatures[1].memberPublicKey,
            committeeMember1Pubkey,
            "signatures[1].memberPublicKey should be equal to the committee member key"
        );
        assertEq(signatures[1].signature, signature, "signatures[1].signature should be equal to the signature");
    }

    function test_addMemberNonce_Revert_SignatureHashNotFound() external {
        // Arrange
        bytes32 signatureHash = 0x0000000000000000000000000000000000000000000000000000000000000001;

        // The signature an nonce values are dummy values
        bytes memory nonce =
            hex"f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a00000";

        // Assert
        vm.expectRevert(abi.encodeWithSelector(ISignatureManager.SignatureHashNotFound.selector, signatureHash));

        // Act
        vm.prank(MEMBER_0_ADDRESS);
        signatureManager.addMemberNonce(signatureHash, nonce);
    }

    function test_addMemberSignature_Revert_SignatureHashNotFound() external {
        // Arrange
        bytes32 signatureHash = 0x0000000000000000000000000000000000000000000000000000000000000001;

        // The signature an nonce values are dummy values
        bytes32 signature = hex"f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0";

        // Assert
        vm.expectRevert(abi.encodeWithSelector(ISignatureManager.SignatureHashNotFound.selector, signatureHash));

        // Act
        vm.prank(MEMBER_0_ADDRESS);
        signatureManager.addMemberSignature(signatureHash, signature);
    }

    function test_addMemberNonce_Revert_MemberNotRegistered() external {
        bytes32 signatureHash = setup_initSignatures();

        // The nonce values are dummy values
        bytes memory nonce =
            hex"f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a00000";

        // Assert
        address memberAddress = address(0);
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.MemberNotRegistered.selector, memberAddress));

        vm.prank(memberAddress);
        signatureManager.addMemberNonce(signatureHash, nonce);
    }

    function test_addMemberSignature_Revert_MemberNotRegistered() external {
        // Init signatures and add all nonces
        bytes32 signatureHash = setup_initSignatures();
        setup_addAllNonces(signatureHash);

        // The signature values are dummy values
        bytes32 signature = hex"f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0";

        // Assert
        address memberAddress = address(0);
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.MemberNotRegistered.selector, memberAddress));

        vm.prank(memberAddress);
        signatureManager.addMemberSignature(signatureHash, signature);
    }

    function test_addMemberNonce_Revert_MemberHasAlreadySigned() external {
        // Init signatures
        bytes32 signatureHash = setup_initSignatures();
        // Arrange
        // The nonce values are dummy values
        bytes memory nonce =
            hex"f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a00000";
        bytes32 committeeMember0Pubkey = MEMBER_0_PUBKEY;

        // First time adding the nonce
        address committeeMember0adr = MEMBER_0_ADDRESS;
        vm.prank(committeeMember0adr);
        signatureManager.addMemberNonce(signatureHash, nonce);

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                ISignatureManager.MemberAlreadyAddedNonce.selector, committeeMember0Pubkey, committeeMember0adr, nonce
            )
        );

        // Act add nonce a second time with the same committee member
        vm.prank(committeeMember0adr);
        signatureManager.addMemberNonce(signatureHash, nonce);
    }

    function test_addMemberSignature_Revert_MemberHasAlreadySigned() external {
        // Init signatures and add all nonces
        bytes32 signatureHash = setup_initSignatures();
        setup_addAllNonces(signatureHash);
        // Arrange
        // The signature values are dummy values
        bytes32 signature = hex"f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0";
        bytes32 committeeMember0Pubkey = MEMBER_0_PUBKEY;

        // Sign the first time
        address committeeMember0adr = MEMBER_0_ADDRESS;
        vm.prank(committeeMember0adr);
        signatureManager.addMemberSignature(signatureHash, signature);

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                ISignatureManager.MemberHasAlreadySigned.selector,
                committeeMember0Pubkey,
                committeeMember0adr,
                signatureHash
            )
        );

        // Act sign a second time with the same committee member
        vm.prank(committeeMember0adr);
        signatureManager.addMemberSignature(signatureHash, signature);
    }

    function test_addMemberNonce_Revert_MemberNotFoundInCommittee() external {
        bytes32 signatureHash = setup_initSignatures();

        // Arrange
        // The nonce values are dummy values
        bytes memory nonce =
            hex"f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a00000";

        address nonCommitteeMember = MEMBER_2_ADDRESS;
        bytes32 nonCommitteeMemberPubkey = MEMBER_2_PUBKEY;

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                ISignatureManager.MemberNotFoundInCommittee.selector,
                nonCommitteeMemberPubkey,
                nonCommitteeMember,
                signatureHash
            )
        );

        // Act
        vm.prank(nonCommitteeMember);
        signatureManager.addMemberNonce(signatureHash, nonce);
    }

    function test_addMemberSignature_Revert_MemberNotFoundInCommittee() external {
        // Init signatures and add all nonces
        bytes32 signatureHash = setup_initSignatures();
        setup_addAllNonces(signatureHash);

        // Arrange
        // The signature an nonce values are dummy values
        bytes32 signature = hex"f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0";
        address nonCommitteeMember = MEMBER_2_ADDRESS;
        bytes32 nonCommitteeMemberPubkey = MEMBER_2_PUBKEY;

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                ISignatureManager.MemberNotFoundInCommittee.selector,
                nonCommitteeMemberPubkey,
                nonCommitteeMember,
                signatureHash
            )
        );

        // Act
        vm.prank(nonCommitteeMember);
        signatureManager.addMemberSignature(signatureHash, signature);
    }

    function test_addMemberSignature_Revert_InvalidNonceLength() external {
        bytes32 signatureHash = setup_initSignatures();

        // Arrange
        // The signature an nonce values are dummy values
        bytes memory nonce =
            hex"fff8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a00000";

        address CommitteeMember = MEMBER_0_ADDRESS;

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                ISignatureManager.InvalidNonceLength.selector, nonce.length, Constants.SIGNATURE_NONCE_LENGTH
            )
        );

        // Act
        vm.prank(CommitteeMember);
        signatureManager.addMemberNonce(signatureHash, nonce);
    }

    function test_initSignatures_Success() external {
        // Arrange
        bytes32 committeeKey = COMMITEE_1_PUB_KEY;
        bytes32 committeeMember0Pubkey = MEMBER_0_PUBKEY;
        bytes32 committeeMember1Pubkey = MEMBER_1_PUBKEY;
        uint8 committeeMemberCount = 2;
        bytes32 signatureHash = 0x1000000000000000000000000000000000000000000000000000000000000001;

        // Act
        vm.prank(address(pm));
        signatureManager.initSignatures(signatureHash, committeeKey);

        // Assert
        (uint8 missingSignatures, uint8 missingNonces, bytes32 aggregatedKey) =
            signatureManager.getSignaturesStatus(signatureHash);
        assertEq(
            missingSignatures, committeeMemberCount, "missingSignatures should be equal to the committee member count"
        );
        assertEq(missingNonces, committeeMemberCount, "missingNonces should be equal to the committee member count");
        assertEq(aggregatedKey, committeeKey, "aggregatedKey should be equal to the committee key");

        SignatureData[] memory signatures = signatureManager.getPartialSignatures(signatureHash);
        assertEq(
            signatures.length, committeeMemberCount, "signatures length should be equal to the committee member count"
        );
        assertEq(
            signatures[0].memberPublicKey,
            committeeMember0Pubkey,
            "signatures[0].memberPublicKey should be equal to the committee member key"
        );
        assertEq(
            signatures[1].memberPublicKey,
            committeeMember1Pubkey,
            "signatures[1].memberPublicKey should be equal to the committee member key"
        );
    }

    function test_initSignatures_Revert_InvalidSignatureHash() external {
        // Arrange
        bytes32 committeeKey = COMMITEE_1_PUB_KEY;
        bytes32 signatureHash = 0x0000000000000000000000000000000000000000000000000000000000000000;

        // Assert
        vm.expectRevert(abi.encodeWithSelector(ISignatureManager.InvalidSignatureHash.selector, signatureHash));

        // Act
        vm.prank(address(pm));
        signatureManager.initSignatures(signatureHash, committeeKey);
    }

    function test_initSignatures_Revert_SignaturesAlreadyInitialized() external {
        // Arrange
        bytes32 committeeKey = COMMITEE_1_PUB_KEY;
        bytes32 signatureHash = 0x1000000000000000000000000000000000000000000000000000000000000001;

        // First time initializing the signatures
        vm.prank(address(pm));
        signatureManager.initSignatures(signatureHash, committeeKey);

        // Assert
        vm.expectRevert(abi.encodeWithSelector(ISignatureManager.SignaturesAlreadyInitialized.selector, signatureHash));

        // Act second time initializing the signatures
        vm.prank(address(pm));
        signatureManager.initSignatures(signatureHash, committeeKey);
    }

    function test_initSignatures_Revert_InvalidCommitteeKey() external {
        // Arrange
        bytes32 committeeKey = 0x0000000000000000000000000000000000000000000000000000000000000000;
        bytes32 signatureHash = 0x1000000000000000000000000000000000000000000000000000000000000001;

        // Assert
        vm.expectRevert(abi.encodeWithSelector(ISignatureManager.InvalidCommittee.selector, committeeKey));

        // Act
        vm.prank(address(pm));
        signatureManager.initSignatures(signatureHash, committeeKey);
    }

    function test_initSignatures_Revert_Unauthorized() external {
        // Arrange
        bytes32 committeeKey = COMMITEE_1_PUB_KEY;
        bytes32 signatureHash = 0x1000000000000000000000000000000000000000000000000000000000000001;

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.UnauthorizedAccount.selector, address(this)));

        // Act
        signatureManager.initSignatures(signatureHash, committeeKey);
    }

    function setup_initSignatures() internal returns (bytes32) {
        bytes32 committeeKey = COMMITEE_1_PUB_KEY;
        bytes32 signatureHash = 0x1200000000000000000000000000000000000000000000000000000000000001;

        // Act
        vm.prank(address(pm));
        signatureManager.initSignatures(signatureHash, committeeKey);

        return signatureHash;
    }

    function setup_addAllNonces(bytes32 signatureHash) internal {
        bytes memory nonce0 =
            hex"f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a00000";
        vm.prank(MEMBER_0_ADDRESS);
        signatureManager.addMemberNonce(signatureHash, nonce0);

        bytes memory nonce1 =
            hex"f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a00001";
        vm.prank(MEMBER_1_ADDRESS);
        signatureManager.addMemberNonce(signatureHash, nonce1);
    }
}
