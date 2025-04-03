// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {DeployScript} from "script/deploy/DeployScript.s.sol";
import {PegManager} from "src/PegManager.sol";
import {PegManagerHarness} from "test/helpers/PegManagerHarness.sol";
import {Role, Member, CommitteeMember, Committee, CommitteeRegistry} from "src/CommitteeRegistry.sol";
import {StreamDenomination} from "src/interfaces/IStreamManager.sol";
import {BtcTxIn, BtcTxOut, BtcTransaction, TIMELOCK_BLOCKS} from "src/interfaces/IBitcoinManager.sol";
import {BitcoinManager} from "src/BitcoinManager.sol";
import {P2TR_FEES, SPEED_UP_AMOUNT} from "src/interfaces/IBitcoinManager.sol";
import {BtcScriptParser} from "src/libraries/BtcScriptParser.sol";
import {BtcHelper} from "src/libraries/BtcHelper.sol";
import {BtcTxEncoder} from "src/libraries/BtcTxEncoder.sol";
import {RSK_BRIDGE_ADDRESS, IBridge} from "src/interfaces/IBridge.sol";
import {BridgeMock} from "./BridgeMock.sol";
import {TestUtils} from "./TestUtils.sol";

abstract contract HelperContract is Test, TestUtils {
    // Mock keys
    bytes32 constant COMMITEE_1_PUB_KEY = 0xd1cfc2049322ff6ba3a88c6e17c6622308f0fb1d2910ffadb309e4116358723d;
    bytes32 constant COMMITEE_2_PUB_KEY = 0x1908421cb37d204b0c68660d093534d50d01fa791a3313e5fd9c21da137785ec;
    bytes32 constant COMMITEE_3_PUB_KEY = 0x2908421cb37d204b0c68660d093534d50d01fa791a3313e5fd9c21da137785ed;
    bytes32 internal constant BTC_REIMBURSEMENT_PUBKEY =
        0x7d235c24420b2f55450c8414725aa74e6db01035245efdab0e1cfa7ab29aca0f;

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
    PegManagerHarness internal pm;
    BridgeMock internal bridgeMock;
    address upgradeOwner = vm.addr(777);
    // Arrange
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

    function runTestDeployScript() internal {
        // Using the deployment script in tests like in
        // https://github.com/Cyfrin/foundry-smart-contract-lottery-cu/blob/main/test/unit/RaffleTest.t.sol#L38
        DeployScript deployScript = new DeployScript();
        deployScript.run();
        bitcoinManager = deployScript.bitcoinManager();
        registry = deployScript.committeeRegistry();
        pm = PegManagerHarness(address(deployScript.pegManager()));
        // Set up bridge mock at bridge precompiled address
        bridgeMock = BridgeMock(deployScript.bridgeAddress());

        // Register committees with their mock keys. These are Bitcoin x-only public keys.
        setUpCommittees();
    }

    // ========================== Peg In Request ==========================
    function getPegInRequestTxIn() internal pure returns (BtcTxIn memory) {
        return BtcTxIn({
            txId: 0x360b81785dc7c2f40627fea364676dbb73e6276683caffd9f906b0e0bd36b3d2,
            vout: 1694,
            sequence: 4294967293,
            scriptSig: hex""
        });
    }

    function getPegInRequestP2TROut() internal pure returns (BtcTxOut memory) {
        return BtcTxOut({
            amount: VALUE,
            // TODO this is the value that includes the op_return data inside the taptree
            // It should be put back once the protocol builder is updated
            // scriptPubKey: hex"5120c8c2100e84799661079100ee50ce96bd1db6a1021819042b5b950ef01a4e7f41"
            scriptPubKey: hex"5120228f281f297fd01cd363b9c93f742ba2976c1ec5a6083d9f754cb61e505356c3"
        });
    }

    function getPegInRequestPacket() internal pure returns (uint64) {
        return 0;
    }

    function getPegInRskDestinationAddress() internal pure returns (address) {
        return 0x7Ac5496aee77c1bA1F0854206A26DdA82A81d6d8;
    }

    function getPegInBtcReimbursementPubKey() internal pure returns (bytes32) {
        return 0x7d235c24420b2f55450c8414725aa74e6db01035245efdab0e1cfa7ab29aca0f;
    }

    function getPegInRequestOpReturnOut() internal pure returns (BtcTxOut memory) {
        return BtcTxOut({
            amount: 0,
            scriptPubKey: hex"6a4552534b5f504547494e00000000000000007ac5496aee77c1ba1f0854206a26dda82a81d6d87d235c24420b2f55450c8414725aa74e6db01035245efdab0e1cfa7ab29aca0f"
        });
    }

    function getBtcPegInRequestTx() internal pure returns (BtcTransaction memory) {
        BtcTxIn[] memory btcInputs = new BtcTxIn[](1);
        btcInputs[0] = getPegInRequestTxIn();
        // Output
        BtcTxOut[] memory btcOutputs = new BtcTxOut[](2);
        btcOutputs[0] = getPegInRequestP2TROut();
        btcOutputs[1] = getPegInRequestOpReturnOut();
        return BtcTransaction({version: 2, inputs: btcInputs, outputs: btcOutputs, locktime: 0});
    }

    function getExpectedPegInRequestTxHash() internal pure returns (bytes32) {
        return BtcHelper.hash256(BtcTxEncoder.encodeTx(getBtcPegInRequestTx()));
    }

    // ========================== Peg In Accept ==========================
    function getBtcAcceptPegInTx() internal pure returns (BtcTransaction memory) {
        BtcTxIn[] memory btcInputs = new BtcTxIn[](1);
        btcInputs[0] = getAcceptPegInTxIn();
        // Output
        BtcTxOut[] memory btcOutputs = new BtcTxOut[](2);
        btcOutputs[0] = getAcceptPegInP2TROut();
        btcOutputs[1] = getBtcSpeedUpOut();
        // Locktime
        // TODO: Add real locktime
        uint32 locktime = TIMELOCK_BLOCKS * 600;
        return BtcTransaction({version: 2, inputs: btcInputs, outputs: btcOutputs, locktime: locktime});
    }

    function getExpectedAcceptPegInTxHash() internal pure returns (bytes32) {
        return BtcHelper.hash256(BtcTxEncoder.encodeTx(getBtcAcceptPegInTx()));
    }

    function getAcceptPegInTxIn() internal pure returns (BtcTxIn memory) {
        return BtcTxIn({txId: getExpectedPegInRequestTxHash(), vout: 0, sequence: 0xfffffffd, scriptSig: hex""});
    }

    function getBtcSpeedUpOut() internal pure returns (BtcTxOut memory) {
        return BtcTxOut({
            amount: SPEED_UP_AMOUNT,
            // TODO we consider the btc reimbursement public key as even
            // this may not be the case in the future and we should change this
            scriptPubKey: BtcScriptParser.getP2WPKHScript(abi.encodePacked(uint8(0x02), BTC_REIMBURSEMENT_PUBKEY))
        });
    }

    function getAcceptPegInP2TROut() internal pure returns (BtcTxOut memory) {
        return BtcTxOut({
            amount: VALUE - (P2TR_FEES + SPEED_UP_AMOUNT),
            scriptPubKey: hex"51209687ca13c4fb3fa3ba05c2f9119dda026bfe66f0098dcf9b896a98ecb2e96702"
        });
    }

    function satoshiToWei(uint256 _amount) internal pure returns (uint256) {
        return _amount * 10 ** 10;
    }
}
