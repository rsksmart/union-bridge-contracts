// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {HelperContract} from "test/helpers/HelperContract.sol";
import {
    BtcTransaction,
    BtcTxSPVProof,
    StreamPosition,
    RequestPeginTempInfo,
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
        setupExpectedCommittee.leaderAddress = expectedCommittee.leaderAddress;
        for (uint64 i = 0; i < expectedCommittee.members.length; i++) {
            setupExpectedCommittee.members.push(expectedCommittee.members[i]);
        }
        setupStreamId = streamId;
    }

    function test_getTemporaryPeginAddress_Success() external view {
        address dummyRskAddress = 0x7Ac5496aee77c1bA1F0854206A26DdA82A81d6d8;
        // TODO this is the value that includes the op_return data inside the taptree
        // this should be put back once the protocol builder is updated
        // string memory tempAddress = "bcrt1ptp8gw3yt9rjavkrlxhwmlm9y5w4c5u6yeeltmupanle76eq4ftrszyjhnn";
        string memory tempAddress = "bcrt1py28js8ef0lgpe5mrh8yn7apt52tkc8k95cyrm8m4fjmpu5zn2mps7esu9h";

        string memory result = pm.getTemporaryPeginAddress(dummyRskAddress, VALUE, BTC_REIMBURSEMENT_PUBKEY);
        assertEq(result, tempAddress, "Incorrect temporary peg in address at PegManager");
    }

    // ========================== REGISTER PEG IN REQUEST ==========================
    function test_requestPegin_Success() external {
        // Arrange
        BtcTransaction memory btcTransaction = getBtcPeginRequestTx();
        // Set Mock Bridge state
        bridgeMock.setBtcTransactionConfirmations(10);
        // Create Pegin struct information
        BtcTxSPVProof memory peginRequestTxSPVProof = createBtcTxSPVProof(btcTransaction);

        // Assert
        vm.expectEmit(address(pm));
        // We emit the event we expect to see.
        emit IPegManager.PeginRequested(
            peginRequestTxSPVProof.blockHash,
            getBtcTxHash(btcTransaction),
            0,
            VALUE,
            PACKET_NUMBER,
            RSK_DESTINATION_ADDRESS,
            BTC_REIMBURSEMENT_PUBKEY,
            btcTransaction.outputs[0].scriptPubKey
        );

        // Act
        pm.requestPegin(peginRequestTxSPVProof);

        // Assert
        bytes32 txHash = getBtcTxHash(btcTransaction);
        // Registered Peg In
        StreamPosition memory streamPosition = pm.getStreamPosition(txHash);
        assertEq(streamPosition.streamId, 1, "Incorrect streamId registered");
        assertEq(streamPosition.packetNumber, 0, "Incorrect packetNumber registered");
        assertEq(uint256(streamPosition.pegStatus), uint256(PegStatus.REGISTERED), "Pegin Request was not registered");

        BtcTransaction memory acceptPeginTx = getBtcAcceptPeginTx(btcTransaction);
        // Registered Peg In Temp info
        RequestPeginTempInfo memory peginTempInfo = pm.getRequestPeginTempInfo(txHash);
        assertEq(
            peginTempInfo.acceptPeginTxHash, getBtcTxHash(acceptPeginTx), "Incorrect peg in temp info acceptPeginTxHash"
        );
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
    }

    function test_requestPegin_Revert_PeginAlreadyRequested() external {
        // Arrange
        BtcTransaction memory btcTransaction = getBtcPeginRequestTx();
        // Set Mock Bridge state
        bridgeMock.setBtcTransactionConfirmations(10);
        // Create Pegin struct information
        BtcTxSPVProof memory peginRequestTxSPVProof = createBtcTxSPVProof(btcTransaction);

        // Register First Peg In Request
        pm.requestPegin(peginRequestTxSPVProof);

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(IPegManager.PeginAlreadyRequested.selector, getBtcTxHash(btcTransaction))
        );

        // Act Register Second Peg In Request
        pm.requestPegin(peginRequestTxSPVProof);
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
        pm.requestPegin(peginRequestTxSPVProof);
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
                getBtcTxHash(btcTransaction),
                peginRequestTxSPVProof.merkleBranchPath,
                peginRequestTxSPVProof.merkleBranchHashes
            )
        );
        // Act
        pm.requestPegin(peginRequestTxSPVProof);
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
                IPegManager.InvalidBtcTxVersion.selector, btcTransaction.version, Constants.BTC_TX_VERSION
            )
        );

        // Act
        pm.requestPegin(peginRequestTxSPVProof);
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
            abi.encodeWithSelector(IPegManager.InvalidLocktime.selector, btcTransaction.locktime, Constants.LOCKTIME)
        );

        // Act
        pm.requestPegin(peginRequestTxSPVProof);
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
        vm.expectRevert(abi.encodeWithSelector(IPegManager.PeginNotRequested.selector, btcTransaction.inputs[0].txId));

        // Act
        pm.acceptPegin(peginAcceptedTxSPVProof);
    }

    function test_acceptPegin_newPacketCreated() external {
        // Arrange
        // Create pegins until the new packet threshold is reached
        setup_multipleRequestAndAcceptPeginFlows(Constants.SLOT_USAGE_THRESHOLD - 1, setupStreamId);
        Committee memory expectedCommittee = setup_getExpectedSecondCommittee();

        // Arrange
        BtcTransaction memory peginTx = setup_requestPeginFlow();
        BtcTransaction memory btcTransaction = getBtcAcceptPeginTx(peginTx);
        // Create Pegin accepted tx struct information
        BtcTxSPVProof memory peginAcceptedTxSPVProof = createBtcTxSPVProof(btcTransaction);

        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.NewPendingCommittee(setupStreamId, expectedCommittee);

        // Act
        pm.acceptPegin(peginAcceptedTxSPVProof);

        // Now we should provide members info to create the committee/packet. This works with second group of members, their indexes start at registry.minCommitteeMembers()
        uint256 memberIndexStart = registry.minCommitteeMembers();
        uint256 memberCount = registry.minCommitteeMembers() - 1;
        setup_depositMemberInfo_MultipleMembers(setupStreamId, memberIndexStart, memberCount);

        // Update expected committee with aggregated key
        expectedCommittee.aggregatedKey = COMMITTEE_PUB_KEY;
        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.NewCommittee(COMMITTEE_ID_STREAM_1_PACKET_1, expectedCommittee);

        vm.expectEmit(address(streamManager));
        emit IStreamManager.PacketCreated(setupStreamId, 1);

        vm.prank(vm.addr(registry.minCommitteeMembers() * 2));
        registry.depositMemberInfoForCommittee(setupStreamId, COMMITTEE_PUB_KEY);
    }

    function test_acceptPegin_newPacketUsed() external {
        // Arrange
        // Create pegins until the new packet treshold is reached
        setup_multipleRequestAndAcceptPeginFlows(Constants.SLOTS_PER_PACKET, setupStreamId);
        // Members must deposite their info to create new packet
        uint256 memberIndexStart = registry.minCommitteeMembers();
        uint256 memberCount = registry.minCommitteeMembers();
        setup_depositMemberInfo_MultipleMembers(setupStreamId, memberIndexStart, memberCount);

        // Arrange
        BtcTransaction memory peginTx = setup_requestPeginFlow();
        BtcTransaction memory btcTransaction = getBtcAcceptPeginTx(peginTx);
        // Create Pegin accepted tx struct information
        BtcTxSPVProof memory peginAcceptedTxSPVProof = createBtcTxSPVProof(btcTransaction);

        // Assert
        vm.expectEmit(address(pm));
        // We emit the event we expect to see.
        bytes32 peginRequestTxHash = peginAcceptedTxSPVProof.btcTx.inputs[0].txId;
        bytes32 acceptPeginTxHash = HelperContract.getBtcTxHash(btcTransaction);
        uint64 packetId = 1;
        uint64 slotId = 0;
        emit IPegManager.PeginAccepted(
            peginAcceptedTxSPVProof.blockHash,
            acceptPeginTxHash,
            peginRequestTxHash,
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
        pm.acceptPegin(peginAcceptedTxSPVProof);
    }

    function test_acceptPegin_Success() external {
        setup_requestPeginFlow();

        // ===  Before test setup  is run for this  test ===
        BtcTransaction memory peginTx = setup_requestPeginFlow();
        // Arrange
        BtcTransaction memory btcTransaction = getBtcAcceptPeginTx(peginTx);
        // Set Mock Bridge state
        bridgeMock.setBtcTransactionConfirmations(10);
        // Create Pegin struct information
        BtcTxSPVProof memory peginAcceptedTxSPVProof = createBtcTxSPVProof(btcTransaction);

        // Assert
        vm.expectEmit(address(pm));

        // We emit the event we expect to see.
        bytes32 peginRequestTxHash = peginAcceptedTxSPVProof.btcTx.inputs[0].txId;
        bytes32 acceptPeginTxHash = getBtcTxHash(btcTransaction);
        uint64 streamId = 1;
        uint64 slotId = 0;
        emit IPegManager.PeginAccepted(
            peginAcceptedTxSPVProof.blockHash,
            acceptPeginTxHash,
            peginRequestTxHash,
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
        pm.acceptPegin(peginAcceptedTxSPVProof);

        // Assert
        // Registered Peg In Stream Position
        StreamPosition memory streamPosition = pm.getStreamPosition(peginRequestTxHash);
        assertEq(streamPosition.streamId, streamId, "Incorrect streamId registered");
        assertEq(streamPosition.packetNumber, PACKET_NUMBER, "Incorrect packetNumber registered");
        assertEq(streamPosition.slotId, 0, "Incorrect slotId registered");
        assertEq(uint256(streamPosition.pegStatus), uint256(PegStatus.ACCEPTED), "Pegin Request was not accepted");
        // Registered Peg In Slot
        Slot memory slot = streamManager.getSlot(streamId, PACKET_NUMBER, slotId);
        assertEq(uint256(slot.state), uint256(SlotState.FILLED), "Slot should be filled");
        assertEq(slot.acceptPeginTx, acceptPeginTxHash, "Incorrect acceptPeginTx");
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
        pm.acceptPegin(peginAcceptedTxSPVProof);

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(IPegManager.PeginAlreadyAccepted.selector, btcTransaction.inputs[0].txId)
        );

        // Act Register Second Accept Peg In Request
        pm.acceptPegin(peginAcceptedTxSPVProof);
    }

    function test_acceptPegin_Revert_InvalidAcceptPeginTxHash() external {
        setup_requestPeginFlow();

        // ===  Before test setup  is run for this  test ===
        BtcTransaction memory peginTx = setup_requestPeginFlow();
        // Arrange
        BtcTransaction memory btcTransaction = getBtcAcceptPeginTx(peginTx);
        bytes32 expectedAcceptPeginTxHash = bitcoinManager.getBtcTxHash(btcTransaction);
        btcTransaction.outputs[0].scriptPubKey = hex"111111b4045c40a133ee361f766ceae4d82398fc5058";
        bytes32 actualAcceptPeginTxHash = bitcoinManager.getBtcTxHash(btcTransaction);
        // Set Mock Bridge state
        bridgeMock.setBtcTransactionConfirmations(10);
        // Create Pegin accepted tx struct information
        BtcTxSPVProof memory peginAcceptedTxSPVProof = createBtcTxSPVProof(btcTransaction);

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                IPegManager.InvalidAcceptPeginTxHash.selector, expectedAcceptPeginTxHash, actualAcceptPeginTxHash
            )
        );

        // Act
        pm.acceptPegin(peginAcceptedTxSPVProof);
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
        pm.acceptPegin(peginAcceptedTxSPVProof);
    }

    function test_peginFlow_RequestMultiplePegin_Revert_IncorrectPacketNumber() external {
        // Arrange
        // Left just one empty slot in packet
        setup_multipleRequestAndAcceptPeginFlows(Constants.SLOTS_PER_PACKET - 1, setupStreamId);

        // Send 2 more pegins to fill the packet
        BtcTransaction memory peginTxN = setup_requestPeginFlow();
        BtcTransaction memory peginTxN_1 = setup_requestPeginFlow();

        assertNotEq(peginTxN.inputs[0].txId, peginTxN_1.inputs[0].txId, "Pegin txId should be different for each pegin");

        BtcTransaction memory btcTransaction = getBtcAcceptPeginTx(peginTxN);
        bytes32 peginRequestTxHash = HelperContract.getBtcTxHash(peginTxN);
        bytes32 acceptPeginTxHash = HelperContract.getBtcTxHash(btcTransaction);
        BtcTxSPVProof memory peginAcceptedTxSPVProof = createBtcTxSPVProof(btcTransaction);

        vm.expectEmit(address(pm));
        emit IPegManager.PeginAccepted(
            peginAcceptedTxSPVProof.blockHash,
            acceptPeginTxHash,
            peginRequestTxHash,
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
        pm.acceptPegin(peginAcceptedTxSPVProof);

        btcTransaction = getBtcAcceptPeginTx(peginTxN_1);
        peginRequestTxHash = HelperContract.getBtcTxHash(peginTxN_1);
        acceptPeginTxHash = HelperContract.getBtcTxHash(btcTransaction);
        peginAcceptedTxSPVProof = createBtcTxSPVProof(btcTransaction);

        // This should revert because this pegin was linked to packet 0 and now we are in packet 1
        vm.expectRevert(abi.encodeWithSelector(IStreamManager.InvalidPeginPacketNumber.selector, setupStreamId, 0));
        pm.acceptPegin(peginAcceptedTxSPVProof);
    }
}
