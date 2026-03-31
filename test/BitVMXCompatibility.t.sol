// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

/**
 * ============================================================================
 * BitVMX COMPATIBILITY TEST
 * ============================================================================
 *
 * This test file is the static part — do not modify it unless the test logic changes.
 * Transaction data lives in BitVMXCompatibilityData.sol, which is the generated part.
 *
 * WORKFLOW:
 *   1. Run BitVMX example:
 *        ./examples/union/scripts/run-example.sh <example_name>
 *      (in the rust-bitvmx-client repository)
 *   2. Copy the generated BitVMXCompatibilityData.sol into this repo's test/ directory
 *   3. Run: forge clean && forge test --match-contract BitVMXCompatibility1Test -vv
 *   4. Pass = compatible, fail = mismatch
 *
 * ============================================================================
 */
import {Test} from "forge-std/Test.sol";
import {HelperContract} from "test/helpers/HelperContract.sol";
import {BitVMXCompatibilityData} from "test/BitVMXCompatibilityData.sol";
import {BtcTxSPVProof, PegStatus} from "src/interfaces/IPegCommonTypes.sol";
import {Role, Committee} from "src/interfaces/ICommitteeRegistry.sol";
import {CompactPubKey} from "src/interfaces/IMemberRegistry.sol";
import {StreamDenomination} from "src/interfaces/IStreamManager.sol";
import {OperatorTakeInfo} from "src/interfaces/IOperatorTakeManager.sol";
import {BtcHelper} from "src/libraries/BtcHelper.sol";
import {Constants} from "src/libraries/Constants.sol";

