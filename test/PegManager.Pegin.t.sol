// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {HelperContract} from "test/helpers/HelperContract.sol";
import {
    BtcTransaction,
    BtcTxSPVProof,
    StreamPosition,
    RequestPegInTempInfo,
    PegStatus,
    IPegManager
} from "src/interfaces/IPegManager.sol";
import {BtcTxIn, BtcTxOut, IBitcoinManager} from "src/interfaces/IBitcoinManager.sol";
import {Slot, SlotState, Packet, Stream, IStreamManager} from "src/interfaces/IStreamManager.sol";
import {BTC_TRANSACTION_CONFIRMATION_INVALID_MERKLE_BRANCH_ERROR_CODE} from "src/interfaces/IBridge.sol";
import {ProofValidator} from "src/ProofValidator.sol";
import {BtcHelper} from "src/libraries/BtcHelper.sol";
import {Constants} from "src/libraries/Constants.sol";
import {ICommitteeRegistry, Committee} from "src/interfaces/ICommitteeRegistry.sol";

contract TestPegManager is Test, HelperContract {
    // Arrange
    // https://www.blockchain.com/explorer/blocks/btc/879500
    uint64 internal constant PACKET_NUMBER = 0;
    address internal constant RSK_DESTINATION_ADDRESS = 0x7Ac5496aee77c1bA1F0854206A26DdA82A81d6d8;
    uint64 internal setupStreamId;
    Committee internal setupExpectedCommittee;

    function setUp() external {
        runTestDeployScript();
        (, Committee memory expectedCommittee, uint64 streamId) = setup_completeCommitteeAndNewMembers();

        setupExpectedCommittee.aggregatedKey = expectedCommittee.aggregatedKey;
        setupExpectedCommittee.leaderIndex = expectedCommittee.leaderIndex;
        for (uint64 i = 0; i < expectedCommittee.memberIndexesAndRoles.length; i++) {
            setupExpectedCommittee.memberIndexesAndRoles.push(expectedCommittee.memberIndexesAndRoles[i]);
        }
        setupStreamId = streamId;
    }

    function test_getTemporaryPegInAddress_Success() external view {
        address dummyRskAddress = 0x7Ac5496aee77c1bA1F0854206A26DdA82A81d6d8;
        // TODO this is the value that includes the op_return data inside the taptree
        // this should be put back once the protocol builder is updated
        // string memory tempAddress = "bcrt1ptp8gw3yt9rjavkrlxhwmlm9y5w4c5u6yeeltmupanle76eq4ftrszyjhnn";
        string memory tempAddress = "bcrt1py28js8ef0lgpe5mrh8yn7apt52tkc8k95cyrm8m4fjmpu5zn2mps7esu9h";

        string memory result = pm.getTemporaryPegInAddress(dummyRskAddress, VALUE, BTC_REIMBURSEMENT_PUBKEY);
        assertEq(result, tempAddress, "Incorrect temporary peg in address at PegManager");
    }

    // ========================== REGISTER PEG IN REQUEST ==========================
    function test_registerPegInRequest_Success() external {
        // Arrange
        BtcTransaction memory btcTransaction = getBtcPegInRequestTx();
        // Set Mock Bridge state
        bridgeMock.setBtcTransactionConfirmations(10);
        // Create PegIn struct information
        BtcTxSPVProof memory pegInRequestTxSPVProof = createBtcTxSPVProof(btcTransaction);

        // Assert
        vm.expectEmit(address(pm));
        // We emit the event we expect to see.
        emit IPegManager.RegisteredPegInRequest(
            pegInRequestTxSPVProof.blockHash,
            getBtcTxHash(btcTransaction),
            0,
            VALUE,
            PACKET_NUMBER,
            RSK_DESTINATION_ADDRESS,
            BTC_REIMBURSEMENT_PUBKEY,
            btcTransaction.outputs[0].scriptPubKey
        );

        // Act
        pm.registerPegInRequest(pegInRequestTxSPVProof);

        // Assert
        bytes32 txHash = getBtcTxHash(btcTransaction);
        // Registered Peg In
        StreamPosition memory streamPosition = pm.getStreamPosition(txHash);
        assertEq(streamPosition.streamId, 1, "Incorrect streamId registered");
        assertEq(streamPosition.packetNumber, 0, "Incorrect packetNumber registered");
        assertEq(uint256(streamPosition.pegStatus), uint256(PegStatus.REGISTERED), "PegIn Request was not registered");

        BtcTransaction memory acceptPegInTx = getBtcAcceptPegInTx(btcTransaction);
        // Registered Peg In Temp info
        RequestPegInTempInfo memory pegInTempInfo = pm.getRequestPegInTempInfo(txHash);
        assertEq(
            pegInTempInfo.acceptPeginTxHash, getBtcTxHash(acceptPegInTx), "Incorrect peg in temp info acceptPeginTxHash"
        );
        assertEq(
            pegInTempInfo.rskDestinationAddress,
            RSK_DESTINATION_ADDRESS,
            "Incorrect peg in temp info destinationAddress"
        );
        assertEq(
            pegInTempInfo.btcReimbursementPubKey,
            BTC_REIMBURSEMENT_PUBKEY,
            "Incorrect peg in temp info btcReimbursementPubKey"
        );
    }

    function test_registerPegInRequest_Revert_AlreadyRegistered() external {
        // Arrange
        BtcTransaction memory btcTransaction = getBtcPegInRequestTx();
        // Set Mock Bridge state
        bridgeMock.setBtcTransactionConfirmations(10);
        // Create PegIn struct information
        BtcTxSPVProof memory pegInRequestTxSPVProof = createBtcTxSPVProof(btcTransaction);

        // Register First Peg In Request
        pm.registerPegInRequest(pegInRequestTxSPVProof);

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(IPegManager.AlreadyRegisteredPegInRequest.selector, getBtcTxHash(btcTransaction))
        );

        // Act Register Second Peg In Request
        pm.registerPegInRequest(pegInRequestTxSPVProof);
    }

    function test_registerPegInRequest_Revert_NotEnoughConfirmations() external {
        // Arrange
        int256 actualConfirmations = 0;
        BtcTransaction memory btcTransaction = getBtcPegInRequestTx();
        // Set Mock Bridge state
        bridgeMock.setBtcTransactionConfirmations(actualConfirmations);
        // Create PegIn struct information
        BtcTxSPVProof memory pegInRequestTxSPVProof = createBtcTxSPVProof(btcTransaction);

        // Assert
        Stream memory stream = streamManager.getStream(VALUE);
        vm.expectRevert(
            abi.encodeWithSelector(
                ProofValidator.NotEnoughConfirmations.selector, actualConfirmations, stream.peginConfirmations
            )
        );
        // Act
        pm.registerPegInRequest(pegInRequestTxSPVProof);
    }

    function test_registerPegInRequest_Revert_BridgeBtcTxInvalidMerkleBranch() external {
        // Arrange
        BtcTransaction memory btcTransaction = getBtcPegInRequestTx();
        // Set Mock Bridge state
        bridgeMock.setBtcTransactionConfirmations(BTC_TRANSACTION_CONFIRMATION_INVALID_MERKLE_BRANCH_ERROR_CODE);
        // Create PegIn struct information
        BtcTxSPVProof memory pegInRequestTxSPVProof = createBtcTxSPVProof(btcTransaction);

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                ProofValidator.BridgeBtcTxInvalidMerkleBranch.selector,
                getBtcTxHash(btcTransaction),
                pegInRequestTxSPVProof.merkleBranchPath,
                pegInRequestTxSPVProof.merkleBranchHashes
            )
        );
        // Act
        pm.registerPegInRequest(pegInRequestTxSPVProof);
    }

    function test_registerPegInRequest_Revert_IncorrectBtcTxVersion() external {
        // ===  Before test setup  is run for this  test ===
        // Arrange
        BtcTransaction memory btcTransaction = getBtcPegInRequestTx();
        btcTransaction.version = 1;
        // Set Mock Bridge state
        bridgeMock.setBtcTransactionConfirmations(10);
        // Create PegIn struct information
        BtcTxSPVProof memory pegInRequestTxSPVProof = createBtcTxSPVProof(btcTransaction);

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                IPegManager.InvalidBtcTxVersion.selector, btcTransaction.version, Constants.BTC_TX_VERSION
            )
        );

        // Act
        pm.registerPegInRequest(pegInRequestTxSPVProof);
    }

    function test_registerPegInRequest_Revert_IncorrectLocktime() external {
        // ===  Before test setup  is run for this  test ===
        // Arrange
        BtcTransaction memory btcTransaction = getBtcPegInRequestTx();
        btcTransaction.locktime = 1;
        // Set Mock Bridge state
        bridgeMock.setBtcTransactionConfirmations(10);
        // Create PegIn struct information
        BtcTxSPVProof memory pegInRequestTxSPVProof = createBtcTxSPVProof(btcTransaction);
        pegInRequestTxSPVProof.merkleBranchHashes[0] =
            0x3fcef4a1ddf759a858190b89ecbd1ff3dffb49704e110b68baf5b5de7021910f;

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(IPegManager.InvalidLocktime.selector, btcTransaction.locktime, Constants.LOCKTIME)
        );

        // Act
        pm.registerPegInRequest(pegInRequestTxSPVProof);
    }

    // ========================== ACCEPT PEG IN ==========================
    function test_acceptPegInRequest_Revert_UnregisteredPegInRequest() external {
        BtcTransaction memory btcTx = HelperContract.getBtcPegInRequestTx();

        // Arrange
        BtcTransaction memory btcTransaction = getBtcAcceptPegInTx(btcTx);
        // Set Mock Bridge state
        bridgeMock.setBtcTransactionConfirmations(10);
        // Create PegIn struct information
        BtcTxSPVProof memory pegInAcceptedTxSPVProof = createBtcTxSPVProof(btcTransaction);

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(IPegManager.UnregisteredPegInRequest.selector, btcTransaction.inputs[0].txId)
        );

        // Act
        pm.acceptPegInRequest(pegInAcceptedTxSPVProof);
    }

    function test_acceptPegInRequest_newPacketCreated() external {
        // Arrange
        // Create pegins until the new packet threshold is reached
        setup_multipleRequestAndAcceptPeginFlows(Constants.SLOT_USAGE_THRESHOLD - 1, setupStreamId);
        Committee memory expectedCommittee = setupExpectedCommittee;

        // Arrange
        BtcTransaction memory peginTx = setup_requestPeginFlow();
        BtcTransaction memory btcTransaction = getBtcAcceptPegInTx(peginTx);
        // Create PegIn accepted tx struct information
        BtcTxSPVProof memory pegInAcceptedTxSPVProof = createBtcTxSPVProof(btcTransaction);

        emit ICommitteeRegistry.NewPendingCommittee(setupStreamId, expectedCommittee);

        // Act
        pm.acceptPegInRequest(pegInAcceptedTxSPVProof);

        // Now we should provide members info to create the committee/packet. This works with second group of members, their indexes start at registry.MIN_COMMITTEE_MEMBERS()
        setup_depositMemberInfo_MultipleMembers(
            setupStreamId, registry.MIN_COMMITTEE_MEMBERS(), registry.MIN_COMMITTEE_MEMBERS() * 2 - 2
        );

        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.NewCommittee(COMMITTEE_ID_STREAM_1_PACKET_1, expectedCommittee);

        vm.expectEmit(address(streamManager));
        emit IStreamManager.PacketCreated(setupStreamId, 1);

        vm.prank(vm.addr(registry.MIN_COMMITTEE_MEMBERS() * 2));
        registry.depositMemberInfoForCommittee(setupStreamId, COMMITTEE_PUB_KEY_STREAM_1_PACKET_0);
    }

    function test_acceptPegInRequest_newPacketUsed() external {
        // Arrange
        // Create pegins until the new packet treshold is reached
        setup_multipleRequestAndAcceptPeginFlows(Constants.SLOTS_PER_PACKET, setupStreamId);
        // Members must deposite their info to create new packet
        setup_depositMemberInfo_MultipleMembers(
            setupStreamId, registry.MIN_COMMITTEE_MEMBERS(), registry.MIN_COMMITTEE_MEMBERS() * 2 - 1
        );

        // Arrange
        BtcTransaction memory peginTx = setup_requestPeginFlow();
        BtcTransaction memory btcTransaction = getBtcAcceptPegInTx(peginTx);
        // Create PegIn accepted tx struct information
        BtcTxSPVProof memory pegInAcceptedTxSPVProof = createBtcTxSPVProof(btcTransaction);

        // Assert
        vm.expectEmit(address(pm));
        // We emit the event we expect to see.
        bytes32 pegInRequestTxHash = pegInAcceptedTxSPVProof.btcTx.inputs[0].txId;
        bytes32 acceptPegInTxHash = HelperContract.getBtcTxHash(btcTransaction);
        uint64 packetId = 1;
        uint64 slotId = 0;
        emit IPegManager.AcceptedPegInRequest(
            pegInAcceptedTxSPVProof.blockHash,
            acceptPegInTxHash,
            pegInRequestTxHash,
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
        pm.acceptPegInRequest(pegInAcceptedTxSPVProof);
    }

    function test_acceptPegInRequest_Success() external {
        setup_requestPeginFlow();

        // ===  Before test setup  is run for this  test ===
        BtcTransaction memory peginTx = setup_requestPeginFlow();
        // Arrange
        BtcTransaction memory btcTransaction = getBtcAcceptPegInTx(peginTx);
        // Set Mock Bridge state
        bridgeMock.setBtcTransactionConfirmations(10);
        // Create PegIn struct information
        BtcTxSPVProof memory pegInAcceptedTxSPVProof = createBtcTxSPVProof(btcTransaction);

        // Assert
        vm.expectEmit(address(pm));

        // We emit the event we expect to see.
        bytes32 pegInRequestTxHash = pegInAcceptedTxSPVProof.btcTx.inputs[0].txId;
        bytes32 acceptPegInTxHash = getBtcTxHash(btcTransaction);
        uint64 streamId = 1;
        uint64 slotId = 0;
        emit IPegManager.AcceptedPegInRequest(
            pegInAcceptedTxSPVProof.blockHash,
            acceptPegInTxHash,
            pegInRequestTxHash,
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
        pm.acceptPegInRequest(pegInAcceptedTxSPVProof);

        // Assert
        // Registered Peg In Stream Position
        StreamPosition memory streamPosition = pm.getStreamPosition(pegInRequestTxHash);
        assertEq(streamPosition.streamId, streamId, "Incorrect streamId registered");
        assertEq(streamPosition.packetNumber, PACKET_NUMBER, "Incorrect packetNumber registered");
        assertEq(streamPosition.slotId, 0, "Incorrect slotId registered");
        assertEq(uint256(streamPosition.pegStatus), uint256(PegStatus.ACCEPTED), "PegIn Request was not accepted");
        // Registered Peg In Slot
        Slot memory slot = streamManager.getSlot(streamId, PACKET_NUMBER, slotId);
        assertEq(uint256(slot.state), uint256(SlotState.FILLED), "Slot should be filled");
        assertEq(slot.acceptPegInTx, acceptPegInTxHash, "Incorrect acceptPegInTx");
        assertEq(slot.acceptPegInAmount, btcTransaction.outputs[0].amount, "Incorrect acceptPegInAmount");
        assertEq(slot.scriptPubKey, btcTransaction.outputs[0].scriptPubKey, "Incorrect scriptPubKey");
    }

    function test_acceptPegInRequest_Revert_AlreadyRegisteredAcceptPegIn() external {
        setup_requestPeginFlow();

        // ===  Before test setup  is run for this  test ===
        BtcTransaction memory peginTx = setup_requestPeginFlow();
        // Arrange
        BtcTransaction memory btcTransaction = getBtcAcceptPegInTx(peginTx);
        // Set Mock Bridge state
        bridgeMock.setBtcTransactionConfirmations(10);
        // Create PegIn struct information
        BtcTxSPVProof memory pegInAcceptedTxSPVProof = createBtcTxSPVProof(btcTransaction);

        // Register First  Accept Peg In Request
        pm.acceptPegInRequest(pegInAcceptedTxSPVProof);

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(IPegManager.AlreadyRegisteredAcceptPegIn.selector, btcTransaction.inputs[0].txId)
        );

        // Act Register Second Accept Peg In Request
        pm.acceptPegInRequest(pegInAcceptedTxSPVProof);
    }

    function test_acceptPegInRequest_Revert_InvalidAcceptPegInTxHash() external {
        setup_requestPeginFlow();

        // ===  Before test setup  is run for this  test ===
        BtcTransaction memory peginTx = setup_requestPeginFlow();
        // Arrange
        BtcTransaction memory btcTransaction = getBtcAcceptPegInTx(peginTx);
        bytes32 expectedAcceptPegInTxHash = bitcoinManager.getBtcTxHash(btcTransaction);
        btcTransaction.outputs[0].scriptPubKey = hex"111111b4045c40a133ee361f766ceae4d82398fc5058";
        bytes32 actualAcceptPegInTxHash = bitcoinManager.getBtcTxHash(btcTransaction);
        // Set Mock Bridge state
        bridgeMock.setBtcTransactionConfirmations(10);
        // Create PegIn accepted tx struct information
        BtcTxSPVProof memory pegInAcceptedTxSPVProof = createBtcTxSPVProof(btcTransaction);

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                IPegManager.InvalidAcceptPegInTxHash.selector, expectedAcceptPegInTxHash, actualAcceptPegInTxHash
            )
        );

        // Act
        pm.acceptPegInRequest(pegInAcceptedTxSPVProof);
    }

    function test_acceptPegInRequest_Revert_Revert_NotEnoughConfirmations() external {
        // ===  Before test setup  is run for this  test ===
        BtcTransaction memory peginTx = setup_requestPeginFlow();
        // Arrange
        BtcTransaction memory btcTransaction = getBtcAcceptPegInTx(peginTx);
        int256 actualConfirmations = 0;
        // Set Mock Bridge state
        bridgeMock.setBtcTransactionConfirmations(actualConfirmations);
        // Create PegIn accepted tx struct information
        BtcTxSPVProof memory pegInAcceptedTxSPVProof = createBtcTxSPVProof(btcTransaction);
        Stream memory stream = streamManager.getStreamById(0);
        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                ProofValidator.NotEnoughConfirmations.selector, actualConfirmations, stream.peginConfirmations
            )
        );

        // Act
        pm.acceptPegInRequest(pegInAcceptedTxSPVProof);
    }

    function test_peginFlow_RequestMultiplePegin_Revert_IncorrectPacketNumber() external {
        // Arrange
        // Left just one empty slot in packet
        setup_multipleRequestAndAcceptPeginFlows(Constants.SLOTS_PER_PACKET - 1, setupStreamId);

        // Send 2 more pegins to fill the packet
        BtcTransaction memory peginTxN = setup_requestPeginFlow();
        BtcTransaction memory peginTxN_1 = setup_requestPeginFlow();

        assertNotEq(peginTxN.inputs[0].txId, peginTxN_1.inputs[0].txId, "PegIn txId should be different for each pegIn");

        BtcTransaction memory btcTransaction = getBtcAcceptPegInTx(peginTxN);
        bytes32 pegInRequestTxHash = HelperContract.getBtcTxHash(peginTxN);
        bytes32 acceptPegInTxHash = HelperContract.getBtcTxHash(btcTransaction);
        BtcTxSPVProof memory pegInAcceptedTxSPVProof = createBtcTxSPVProof(btcTransaction);

        vm.expectEmit(address(pm));
        emit IPegManager.AcceptedPegInRequest(
            pegInAcceptedTxSPVProof.blockHash,
            acceptPegInTxHash,
            pegInRequestTxHash,
            0, //vout
            StreamPosition({
                streamId: setupStreamId,
                packetNumber: 0,
                slotId: Constants.SLOTS_PER_PACKET - 1,
                pegStatus: PegStatus.ACCEPTED
            }),
            BTC_REIMBURSEMENT_PUBKEY,
            RSK_DESTINATION_ADDRESS,
            satoshiToWei(btcTransaction.outputs[0].amount), // Rbtc amount
            btcTransaction.outputs[0].scriptPubKey
        );
        pm.acceptPegInRequest(pegInAcceptedTxSPVProof);

        btcTransaction = getBtcAcceptPegInTx(peginTxN_1);
        pegInRequestTxHash = HelperContract.getBtcTxHash(peginTxN_1);
        acceptPegInTxHash = HelperContract.getBtcTxHash(btcTransaction);
        pegInAcceptedTxSPVProof = createBtcTxSPVProof(btcTransaction);

        // This should revert because this pegin was linked to packet 0 and now we are in packet 1
        vm.expectRevert(abi.encodeWithSelector(IStreamManager.InvalidPeginPacketNumber.selector, setupStreamId, 0));
        pm.acceptPegInRequest(pegInAcceptedTxSPVProof);
    }
}
