// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {HelperContract} from "test/helpers/HelperContract.sol";
import {
    BtcTransaction,
    BtcTxSPVProof,
    StreamPosition,
    RequestPeginTempInfo,
    PegStatus
} from "src/interfaces/IPegCommonTypes.sol";
import {IPeginManager} from "src/interfaces/IPeginManager.sol";
import {PrevoutData} from "src/interfaces/IBitcoinManager.sol";
import {Slot, SlotState, Stream, IStreamManager} from "src/interfaces/IStreamManager.sol";
import {BTC_TRANSACTION_CONFIRMATION_INVALID_MERKLE_BRANCH_ERROR_CODE} from "src/interfaces/IBridge.sol";
import {ProofValidator} from "src/ProofValidator.sol";
import {Constants} from "src/libraries/Constants.sol";
import {ICommitteeRegistry, Committee} from "src/interfaces/ICommitteeRegistry.sol";

contract TestPegManager is Test, HelperContract {
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

    function test_getTemporaryPeginAddress_Success() external view {
        address dummyRskAddress = 0x7Ac5496aee77c1bA1F0854206A26DdA82A81d6d8;
        // Address is different according to amount and destination address
        string memory tempAddress = "bcrt1p9hdr74xdg69a7w6r4pfsrrnj3l7ku54x5jdmtwf4thnjyhkmeuhs79pnrw";

        (string memory result, uint64 packetNumber) =
            peginManager.getTemporaryPeginAddress(dummyRskAddress, VALUE, BTC_REIMBURSEMENT_PUBKEY);
        assertEq(result, tempAddress, "Incorrect temporary peg in address at PegManager");
        assertEq(packetNumber, PACKET_NUMBER, "Incorrect packet number at PegManager");
    }

    // ========================== REQUEST PEGIN ==========================
    function test_requestPegin_Success() external {
        // Arrange
        BtcTransaction memory btcTransaction = getBtcPeginRequestTx();
        // Set Mock Bridge state
        bridgeMock.setBtcTransactionConfirmations(10);
        // Create Pegin struct information
        BtcTxSPVProof memory peginRequestTxSPVProof = createBtcTxSPVProof(btcTransaction);
        bytes32 expectedRequestPeginTxid = getBtcTxid(btcTransaction);
        bytes32 expectedAcceptPeginTxid = getBtcTxid(getBtcAcceptPeginTx(btcTransaction));
        bytes32 expectedAcceptPeginSignatureHash = hex"80ad6ee31d49f3021483e3212fc64c9a20139f6ea38b0bfedc2af0480fca166a";
        bytes memory expectedAcceptPeginSignatureMessage =
            hex"0001020000000000000045eb25874678e195a26959dbc0597bca2bbc693af2ff2e73a862eb5156b285384f973621fe8403b6facae9abab80d863a847d3fb007ba2f9830f8e16e6e9b4d45314b96b3848ec1e8f6c656d51101273a35b12be9382350f8d4fa53959c09e9c23e9829bfb4e23fbd3c4848baa035af15d73bcb83e510f7f097f90a21a4280d226916279b0a803d308531e7b8917970c07fb21a964842101f7278dda63f4cfce0000000000";

        RequestPeginTempInfo memory expectedRequestPeginInfo = RequestPeginTempInfo({
            rskDestinationAddress: RSK_DESTINATION_ADDRESS,
            btcReimbursementPubKey: BTC_REIMBURSEMENT_PUBKEY,
            acceptPeginSignatureHash: expectedAcceptPeginSignatureHash
        });
        PrevoutData memory expectedPrevoutData =
            PrevoutData({value: btcTransaction.outputs[0].amount, scriptPubKey: btcTransaction.outputs[0].scriptPubKey});
        uint128 expectedCommitteeId = streamManager.getCommitteeId(setupStreamId, PACKET_NUMBER);

        // Assert
        vm.expectEmit(address(peginManager));
        emit IPeginManager.PeginRequested(
            expectedCommitteeId,
            expectedRequestPeginTxid,
            expectedAcceptPeginTxid,
            0,
            StreamPosition({
                streamId: setupStreamId,
                packetNumber: PACKET_NUMBER,
                slotId: 0, // First slot in packet
                pegStatus: PegStatus.REGISTERED
            }),
            expectedRequestPeginInfo,
            expectedPrevoutData,
            expectedAcceptPeginSignatureMessage
        );

        // Act
        peginManager.requestPegin(peginRequestTxSPVProof);

        // Assert
        bytes32 txid = getBtcTxid(btcTransaction);
        // Registered Peg In
        StreamPosition memory streamPosition = peginManager.getStreamPosition(txid);
        assertEq(streamPosition.streamId, 1, "Incorrect streamId registered");
        assertEq(streamPosition.packetNumber, 0, "Incorrect packetNumber registered");
        assertEq(streamPosition.slotId, 0, "Should reserve first slot in packet");
        assertEq(uint256(streamPosition.pegStatus), uint256(PegStatus.REGISTERED), "Pegin Request was not registered");

        // Verify slot is properly reserved
        Slot memory reservedSlot =
            streamManager.getSlot(streamPosition.streamId, streamPosition.packetNumber, streamPosition.slotId);
        assertEq(uint256(reservedSlot.state), uint256(SlotState.RESERVED), "Slot should be RESERVED");
        assertEq(reservedSlot.slotId, streamPosition.slotId, "Slot ID should match StreamPosition");

        // Verify stream pointers haven't advanced (since packet not full)
        Stream memory stream = streamManager.getStreamById(streamPosition.streamId);
        assertEq(stream.peginPacketPointer, 0, "Packet pointer should not advance for single request");

        BtcTransaction memory expectedAcceptPeginTx = getBtcAcceptPeginTx(btcTransaction);
        // Registered Pegin Request
        bytes32 acceptPeginTxid = peginManager.getAcceptPegin(txid);
        assertEq(acceptPeginTxid, getBtcTxid(expectedAcceptPeginTx), "Incorrect pegin request acceptPeginTxid");
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
            hex"80ad6ee31d49f3021483e3212fc64c9a20139f6ea38b0bfedc2af0480fca166a",
            "Incorrect peg in temp info btcReimbursementPubKey"
        );
    }

    function test_requestPegin_Revert_PeginAlreadyRequested() external {
        // Arrange
        BtcTransaction memory btcTransaction = getBtcPeginRequestTx();
        // Set Mock Bridge state
        bridgeMock.setBtcTransactionConfirmations(10);
        // Create Pegin struct information
        BtcTxSPVProof memory peginRequestTxSPVProof = createBtcTxSPVProof(btcTransaction);

        // Register First Peg In Request
        peginManager.requestPegin(peginRequestTxSPVProof);

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(IPeginManager.PeginAlreadyRequested.selector, getBtcTxid(btcTransaction))
        );

        // Act Register Second Peg In Request
        peginManager.requestPegin(peginRequestTxSPVProof);
    }

    function test_requestPegin_Revert_NotEnoughConfirmations() external {
        // Arrange
        int256 actualConfirmations = 0;
        BtcTransaction memory btcTransaction = getBtcPeginRequestTx();
        // Set Mock Bridge state
        bridgeMock.setBtcTransactionConfirmations(actualConfirmations);
        // Create Pegin struct information
        BtcTxSPVProof memory peginRequestTxSPVProof = createBtcTxSPVProof(btcTransaction);

        // Assert
        Stream memory stream = streamManager.getStream(VALUE);
        vm.expectRevert(
            abi.encodeWithSelector(
                ProofValidator.NotEnoughConfirmations.selector, actualConfirmations, stream.peginConfirmations
            )
        );
        // Act
        peginManager.requestPegin(peginRequestTxSPVProof);
    }

    function test_requestPegin_Revert_BridgeBtcTxInvalidMerkleBranch() external {
        // Arrange
        BtcTransaction memory btcTransaction = getBtcPeginRequestTx();
        // Set Mock Bridge state
        bridgeMock.setBtcTransactionConfirmations(BTC_TRANSACTION_CONFIRMATION_INVALID_MERKLE_BRANCH_ERROR_CODE);
        // Create Pegin struct information
        BtcTxSPVProof memory peginRequestTxSPVProof = createBtcTxSPVProof(btcTransaction);

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                ProofValidator.BridgeBtcTxInvalidMerkleBranch.selector,
                getBtcTxid(btcTransaction),
                peginRequestTxSPVProof.merkleBranchPath,
                peginRequestTxSPVProof.merkleBranchHashes
            )
        );
        // Act
        peginManager.requestPegin(peginRequestTxSPVProof);
    }

    function test_requestPegin_Revert_IncorrectBtcTxVersion() external {
        // ===  Before test setup  is run for this  test ===
        // Arrange
        BtcTransaction memory btcTransaction = getBtcPeginRequestTx();
        btcTransaction.version = 1;
        // Set Mock Bridge state
        bridgeMock.setBtcTransactionConfirmations(10);
        // Create Pegin struct information
        BtcTxSPVProof memory peginRequestTxSPVProof = createBtcTxSPVProof(btcTransaction);

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                IPeginManager.InvalidBtcTxVersion.selector, btcTransaction.version, Constants.BTC_TX_VERSION
            )
        );

        // Act
        peginManager.requestPegin(peginRequestTxSPVProof);
    }

    function test_requestPegin_Revert_IncorrectLocktime() external {
        // ===  Before test setup  is run for this  test ===
        // Arrange
        BtcTransaction memory btcTransaction = getBtcPeginRequestTx();
        btcTransaction.locktime = 1;
        // Set Mock Bridge state
        bridgeMock.setBtcTransactionConfirmations(10);
        // Create Pegin struct information
        BtcTxSPVProof memory peginRequestTxSPVProof = createBtcTxSPVProof(btcTransaction);
        peginRequestTxSPVProof.merkleBranchHashes[0] =
            0x3fcef4a1ddf759a858190b89ecbd1ff3dffb49704e110b68baf5b5de7021910f;

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(IPeginManager.InvalidLocktime.selector, btcTransaction.locktime, Constants.LOCKTIME)
        );

        // Act
        peginManager.requestPegin(peginRequestTxSPVProof);
    }

    // ========================== ACCEPT PEG IN ==========================
    function test_acceptPegin_Revert_PeginNotRequested() external {
        BtcTransaction memory btcTx = HelperContract.getBtcPeginRequestTx();

        // Arrange
        BtcTransaction memory btcTransaction = getBtcAcceptPeginTx(btcTx);
        // Set Mock Bridge state
        bridgeMock.setBtcTransactionConfirmations(10);
        // Create Pegin struct information
        BtcTxSPVProof memory peginAcceptedTxSPVProof = createBtcTxSPVProof(btcTransaction);

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IPeginManager.PeginNotRequested.selector, btcTransaction.inputs[0].txId));

        // Act
        peginManager.acceptPegin(peginAcceptedTxSPVProof);
    }

    function test_acceptPegin_newPacketCreated() external {
        // Arrange
        // Create pegins until the new packet threshold is reached
        setup_multipleRequestAndAcceptPeginFlows(Constants.SLOT_USAGE_THRESHOLD - 1);
        Committee memory expectedCommittee = setup_getExpectedSecondCommittee();

        // Arrange
        BtcTransaction memory peginTx = setup_requestPeginFlow();
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
        BtcTransaction memory peginTx = setup_requestPeginFlow();
        BtcTransaction memory btcTransaction = getBtcAcceptPeginTx(peginTx);
        // Create Pegin accepted tx struct information
        BtcTxSPVProof memory peginAcceptedTxSPVProof = createBtcTxSPVProof(btcTransaction);

        // Assert
        vm.expectEmit(address(peginManager));
        // We emit the event we expect to see.
        bytes32 peginRequestTxid = peginAcceptedTxSPVProof.btcTx.inputs[0].txId;
        bytes32 acceptPeginTxid = HelperContract.getBtcTxid(btcTransaction);
        uint64 packetId = 1;
        uint64 slotId = 0;
        emit IPeginManager.PeginAccepted(
            peginAcceptedTxSPVProof.blockHash,
            acceptPeginTxid,
            peginRequestTxid,
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
        BtcTransaction memory peginTx = setup_requestPeginFlow();
        // Arrange
        BtcTransaction memory btcTransaction = getBtcAcceptPeginTx(peginTx);
        // Set Mock Bridge state
        bridgeMock.setBtcTransactionConfirmations(10);
        // Create Pegin struct information
        BtcTxSPVProof memory peginAcceptedTxSPVProof = createBtcTxSPVProof(btcTransaction);

        // Assert
        vm.expectEmit(address(peginManager));

        // We emit the event we expect to see.
        bytes32 peginRequestTxid = peginAcceptedTxSPVProof.btcTx.inputs[0].txId;
        bytes32 acceptPeginTxid = getBtcTxid(btcTransaction);
        uint64 streamId = 1;
        uint64 slotId = 0;
        emit IPeginManager.PeginAccepted(
            peginAcceptedTxSPVProof.blockHash,
            acceptPeginTxid,
            peginRequestTxid,
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
        StreamPosition memory streamPosition = peginManager.getStreamPosition(peginRequestTxid);
        assertEq(streamPosition.streamId, streamId, "Incorrect streamId registered");
        assertEq(streamPosition.packetNumber, PACKET_NUMBER, "Incorrect packetNumber registered");
        assertEq(streamPosition.slotId, slotId, "Incorrect slotId registered");
        assertEq(uint256(streamPosition.pegStatus), uint256(PegStatus.ACCEPTED), "Pegin Request was not accepted");
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
        BtcTransaction memory peginTx = setup_requestPeginFlow();
        // Arrange
        BtcTransaction memory btcTransaction = getBtcAcceptPeginTx(peginTx);
        // Set Mock Bridge state
        bridgeMock.setBtcTransactionConfirmations(10);
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
        BtcTransaction memory peginTx = setup_requestPeginFlow();
        // Arrange
        BtcTransaction memory btcTransaction = getBtcAcceptPeginTx(peginTx);
        bytes32 expectedAcceptPeginTxid = bitcoinManager.getBtcTxid(btcTransaction);
        btcTransaction.outputs[0].scriptPubKey = hex"111111b4045c40a133ee361f766ceae4d82398fc5058";
        bytes32 actualAcceptPeginTxid = bitcoinManager.getBtcTxid(btcTransaction);
        // Set Mock Bridge state
        bridgeMock.setBtcTransactionConfirmations(10);
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
        BtcTransaction memory peginTx = setup_requestPeginFlow();
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
            BtcTransaction memory btcTransaction = getBtcPeginRequestTx();
            // Modify tx to make each unique
            btcTransaction.inputs[0].scriptSig = abi.encodePacked(bytes32(uint256(i + 1)));
            BtcTxSPVProof memory peginRequestTxSPVProof = createBtcTxSPVProof(btcTransaction);

            peginManager.requestPegin(peginRequestTxSPVProof);

            // Verify each request gets correct slotId
            bytes32 requestPeginTxid = getBtcTxid(btcTransaction);
            StreamPosition memory streamPosition = peginManager.getStreamPosition(requestPeginTxid);
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
            BtcTransaction memory btcTransaction = getBtcPeginRequestTx();
            btcTransaction.inputs[0].scriptSig = abi.encodePacked(bytes32(uint256(i + 1)));
            BtcTxSPVProof memory peginRequestTxSPVProof = createBtcTxSPVProof(btcTransaction);

            peginManager.requestPegin(peginRequestTxSPVProof);
        }

        // Verify packet pointer has advanced
        Stream memory stream = streamManager.getStreamById(setupStreamId);
        assertEq(stream.peginPacketPointer, 1, "Packet pointer should advance after packet is full");
    }

    function test_acceptPegin_UsesSpecificSlotId() external {
        // 1. Make multiple pegin requests
        BtcTransaction memory peginTx1 = getBtcPeginRequestTx();
        peginTx1.inputs[0].scriptSig = abi.encodePacked(bytes32(uint256(1)));
        BtcTxSPVProof memory peginRequestTxSPVProof1 = createBtcTxSPVProof(peginTx1);
        peginManager.requestPegin(peginRequestTxSPVProof1);
        bytes32 requestPeginTxid1 = getBtcTxid(peginTx1);

        BtcTransaction memory peginTx2 = getBtcPeginRequestTx();
        peginTx2.inputs[0].scriptSig = abi.encodePacked(bytes32(uint256(2)));
        BtcTxSPVProof memory peginRequestTxSPVProof2 = createBtcTxSPVProof(peginTx2);
        peginManager.requestPegin(peginRequestTxSPVProof2);
        bytes32 requestPeginTxid2 = getBtcTxid(peginTx2);

        // 2. Accept only the second pegin transaction
        BtcTransaction memory acceptTx2 = getBtcAcceptPeginTx(peginTx2);
        BtcTxSPVProof memory acceptPeginTxSPVProof2 = createBtcTxSPVProof(acceptTx2);
        peginManager.acceptPegin(acceptPeginTxSPVProof2);

        // 3. Verify correct slot is filled (slot 1, not slot 0)
        StreamPosition memory streamPosition2 = peginManager.getStreamPosition(requestPeginTxid2);
        Slot memory filledSlot =
            streamManager.getSlot(streamPosition2.streamId, streamPosition2.packetNumber, streamPosition2.slotId);
        assertEq(uint256(filledSlot.state), uint256(SlotState.FILLED), "Slot 1 should be FILLED");
        assertEq(streamPosition2.slotId, 1, "Should be slot 1");

        // 4. Verify first slot remains in RESERVED state
        StreamPosition memory streamPosition1 = peginManager.getStreamPosition(requestPeginTxid1);
        Slot memory reservedSlot =
            streamManager.getSlot(streamPosition1.streamId, streamPosition1.packetNumber, streamPosition1.slotId);
        assertEq(uint256(reservedSlot.state), uint256(SlotState.RESERVED), "Slot 0 should remain RESERVED");
        assertEq(streamPosition1.slotId, 0, "Should be slot 0");
    }

    function test_acceptPegin_Revert_SlotBlocked() external {
        // 1. Request pegin to reserve slot
        BtcTransaction memory peginTx = setup_requestPeginFlow();
        bytes32 requestPeginTxid = getBtcTxid(peginTx);
        StreamPosition memory streamPosition = peginManager.getStreamPosition(requestPeginTxid);

        // 2. Block the slot externally
        vm.prank(streamManager.owner());
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
}