contract BitVMXCompatibility1Test is Test, HelperContract, BitVMXCompatibilityData {
    // =========================================================================
    // Tests
    // =========================================================================

    function test_requestPeginPassesValidation() external {
        _bitvmx_baseSetup();

        BtcTxSPVProof memory requestPeginSPV = createBtcTxSPVProof(_getBitVMXRequestPeginTx());
        peginManager.requestPegin(requestPeginSPV);

        assertEq(
            peginManager.getAcceptPegin(EXPECTED_REQUEST_PEGIN_TXID),
            EXPECTED_ACCEPT_PEGIN_TXID,
            "Accept Pegin TXID mismatch"
        );
    }

    function test_acceptPeginPassesValidation() external {
        _bitvmx_throughRequestPegin();

        BtcTxSPVProof memory acceptPeginSPV = createBtcTxSPVProof(_getBitVMXAcceptPeginTx());
        peginManager.acceptPegin(acceptPeginSPV);

        assertEq(
            bitcoinManager.getBtcTxid(_getBitVMXAcceptPeginTx()),
            EXPECTED_ACCEPT_PEGIN_TXID,
            "Accept Pegin TXID mismatch"
        );
    }

    function test_registerAdvanceFundsPassesValidation() external {
        address operatorAddress = _bitvmx_throughCancelUserTake();

        BtcTxSPVProof memory advanceFundsSPV = createBtcTxSPVProof(_getBitVMXAdvanceFundsTx());
        vm.prank(operatorAddress);
        operatorTakeManager.registerAdvanceFunds(EXPECTED_ACCEPT_PEGIN_TXID, advanceFundsSPV);
    }

    function test_registerReimbursementKickoffPassesValidation() external {
        address operatorAddress = _bitvmx_throughAdvanceFunds();

        BtcTxSPVProof memory kickoffSPV = createBtcTxSPVProof(_getBitVMXReimbursementKickoffTx());
        vm.prank(operatorAddress);
        operatorTakeManager.registerReimbursementKickoff(EXPECTED_ACCEPT_PEGIN_TXID, kickoffSPV);

        assertEq(
            operatorTakeManager.getOperatorTakeInfo(EXPECTED_ACCEPT_PEGIN_TXID).reimbursementKickoffTxid,
            EXPECTED_REIMBURSEMENT_KICKOFF_TXID,
            "Kickoff TXID mismatch"
        );
    }

    function test_registerChallengePassesValidation() external {
        address operatorAddress = _bitvmx_throughKickoff();

        BtcTxSPVProof memory challengeSPV = createBtcTxSPVProof(_getBitVMXChallengeTx());
        vm.prank(operatorAddress);
        challengeManager.registerChallenge(EXPECTED_ACCEPT_PEGIN_TXID, challengeSPV);

        assertEq(
            challengeManager.getChallengeInfo(EXPECTED_ACCEPT_PEGIN_TXID).challengeTxid,
            EXPECTED_CHALLENGE_TXID,
            "Challenge TXID mismatch"
        );
    }

    function test_registerInputRevealedPassesValidation() external {
        address operatorAddress = _bitvmx_throughChallenge();

        BtcTxSPVProof memory inputRevealSPV = createBtcTxSPVProof(_getBitVMXRevealInputTx());
        vm.prank(operatorAddress);
        challengeManager.registerInputRevealed(EXPECTED_ACCEPT_PEGIN_TXID, inputRevealSPV);

        assertEq(
            challengeManager.getChallengeInfo(EXPECTED_ACCEPT_PEGIN_TXID).revealTxid,
            EXPECTED_REVEAL_INPUT_TXID,
            "Reveal TXID mismatch"
        );
    }

    function test_registerOperatorTakePassesValidation() external {
        address operatorAddress = _bitvmx_throughKickoff();

        BtcTxSPVProof memory opTakeSPV = createBtcTxSPVProof(_getBitVMXOperatorTakeTx());
        vm.prank(operatorAddress);
        operatorTakeManager.registerOperatorTake(opTakeSPV);

        assertEq(
            uint256(streamManager.getStreamPosition(EXPECTED_ACCEPT_PEGIN_TXID).pegStatus),
            uint256(PegStatus.COMPLETED),
            "Operator Take TXID mismatch"
        );
    }

    function test_registerOperatorWonPassesValidation() external {
        address operatorAddress = _bitvmx_throughInputReveal();

        BtcTxSPVProof memory opWonSPV = createBtcTxSPVProof(_getBitVMXOperatorWonTx());
        vm.prank(operatorAddress);
        operatorTakeManager.registerOperatorWon(opWonSPV);

        assertEq(
            uint256(streamManager.getStreamPosition(EXPECTED_ACCEPT_PEGIN_TXID).pegStatus),
            uint256(PegStatus.COMPLETED),
            "Operator Won TXID mismatch"
        );
    }

    function test_registerInputNotRevealedPassesValidation() external {
        address operatorAddress = _bitvmx_throughChallenge();

        BtcTxSPVProof memory notRevealedSPV = createBtcTxSPVProof(_getBitVMXInputNotRevealedTx());
        vm.prank(operatorAddress);
        challengeManager.registerInputNotRevealed(EXPECTED_ACCEPT_PEGIN_TXID, notRevealedSPV);

        vm.expectRevert();
        challengeManager.getChallengeInfo(EXPECTED_ACCEPT_PEGIN_TXID);
    }

    // =========================================================================
    // Shared setup helpers
    // =========================================================================

    /// @dev Deploy contracts and set up the BitVMX committee. Returns the committeeId.
    function _bitvmx_baseSetup() internal returns (uint128 committeeId) {
        runTestDeployScript();
        registry.setMinCommitteeWatchtowersHarness(WATCHTOWER_COUNT);
        registry.setMinCommitteeOperatorsHarness(OPERATOR_COUNT);
        bridgeMock.setBtcTransactionConfirmations(10);
        committeeId = _bitvmx_createCommittee();
        _bitvmx_injectKeys(committeeId);
    }

    /// @dev Run setup through requestPegin.
    function _bitvmx_throughRequestPegin() internal returns (uint128 committeeId) {
        committeeId = _bitvmx_baseSetup();

        BtcTxSPVProof memory requestPeginSPV = createBtcTxSPVProof(_getBitVMXRequestPeginTx());
        peginManager.requestPegin(requestPeginSPV);
    }

    /// @dev Run setup through acceptPegin.
    function _bitvmx_throughAcceptPegin() internal returns (uint128 committeeId) {
        committeeId = _bitvmx_throughRequestPegin();

        BtcTxSPVProof memory acceptPeginSPV = createBtcTxSPVProof(_getBitVMXAcceptPeginTx());
        peginManager.acceptPegin(acceptPeginSPV);
    }

    /// @dev Each operator registers their pre-committed take/won txids after acceptPegin.
    function _bitvmx_registerTakeTxids(uint128 committeeId) internal {
        Committee memory committee = registry.getCommittee(committeeId);
        bytes32 takeTxid = getBtcTxid(_getBitVMXOperatorTakeTx());
        bytes32 wonTxid = getBtcTxid(_getBitVMXOperatorWonTx());

        for (uint256 i = 0; i < committee.members.length; i++) {
            if (committee.members[i].role != Role.OPERATOR) continue;
            setup_addOperatorTakeTxids(
                committee.members[i].memberAddress, EXPECTED_ACCEPT_PEGIN_TXID, takeTxid, wonTxid
            );
        }
    }

    /// @dev Find the committee member whose dispute key matches _getBitVMXDisputeKeys()[OPERATOR_INDEX].
    function _bitvmx_findTargetOperator(uint128 committeeId) internal view returns (address) {
        CompactPubKey memory targetKey = _getBitVMXDisputeKeys()[OPERATOR_INDEX];
        Committee memory committee = registry.getCommittee(committeeId);
        for (uint256 i = 0; i < committee.members.length; i++) {
            address addr = committee.members[i].memberAddress;
            CompactPubKey memory key = memberRegistry.getMemberDisputePubKey(addr);
            if (key.xOnly == targetKey.xOnly && key.parity == targetKey.parity) {
                return addr;
            }
        }
        revert("BitVMX: target operator not found");
    }

    /// @dev Run setup through registerCancelUserTake.
    ///      The target operator (bitvmxDisputeKeys[OPERATOR_INDEX]) is guaranteed to be selected via
    ///      signatures — only that operator signs, so selectTakeOperator picks it.
    ///      Also injects PEGOUT_ID via the harness so that _getBitVMXAdvanceFundsTx()
    ///      passes registerAdvanceFunds validation.
    /// @return operatorAddress The selected operator address (holder of bitvmxDisputeKeys[OPERATOR_INDEX]).
    function _bitvmx_throughCancelUserTake() internal returns (address operatorAddress) {
        uint128 committeeId = _bitvmx_throughAcceptPegin();
        _bitvmx_registerTakeTxids(committeeId);

        address targetOp = _bitvmx_findTargetOperator(committeeId);

        // tryPegout — msg.value equals the denomination, derived from the request pegin tx
        uint256 pegoutWei = BtcHelper.satoshiToWei(
            uint64(_getBitVMXRequestPeginTx().outputs[Constants.REQUEST_PEGIN_VOUT_TAPTREE].amount)
        );
        vm.deal(globalUserAddress, pegoutWei);
        bridgeMock.setWeisTransferredToUnionBridge(pegoutWei);
        vm.prank(globalUserAddress);
        pegoutManager.tryPegout{value: pegoutWei}(USER_COMPRESSED_PUBKEY);

        // Add nonces for ALL members
        bytes32 pegoutTxid = pegoutManager.getPegoutStartInfo(EXPECTED_ACCEPT_PEGIN_TXID).pegoutTxid;
        setup_addMemberNonce_MultipleMembers(pegoutTxid, 0, registry.committeeMemberCount());

        // Add a signature ONLY for the target operator — guarantees it is the one selected
        vm.prank(targetOp);
        signatureManager.addMemberSignature(pegoutTxid, bytes32(uint256(0xdeadbeef)));

        // Expire user take timeout so triggerOperatorTake can proceed
        vm.warp(block.timestamp + TAKE_0_TIMEOUT_DEFAULT + 1);
        operatorTakeManager.triggerOperatorTake(EXPECTED_ACCEPT_PEGIN_TXID);

        // Inject the fixed pegoutId so _getBitVMXAdvanceFundsTx() passes registerAdvanceFunds validation
        operatorTakeManager.setPegoutIdHarness(EXPECTED_ACCEPT_PEGIN_TXID, PEGOUT_ID);

        OperatorTakeInfo memory opInfo = operatorTakeManager.getOperatorTakeInfo(EXPECTED_ACCEPT_PEGIN_TXID);
        operatorAddress = opInfo.operatorTakeAddress;
        assertEq(operatorAddress, targetOp, "BitVMX: wrong operator selected");

        // registerCancelUserTake (standard cancel tx spending the acceptPegin enabler output)
        bytes memory opDispKey = BtcHelper.compactPubKeyToBytes(memberRegistry.getMemberDisputePubKey(operatorAddress));
        BtcTxSPVProof memory cancelSPV =
            createBtcTxSPVProof(createCancelUserTakeTx(EXPECTED_ACCEPT_PEGIN_TXID, opDispKey));
        operatorTakeManager.registerCancelUserTake(cancelSPV);
    }

    /// @dev Run the full flow through registerAdvanceFunds using the BitVMX advance funds tx.
    /// @return operatorAddress The selected operator address (holder of bitvmxDisputeKeys[OPERATOR_INDEX]).
    function _bitvmx_throughAdvanceFunds() internal returns (address operatorAddress) {
        operatorAddress = _bitvmx_throughCancelUserTake();

        BtcTxSPVProof memory advanceSPV = createBtcTxSPVProof(_getBitVMXAdvanceFundsTx());
        vm.prank(operatorAddress);
        operatorTakeManager.registerAdvanceFunds(EXPECTED_ACCEPT_PEGIN_TXID, advanceSPV);
    }

    /// @dev Run the full flow through registerReimbursementKickoff using the BitVMX kickoff tx.
    /// @return operatorAddress The selected operator address (holder of bitvmxDisputeKeys[OPERATOR_INDEX]).
    function _bitvmx_throughKickoff() internal returns (address operatorAddress) {
        operatorAddress = _bitvmx_throughAdvanceFunds();

        BtcTxSPVProof memory kickoffSPV = createBtcTxSPVProof(_getBitVMXReimbursementKickoffTx());
        vm.prank(operatorAddress);
        operatorTakeManager.registerReimbursementKickoff(EXPECTED_ACCEPT_PEGIN_TXID, kickoffSPV);
    }

    /// @dev Run the full flow through registerChallenge using the BitVMX challenge tx.
    /// @return operatorAddress The selected operator address (holder of bitvmxDisputeKeys[OPERATOR_INDEX]).
    function _bitvmx_throughChallenge() internal returns (address operatorAddress) {
        operatorAddress = _bitvmx_throughKickoff();

        BtcTxSPVProof memory challengeSPV = createBtcTxSPVProof(_getBitVMXChallengeTx());
        vm.prank(operatorAddress);
        challengeManager.registerChallenge(EXPECTED_ACCEPT_PEGIN_TXID, challengeSPV);
    }

    /// @dev Run the full flow through registerInputRevealed using the BitVMX reveal input tx.
    /// @return operatorAddress The selected operator address (holder of bitvmxDisputeKeys[OPERATOR_INDEX]).
    function _bitvmx_throughInputReveal() internal returns (address operatorAddress) {
        operatorAddress = _bitvmx_throughChallenge();

        BtcTxSPVProof memory revealSPV = createBtcTxSPVProof(_getBitVMXRevealInputTx());
        vm.prank(operatorAddress);
        challengeManager.registerInputRevealed(EXPECTED_ACCEPT_PEGIN_TXID, revealSPV);
    }

    // =========================================================================
    // Committee setup helpers
    // =========================================================================

    /// @dev Creates a committee with generic keys for the stream matching the BitVMX pegin denomination.
    function _bitvmx_createCommittee() internal returns (uint128 committeeId) {
        uint64 peginAmount = uint64(_getBitVMXRequestPeginTx().outputs[Constants.REQUEST_PEGIN_VOUT_TAPTREE].amount);
        StreamDenomination denomination = StreamDenomination(streamManager.getStream(peginAmount).streamId);

        uint256 totalMembers = OPERATOR_COUNT + WATCHTOWER_COUNT;
        vm.prank(registry.owner());
        registry.setCommitteeMemberCount(totalMembers);

        vm.warp(10);
        vm.roll(10);
        setup_registerNewMembers(WATCHTOWER_COUNT, OPERATOR_COUNT, denomination);

        committeeId = registry.getPendingCommitteeId(uint64(denomination));
        setup_depositAggregatedKey_MultipleMembers(committeeId, 0, totalMembers);
    }

    /// @dev Overrides the committee's keys with the BitVMX-specific aggregated and dispute keys,
    ///      then recomputes the enabler script.
    function _bitvmx_injectKeys(uint128 committeeId) internal {
        registry.setCommitteeTakeAggregatedKeyHarness(committeeId, COMMITTEE_AGGREGATED_KEY);

        Committee memory committee = registry.getCommittee(committeeId);
        CompactPubKey[] memory bitvmxDisputeKeys = _getBitVMXDisputeKeys();
        uint256 opAssigned = 0;
        uint256 wtAssigned = 0;

        for (uint256 i = 0; i < committee.members.length; i++) {
            if (opAssigned < OPERATOR_COUNT && committee.members[i].role == Role.OPERATOR) {
                memberRegistry.setMemberDisputeKeyHarness(
                    committee.members[i].memberAddress, bitvmxDisputeKeys[opAssigned]
                );
                opAssigned++;
                continue;
            }
            if (wtAssigned < WATCHTOWER_COUNT && committee.members[i].role == Role.WATCHTOWER) {
                memberRegistry.setMemberDisputeKeyHarness(
                    committee.members[i].memberAddress, bitvmxDisputeKeys[OPERATOR_COUNT + wtAssigned]
                );
                wtAssigned++;
                continue;
            }
            if (opAssigned >= OPERATOR_COUNT && wtAssigned >= WATCHTOWER_COUNT) break;
        }

        CompactPubKey[] memory updatedDisputeKeys = registry.getCommitteeDisputeKeys(committeeId);
        bytes memory enablerScript =
            bitcoinManager.getEnablerOutputP2TRScriptPub(COMMITTEE_AGGREGATED_KEY, updatedDisputeKeys);
        streamManager.setPacketEnablerScriptHarness(0, 0, enablerScript);
    }
}
