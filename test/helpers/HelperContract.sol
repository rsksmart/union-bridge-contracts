// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {DeployScript} from "script/DeployScript.s.sol";
import {PegManager} from "src/PegManager.sol";
import {Role, Member, CommitteeMember, Committee, CommitteeRegistry} from "src/CommitteeRegistry.sol";
import {StreamDenomination} from "src/interfaces/IStreamManager.sol";
import {BtcTxIn, BtcTxOut, BtcTransaction} from "src/interfaces/IBitcoinManager.sol";
import {BitcoinManager} from "src/BitcoinManager.sol";
import {RSK_BRIDGE_ADDRESS, IBridge} from "src/interfaces/IBridge.sol";
import {BridgeMock} from "./BridgeMock.sol";
import {TestUtils} from "./TestUtils.sol";

abstract contract HelperContract is Test, TestUtils {
    // Mock keys
    bytes32 constant COMMITEE_1_PUB_KEY = 0x924c163b385af7093440184af6fd6244936d1288cbb41cc3812286d3f83a3329;
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
    address upgradeOwner = vm.addr(777);
    // Arrenge
    uint64 internal constant VALUE = 100_000; // 0.001 BTC

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

    function setUpBridgeMock() internal {
        // Deploy mock of the precompile
        // Set mock bytecode to the expected precompile address
        // https://book.getfoundry.sh/cheatcodes/etch
        vm.etch(RSK_BRIDGE_ADDRESS, address(new BridgeMock()).code);
        bridgeMock = BridgeMock(RSK_BRIDGE_ADDRESS);
    }

    function runTestDeployScript() internal {
        // Set up bridge mock at bridge precompiled address
        setUpBridgeMock();
        // Using the deployment script in tests like in
        // https://github.com/Cyfrin/foundry-smart-contract-lottery-cu/blob/main/test/unit/RaffleTest.t.sol#L38
        DeployScript deployScript = new DeployScript();
        deployScript.run();
        bitcoinManager = deployScript.bitcoinManager();
        registry = deployScript.committeeRegistry();
        pm = deployScript.pegManager();

        // Register committees with their mock keys. These are Bitcoin x-only public keys.
        setUpCommittees();
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
            scriptPubKey: hex"5120cce32aec920a48fb9e430a14e9ee4b98694e121a6478aa09d6785d7ad2821a9c"
        });
    }

    function getBtcOPReturnPacket() internal pure returns (uint64) {
        return 0;
    }

    function getBtcOPReturnDestinationAddress() internal pure returns (address) {
        return 0x7Ac5496aee77c1bA1F0854206A26DdA82A81d6d8;
    }

    function getBtcOPReturnReimbursementPubKey() internal pure returns (bytes32) {
        return 0x5d238354a7e74c9e373317053226537dec221c5c775bcca01e806ec358c5c08d;
    }

    function getBtcOPReturnOut() internal pure returns (BtcTxOut memory) {
        return BtcTxOut({
            amount: 0,
            scriptPubKey: hex"6a4552534b5f504547494e00000000000000007ac5496aee77c1ba1f0854206a26dda82a81d6d85d238354a7e74c9e373317053226537dec221c5c775bcca01e806ec358c5c08d"
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
        return 0x7c7a3ba2bdc40c5559dc5c9b60a14ab5eadd1e3b7a5fc9cc66a9804e250374a9;
    }
}
