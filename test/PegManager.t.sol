// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {HelperContract, StreamManagerHarness} from "test/helpers/HelperContract.sol";
import {BtcTransaction, BtcTxSPVProof, IPegManager, BitcoinSignatureData} from "src/interfaces/IPegManager.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {Pausable} from "src/Pausable.sol";
import {SlotState, Stream} from "src/interfaces/IStreamManager.sol";
import {BtcHelper} from "src/libraries/BtcHelper.sol";
import {Committee} from "src/interfaces/ICommitteeRegistry.sol";
import {BtcTxIn, BtcTxOut} from "src/interfaces/IBitcoinManager.sol";

contract TestPegManager is Test, HelperContract {
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

    function pausePegManager() internal {
        vm.prank(pm.pauser());
        pm.pause();
    }

    function pauseAndUnpausePegManager() internal {
        vm.startPrank(pm.pauser());
        pm.pause();
        pm.unpause();
        vm.stopPrank();
    }

    function test_Success_OwnerIsPauser() external view {
        assertEq(pm.pauser(), pm.owner());
    }

    function test_pause_Revert_UnauthorizedAccount_CallFromNotPauser() external {
        // Assert
        vm.expectRevert(abi.encodeWithSelector(Pausable.UnauthorizedAccount.selector, address(this)));

        // Act
        pm.pause();
    }

    function test_pause_Success_CallFromPauser() external {
        // Arrange
        address pauser = pm.pauser();

        // Assert
        vm.expectEmit(address(pm));
        emit PausableUpgradeable.Paused(pauser);

        // Act
        vm.prank(pauser);
        pm.pause();

        // Assert
        assertTrue(pm.isPaused());
        assertTrue(pm.committeeRegistry().isPaused());
        assertTrue(pm.memberRegistry().isPaused());
    }

    function test_unpause_Revert_UnauthorizedAccount_CallFromNotPauser() external {
        // Arrange
        pausePegManager();

        // Assert
        vm.expectRevert(abi.encodeWithSelector(Pausable.UnauthorizedAccount.selector, address(this)));

        // Act
        pm.unpause();
    }

    function test_unpause_Success_CallFromPauser() external {
        // Arrange
        pausePegManager();
        address pauser = pm.pauser();

        // Assert
        vm.expectEmit(address(pm));
        emit PausableUpgradeable.Unpaused(pauser);

        // Act
        vm.prank(pauser);
        pm.unpause();

        // Assert
        assertFalse(pm.isPaused());
        assertFalse(pm.committeeRegistry().isPaused());
        assertFalse(pm.memberRegistry().isPaused());
    }

    function test_unpause_Revert_ExpectedPause_CallFromPauser_ContractNotPaused() external {
        // Arrange
        address pauser = pm.pauser();

        // Assert
        vm.expectRevert(abi.encodeWithSelector(PausableUpgradeable.ExpectedPause.selector, pauser));

        // Act
        vm.prank(pauser);
        pm.unpause();
    }

    function test_pause_Revert_EnforcedPause_CallFromPauser_ContractAlreadyPaused() external {
        // Arrange
        pausePegManager();
        address pauser = pm.pauser();

        // Assert
        vm.expectRevert(abi.encodeWithSelector(PausableUpgradeable.EnforcedPause.selector, address(pm)));

        // Act
        vm.prank(pauser);
        pm.pause();
    }

    function test_pause_CallFromPauser_ShouldAlsoPauseCommitteeRegistry() external {
        // Arrange
        address pauser = pm.pauser();
        address registryAddress = address(registry);

        // Assert
        vm.expectEmit(registryAddress);
        emit PausableUpgradeable.Paused(address(pm));

        // Act
        vm.prank(pauser);
        pm.pause();
    }

    function test_setStreamManager_Success_PausedContract() external {
        // Arrange
        uint256 privKey = uint256(1);
        address newStreamManagerAddress = vm.addr(privKey);
        StreamManagerHarness newStreamManager = StreamManagerHarness(newStreamManagerAddress);
        pausePegManager();

        // Assert
        vm.prank(pm.owner());
        vm.expectEmit(address(pm));
        emit IPegManager.StreamManagerUpdated(newStreamManager);

        // Act
        pm.setStreamManager(newStreamManager);

        // Assert
        assertEq(address(pm.streamManager()), newStreamManagerAddress);
    }

    function test_setSignatureManager_Success_PausedContract() external {
        // Arrange
        uint256 privKey = uint256(1);
        address newStreamManagerAddress = vm.addr(privKey);
        StreamManagerHarness newStreamManager = StreamManagerHarness(newStreamManagerAddress);

        pausePegManager();

        // Assert
        vm.prank(pm.owner());
        vm.expectEmit(address(pm));
        emit IPegManager.StreamManagerUpdated(newStreamManager);

        // Act
        pm.setStreamManager(newStreamManager);

        // Assert
        assertEq(address(pm.streamManager()), newStreamManagerAddress);
    }

    function test_setMemberRegistry_Success_PausedContract() external {
        // Arrange
        uint256 privKey = uint256(1);
        address newStreamManagerAddress = vm.addr(privKey);
        StreamManagerHarness newStreamManager = StreamManagerHarness(newStreamManagerAddress);

        pausePegManager();

        // Assert
        vm.prank(pm.owner());
        vm.expectEmit(address(pm));
        emit IPegManager.StreamManagerUpdated(newStreamManager);

        // Act
        pm.setStreamManager(newStreamManager);

        // Assert
        assertEq(address(pm.streamManager()), newStreamManagerAddress);
    }

    function test_requestPegin_Revert_EnforcedPause_PausedContract() external {
        // Arrange
        BtcTransaction memory btcTransaction = getBtcPeginRequestTx();
        BtcTxSPVProof memory peginRequestTxSPVProof = createBtcTxSPVProof(btcTransaction);

        pausePegManager();

        // Assert
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);

        // Act
        pm.requestPegin(peginRequestTxSPVProof);
    }

    function test_requestPegin_Success_UnpausedContract() external {
        // Arrange
        BtcTransaction memory btcTransaction = getBtcPeginRequestTx();
        BtcTxSPVProof memory peginRequestTxSPVProof = createBtcTxSPVProof(btcTransaction);

        pauseAndUnpausePegManager();

        // Act & Assert
        pm.requestPegin(peginRequestTxSPVProof);
    }

    function test_acceptPegin_Revert_EnforcedPause_PausedContract() external {
        // Arrange
        BtcTransaction memory peginTx = setup_requestPeginFlow();
        BtcTransaction memory btcTransaction = getBtcAcceptPeginTx(peginTx);
        BtcTxSPVProof memory peginAcceptedTxSPVProof = createBtcTxSPVProof(btcTransaction);

        pausePegManager();

        // Assert
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);

        // Act
        pm.acceptPegin(peginAcceptedTxSPVProof);
    }

    function test_acceptPegin_Success_UnpausedContract() external {
        // Arrange
        BtcTransaction memory peginTx = setup_requestPeginFlow();
        BtcTransaction memory btcTransaction = getBtcAcceptPeginTx(peginTx);
        BtcTxSPVProof memory peginAcceptedTxSPVProof = createBtcTxSPVProof(btcTransaction);

        pauseAndUnpausePegManager();

        // Act & Assert
        pm.acceptPegin(peginAcceptedTxSPVProof);
    }

    function test_tryPegout_Revert_EnforcedPause_PausedContract() external {
        // Arrange
        uint64 amount = 1000000; // 0.01 BTC
        uint256 amountInWei = BtcHelper.satoshiToWei(amount);
        bytes memory userPubKey = hex"02d56ad001b55eabf431e602599fcc0d7ed9d676ac93c2be11d0de6e25dd598d8b";

        pausePegManager();

        // Assert
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);

        // Act
        pm.tryPegout{value: amountInWei}(userPubKey);
    }

    function test_tryPegout_Success_UnpausedContract() external {
        // Arrange
        pauseAndUnpausePegManager();
        // Arrange
        BtcTxIn[] memory inputs = new BtcTxIn[](1);
        inputs[0] = BtcTxIn({
            txId: 0xb24858ade3e5be49ae63facb93524ddf460d0771f093525dae328b6c435516a2,
            vout: 0,
            sequence: 4294967293,
            scriptSig: hex""
        });

        BtcTxOut[] memory outputs = new BtcTxOut[](2);
        outputs[0] = BtcTxOut({amount: 999125, scriptPubKey: hex"00143fd2e14f4b448a071e074e1e1879318447f2a266"});
        outputs[1] = BtcTxOut({amount: 540, scriptPubKey: hex"00143fd2e14f4b448a071e074e1e1879318447f2a266"});

        BitcoinSignatureData memory expectedSignatureData = BitcoinSignatureData({
            tx: BtcTransaction({version: 2, inputs: inputs, outputs: outputs, locktime: 0}),
            txid: 0x797853a318220995510a2cfd90f40ee81ca9931896fd9f86e4681ac925e2c1fc,
            signatureHash: 0xfb6d69787860ef13b81041a168cb1f530eb5d87973d34430fc9eb8cef62eb7ad,
            signatureMessage: hex"00010200000000000000234337e863e00e6ff45f167a14f3963bea912bc0d739c2b402d04f376e814ae24f973621fe8403b6facae9abab80d863a847d3fb007ba2f9830f8e16e6e9b4d4a0c6dbc3091625a23fd870bf8d09182484c12fa63a5c29045a431cf445f153e523e9829bfb4e23fbd3c4848baa035af15d73bcb83e510f7f097f90a21a4280d2bfd84e32f90f61452c95235739095ef9347def223e2b2a49d799abe42099e5850000000000"
        });

        bytes memory userPubKey = hex"02d56ad001b55eabf431e602599fcc0d7ed9d676ac93c2be11d0de6e25dd598d8b";

        bytes32 txId = 0xb24858ade3e5be49ae63facb93524ddf460d0771f093525dae328b6c435516a2;
        bytes memory scriptPubKey = hex"02f519f51e435c20d38af683ea86862f4591ce8cda248077c2d9a72a76b62f32";

        uint64 amount = 1000000; // 0.01 BTC
        uint256 amountInWei = BtcHelper.satoshiToWei(amount);

        Stream memory stream = streamManager.getStream(uint64(amount));
        uint64 packetNumber = 0;
        uint64 slotId = 0;

        streamManager.setSlotHarness(stream.streamId, packetNumber, scriptPubKey, txId, amount, SlotState.FILLED);

        // Calculate expected PegoutId using mock block hash
        bytes32 mockBlockHash = 0x0000000000000000000049b460f18614380a01b8709d2c3a8ddf451d08d862b8;
        bytes32 expectedPegoutId =
            keccak256(abi.encode(stream.streamId, packetNumber, slotId, address(this), mockBlockHash));

        // Assert
        vm.expectEmit(address(pm));
        emit IPegManager.PegoutRequested(
            userPubKey,
            COMMITTEE_ID_STREAM_1_COMMITTEE_1,
            expectedSignatureData,
            stream.streamId,
            packetNumber,
            slotId,
            amount,
            expectedPegoutId
        );

        // Act
        pm.tryPegout{value: amountInWei}(userPubKey);
    }

    function test_registerUserTake_Revert_EnforcedPause_PausedContract() external {
        // Arrange
        RegisterUserTakeSetup memory pegoutSetup = setup_pegout();
        pausePegManager();

        // Assert
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);

        // Act
        pm.registerUserTake(pegoutSetup.pegoutTxSPVProof);
    }

    function test_registerUserTake_Success_UnpausedContract() external {
        // Arrange
        RegisterUserTakeSetup memory pegoutSetup = setup_pegout();
        pauseAndUnpausePegManager();

        // Act
        pm.registerUserTake(pegoutSetup.pegoutTxSPVProof);
    }

    function test_triggerOperatorTake_Revert_EnforcedPause_PausedContract() external {
        // Arrange
        RegisterUserTakeSetup memory pegoutSetup = setup_pegout();
        pausePegManager();

        // Assert
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);

        // Act
        pm.triggerOperatorTake(pegoutSetup.pegoutSignatureHash);
    }

    function test_triggerOperatorTake_Success_UnpausedContract() external {
        // Arrange
        pauseAndUnpausePegManager();
        RegisterUserTakeSetup memory pegoutSetup = setup_pegout();
        bytes32 pegoutTxId = pegoutSetup.pegoutTxid;
        bytes memory nonce =
            hex"f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a00000";
        uint256 createdAt = block.timestamp;
        // Expire TAKE_0
        vm.warp(createdAt + TAKE_0_TIMEOUT_DEFAULT + 1);

        Committee memory committee = registry.getCommittee(COMMITTEE_ID_STREAM_1_COMMITTEE_1);
        address firstOpAddress = committee.members[0].memberAddress;
        address secondOpAddress = committee.members[1].memberAddress;
        setup_addMemberNonce(firstOpAddress, pegoutTxId, nonce);
        setup_addMemberNonce(secondOpAddress, pegoutTxId, nonce);

        // Assert
        assertEventOperatorTakeTriggered(pegoutTxId, pegoutSetup, secondOpAddress, createdAt);

        // Act
        pm.triggerOperatorTake(pegoutTxId);
    }

    function test_registerOperatorTake_Revert_EnforcedPause_PausedContract() external {
        // Arrange
        (address operatorAddress, RegisterUserTakeSetup memory setup) = setup_operatorTake();
        bytes32 operatorPubKey = getMemberTakePubKey(operatorAddress);
        BtcTransaction memory pegoutTx =
            createPegoutTx(setup.acceptPeginTxid, BtcHelper.pubKeyXonlyToCompact(operatorPubKey), VALUE);
        BtcTxSPVProof memory pegoutTxSPVProof = createBtcTxSPVProof(pegoutTx);

        pausePegManager();

        // Assert
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);

        // Act
        vm.prank(operatorAddress);
        pm.registerOperatorTake(pegoutTxSPVProof);
    }

    function test_registerOperatorTake_Success_UnpausedContract() external {
        // Arrange
        pauseAndUnpausePegManager();

        (address operatorAddress, RegisterUserTakeSetup memory setup) = setup_operatorTake();
        bytes32 operatorPubKey = getMemberTakePubKey(operatorAddress);
        BtcTransaction memory pegoutTx =
            createPegoutTx(setup.acceptPeginTxid, BtcHelper.pubKeyXonlyToCompact(operatorPubKey), VALUE);
        BtcTxSPVProof memory pegoutTxSPVProof = createBtcTxSPVProof(pegoutTx);

        // Act
        vm.prank(operatorAddress);
        pm.registerOperatorTake(pegoutTxSPVProof);
    }

    function test_setUserTakeTimeout_Success_PausedContract() external {
        // Arrange
        pausePegManager();

        uint256 timeout = TAKE_0_TIMEOUT_DEFAULT + 1 days;
        address owner = pm.owner();

        // Assert
        vm.expectEmit(address(pm));
        emit IPegManager.UserTakeTimeoutUpdated(timeout);

        // Act
        vm.prank(owner);
        pm.setUserTakeTimeout(timeout);
    }

    function test_setOperatorTakeTimeout_Success_PausedContract() external {
        // Arrange
        pausePegManager();

        uint256 timeout = TAKE_1_TIMEOUT_DEFAULT + 1 days;
        address owner = pm.owner();

        // Assert
        vm.expectEmit(address(pm));
        emit IPegManager.OperatorTakeTimeoutUpdated(timeout);

        // Act
        vm.prank(owner);
        pm.setOperatorTakeTimeout(timeout);
    }
}
