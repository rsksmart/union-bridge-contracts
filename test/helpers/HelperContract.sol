// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {PegManager} from "src/PegManager.sol";
import {Role, Member, CommitteeMember, Committee, CommitteeRegistry} from "src/CommitteeRegistry.sol";
import {StreamDenomination} from "src/interfaces/IStreamManager.sol";
import {BtcTxIn, BtcTxOut, BtcTransaction} from "src/interfaces/IBitcoinManager.sol";
import {BitcoinManager} from "src/BitcoinManager.sol";
import {RSK_BRIDGE_ADDRESS, IBridge} from "src/interfaces/IBridge.sol";
import {BridgeMock} from "./BridgeMock.sol";

abstract contract HelperContract is Test {
    // Mock keys
    bytes32 constant COMMITEE_1_PUB_KEY = 0x0908421cb37d204b0c68660d093534d50d01fa791a3313e5fd9c21da137785eb;
    bytes32 constant COMMITEE_2_PUB_KEY = 0x1908421cb37d204b0c68660d093534d50d01fa791a3313e5fd9c21da137785ec;
    bytes32 constant COMMITEE_3_PUB_KEY = 0x2908421cb37d204b0c68660d093534d50d01fa791a3313e5fd9c21da137785ed;

    // Dummy requested roles and streams for the members
    StreamDenomination[] internal requestedStreams;
    Role[] internal requestedRoles;

    BitcoinManager internal bitcoinManager;
    CommitteeRegistry internal registry;
    Committee internal committee1;
    Committee internal committee2;
    Committee internal committee3;
    bytes32 internal committee1Key;
    bytes32 internal committee2Key;
    bytes32 internal committee3Key;
    CommitteeMember[] internal committee1Members;
    CommitteeMember[] internal committee2Members;
    CommitteeMember[] internal committee3Members;
    PegManager internal pm;
    BridgeMock internal bridgeMock;
    // Arrenge
    uint64 internal constant VALUE = 100_000; // 0.001 BTC

    function setUpBitcoinManager() internal {
        bitcoinManager = new BitcoinManager();
    }

    function setUpCommittees() internal {
        requestedStreams = new StreamDenomination[](1);
        requestedRoles = new Role[](1);
        requestedStreams[0] = StreamDenomination._0_001BTC;
        requestedRoles[0] = Role.Operator;

        committee1Key = COMMITEE_1_PUB_KEY;
        committee2Key = COMMITEE_2_PUB_KEY;
        committee3Key = COMMITEE_3_PUB_KEY;

        committee1Members.push(CommitteeMember({index: 0, role: Role.Operator}));
        committee1Members.push(CommitteeMember({index: 1, role: Role.Operator}));

        committee2Members.push(CommitteeMember({index: 2, role: Role.Operator}));
        committee2Members.push(CommitteeMember({index: 3, role: Role.Operator}));

        committee3Members.push(CommitteeMember({index: 4, role: Role.Operator}));
        committee3Members.push(CommitteeMember({index: 5, role: Role.Operator}));

        committee1.internalKey = committee1Key;
        committee1.memberIndexesAndRoles = committee1Members;
        committee1.leaderIndex = 0;

        committee2.internalKey = committee2Key;
        committee2.memberIndexesAndRoles = committee2Members;
        committee2.leaderIndex = 0;

        committee3.internalKey = committee3Key;
        committee3.memberIndexesAndRoles = committee3Members;
        committee3.leaderIndex = 0;
    }

    function registerMockMembers() internal {
        // Register members with their mock keys
        registry.registerMember(generatePubKey(0), requestedStreams, requestedRoles);
        registry.registerMember(generatePubKey(1), requestedStreams, requestedRoles);
        registry.registerMember(generatePubKey(2), requestedStreams, requestedRoles);
        registry.registerMember(generatePubKey(3), requestedStreams, requestedRoles);
        registry.registerMember(generatePubKey(4), requestedStreams, requestedRoles);
        registry.registerMember(generatePubKey(5), requestedStreams, requestedRoles);
    }

    function setUpCommitteeRegistry() internal {
        setUpCommittees();

        registry = new CommitteeRegistry();
        registry.initialize();

        registerMockMembers();

        // Register committees with their mock keys. These are Bitcoin x-only public keys.
        registry.registerCommittee(committee1);
        registry.registerCommittee(committee2);
        registry.registerCommittee(committee3);
    }

    function setUpBridgeMock() internal {
        // Deploy mock of the precompile
        // Set mock bytecode to the expected precompile address
        // https://book.getfoundry.sh/cheatcodes/etch
        vm.etch(RSK_BRIDGE_ADDRESS, address(new BridgeMock()).code);
        bridgeMock = BridgeMock(RSK_BRIDGE_ADDRESS);
    }

    function setUpPegManager() internal {
        setUpBitcoinManager();
        setUpCommitteeRegistry();
        setUpBridgeMock();

        pm = new PegManager();
        pm.initialize(registry, bitcoinManager);
    }

    function assertEqCommittee(
        Committee memory actualCommittee,
        Committee memory expectedCommittee,
        string memory testName
    ) internal pure {
        assertEq(
            actualCommittee.internalKey,
            expectedCommittee.internalKey,
            string(abi.encodePacked("expect", testName, "to have  same internalKey"))
        );
        for (uint256 i = 0; i < actualCommittee.memberIndexesAndRoles.length; i++) {
            assertEq(
                actualCommittee.memberIndexesAndRoles[i].index,
                expectedCommittee.memberIndexesAndRoles[i].index,
                string(abi.encodePacked("expect", testName, "to have  same memberIndices[", Strings.toString(i), "]"))
            );
        }
        assertEq(
            actualCommittee.leaderIndex,
            expectedCommittee.leaderIndex,
            string(abi.encodePacked("expect", testName, "to have same leader"))
        );
    }

    function assertEqCommitteeMembers(
        CommitteeMember[] memory actualMembers,
        CommitteeMember[] memory expectedMembers,
        string memory testName
    ) internal pure {
        assertEq(
            actualMembers.length,
            expectedMembers.length,
            string(abi.encodePacked("expect", testName, "to have same amount of members"))
        );
        for (uint256 i = 0; i < actualMembers.length; i++) {
            assertEq(
                actualMembers[i].index,
                expectedMembers[i].index,
                string(abi.encodePacked("expect", testName, " memeber[", Strings.toString(i), "] to have same address"))
            );
        }
    }

    function uintToAddress(uint256 i) internal pure returns (address) {
        return bytes32ToAddress(uintToBytes32(i));
    }

    function bytes32ToAddress(bytes32 word) internal pure returns (address) {
        return address(bytes20(word));
    }

    function uintToBytes32(uint256 i) internal pure returns (bytes32) {
        return keccak256(abi.encode(i));
    }

    function getBtcTxIn() internal pure returns (BtcTxIn memory) {
        return BtcTxIn({
            txId: 0x360b81785dc7c2f40627fea364676dbb73e6276683caffd9f906b0e0bd36b3d2,
            vout: 1694,
            sequence: 4294967293,
            scriptSig: hex""
        });
    }

    function getBtcP2TROut() internal pure returns (BtcTxOut memory) {
        return BtcTxOut({
            amount: VALUE,
            scriptPubKey: hex"5120e2619c2583f4b3bbc15e61ce22e52aa89ea74b8b4f64a1765e58cdc9ad4dd956"
        });
    }

    function getBtcOPReturnOut() internal pure returns (BtcTxOut memory) {
        return BtcTxOut({
            amount: 0,
            scriptPubKey: hex"6a4552534b5f504547494e00000000000000007ac5496aee77c1ba1f0854206a26dda82a81d6d8741976f972e9aa5e226eae26289b794aac9bbe702f378aa64c6104f16b79298c"
        });
    }

    function getBtcPegInRequestTx() internal pure returns (BtcTransaction memory) {
        BtcTxIn[] memory btcInputs = new BtcTxIn[](1);
        btcInputs[0] = getBtcTxIn();
        // Output
        BtcTxOut[] memory btcOutputs = new BtcTxOut[](2);
        btcOutputs[0] = getBtcP2TROut();
        btcOutputs[1] = getBtcOPReturnOut();
        return BtcTransaction({version: 2, inputs: btcInputs, outputs: btcOutputs, locktime: 0});
    }

    function getExpectedPegInRequestTxHash() internal pure returns (bytes32) {
        return 0x9a68bd7cee559ed776567741ee1fa48bc50c6d80376165d5ead2245cef96725c;
    }

    function generatePubKey(uint256 i) internal pure returns (bytes32) {
        return bytes32(i);
    }
}
