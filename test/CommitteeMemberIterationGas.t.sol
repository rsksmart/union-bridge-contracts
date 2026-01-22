// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {CommitteeMember, SignatureData, CommunicationData} from "src/interfaces/ICommitteeRegistry.sol";
import {HelperContract} from "test/helpers/HelperContract.sol";
import {StreamDenomination} from "src/interfaces/IStreamManager.sol";

contract CommitteeMemberIterationGasTest is Test, HelperContract {
    bytes private constant TEST_NONCE =
        hex"f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a00000";

    bytes32 private constant TEST_SIGNATURE = bytes32(uint256(1));

    uint256 private constant TEST_GAS_PRICE = 20 * 1e9;

    function _getTestTxid(string memory testName, uint256 iterationIndex) internal pure returns (bytes32) {
        return keccak256(abi.encode(testName, iterationIndex));
    }

    function setUp() external {
        runTestDeployScript();
        vm.roll(1000);
        vm.txGasPrice(TEST_GAS_PRICE);
    }

    function _logGasConsumption(
        string memory testName,
        uint256 size,
        uint256 gasUsed,
        uint256 gasPrice,
        uint256 costInWei
    ) internal pure {
        console.log(string.concat("\n=== ", testName, " Gas Consumption ==="));
        console.log(string.concat("Committee Size: ", Strings.toString(size)));
        console.log(string.concat("Gas Used: ", Strings.toString(gasUsed)));
        console.log(string.concat("Gas Price (gwei): ", Strings.toString(gasPrice / 1e9)));
        console.log(string.concat("Cost (wei): ", Strings.toString(costInWei)));
    }

    function test_GasConsumption_SignatureManager_addMemberNonce_Size10() public {
        _test_GasConsumption_SignatureManager_addMemberNonce(10);
    }

    function test_GasConsumption_SignatureManager_addMemberNonce_Size20() public {
        _test_GasConsumption_SignatureManager_addMemberNonce(20);
    }

    function test_GasConsumption_SignatureManager_addMemberNonce_Size30() public {
        _test_GasConsumption_SignatureManager_addMemberNonce(30);
    }

    function test_GasConsumption_SignatureManager_addMemberNonce_Size50() public {
        _test_GasConsumption_SignatureManager_addMemberNonce(50);
    }

    function test_GasConsumption_SignatureManager_addMemberNonce_Size70() public {
        _test_GasConsumption_SignatureManager_addMemberNonce(70);
    }

    function test_GasConsumption_SignatureManager_addMemberNonce_Size100() public {
        _test_GasConsumption_SignatureManager_addMemberNonce(100);
    }

    function _test_GasConsumption_SignatureManager_addMemberNonce(uint256 size) internal {
        // Arrange
        (uint128 committeeId, CommitteeMember[] memory members) = setup_completeCommitteeWithSize(size);

        bytes32 txid = _getTestTxid("test_GasConsumption_SignatureManager_addMemberNonce", size);
        vm.prank(address(peginManager));
        signatureManager.initSignatures(txid, committeeId);

        // Test worst case: last member (position N-1)
        address lastMember = members[size - 1].memberAddress;

        // Act
        uint256 gasStart = gasleft();
        vm.prank(lastMember);
        signatureManager.addMemberNonce(txid, TEST_NONCE);
        uint256 gasUsed = gasStart - gasleft();
        (uint256 gasPrice, uint256 costInWei) = calculateGasCost(gasUsed);

        // Log
        _logGasConsumption("SignatureManager.addMemberNonce", size, gasUsed, gasPrice, costInWei);
    }

    function test_GasConsumption_SignatureManager_getPartialSignatures_Size10() public {
        _test_GasConsumption_SignatureManager_getPartialSignatures(10);
    }

    function test_GasConsumption_SignatureManager_getPartialSignatures_Size20() public {
        _test_GasConsumption_SignatureManager_getPartialSignatures(20);
    }

    function test_GasConsumption_SignatureManager_getPartialSignatures_Size30() public {
        _test_GasConsumption_SignatureManager_getPartialSignatures(30);
    }

    function test_GasConsumption_SignatureManager_getPartialSignatures_Size50() public {
        _test_GasConsumption_SignatureManager_getPartialSignatures(50);
    }

    function test_GasConsumption_SignatureManager_getPartialSignatures_Size70() public {
        _test_GasConsumption_SignatureManager_getPartialSignatures(70);
    }

    function test_GasConsumption_SignatureManager_getPartialSignatures_Size100() public {
        _test_GasConsumption_SignatureManager_getPartialSignatures(100);
    }

    function _test_GasConsumption_SignatureManager_getPartialSignatures(uint256 size) internal {
        // Arrange
        (uint128 committeeId, CommitteeMember[] memory members) = setup_completeCommitteeWithSize(size);

        bytes32 txid = _getTestTxid("test_GasConsumption_SignatureManager_getPartialSignatures", size);
        vm.prank(address(peginManager));
        signatureManager.initSignatures(txid, committeeId);

        for (uint256 i = 0; i < members.length; i++) {
            setup_addMemberNonce(members[i].memberAddress, txid, TEST_NONCE);
        }

        for (uint256 i = 0; i < members.length; i++) {
            setup_addMemberSignature(members[i].memberAddress, txid, TEST_SIGNATURE);
        }

        // Act
        uint256 gasStart = gasleft();
        signatureManager.getPartialSignatures(txid);
        uint256 gasUsed = gasStart - gasleft();
        (uint256 gasPrice, uint256 costInWei) = calculateGasCost(gasUsed);

        // Log
        _logGasConsumption("SignatureManager.getPartialSignatures", size, gasUsed, gasPrice, costInWei);
    }

    function test_GasConsumption_SignatureManager_initOperatorTakeTxids_Size10() public {
        _test_GasConsumption_SignatureManager_initOperatorTakeTxids(10);
    }

    function test_GasConsumption_SignatureManager_initOperatorTakeTxids_Size20() public {
        _test_GasConsumption_SignatureManager_initOperatorTakeTxids(20);
    }

    function test_GasConsumption_SignatureManager_initOperatorTakeTxids_Size30() public {
        _test_GasConsumption_SignatureManager_initOperatorTakeTxids(30);
    }

    function test_GasConsumption_SignatureManager_initOperatorTakeTxids_Size50() public {
        _test_GasConsumption_SignatureManager_initOperatorTakeTxids(50);
    }

    function test_GasConsumption_SignatureManager_initOperatorTakeTxids_Size70() public {
        _test_GasConsumption_SignatureManager_initOperatorTakeTxids(70);
    }

    function test_GasConsumption_SignatureManager_initOperatorTakeTxids_Size100() public {
        _test_GasConsumption_SignatureManager_initOperatorTakeTxids(100);
    }

    function _test_GasConsumption_SignatureManager_initOperatorTakeTxids(uint256 size) internal {
        // Arrange
        (uint128 committeeId,) = setup_completeCommitteeWithSize(size);

        bytes32 acceptPeginTxid = _getTestTxid("test_GasConsumption_SignatureManager_initOperatorTakeTxids", size);

        // Act
        uint256 gasStart = gasleft();
        setup_initOperatorTakeTxids(acceptPeginTxid, committeeId);
        uint256 gasUsed = gasStart - gasleft();
        (uint256 gasPrice, uint256 costInWei) = calculateGasCost(gasUsed);

        // Log
        _logGasConsumption("SignatureManager.initOperatorTakeTxids", size, gasUsed, gasPrice, costInWei);
    }

    function test_GasConsumption_SignatureManager_getOperatorTakeData_Size10() public {
        _test_GasConsumption_SignatureManager_getOperatorTakeData(10);
    }

    function test_GasConsumption_SignatureManager_getOperatorTakeData_Size20() public {
        _test_GasConsumption_SignatureManager_getOperatorTakeData(20);
    }

    function test_GasConsumption_SignatureManager_getOperatorTakeData_Size30() public {
        _test_GasConsumption_SignatureManager_getOperatorTakeData(30);
    }

    function test_GasConsumption_SignatureManager_getOperatorTakeData_Size50() public {
        _test_GasConsumption_SignatureManager_getOperatorTakeData(50);
    }

    function test_GasConsumption_SignatureManager_getOperatorTakeData_Size70() public {
        _test_GasConsumption_SignatureManager_getOperatorTakeData(70);
    }

    function test_GasConsumption_SignatureManager_getOperatorTakeData_Size100() public {
        _test_GasConsumption_SignatureManager_getOperatorTakeData(100);
    }

    function _test_GasConsumption_SignatureManager_getOperatorTakeData(uint256 size) internal {
        // Arrange
        (uint128 committeeId,) = setup_completeCommitteeWithSize(size);

        bytes32 acceptPeginTxid = _getTestTxid("test_GasConsumption_SignatureManager_getOperatorTakeData", size);
        setup_initOperatorTakeTxids(acceptPeginTxid, committeeId);

        uint256 operatorCount = size / 2;
        uint32 slotId = 0;
        setup_addOperatorTakeTxids_MultipleOperators(acceptPeginTxid, committeeId, slotId, operatorCount);

        // Act
        uint256 gasStart = gasleft();
        signatureManager.getOperatorTakeData(acceptPeginTxid);
        uint256 gasUsed = gasStart - gasleft();
        (uint256 gasPrice, uint256 costInWei) = calculateGasCost(gasUsed);

        // Log
        _logGasConsumption("SignatureManager.getOperatorTakeData", size, gasUsed, gasPrice, costInWei);
    }

    function test_GasConsumption_CommitteeRegistry_getOperatorDisputeData_Size10() public {
        _test_GasConsumption_CommitteeRegistry_getOperatorDisputeData(10);
    }

    function test_GasConsumption_CommitteeRegistry_getOperatorDisputeData_Size20() public {
        _test_GasConsumption_CommitteeRegistry_getOperatorDisputeData(20);
    }

    function test_GasConsumption_CommitteeRegistry_getOperatorDisputeData_Size30() public {
        _test_GasConsumption_CommitteeRegistry_getOperatorDisputeData(30);
    }

    function test_GasConsumption_CommitteeRegistry_getOperatorDisputeData_Size50() public {
        _test_GasConsumption_CommitteeRegistry_getOperatorDisputeData(50);
    }

    function test_GasConsumption_CommitteeRegistry_getOperatorDisputeData_Size70() public {
        _test_GasConsumption_CommitteeRegistry_getOperatorDisputeData(70);
    }

    function test_GasConsumption_CommitteeRegistry_getOperatorDisputeData_Size100() public {
        _test_GasConsumption_CommitteeRegistry_getOperatorDisputeData(100);
    }

    function _test_GasConsumption_CommitteeRegistry_getOperatorDisputeData(uint256 size) internal {
        // Arrange
        (uint128 committeeId, CommitteeMember[] memory members) = setup_completeCommitteeWithSize(size);

        bytes32 txid = _getTestTxid("test_GasConsumption_CommitteeRegistry_getOperatorDisputeData", size);
        vm.prank(address(peginManager));
        signatureManager.initSignatures(txid, committeeId);

        SignatureData[] memory signatureData = new SignatureData[](size);
        for (uint256 i = 0; i < members.length; i++) {
            vm.prank(members[i].memberAddress);
            signatureManager.addMemberNonce(txid, TEST_NONCE);
            signatureData[i] = SignatureData({nonce: TEST_NONCE, signature: bytes32(0)});
        }

        // Act
        uint256 gasStart = gasleft();
        vm.prank(address(peginManager));
        registry.getOperatorDisputeData(committeeId, signatureData, 1);
        uint256 gasUsed = gasStart - gasleft();
        (uint256 gasPrice, uint256 costInWei) = calculateGasCost(gasUsed);

        // Log
        _logGasConsumption("CommitteeRegistry.getOperatorDisputeData", size, gasUsed, gasPrice, costInWei);
    }

    function test_GasConsumption_CommitteeRegistry_getCommunicationData_Size10() public {
        _test_GasConsumption_CommitteeRegistry_getCommunicationData(10);
    }

    function test_GasConsumption_CommitteeRegistry_getCommunicationData_Size20() public {
        _test_GasConsumption_CommitteeRegistry_getCommunicationData(20);
    }

    function test_GasConsumption_CommitteeRegistry_getCommunicationData_Size30() public {
        _test_GasConsumption_CommitteeRegistry_getCommunicationData(30);
    }

    function test_GasConsumption_CommitteeRegistry_getCommunicationData_Size50() public {
        _test_GasConsumption_CommitteeRegistry_getCommunicationData(50);
    }

    function test_GasConsumption_CommitteeRegistry_getCommunicationData_Size70() public {
        _test_GasConsumption_CommitteeRegistry_getCommunicationData(70);
    }

    function test_GasConsumption_CommitteeRegistry_getCommunicationData_Size100() public {
        _test_GasConsumption_CommitteeRegistry_getCommunicationData(100);
    }

    function _test_GasConsumption_CommitteeRegistry_getCommunicationData(uint256 size) internal {
        // Arrange
        (uint128 committeeId, CommitteeMember[] memory members) = setup_pendingCommitteeWithSize(size);

        for (uint256 i = 0; i < members.length; i++) {
            CommunicationData[] memory commData = createMinimalCommunicationData(members.length, i);

            vm.prank(members[i].memberAddress);
            registry.depositCommunicationData(committeeId, commData);
        }

        address lastMember = members[members.length - 1].memberAddress;

        // Act
        uint256 gasStart = gasleft();
        vm.prank(lastMember);
        registry.getMemberCommunicationData(committeeId, lastMember);
        uint256 gasUsed = gasStart - gasleft();
        (uint256 gasPrice, uint256 costInWei) = calculateGasCost(gasUsed);

        // Log
        _logGasConsumption("CommitteeRegistry.getMemberCommunicationData", size, gasUsed, gasPrice, costInWei);
    }

    function test_GasConsumption_PeginManager_getRequestPeginData_Size10() public {
        _test_GasConsumption_PeginManager_getRequestPeginData(10);
    }

    function test_GasConsumption_PeginManager_getRequestPeginData_Size20() public {
        _test_GasConsumption_PeginManager_getRequestPeginData(20);
    }

    function test_GasConsumption_PeginManager_getRequestPeginData_Size30() public {
        _test_GasConsumption_PeginManager_getRequestPeginData(30);
    }

    function test_GasConsumption_PeginManager_getRequestPeginData_Size50() public {
        _test_GasConsumption_PeginManager_getRequestPeginData(50);
    }

    function test_GasConsumption_PeginManager_getRequestPeginData_Size70() public {
        _test_GasConsumption_PeginManager_getRequestPeginData(70);
    }

    function test_GasConsumption_PeginManager_getRequestPeginData_Size100() public {
        _test_GasConsumption_PeginManager_getRequestPeginData(100);
    }

    function _test_GasConsumption_PeginManager_getRequestPeginData(uint256 size) internal {
        // Arrange
        address dummyRskAddress = getPeginRskDestinationAddress();
        bytes32 dummyBtcReimbursementPubKey = getPeginBtcReimbursementPubKey();

        setup_completeCommitteeWithSize(size);

        // Act
        uint256 gasStart = gasleft();
        peginManager.getRequestPeginData(dummyRskAddress, VALUE, dummyBtcReimbursementPubKey);
        uint256 gasUsed = gasStart - gasleft();
        (uint256 gasPrice, uint256 costInWei) = calculateGasCost(gasUsed);

        // Log
        _logGasConsumption("PeginManager.getRequestPeginData", size, gasUsed, gasPrice, costInWei);
    }

    function test_GasConsumption_MemberRegistry_releaseCommitteeMembers_Size10() public {
        _test_GasConsumption_MemberRegistry_releaseCommitteeMembers(10);
    }

    function test_GasConsumption_MemberRegistry_releaseCommitteeMembers_Size20() public {
        _test_GasConsumption_MemberRegistry_releaseCommitteeMembers(20);
    }

    function test_GasConsumption_MemberRegistry_releaseCommitteeMembers_Size30() public {
        _test_GasConsumption_MemberRegistry_releaseCommitteeMembers(30);
    }

    function test_GasConsumption_MemberRegistry_releaseCommitteeMembers_Size50() public {
        _test_GasConsumption_MemberRegistry_releaseCommitteeMembers(50);
    }

    function test_GasConsumption_MemberRegistry_releaseCommitteeMembers_Size70() public {
        _test_GasConsumption_MemberRegistry_releaseCommitteeMembers(70);
    }

    function test_GasConsumption_MemberRegistry_releaseCommitteeMembers_Size100() public {
        _test_GasConsumption_MemberRegistry_releaseCommitteeMembers(100);
    }

    function _test_GasConsumption_MemberRegistry_releaseCommitteeMembers(uint256 size) internal {
        // Arrange
        (, CommitteeMember[] memory members) = setup_completeCommitteeWithSize(size);

        StreamDenomination denomination = StreamDenomination._0_01BTC;
        uint64 streamId = uint64(denomination);
        uint64 packetNumber = 0;

        for (uint256 i = 0; i < members.length; i++) {
            vm.prank(members[i].memberAddress);
            memberRegistry.setReApplyForStream(denomination, false);
        }

        // Act
        uint256 gasStart = gasleft();
        vm.prank(address(registry));
        memberRegistry.releaseCommitteeMembers(members, streamId, packetNumber);
        uint256 gasUsed = gasStart - gasleft();
        (uint256 gasPrice, uint256 costInWei) = calculateGasCost(gasUsed);

        // Log
        _logGasConsumption("MemberRegistry.releaseCommitteeMembers", size, gasUsed, gasPrice, costInWei);
    }

    function test_GasConsumption_MemberRegistry_stakePreStakedCandidatesBalance_Size10() public {
        _test_GasConsumption_MemberRegistry_stakePreStakedCandidatesBalance(10);
    }

    function test_GasConsumption_MemberRegistry_stakePreStakedCandidatesBalance_Size20() public {
        _test_GasConsumption_MemberRegistry_stakePreStakedCandidatesBalance(20);
    }

    function test_GasConsumption_MemberRegistry_stakePreStakedCandidatesBalance_Size30() public {
        _test_GasConsumption_MemberRegistry_stakePreStakedCandidatesBalance(30);
    }

    function test_GasConsumption_MemberRegistry_stakePreStakedCandidatesBalance_Size50() public {
        _test_GasConsumption_MemberRegistry_stakePreStakedCandidatesBalance(50);
    }

    function test_GasConsumption_MemberRegistry_stakePreStakedCandidatesBalance_Size70() public {
        _test_GasConsumption_MemberRegistry_stakePreStakedCandidatesBalance(70);
    }

    function test_GasConsumption_MemberRegistry_stakePreStakedCandidatesBalance_Size100() public {
        _test_GasConsumption_MemberRegistry_stakePreStakedCandidatesBalance(100);
    }

    function _test_GasConsumption_MemberRegistry_stakePreStakedCandidatesBalance(uint256 size) internal {
        // Arrange
        (, CommitteeMember[] memory members) = setup_pendingCommitteeWithSize(size);

        StreamDenomination denomination = StreamDenomination._0_01BTC;
        uint64 packetNumber = 0;

        // Act
        uint256 gasStart = gasleft();
        vm.prank(address(registry));
        memberRegistry.stakePreStakedCandidatesBalance(members, denomination, packetNumber);
        uint256 gasUsed = gasStart - gasleft();
        (uint256 gasPrice, uint256 costInWei) = calculateGasCost(gasUsed);

        // Log
        _logGasConsumption("MemberRegistry.stakePreStakedCandidatesBalance", size, gasUsed, gasPrice, costInWei);
    }

    function test_GasConsumption_CommitteeRegistry_createCommittee_Size10() public {
        _test_GasConsumption_CommitteeRegistry_createCommittee(10);
    }

    function test_GasConsumption_CommitteeRegistry_createCommittee_Size20() public {
        _test_GasConsumption_CommitteeRegistry_createCommittee(20);
    }

    function test_GasConsumption_CommitteeRegistry_createCommittee_Size30() public {
        _test_GasConsumption_CommitteeRegistry_createCommittee(30);
    }

    function test_GasConsumption_CommitteeRegistry_createCommittee_Size50() public {
        _test_GasConsumption_CommitteeRegistry_createCommittee(50);
    }

    function test_GasConsumption_CommitteeRegistry_createCommittee_Size70() public {
        _test_GasConsumption_CommitteeRegistry_createCommittee(70);
    }

    function test_GasConsumption_CommitteeRegistry_createCommittee_Size100() public {
        _test_GasConsumption_CommitteeRegistry_createCommittee(100);
    }

    function _test_GasConsumption_CommitteeRegistry_createCommittee(uint256 size) internal {
        // Arrange
        StreamDenomination denomination = StreamDenomination._0_01BTC;
        uint64 streamId = uint64(denomination);

        vm.roll(block.number + 1);

        vm.prank(registry.owner());
        registry.setCommitteeMemberCount(size);

        uint256 numOperators = size / 2;
        uint256 numWatchtowers = size - numOperators;
        setup_registerNewMembers(numWatchtowers, numOperators, denomination);

        // Act
        uint256 gasStart = gasleft();
        vm.prank(address(peginManager));
        registry.createCommittee(streamId);
        uint256 gasUsed = gasStart - gasleft();

        (uint256 gasPrice, uint256 costInWei) = calculateGasCost(gasUsed);

        // Log
        _logGasConsumption(
            "CommitteeRegistry._createCommittee (via createCommittee)", size, gasUsed, gasPrice, costInWei
        );
    }

    function test_GasConsumption_MemberRegistry_selectCommittee_Size10() public {
        _test_GasConsumption_MemberRegistry_selectCommittee(10);
    }

    function test_GasConsumption_MemberRegistry_selectCommittee_Size20() public {
        _test_GasConsumption_MemberRegistry_selectCommittee(20);
    }

    function test_GasConsumption_MemberRegistry_selectCommittee_Size30() public {
        _test_GasConsumption_MemberRegistry_selectCommittee(30);
    }

    function test_GasConsumption_MemberRegistry_selectCommittee_Size50() public {
        _test_GasConsumption_MemberRegistry_selectCommittee(50);
    }

    function test_GasConsumption_MemberRegistry_selectCommittee_Size70() public {
        _test_GasConsumption_MemberRegistry_selectCommittee(70);
    }

    function test_GasConsumption_MemberRegistry_selectCommittee_Size100() public {
        _test_GasConsumption_MemberRegistry_selectCommittee(100);
    }

    function _test_GasConsumption_MemberRegistry_selectCommittee(uint256 size) internal {
        // Arrange
        StreamDenomination denomination = StreamDenomination._0_01BTC;
        uint64 streamId = uint64(denomination);

        vm.prank(registry.owner());
        registry.setCommitteeMemberCount(size);

        uint256 numOperators = size / 2;
        uint256 numWatchtowers = size - numOperators;
        setup_registerCandidatesForStream(numWatchtowers, numOperators, denomination);

        // Act

        uint256 minSize = size / 2;
        uint256 gasStart = gasleft();
        vm.prank(address(registry));
        memberRegistry.selectCommittee(streamId, minSize, minSize, size);
        uint256 gasUsed = gasStart - gasleft();

        (uint256 gasPrice, uint256 costInWei) = calculateGasCost(gasUsed);
        // Log
        _logGasConsumption("MemberRegistry._selectCommittee (via selectCommittee)", size, gasUsed, gasPrice, costInWei);
    }
}
