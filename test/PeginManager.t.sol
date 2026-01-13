// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {HelperContract, StreamManagerHarness} from "test/helpers/HelperContract.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {Pausable} from "src/Pausable.sol";
import {BtcTransaction, BtcTxSPVProof, StreamPosition, PegStatus} from "src/interfaces/IPegCommonTypes.sol";
import {IPeginManager, RequestPeginTempInfo} from "src/interfaces/IPeginManager.sol";
import {IPegManagerBase} from "src/interfaces/IPegManagerBase.sol";
import {PrevoutData} from "src/interfaces/IBitcoinManager.sol";
import {Slot, SlotState, Stream, IStreamManager} from "src/interfaces/IStreamManager.sol";
import {BTC_TRANSACTION_CONFIRMATION_INVALID_MERKLE_BRANCH_ERROR_CODE} from "src/interfaces/IBridge.sol";
import {ProofValidator} from "src/ProofValidator.sol";
import {Constants} from "src/libraries/Constants.sol";
import {ICommitteeRegistry, Committee, CommitteeMember} from "src/interfaces/ICommitteeRegistry.sol";
import {IMemberRegistry, MemberKeys} from "src/interfaces/IMemberRegistry.sol";
import {ISignatureManager} from "src/interfaces/ISignatureManager.sol";
import {IRbtcBridge} from "src/interfaces/IRbtcBridge.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract TestPeginManager is Test, HelperContract {
    // Arrange
    // https://www.blockchain.com/explorer/blocks/btc/879500
    uint64 internal constant PACKET_NUMBER = 0;
    address internal constant RSK_DESTINATION_ADDRESS = 0x7Ac5496aee77c1bA1F0854206A26DdA82A81d6d8;
    uint64 internal setupStreamId;
    uint128 internal setupCommitteeId;
    Committee internal setupExpectedCommittee;

    function setUp() external {
        runTestDeployScript();
        (, Committee memory expectedCommittee, uint128 committeeId) = setup_completeCommitteeAndNewMembers();

        setupExpectedCommittee.aggregatedKey = expectedCommittee.aggregatedKey;
        setupExpectedCommittee.leaderAddress = expectedCommittee.leaderAddress;
        for (uint64 i = 0; i < expectedCommittee.members.length; i++) {
            setupExpectedCommittee.members.push(expectedCommittee.members[i]);
        }
        setupStreamId = expectedCommittee.streamId;
        setupCommitteeId = committeeId;
    }

    function test_getRequestPeginData_Success() external view {
        address dummyRskAddress = 0x7Ac5496aee77c1bA1F0854206A26DdA82A81d6d8;
        // Address is different according to amount and destination address
        string memory tempAddress = "bcrt1p9hdr74xdg69a7w6r4pfsrrnj3l7ku54x5jdmtwf4thnjyhkmeuhs79pnrw";

        (string memory result, uint64 packetNumber, bytes32[] memory memberDisputeKeys, uint64 availableSlots) =
            peginManager.getRequestPeginData(dummyRskAddress, VALUE, BTC_REIMBURSEMENT_PUBKEY);
        assertEq(result, tempAddress, "Incorrect temporary peg in address at PegManager");
        assertEq(packetNumber, PACKET_NUMBER, "Incorrect packet number at PegManager");
        assertEq(availableSlots, Constants.SLOTS_PER_PACKET, "Incorrect available slots for fresh packet");

        // Get the committee ID for the current packet
        uint128 currentCommitteeId = streamManager.getCommitteeId(setupStreamId, PACKET_NUMBER);

        // Get the actual committee members from the contract
        CommitteeMember[] memory committeeMembers = registry.getCommitteeMembers(currentCommitteeId);
        assertEq(memberDisputeKeys.length, committeeMembers.length, "Incorrect number of dispute keys");

        // Verify each dispute key matches the expected covenant key for that committee member
        IMemberRegistry memberRegistry = registry.memberRegistry();
        for (uint256 i = 0; i < committeeMembers.length; i++) {
            MemberKeys memory keys = memberRegistry.getMemberPublicKeys(committeeMembers[i].memberAddress);
            assertEq(memberDisputeKeys[i], keys.covenantPubKey, "Incorrect dispute key for committee member");
        }
    }

    function test_getRequestPeginData_Revert_BridgeExceededLockingCap() external {
        // Arrange
        address dummyRskAddress = 0x7Ac5496aee77c1bA1F0854206A26DdA82A81d6d8;
        uint64 testValue = VALUE; // 1_000_000 satoshis

        // Simulate that all capacity has been used (lockingCap will be 0)
        bridgeMock.setWeisTransferredToUnionBridge(400 ether);

        uint256 lockingCap = rbtcBridge.getUnionBridgeLockingCap();

        // Assert - expect revert with specific error
        vm.expectRevert(abi.encodeWithSelector(IPeginManager.BridgeExceededLockingCap.selector, testValue, lockingCap));

        // Act
        peginManager.getRequestPeginData(dummyRskAddress, testValue, BTC_REIMBURSEMENT_PUBKEY);
    }

    function test_requestPegin_Success() external {
        // Arrange
        (BtcTransaction memory btcTransaction,) = getBtcRequestPeginTx();
        bridgeMock.setBtcBlockchainBestChainHeight(BEST_CHAIN_HEIGHT);
        // Create Pegin struct information
        BtcTxSPVProof memory requestPeginTxSPVProof = createBtcTxSPVProof(btcTransaction);
        bytes32 expectedRequestPeginTxid = getBtcTxid(btcTransaction);
        bytes32 expectedAcceptPeginTxid = getBtcTxid(getBtcAcceptPeginTx(btcTransaction));
        bytes32 expectedAcceptPeginSignatureHash = hex"1a1fba8f81e68461425440126f33619691ce7dc26e7a2310543e5d7388db68da";
        bytes memory expectedAcceptPeginSignatureMessage =
            hex"00010200000000000000cca7f37cc7110cc0b507a5507ba2d8df3c539bb987b27e662bde2740048dc41120cb368f69e16a937d044c377b1f7fd5568bb167c478f5dbec16b25df5f66e424147566e5a4482ee0e3dcbae3fc237584ddfb58a3fd46c1c84b10f20a667227e82d397cbbcff87bc5d0c4c70e424f9b830efbad7bf0be479da5d1d1bafdb9798a7639b7aac9bfcebbaac4b8eb8685ed0c7ef5b017bd81e5c140868cbe0de2f5c0000000000";

        RequestPeginTempInfo memory expectedRequestPeginInfo = RequestPeginTempInfo({
            rskDestinationAddress: RSK_DESTINATION_ADDRESS,
            btcReimbursementPubKey: BTC_REIMBURSEMENT_PUBKEY,
            acceptPeginSignatureHash: expectedAcceptPeginSignatureHash,
            btcBlockNumber: BEST_CHAIN_HEIGHT - CONFIRMATIONS,
            userReimbursementTxid: bytes32(0),
            rejectPeginTxid: bytes32(0)
        });
        uint128 expectedCommitteeId = streamManager.getCommitteeId(setupStreamId, PACKET_NUMBER);

        // Assert
        vm.expectEmit(address(peginManager));
        emit IPeginManager.PeginRequested(
            expectedCommitteeId,
            expectedRequestPeginTxid,
            expectedAcceptPeginTxid,
            StreamPosition({
                streamId: setupStreamId,
                packetNumber: PACKET_NUMBER,
                slotId: 0, // First slot in packet
                pegStatus: PegStatus.REGISTERED
            }),
            expectedRequestPeginInfo,
            expectedAcceptPeginSignatureMessage
        );

        // Act
        peginManager.requestPegin(requestPeginTxSPVProof);

        // Assert
        bytes32 txid = getBtcTxid(btcTransaction);

        // Verify slot is properly reserved
        assertStreamPositionAndSlotStateByRequestPegin(txid, setupStreamId, PACKET_NUMBER, 0, SlotState.RESERVED);

        // Verify stream pointers haven't advanced (since packet not full)
        Stream memory stream = streamManager.getStreamById(setupStreamId);
        assertEq(stream.peginPacketPointer, 0, "Packet pointer should not advance for single request");

        BtcTransaction memory expectedAcceptPeginTx = getBtcAcceptPeginTx(btcTransaction);
        // Registered Request Pegin
        bytes32 acceptPeginTxid = peginManager.getAcceptPegin(txid);
        assertEq(acceptPeginTxid, getBtcTxid(expectedAcceptPeginTx), "Incorrect request pegin acceptPeginTxid");
        // Registered Peg In Temp info
        RequestPeginTempInfo memory peginTempInfo = peginManager.getRequestPeginTempInfo(txid);
        assertEq(
            peginTempInfo.rskDestinationAddress,
            RSK_DESTINATION_ADDRESS,
            "Incorrect peg in temp info destinationAddress"
        );
        assertEq(
            peginTempInfo.btcReimbursementPubKey,
            BTC_REIMBURSEMENT_PUBKEY,
            "Incorrect peg in temp info btcReimbursementPubKey"
        );
        assertEq(
            peginTempInfo.acceptPeginSignatureHash,
            expectedAcceptPeginSignatureHash,
            "Incorrect peg in temp info acceptPeginSignatureHash"
        );
        assertEq(peginTempInfo.userReimbursementTxid, bytes32(0), "Incorrect peg in temp info userReimbursementTxid");
        assertEq(peginTempInfo.rejectPeginTxid, bytes32(0), "Incorrect peg in temp info rejectPeginTxid");
    }

    function test_requestPegin_Revert_PeginAlreadyRequested() external {
        // Arrange
        (BtcTransaction memory btcTransaction,) = getBtcRequestPeginTx();

        // Create Pegin struct information
        BtcTxSPVProof memory requestPeginTxSPVProof = createBtcTxSPVProof(btcTransaction);

        // Register First Peg In Request
        peginManager.requestPegin(requestPeginTxSPVProof);

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(IPeginManager.PeginAlreadyRequested.selector, getBtcTxid(btcTransaction))
        );

        // Act Register Second Peg In Request
        peginManager.requestPegin(requestPeginTxSPVProof);
    }

    function test_requestPegin_Revert_NotEnoughConfirmations() external {
        // Arrange
        int256 actualConfirmations = 0;
        (BtcTransaction memory btcTransaction,) = getBtcRequestPeginTx();
        // Set Mock Bridge state
        bridgeMock.setBtcTransactionConfirmations(actualConfirmations);
        // Create Pegin struct information
        BtcTxSPVProof memory requestPeginTxSPVProof = createBtcTxSPVProof(btcTransaction);

        // Assert
        Stream memory stream = streamManager.getStream(VALUE);
        vm.expectRevert(
            abi.encodeWithSelector(
                ProofValidator.NotEnoughConfirmations.selector, actualConfirmations, stream.peginConfirmations
            )
        );
        // Act
        peginManager.requestPegin(requestPeginTxSPVProof);
    }

    function test_requestPegin_Revert_BridgeBtcTxInvalidMerkleBranch() external {
        // Arrange
        (BtcTransaction memory btcTransaction,) = getBtcRequestPeginTx();
        // Set Mock Bridge state
        bridgeMock.setBtcTransactionConfirmations(BTC_TRANSACTION_CONFIRMATION_INVALID_MERKLE_BRANCH_ERROR_CODE);
        // Create Pegin struct information
        BtcTxSPVProof memory requestPeginTxSPVProof = createBtcTxSPVProof(btcTransaction);

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                ProofValidator.BridgeBtcTxInvalidMerkleBranch.selector,
                getBtcTxid(btcTransaction),
                requestPeginTxSPVProof.merkleBranchPath,
                requestPeginTxSPVProof.merkleBranchHashes
            )
        );
        // Act
        peginManager.requestPegin(requestPeginTxSPVProof);
    }

    function test_requestPegin_Revert_IncorrectBtcTxVersion() external {
        // ===  Before test setup  is run for this  test ===
        // Arrange
        (BtcTransaction memory btcTransaction,) = getBtcRequestPeginTx();
        btcTransaction.version = 1;

        // Create Pegin struct information
        BtcTxSPVProof memory requestPeginTxSPVProof = createBtcTxSPVProof(btcTransaction);

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                IPeginManager.InvalidBtcTxVersion.selector, btcTransaction.version, Constants.BTC_TX_VERSION
            )
        );

        // Act
        peginManager.requestPegin(requestPeginTxSPVProof);
    }

    function test_requestPegin_Revert_IncorrectLocktime() external {
        // ===  Before test setup  is run for this  test ===
        // Arrange
        (BtcTransaction memory btcTransaction,) = getBtcRequestPeginTx();
        btcTransaction.locktime = 1;

        // Create Pegin struct information
        BtcTxSPVProof memory requestPeginTxSPVProof = createBtcTxSPVProof(btcTransaction);
        requestPeginTxSPVProof.merkleBranchHashes[0] =
            0x3fcef4a1ddf759a858190b89ecbd1ff3dffb49704e110b68baf5b5de7021910f;

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(IPeginManager.InvalidLocktime.selector, btcTransaction.locktime, Constants.LOCKTIME)
        );

        // Act
        peginManager.requestPegin(requestPeginTxSPVProof);
    }

    function test_acceptPegin_Revert_PeginNotRequested() external {
        (BtcTransaction memory btcTx,) = HelperContract.getBtcRequestPeginTx();

        // Arrange
        BtcTransaction memory btcTransaction = getBtcAcceptPeginTx(btcTx);

        // Create Pegin struct information
        BtcTxSPVProof memory peginAcceptedTxSPVProof = createBtcTxSPVProof(btcTransaction);

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(IPegManagerBase.PeginNotRequested.selector, btcTransaction.inputs[0].txId)
        );

        // Act
        peginManager.acceptPegin(peginAcceptedTxSPVProof);
    }

    function test_acceptPegin_newPacketCreated() external {
        // Arrange
        // Create pegins until the new packet threshold is reached
        setup_multipleRequestAndAcceptPeginFlows(Constants.SLOT_USAGE_THRESHOLD - 1);
        Committee memory expectedCommittee = setup_getExpectedSecondCommittee();

        // Arrange
        (BtcTransaction memory peginTx,) = setup_requestPeginFlow();
        BtcTransaction memory btcTransaction = getBtcAcceptPeginTx(peginTx);
        // Create Pegin accepted tx struct information
        BtcTxSPVProof memory peginAcceptedTxSPVProof = createBtcTxSPVProof(btcTransaction);
        uint128 committeeId = COMMITTEE_ID_STREAM_1_COMMITTEE_2;
        vm.roll(BLOCK_COMMITTEE_2);
        vm.warp(BLOCK_COMMITTEE_2);

        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.NewPendingCommittee(committeeId, expectedCommittee);

        // Act
        peginManager.acceptPegin(peginAcceptedTxSPVProof);

        // Now we should provide members info to create the committee/packet. This works with second group of members, their indexes start at registry.committeeMemberCount()
        uint256 memberIndexStart = registry.committeeMemberCount();
        uint256 memberCount = registry.committeeMemberCount() - 1;
        setup_depositAggregatedKey_MultipleMembers(committeeId, memberIndexStart, memberCount);

        // Update expected committee with aggregated key
        expectedCommittee.aggregatedKey = COMMITTEE_PUB_KEY();
        expectedCommittee.missingData = 0;
        expectedCommittee.isPending = false;
        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.NewCommittee(committeeId, expectedCommittee);

        vm.expectEmit(address(streamManager));
        emit IStreamManager.PacketCreated(setupStreamId, 1);

        vm.prank(vm.addr(registry.committeeMemberCount() * 2));
        registry.depositAggregatedKey(committeeId, COMMITTEE_PUB_KEY());
    }

    function test_acceptPegin_newPacketUsed() external {
        // Arrange
        // Create pegins until the new packet treshold is reached
        setup_multipleRequestAndAcceptPeginFlows(Constants.SLOTS_PER_PACKET);
        // Members must deposite their info to create new packet
        uint256 memberIndexStart = registry.committeeMemberCount();
        uint256 memberCount = registry.committeeMemberCount();
        setup_depositAggregatedKey_MultipleMembers(COMMITTEE_ID_STREAM_1_COMMITTEE_2, memberIndexStart, memberCount);

        // Arrange
        (BtcTransaction memory peginTx,) = setup_requestPeginFlow();
        BtcTransaction memory btcTransaction = getBtcAcceptPeginTx(peginTx);
        // Create Pegin accepted tx struct information
        BtcTxSPVProof memory peginAcceptedTxSPVProof = createBtcTxSPVProof(btcTransaction);

        // Assert
        vm.expectEmit(address(peginManager));
        // We emit the event we expect to see.
        bytes32 requestPeginTxid = peginAcceptedTxSPVProof.btcTx.inputs[0].txId;
        bytes32 acceptPeginTxid = HelperContract.getBtcTxid(btcTransaction);
        uint64 packetId = 1;
        uint64 slotId = 0;
        emit IPeginManager.PeginAccepted(
            peginAcceptedTxSPVProof.blockHash,
            acceptPeginTxid,
            requestPeginTxid,
            0, //vout
            StreamPosition({
                streamId: setupStreamId,
                packetNumber: packetId,
                slotId: slotId,
                pegStatus: PegStatus.ACCEPTED
            }),
            BTC_REIMBURSEMENT_PUBKEY,
            RSK_DESTINATION_ADDRESS,
            satoshiToWei(btcTransaction.outputs[0].amount), // Rbtc amount
            btcTransaction.outputs[0].scriptPubKey
        );
        // Act
        peginManager.acceptPegin(peginAcceptedTxSPVProof);
    }

    function test_acceptPegin_Success() external {
        // ===  Before test setup  is run for this  test ===
        (BtcTransaction memory peginTx,) = setup_requestPeginFlow();
        // Arrange
        BtcTransaction memory btcTransaction = getBtcAcceptPeginTx(peginTx);

        // Create Pegin struct information
        BtcTxSPVProof memory peginAcceptedTxSPVProof = createBtcTxSPVProof(btcTransaction);

        // Assert
        vm.expectEmit(address(peginManager));

        // We emit the event we expect to see.
        bytes32 requestPeginTxid = peginAcceptedTxSPVProof.btcTx.inputs[0].txId;
        bytes32 acceptPeginTxid = getBtcTxid(btcTransaction);
        uint64 streamId = 1;
        uint64 slotId = 0;
        emit IPeginManager.PeginAccepted(
            peginAcceptedTxSPVProof.blockHash,
            acceptPeginTxid,
            requestPeginTxid,
            0, //vout
            StreamPosition({
                streamId: streamId,
                packetNumber: PACKET_NUMBER,
                slotId: slotId,
                pegStatus: PegStatus.ACCEPTED
            }),
            BTC_REIMBURSEMENT_PUBKEY,
            RSK_DESTINATION_ADDRESS,
            satoshiToWei(btcTransaction.outputs[0].amount), // Rbtc amount
            btcTransaction.outputs[0].scriptPubKey
        );

        // Act
        peginManager.acceptPegin(peginAcceptedTxSPVProof);

        // Assert
        // Registered Peg In Stream Position
        StreamPosition memory streamPosition = peginManager.getStreamPositionByRequestPegin(requestPeginTxid);
        assertEq(streamPosition.streamId, streamId, "Incorrect streamId registered");
        assertEq(streamPosition.packetNumber, PACKET_NUMBER, "Incorrect packetNumber registered");
        assertEq(streamPosition.slotId, slotId, "Incorrect slotId registered");
        assertEq(uint256(streamPosition.pegStatus), uint256(PegStatus.ACCEPTED), "Request Pegin was not accepted");
        // Registered Peg In Slot
        Slot memory slot = streamManager.getSlot(streamId, PACKET_NUMBER, slotId);
        assertEq(uint256(slot.state), uint256(SlotState.FILLED), "Slot should be filled");
        assertEq(slot.slotId, streamPosition.slotId, "Slot ID should match StreamPosition");
        assertEq(slot.acceptPeginTx, acceptPeginTxid, "Incorrect acceptPeginTx");
        assertEq(slot.acceptPeginAmount, btcTransaction.outputs[0].amount, "Incorrect acceptPeginAmount");
        assertEq(slot.scriptPubKey, btcTransaction.outputs[0].scriptPubKey, "Incorrect scriptPubKey");
    }

    function test_acceptPegin_Revert_PeginAlreadyAccepted() external {
        setup_requestPeginFlow();

        // ===  Before test setup  is run for this  test ===
        (BtcTransaction memory peginTx,) = setup_requestPeginFlow();
        // Arrange
        BtcTransaction memory btcTransaction = getBtcAcceptPeginTx(peginTx);

        // Create Pegin struct information
        BtcTxSPVProof memory peginAcceptedTxSPVProof = createBtcTxSPVProof(btcTransaction);

        // Register First  Accept Peg In Request
        peginManager.acceptPegin(peginAcceptedTxSPVProof);

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(IPeginManager.PeginAlreadyAccepted.selector, btcTransaction.inputs[0].txId)
        );

        // Act Register Second Accept Peg In Request
        peginManager.acceptPegin(peginAcceptedTxSPVProof);
    }

    function test_acceptPegin_Revert_InvalidAcceptPeginTxid() external {
        setup_requestPeginFlow();

        // ===  Before test setup  is run for this  test ===
        (BtcTransaction memory peginTx,) = setup_requestPeginFlow();
        // Arrange
        BtcTransaction memory btcTransaction = getBtcAcceptPeginTx(peginTx);
        bytes32 expectedAcceptPeginTxid = bitcoinManager.getBtcTxid(btcTransaction);
        btcTransaction.outputs[0].scriptPubKey = hex"111111b4045c40a133ee361f766ceae4d82398fc5058";
        bytes32 actualAcceptPeginTxid = bitcoinManager.getBtcTxid(btcTransaction);

        // Create Pegin accepted tx struct information
        BtcTxSPVProof memory peginAcceptedTxSPVProof = createBtcTxSPVProof(btcTransaction);

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                IPeginManager.InvalidAcceptPeginTxid.selector, expectedAcceptPeginTxid, actualAcceptPeginTxid
            )
        );

        // Act
        peginManager.acceptPegin(peginAcceptedTxSPVProof);
    }

    function test_acceptPegin_Revert_Revert_NotEnoughConfirmations() external {
        // ===  Before test setup  is run for this  test ===
        (BtcTransaction memory peginTx,) = setup_requestPeginFlow();
        // Arrange
        BtcTransaction memory btcTransaction = getBtcAcceptPeginTx(peginTx);
        int256 actualConfirmations = 0;
        // Set Mock Bridge state
        bridgeMock.setBtcTransactionConfirmations(actualConfirmations);
        // Create Pegin accepted tx struct information
        BtcTxSPVProof memory peginAcceptedTxSPVProof = createBtcTxSPVProof(btcTransaction);
        Stream memory stream = streamManager.getStreamById(0);
        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                ProofValidator.NotEnoughConfirmations.selector, actualConfirmations, stream.peginConfirmations
            )
        );

        // Act
        peginManager.acceptPegin(peginAcceptedTxSPVProof);
    }

    function test_requestPegin_MultipleSlots_SamePacket() external {
        // Make Constants.SLOTS_PER_PACKET - 1 requests
        for (uint64 i = 0; i < Constants.SLOTS_PER_PACKET - 1; i++) {
            (BtcTransaction memory btcTransaction,) = getBtcRequestPeginTx();
            // Modify tx to make each unique
            btcTransaction.inputs[0].scriptSig = abi.encodePacked(bytes32(uint256(i + 1)));
            BtcTxSPVProof memory requestPeginTxSPVProof = createBtcTxSPVProof(btcTransaction);

            peginManager.requestPegin(requestPeginTxSPVProof);

            // Verify each request gets correct slotId
            bytes32 requestPeginTxid = getBtcTxid(btcTransaction);
            StreamPosition memory streamPosition = peginManager.getStreamPositionByRequestPegin(requestPeginTxid);
            assertEq(streamPosition.slotId, i, "SlotId should increment for each request");
            assertEq(streamPosition.packetNumber, 0, "Should stay in same packet");

            // Verify slot is RESERVED
            Slot memory reservedSlot =
                streamManager.getSlot(streamPosition.streamId, streamPosition.packetNumber, streamPosition.slotId);
            assertEq(uint256(reservedSlot.state), uint256(SlotState.RESERVED), "Each slot should be RESERVED");
        }

        // Verify packet pointer hasn't advanced
        Stream memory stream = streamManager.getStreamById(setupStreamId);
        assertEq(stream.peginPacketPointer, 0, "Packet pointer should not advance until packet full");
    }

    function test_requestPegin_PacketAdvancement() external {
        // Fill up the packet
        for (uint64 i = 0; i < Constants.SLOTS_PER_PACKET; i++) {
            (BtcTransaction memory btcTransaction,) = getBtcRequestPeginTx();
            btcTransaction.inputs[0].scriptSig = abi.encodePacked(bytes32(uint256(i + 1)));
            BtcTxSPVProof memory requestPeginTxSPVProof = createBtcTxSPVProof(btcTransaction);

            peginManager.requestPegin(requestPeginTxSPVProof);
        }

        // Verify packet pointer has advanced
        Stream memory stream = streamManager.getStreamById(setupStreamId);
        assertEq(stream.peginPacketPointer, 1, "Packet pointer should advance after packet is full");
    }

    function test_acceptPegin_UsesSpecificSlotId() external {
        // 1. Make multiple request pegins
        (BtcTransaction memory peginTx1,) = getBtcRequestPeginTx();
        peginTx1.inputs[0].scriptSig = abi.encodePacked(bytes32(uint256(1)));
        BtcTxSPVProof memory requestPeginTxSPVProof1 = createBtcTxSPVProof(peginTx1);
        peginManager.requestPegin(requestPeginTxSPVProof1);
        bytes32 requestPeginTxid1 = getBtcTxid(peginTx1);

        (BtcTransaction memory peginTx2,) = getBtcRequestPeginTx();
        peginTx2.inputs[0].scriptSig = abi.encodePacked(bytes32(uint256(2)));
        BtcTxSPVProof memory requestPeginTxSPVProof2 = createBtcTxSPVProof(peginTx2);
        peginManager.requestPegin(requestPeginTxSPVProof2);
        bytes32 requestPeginTxid2 = getBtcTxid(peginTx2);

        // 2. Accept only the second pegin transaction
        BtcTransaction memory acceptTx2 = getBtcAcceptPeginTx(peginTx2);
        BtcTxSPVProof memory acceptPeginTxSPVProof2 = createBtcTxSPVProof(acceptTx2);
        peginManager.acceptPegin(acceptPeginTxSPVProof2);

        // 3. Verify correct slot is filled (slot 1, not slot 0)
        assertStreamPositionAndSlotStateByRequestPegin(
            requestPeginTxid2, setupStreamId, PACKET_NUMBER, 1, SlotState.FILLED
        );

        // 4. Verify first slot remains in RESERVED state
        assertStreamPositionAndSlotStateByRequestPegin(
            requestPeginTxid1, setupStreamId, PACKET_NUMBER, 0, SlotState.RESERVED
        );
    }

    function test_acceptPegin_Revert_SlotBlocked() external {
        // 1. Request pegin to reserve slot
        (BtcTransaction memory peginTx,) = setup_requestPeginFlow();
        bytes32 requestPeginTxid = getBtcTxid(peginTx);
        StreamPosition memory streamPosition = peginManager.getStreamPositionByRequestPegin(requestPeginTxid);

        // 2. Block the slot externally
        vm.prank(address(peginManager));
        streamManager.blockSlot(streamPosition.streamId, streamPosition.packetNumber, streamPosition.slotId);

        // 3. Try to accept pegin
        BtcTransaction memory acceptTx = getBtcAcceptPeginTx(peginTx);
        BtcTxSPVProof memory acceptPeginTxSPVProof = createBtcTxSPVProof(acceptTx);

        // 4. Expect SlotNotReserved revert
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamManager.SlotNotReserved.selector,
                streamPosition.streamId,
                streamPosition.packetNumber,
                streamPosition.slotId,
                SlotState.BLOCKED
            )
        );
        peginManager.acceptPegin(acceptPeginTxSPVProof);
    }

    function test_setStreamManager_Success() external {
        // Arrange
        uint256 privKey = uint256(1);
        address newStreamManagerAddress = vm.addr(privKey);
        IStreamManager newStreamManager = IStreamManager(newStreamManagerAddress);
        address owner = peginManager.owner();

        // Assert
        vm.expectEmit(address(peginManager));
        emit IPegManagerBase.StreamManagerUpdated(newStreamManager);

        // Act
        vm.prank(owner);
        peginManager.setStreamManager(newStreamManager);

        // Assert
        assertEq(address(peginManager.streamManager()), newStreamManagerAddress);
    }

    function test_setStreamManager_Success_PausedContract() external {
        // Arrange
        uint256 privKey = uint256(1);
        address newStreamManagerAddress = vm.addr(privKey);
        StreamManagerHarness newStreamManager = StreamManagerHarness(newStreamManagerAddress);
        pauseContracts();

        // Assert
        vm.prank(peginManager.owner());
        vm.expectEmit(address(peginManager));
        emit IPegManagerBase.StreamManagerUpdated(newStreamManager);

        // Act
        peginManager.setStreamManager(newStreamManager);

        // Assert
        assertEq(address(peginManager.streamManager()), newStreamManagerAddress);
    }

    function test_setStreamManager_Revert_AddressZero() external {
        // Arrange
        address owner = peginManager.owner();
        IStreamManager zeroStreamManager = IStreamManager(address(0));

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IPegManagerBase.StreamManagerAddressZero.selector));

        // Act
        vm.prank(owner);
        peginManager.setStreamManager(zeroStreamManager);
    }

    function test_setStreamManager_Revert_OwnableUnauthorizedAccount() external {
        // Arrange
        uint256 privKey = uint256(1);
        address newStreamManagerAddress = vm.addr(privKey);
        IStreamManager newStreamManager = IStreamManager(newStreamManagerAddress);

        // Assert
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));

        // Act
        peginManager.setStreamManager(newStreamManager);
    }

    function test_setSignatureManager_Success() external {
        // Arrange
        uint256 privKey = uint256(1);
        address newSignatureManagerAddress = vm.addr(privKey);
        ISignatureManager newSignatureManager = ISignatureManager(newSignatureManagerAddress);
        address owner = peginManager.owner();

        // Assert
        vm.expectEmit(address(peginManager));
        emit IPegManagerBase.SignatureManagerUpdated(newSignatureManager);

        // Act
        vm.prank(owner);
        peginManager.setSignatureManager(newSignatureManager);

        // Assert
        assertEq(address(peginManager.signatureManager()), newSignatureManagerAddress);
    }

    function test_setSignatureManager_Success_PausedContract() external {
        // Arrange
        uint256 privKey = uint256(1);
        address newSignatureManagerAddress = vm.addr(privKey);
        ISignatureManager newSignatureManager = ISignatureManager(newSignatureManagerAddress);

        pauseContracts();

        // Assert
        vm.prank(peginManager.owner());
        vm.expectEmit(address(peginManager));
        emit IPegManagerBase.SignatureManagerUpdated(newSignatureManager);

        // Act
        peginManager.setSignatureManager(newSignatureManager);

        // Assert
        assertEq(address(peginManager.signatureManager()), newSignatureManagerAddress);
    }

    function test_setSignatureManager_Revert_AddressZero() external {
        // Arrange
        address owner = peginManager.owner();
        ISignatureManager zeroSignatureManager = ISignatureManager(address(0));

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IPegManagerBase.SignatureManagerAddressZero.selector));

        // Act
        vm.prank(owner);
        peginManager.setSignatureManager(zeroSignatureManager);
    }

    function test_setSignatureManager_Revert_OwnableUnauthorizedAccount() external {
        // Arrange
        uint256 privKey = uint256(1);
        address newSignatureManagerAddress = vm.addr(privKey);
        ISignatureManager newSignatureManager = ISignatureManager(newSignatureManagerAddress);

        // Assert
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));

        // Act
        peginManager.setSignatureManager(newSignatureManager);
    }

    function test_setPauser_Success() external {
        // Arrange
        uint256 privKey = uint256(1);
        address newPauser = vm.addr(privKey);
        address owner = peginManager.owner();

        // Assert
        vm.expectEmit(address(peginManager));
        emit Pausable.PauserUpdated(newPauser);

        // Act
        vm.prank(owner);
        peginManager.setPauser(newPauser);

        // Assert
        assertEq(peginManager.pauser(), newPauser);
    }

    function test_setPauser_Success_PausedContract() external {
        // Arrange
        pauseContracts();

        uint256 privKey = uint256(1);
        address newPauser = vm.addr(privKey);
        address owner = peginManager.owner();

        // Assert
        vm.expectEmit(address(peginManager));
        emit Pausable.PauserUpdated(newPauser);

        // Act
        vm.prank(owner);
        peginManager.setPauser(newPauser);

        // Assert
        assertEq(peginManager.pauser(), newPauser);
    }

    function test_setPauser_Revert_OwnableUnauthorizedAccount() external {
        // Arrange
        uint256 privKey = uint256(1);
        address newPauser = vm.addr(privKey);

        // Assert
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));

        // Act
        peginManager.setPauser(newPauser);
    }

    function test_requestPegin_Revert_EnforcedPause_PausedContract() external {
        // Arrange
        (BtcTransaction memory btcTransaction,) = getBtcRequestPeginTx();
        BtcTxSPVProof memory requestPeginTxSPVProof = createBtcTxSPVProof(btcTransaction);

        pauseContracts();

        // Assert
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);

        // Act
        peginManager.requestPegin(requestPeginTxSPVProof);
    }

    function test_requestPegin_Success_UnpausedContract() external {
        // Arrange
        (BtcTransaction memory btcTransaction,) = getBtcRequestPeginTx();
        BtcTxSPVProof memory requestPeginTxSPVProof = createBtcTxSPVProof(btcTransaction);

        pauseAndUnpauseContracts();

        // Act
        peginManager.requestPegin(requestPeginTxSPVProof);

        // Assert
        assertStreamPositionAndSlotStateByRequestPegin(
            getBtcTxid(btcTransaction), setupStreamId, PACKET_NUMBER, 0, SlotState.RESERVED
        );
    }

    function test_acceptPegin_Revert_EnforcedPause_PausedContract() external {
        // Arrange
        (BtcTransaction memory peginTx,) = setup_requestPeginFlow();
        BtcTransaction memory btcTransaction = getBtcAcceptPeginTx(peginTx);
        BtcTxSPVProof memory peginAcceptedTxSPVProof = createBtcTxSPVProof(btcTransaction);

        pauseContracts();

        // Assert
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);

        // Act
        peginManager.acceptPegin(peginAcceptedTxSPVProof);
    }

    function test_acceptPegin_Success_UnpausedContract() external {
        // Arrange
        (BtcTransaction memory peginTx,) = setup_requestPeginFlow();
        BtcTransaction memory btcTransaction = getBtcAcceptPeginTx(peginTx);
        BtcTxSPVProof memory peginAcceptedTxSPVProof = createBtcTxSPVProof(btcTransaction);

        pauseAndUnpauseContracts();

        // Act & Assert
        peginManager.acceptPegin(peginAcceptedTxSPVProof);
    }

    // ============ RbtcBridge Integration Tests ============

    function test_acceptPegin_RbtcBridgeIntegration() external {
        // Arrange
        (BtcTransaction memory peginTx,) = setup_requestPeginFlow();
        BtcTransaction memory btcTransaction = getBtcAcceptPeginTx(peginTx);
        BtcTxSPVProof memory peginAcceptedTxSPVProof = createBtcTxSPVProof(btcTransaction);

        bytes32 requestPeginTxid = peginAcceptedTxSPVProof.btcTx.inputs[0].txId;
        uint256 recipientBalanceBefore = RSK_DESTINATION_ADDRESS.balance;

        // Act
        peginManager.acceptPegin(peginAcceptedTxSPVProof);

        // Assert - verify the amount minted equals acceptPeginAmount (after fees)
        StreamPosition memory streamPosition = peginManager.getStreamPositionByRequestPegin(requestPeginTxid);
        Slot memory slot =
            streamManager.getSlot(streamPosition.streamId, streamPosition.packetNumber, streamPosition.slotId);

        uint256 acceptPeginAmountInWei = satoshiToWei(slot.acceptPeginAmount);

        // Verify RBTC was sent to correct recipient with correct amount
        assertEq(
            RSK_DESTINATION_ADDRESS.balance,
            recipientBalanceBefore + acceptPeginAmountInWei,
            "RBTC not sent to correct recipient or wrong amount"
        );
    }

    function test_acceptPegin_Revert_BridgeExceededLockingCap() external {
        // Arrange
        (BtcTransaction memory peginTx,) = setup_requestPeginFlow();
        BtcTransaction memory btcTransaction = getBtcAcceptPeginTx(peginTx);
        BtcTxSPVProof memory peginAcceptedTxSPVProof = createBtcTxSPVProof(btcTransaction);

        uint256 amount = satoshiToWei(btcTransaction.outputs[0].amount);

        // Simulate that all capacity has been used (lockingCap will be 0)
        bridgeMock.setWeisTransferredToUnionBridge(400 ether);

        // Assert - expect revert with specific error
        vm.expectRevert(abi.encodeWithSelector(IRbtcBridge.BridgeExceededLockingCap.selector, amount));

        // Act
        peginManager.acceptPegin(peginAcceptedTxSPVProof);
    }

    function test_acceptPegin_Revert_BridgeTransfersDisabled() external {
        // Arrange
        (BtcTransaction memory peginTx,) = setup_requestPeginFlow();
        BtcTransaction memory btcTransaction = getBtcAcceptPeginTx(peginTx);
        BtcTxSPVProof memory peginAcceptedTxSPVProof = createBtcTxSPVProof(btcTransaction);

        // Disable transfers on the bridge
        bridgeMock.setTransfersDisabled(true);

        // Assert - expect revert with specific error
        vm.expectRevert(IRbtcBridge.BridgeTransfersDisabled.selector);

        // Act
        peginManager.acceptPegin(peginAcceptedTxSPVProof);
    }

    // ============ Register User Reimbursement Tests ============
    function test_userReimbursement_Success() external {
        // Arrange
        (BtcTransaction memory requestPeginTx,) = setup_requestPeginFlow();
        bytes32 requestPeginTxid = getBtcTxid(requestPeginTx);

        BtcTransaction memory userReimbursementTx = getBtcUserReimbursementTx(requestPeginTxid);
        uint32 reimbursementPeginVin = userReimbursementTx.inputs[0].vout;
        bytes32 userReimbursementTxid = getBtcTxid(userReimbursementTx);
        BtcTxSPVProof memory userReimbursementTxSPVProof = createBtcTxSPVProof(userReimbursementTx);

        pauseAndUnpauseContracts();

        // Get stream position
        StreamPosition memory streamPositionBefore = peginManager.getStreamPositionByRequestPegin(requestPeginTxid);

        // Assert - expect event
        vm.expectEmit(address(peginManager));
        emit IPeginManager.UserReimbursementRegistered(userReimbursementTxid, requestPeginTxid, streamPositionBefore);

        // Act
        peginManager.userReimbursement(userReimbursementTxSPVProof, reimbursementPeginVin);

        // Assert - verify slot is blocked
        StreamPosition memory streamPositionAfter = peginManager.getStreamPositionByRequestPegin(requestPeginTxid);
        assertEq(
            uint256(streamPositionAfter.pegStatus),
            uint256(PegStatus.BLOCKED),
            "Stream position status should be BLOCKED"
        );
        Slot memory slot = streamManager.getSlot(
            streamPositionAfter.streamId, streamPositionAfter.packetNumber, streamPositionAfter.slotId
        );
        assertEq(uint256(slot.state), uint256(SlotState.BLOCKED), "Slot should be BLOCKED after user reimbursement");

        // Verify user reimbursement txid is stored
        RequestPeginTempInfo memory peginTempInfo = peginManager.getRequestPeginTempInfo(requestPeginTxid);
        assertEq(peginTempInfo.userReimbursementTxid, userReimbursementTxid, "User reimbursement txid should be stored");
    }

    function test_userReimbursement_Revert_PeginNotRequested() external {
        // Arrange
        (BtcTransaction memory requestPeginTx,) = getBtcRequestPeginTx();
        bytes32 requestPeginTxid = getBtcTxid(requestPeginTx);
        BtcTransaction memory userReimbursementTx = getBtcUserReimbursementTx(requestPeginTxid);
        uint32 reimbursementPeginVin = userReimbursementTx.inputs[0].vout;

        BtcTxSPVProof memory userReimbursementTxSPVProof = createBtcTxSPVProof(userReimbursementTx);

        // Assert - expect revert
        vm.expectRevert(abi.encodeWithSelector(IPegManagerBase.PeginNotRequested.selector, bytes32(0)));

        // Act
        peginManager.userReimbursement(userReimbursementTxSPVProof, reimbursementPeginVin);
    }

    function test_userReimbursement_Revert_PeginAlreadyAccepted() external {
        // Arrange
        (BtcTransaction memory requestPeginTx,) = setup_requestPeginFlow();
        bytes32 requestPeginTxid = getBtcTxid(requestPeginTx);

        // Accept the pegin first
        BtcTransaction memory acceptPeginTx = getBtcAcceptPeginTx(requestPeginTx);
        BtcTxSPVProof memory acceptPeginTxSPVProof = createBtcTxSPVProof(acceptPeginTx);
        peginManager.acceptPegin(acceptPeginTxSPVProof);

        // Now try to register user reimbursement
        BtcTransaction memory userReimbursementTx = getBtcUserReimbursementTx(requestPeginTxid);
        uint32 reimbursementPeginVin = userReimbursementTx.inputs[0].vout;
        BtcTxSPVProof memory userReimbursementTxSPVProof = createBtcTxSPVProof(userReimbursementTx);

        // Assert - expect revert with PeginInvalidStatus
        vm.expectRevert(abi.encodeWithSelector(IPegManagerBase.InvalidPegStatus.selector, PegStatus.ACCEPTED));

        // Act
        peginManager.userReimbursement(userReimbursementTxSPVProof, reimbursementPeginVin);
    }

    function test_userReimbursement_Revert_InvalidUserReimbursementTx() external {
        // Arrange
        uint32 reimbursementPeginVin = 0;
        (BtcTransaction memory requestPeginTx,) = setup_requestPeginFlow();
        BtcTransaction memory btcTransaction = getBtcAcceptPeginTx(requestPeginTx);

        BtcTxSPVProof memory acceptPeginTxSPVProof = createBtcTxSPVProof(btcTransaction);
        bytes32 acceptPeginTxid = getBtcTxid(btcTransaction);
        bytes32 expectedUserReimbursementTxid = acceptPeginTxid;

        // Assert - expect revert
        vm.expectRevert(
            abi.encodeWithSelector(IPeginManager.InvalidUserReimbursementTx.selector, expectedUserReimbursementTxid)
        );

        // Act - register accept pegin as user reimbursement
        peginManager.userReimbursement(acceptPeginTxSPVProof, reimbursementPeginVin);
    }

    function test_userReimbursement_Revert_NotEnoughConfirmations() external {
        // Arrange
        (BtcTransaction memory requestPeginTx,) = setup_requestPeginFlow();
        bytes32 requestPeginTxid = getBtcTxid(requestPeginTx);

        BtcTransaction memory userReimbursementTx = getBtcUserReimbursementTx(requestPeginTxid);
        uint32 reimbursementPeginVin = userReimbursementTx.inputs[0].vout;
        int256 actualConfirmations = 0;
        bridgeMock.setBtcTransactionConfirmations(actualConfirmations);
        BtcTxSPVProof memory userReimbursementTxSPVProof = createBtcTxSPVProof(userReimbursementTx);

        StreamPosition memory streamPosition = peginManager.getStreamPositionByRequestPegin(requestPeginTxid);
        Stream memory stream = streamManager.getStreamById(streamPosition.streamId);

        // Assert - expect revert
        vm.expectRevert(
            abi.encodeWithSelector(
                ProofValidator.NotEnoughConfirmations.selector, actualConfirmations, stream.peginConfirmations
            )
        );

        // Act
        peginManager.userReimbursement(userReimbursementTxSPVProof, reimbursementPeginVin);
    }

    function test_userReimbursement_Revert_EnforcedPause_PausedContract() external {
        // Arrange
        (BtcTransaction memory requestPeginTx,) = setup_requestPeginFlow();
        bytes32 requestPeginTxid = getBtcTxid(requestPeginTx);
        BtcTransaction memory userReimbursementTx = getBtcUserReimbursementTx(requestPeginTxid);
        uint32 reimbursementPeginVin = userReimbursementTx.inputs[0].vout;
        BtcTxSPVProof memory userReimbursementTxSPVProof = createBtcTxSPVProof(userReimbursementTx);

        pauseContracts();

        // Assert
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);

        // Act
        peginManager.userReimbursement(userReimbursementTxSPVProof, reimbursementPeginVin);
    }

    function test_userReimbursement_Revert_BridgeBtcTxInvalidMerkleBranch() external {
        // Arrange
        (BtcTransaction memory requestPeginTx,) = setup_requestPeginFlow();
        bytes32 requestPeginTxid = getBtcTxid(requestPeginTx);
        BtcTransaction memory userReimbursementTx = getBtcUserReimbursementTx(requestPeginTxid);
        uint32 reimbursementPeginVin = userReimbursementTx.inputs[0].vout;
        bytes32 userReimbursementTxid = getBtcTxid(userReimbursementTx);

        // Set Mock Bridge state to invalid merkle branch
        bridgeMock.setBtcTransactionConfirmations(BTC_TRANSACTION_CONFIRMATION_INVALID_MERKLE_BRANCH_ERROR_CODE);
        BtcTxSPVProof memory userReimbursementTxSPVProof = createBtcTxSPVProof(userReimbursementTx);

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                ProofValidator.BridgeBtcTxInvalidMerkleBranch.selector,
                userReimbursementTxid,
                userReimbursementTxSPVProof.merkleBranchPath,
                userReimbursementTxSPVProof.merkleBranchHashes
            )
        );

        // Act
        peginManager.userReimbursement(userReimbursementTxSPVProof, reimbursementPeginVin);
    }

    function test_userReimbursement_Revert_AlreadyRegistered() external {
        // Arrange
        (BtcTransaction memory requestPeginTx,) = setup_requestPeginFlow();
        bytes32 requestPeginTxid = getBtcTxid(requestPeginTx);
        BtcTransaction memory userReimbursementTx = getBtcUserReimbursementTx(requestPeginTxid);
        uint32 reimbursementPeginVin = userReimbursementTx.inputs[0].vout;
        BtcTxSPVProof memory userReimbursementTxSPVProof = createBtcTxSPVProof(userReimbursementTx);

        // Register first time
        peginManager.userReimbursement(userReimbursementTxSPVProof, reimbursementPeginVin);

        // Try to register again - should revert because slot is already blocked
        // Assert - expect revert with InvalidPegStatus (since slot is now BLOCKED, not RESERVED)
        vm.expectRevert(abi.encodeWithSelector(IPegManagerBase.InvalidPegStatus.selector, PegStatus.BLOCKED));

        // Act
        peginManager.userReimbursement(userReimbursementTxSPVProof, reimbursementPeginVin);
    }

    function test_userReimbursement_Revert_IncorrectVout() external {
        // Arrange
        (BtcTransaction memory requestPeginTx,) = setup_requestPeginFlow();
        bytes32 requestPeginTxid = getBtcTxid(requestPeginTx);

        // Create a user reimbursement tx with incorrect vout (using vout 1 instead of 0)
        BtcTransaction memory userReimbursementTx = getBtcUserReimbursementTx(requestPeginTxid);
        uint32 reimbursementPeginVin = userReimbursementTx.inputs[0].vout;
        uint32 incorrectVout = reimbursementPeginVin + 1;
        userReimbursementTx.inputs[0].vout = incorrectVout;

        BtcTxSPVProof memory userReimbursementTxSPVProof = createBtcTxSPVProof(userReimbursementTx);

        // Assert - expect revert with IncorrectVout
        vm.expectRevert(
            abi.encodeWithSelector(IPeginManager.IncorrectVout.selector, incorrectVout, reimbursementPeginVin)
        );

        // Act
        peginManager.userReimbursement(userReimbursementTxSPVProof, reimbursementPeginVin);
    }

    function test_userReimbursement_Revert_UserReimbursementBeforeTimelock() external {
        // Arrange
        (BtcTransaction memory requestPeginTx,) = setup_requestPeginFlow();
        bytes32 requestPeginTxid = getBtcTxid(requestPeginTx);

        // Get the stream to check timelock settings
        StreamPosition memory streamPosition = peginManager.getStreamPositionByRequestPegin(requestPeginTxid);
        Stream memory stream = streamManager.getStreamById(streamPosition.streamId);
        uint256 requestPeginTimelock = stream.timelockSettings.requestPeginTimelock;

        // Get the btcBlockNumber stored when request pegin was made
        RequestPeginTempInfo memory peginTempInfo = peginManager.getRequestPeginTempInfo(requestPeginTxid);
        int256 requestPeginBlockNumber = peginTempInfo.btcBlockNumber;

        // Set confirmations high enough to pass _verifyTxConfirmations but make blocksElapsed < timelock
        int256 userReimbursementConfirmations = CONFIRMATIONS + 1; // 11 confirmations
        bridgeMock.setBtcTransactionConfirmations(userReimbursementConfirmations);

        BtcTransaction memory userReimbursementTx = getBtcUserReimbursementTx(requestPeginTxid);
        uint32 reimbursementPeginVin = userReimbursementTx.inputs[0].vout;
        BtcTxSPVProof memory userReimbursementTxSPVProof = createBtcTxSPVProof(userReimbursementTx);

        // Keep BEST_CHAIN_HEIGHT at current value (1001 after setup_requestPeginFlow)
        int256 currentBestChainHeight = bridgeMock.getBtcBlockchainBestChainHeight();
        // Calculate expected blocksElapsed
        int256 userReimbursementBlockNumber = currentBestChainHeight - userReimbursementConfirmations;
        // blocksElapsed = (1001 - 11) - 990 = 0 < 1 ✓
        int256 blocksElapsedSinceRequestPegin = userReimbursementBlockNumber - requestPeginBlockNumber;

        // Assert - expect revert with UserReimbursementBeforeTimelock
        vm.expectRevert(
            abi.encodeWithSelector(
                IPeginManager.UserReimbursementBeforeTimelock.selector,
                blocksElapsedSinceRequestPegin,
                requestPeginTimelock
            )
        );

        // Act
        peginManager.userReimbursement(userReimbursementTxSPVProof, reimbursementPeginVin);
    }

    // ============ Register Reject Peg-in Tests ============
    function test_rejectPegin_Success() external {
        // Arrange
        (BtcTransaction memory requestPeginTx,) = setup_requestPeginFlow();
        bytes32 requestPeginTxid = getBtcTxid(requestPeginTx);

        // Get a committee member address for the onlyMember modifier
        uint128 committeeId = streamManager.getCommitteeId(setupStreamId, PACKET_NUMBER);
        CommitteeMember[] memory committeeMembers = registry.getCommitteeMembers(committeeId);
        address memberAddress = committeeMembers[0].memberAddress;

        // Get operator dispute key used for the speed up output
        bytes memory operatorPubKey = getDisputeKeyByAddress(memberAddress);

        BtcTransaction memory rejectPeginTx = createRejectPeginTx(requestPeginTxid, operatorPubKey);
        bytes32 rejectPeginTxid = getBtcTxid(rejectPeginTx);
        BtcTxSPVProof memory rejectPeginTxSPVProof = createBtcTxSPVProof(rejectPeginTx);

        // Get stream position
        StreamPosition memory streamPositionBefore = peginManager.getStreamPositionByRequestPegin(requestPeginTxid);

        pauseAndUnpauseContracts();

        // Assert - expect event
        vm.expectEmit(address(peginManager));
        emit IPeginManager.RejectPeginRegistered(rejectPeginTxid, requestPeginTxid, streamPositionBefore);

        // Act - call from committee member address
        vm.prank(memberAddress);
        peginManager.rejectPegin(rejectPeginTxSPVProof);

        // Assert - verify slot is blocked
        StreamPosition memory streamPositionAfter = peginManager.getStreamPositionByRequestPegin(requestPeginTxid);
        assertEq(
            uint256(streamPositionAfter.pegStatus),
            uint256(PegStatus.BLOCKED),
            "Stream position status should be BLOCKED"
        );
        Slot memory slot = streamManager.getSlot(
            streamPositionAfter.streamId, streamPositionAfter.packetNumber, streamPositionAfter.slotId
        );
        assertEq(uint256(slot.state), uint256(SlotState.BLOCKED), "Slot should be BLOCKED after reject pegin");

        // Verify rejectPeginTxid is stored
        RequestPeginTempInfo memory peginTempInfo = peginManager.getRequestPeginTempInfo(requestPeginTxid);
        assertEq(peginTempInfo.rejectPeginTxid, rejectPeginTxid, "Reject pegin txid should be stored");
    }

    function test_rejectPegin_Revert_PeginNotRequested() external {
        // Arrange
        // Get a committee member address
        uint128 committeeId = streamManager.getCommitteeId(setupStreamId, PACKET_NUMBER);
        CommitteeMember[] memory committeeMembers = registry.getCommitteeMembers(committeeId);
        address memberAddress = committeeMembers[0].memberAddress;

        // Get operator dispute key used for the speed up output
        bytes memory operatorPubKey = getDisputeKeyByAddress(memberAddress);

        // Create reject pegin tx with invalid request pegin txid (should fail)
        (BtcTransaction memory requestPeginTx,) = getBtcRequestPeginTx();
        bytes32 requestPeginTxid = getBtcTxid(requestPeginTx);
        BtcTransaction memory rejectPeginTx = createRejectPeginTx(requestPeginTxid, operatorPubKey);
        BtcTxSPVProof memory rejectPeginTxSPVProof = createBtcTxSPVProof(rejectPeginTx);

        // Assert - expect revert
        vm.expectRevert(abi.encodeWithSelector(IPegManagerBase.PeginNotRequested.selector, bytes32(0)));

        // Act
        vm.prank(memberAddress);
        peginManager.rejectPegin(rejectPeginTxSPVProof);
    }

    function test_rejectPegin_Revert_PeginAlreadyAccepted() external {
        // Arrange
        (BtcTransaction memory requestPeginTx,) = setup_requestPeginFlow();
        bytes32 requestPeginTxid = getBtcTxid(requestPeginTx);

        // Accept the pegin first
        BtcTransaction memory acceptPeginTx = getBtcAcceptPeginTx(requestPeginTx);
        BtcTxSPVProof memory acceptPeginTxSPVProof = createBtcTxSPVProof(acceptPeginTx);
        peginManager.acceptPegin(acceptPeginTxSPVProof);

        // Get a committee member address
        uint128 committeeId = streamManager.getCommitteeId(setupStreamId, PACKET_NUMBER);
        CommitteeMember[] memory committeeMembers = registry.getCommitteeMembers(committeeId);
        address memberAddress = committeeMembers[0].memberAddress;

        // Get operator dispute key used for the speed up output
        bytes memory operatorPubKey = getDisputeKeyByAddress(memberAddress);

        // Now try to register reject pegin
        BtcTransaction memory rejectPeginTx = createRejectPeginTx(requestPeginTxid, operatorPubKey);
        BtcTxSPVProof memory rejectPeginTxSPVProof = createBtcTxSPVProof(rejectPeginTx);

        // Assert - expect revert with InvalidPegStatus
        vm.expectRevert(abi.encodeWithSelector(IPegManagerBase.InvalidPegStatus.selector, PegStatus.ACCEPTED));

        // Act
        vm.prank(memberAddress);
        peginManager.rejectPegin(rejectPeginTxSPVProof);
    }

    function test_rejectPegin_Revert_InvalidAcceptPeginTxid() external {
        // Arrange
        (BtcTransaction memory requestPeginTx,) = setup_requestPeginFlow();
        bytes32 requestPeginTxid = getBtcTxid(requestPeginTx);

        // Get a committee member address
        uint128 committeeId = streamManager.getCommitteeId(setupStreamId, PACKET_NUMBER);
        CommitteeMember[] memory committeeMembers = registry.getCommitteeMembers(committeeId);
        address memberAddress = committeeMembers[0].memberAddress;

        // Create accept pegin tx and use it as reject pegin (should fail)
        BtcTransaction memory acceptPeginTx = getBtcAcceptPeginTx(requestPeginTx);
        bytes32 acceptPeginTxid = getBtcTxid(acceptPeginTx);
        BtcTxSPVProof memory acceptPeginTxSPVProof = createBtcTxSPVProof(acceptPeginTx);

        // Assert - expect revert
        vm.expectRevert(
            abi.encodeWithSelector(IPeginManager.InvalidAcceptPeginTxid.selector, acceptPeginTxid, acceptPeginTxid)
        );

        // Act - try to register accept pegin as reject pegin (should fail because txids match)
        vm.prank(memberAddress);
        peginManager.rejectPegin(acceptPeginTxSPVProof);
    }

    function test_rejectPegin_Revert_NotEnoughConfirmations() external {
        // Arrange
        (BtcTransaction memory requestPeginTx,) = setup_requestPeginFlow();
        bytes32 requestPeginTxid = getBtcTxid(requestPeginTx);

        // Get a committee member address
        uint128 committeeId = streamManager.getCommitteeId(setupStreamId, PACKET_NUMBER);
        CommitteeMember[] memory committeeMembers = registry.getCommitteeMembers(committeeId);
        address memberAddress = committeeMembers[0].memberAddress;

        // Get operator dispute key used for the speed up output
        bytes memory operatorPubKey = getDisputeKeyByAddress(memberAddress);

        BtcTransaction memory rejectPeginTx = createRejectPeginTx(requestPeginTxid, operatorPubKey);
        int256 actualConfirmations = 0;
        bridgeMock.setBtcTransactionConfirmations(actualConfirmations);
        BtcTxSPVProof memory rejectPeginTxSPVProof = createBtcTxSPVProof(rejectPeginTx);

        StreamPosition memory streamPosition = peginManager.getStreamPositionByRequestPegin(requestPeginTxid);
        Stream memory stream = streamManager.getStreamById(streamPosition.streamId);

        // Assert - expect revert
        vm.expectRevert(
            abi.encodeWithSelector(
                ProofValidator.NotEnoughConfirmations.selector, actualConfirmations, stream.peginConfirmations
            )
        );

        // Act
        vm.prank(memberAddress);
        peginManager.rejectPegin(rejectPeginTxSPVProof);
    }

    function test_rejectPegin_Revert_EnforcedPause_PausedContract() external {
        // Arrange
        (BtcTransaction memory requestPeginTx,) = setup_requestPeginFlow();
        bytes32 requestPeginTxid = getBtcTxid(requestPeginTx);

        // Get a committee member address
        uint128 committeeId = streamManager.getCommitteeId(setupStreamId, PACKET_NUMBER);
        CommitteeMember[] memory committeeMembers = registry.getCommitteeMembers(committeeId);
        address memberAddress = committeeMembers[0].memberAddress;

        // Get operator dispute key used for the speed up output
        bytes memory operatorPubKey = getDisputeKeyByAddress(memberAddress);

        // Create reject pegin tx
        BtcTransaction memory rejectPeginTx = createRejectPeginTx(requestPeginTxid, operatorPubKey);
        BtcTxSPVProof memory rejectPeginTxSPVProof = createBtcTxSPVProof(rejectPeginTx);

        pauseContracts();

        // Assert
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);

        // Act
        vm.prank(memberAddress);
        peginManager.rejectPegin(rejectPeginTxSPVProof);
    }

    function test_rejectPegin_Revert_BridgeBtcTxInvalidMerkleBranch() external {
        // Arrange
        (BtcTransaction memory requestPeginTx,) = setup_requestPeginFlow();
        bytes32 requestPeginTxid = getBtcTxid(requestPeginTx);

        // Get a committee member address
        uint128 committeeId = streamManager.getCommitteeId(setupStreamId, PACKET_NUMBER);
        CommitteeMember[] memory committeeMembers = registry.getCommitteeMembers(committeeId);
        address memberAddress = committeeMembers[0].memberAddress;

        // Get operator dispute key used for the speed up output
        bytes memory operatorPubKey = getDisputeKeyByAddress(memberAddress);

        // Create reject pegin tx
        BtcTransaction memory rejectPeginTx = createRejectPeginTx(requestPeginTxid, operatorPubKey);
        bytes32 rejectPeginTxid = getBtcTxid(rejectPeginTx);

        // Set Mock Bridge state to invalid merkle branch
        bridgeMock.setBtcTransactionConfirmations(BTC_TRANSACTION_CONFIRMATION_INVALID_MERKLE_BRANCH_ERROR_CODE);
        BtcTxSPVProof memory rejectPeginTxSPVProof = createBtcTxSPVProof(rejectPeginTx);

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                ProofValidator.BridgeBtcTxInvalidMerkleBranch.selector,
                rejectPeginTxid,
                rejectPeginTxSPVProof.merkleBranchPath,
                rejectPeginTxSPVProof.merkleBranchHashes
            )
        );

        // Act
        vm.prank(memberAddress);
        peginManager.rejectPegin(rejectPeginTxSPVProof);
    }

    function test_rejectPegin_Revert_AlreadyRegistered() external {
        // Arrange
        (BtcTransaction memory requestPeginTx,) = setup_requestPeginFlow();
        bytes32 requestPeginTxid = getBtcTxid(requestPeginTx);

        // Get a committee member address
        uint128 committeeId = streamManager.getCommitteeId(setupStreamId, PACKET_NUMBER);
        CommitteeMember[] memory committeeMembers = registry.getCommitteeMembers(committeeId);
        address memberAddress = committeeMembers[0].memberAddress;

        // Get operator dispute key used for the speed up output
        bytes memory operatorPubKey = getDisputeKeyByAddress(memberAddress);

        // Create reject pegin tx
        BtcTransaction memory rejectPeginTx = createRejectPeginTx(requestPeginTxid, operatorPubKey);
        BtcTxSPVProof memory rejectPeginTxSPVProof = createBtcTxSPVProof(rejectPeginTx);

        // Register first time
        vm.prank(memberAddress);
        peginManager.rejectPegin(rejectPeginTxSPVProof);

        // Try to register again - should revert because slot is already blocked
        // Assert - expect revert with InvalidPegStatus (since slot is now BLOCKED, not REGISTERED)
        vm.expectRevert(abi.encodeWithSelector(IPegManagerBase.InvalidPegStatus.selector, PegStatus.BLOCKED));

        // Act
        vm.prank(memberAddress);
        peginManager.rejectPegin(rejectPeginTxSPVProof);
    }

    function test_rejectPegin_Revert_IncorrectVout() external {
        // Arrange
        (BtcTransaction memory requestPeginTx,) = setup_requestPeginFlow();
        bytes32 requestPeginTxid = getBtcTxid(requestPeginTx);

        // Get a committee member address
        uint128 committeeId = streamManager.getCommitteeId(setupStreamId, PACKET_NUMBER);
        CommitteeMember[] memory committeeMembers = registry.getCommitteeMembers(committeeId);
        address memberAddress = committeeMembers[0].memberAddress;

        // Get operator dispute key used for the speed up output
        bytes memory operatorPubKey = getDisputeKeyByAddress(memberAddress);

        // Create a reject pegin tx with incorrect vout (using vout 0 instead of 2)
        BtcTransaction memory rejectPeginTx = createRejectPeginTx(requestPeginTxid, operatorPubKey);
        uint32 correctVout = Constants.REQUEST_PEGIN_VOUT_ENABLER;
        uint32 incorrectVout = 0;
        rejectPeginTx.inputs[0].vout = incorrectVout;

        BtcTxSPVProof memory rejectPeginTxSPVProof = createBtcTxSPVProof(rejectPeginTx);

        // Assert - expect revert with IncorrectVout
        vm.expectRevert(abi.encodeWithSelector(IPeginManager.IncorrectVout.selector, incorrectVout, correctVout));

        // Act
        vm.prank(memberAddress);
        peginManager.rejectPegin(rejectPeginTxSPVProof);
    }
}
