// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {PegManager} from "src/PegManager.sol";
import {BtcTxIn, BtcTxOut, BtcTransaction} from "src/interfaces/IPegManager.sol";
import {Committee, CommitteeRegistry} from "src/CommitteeRegistry.sol";
import {BitcoinManager} from "src/BitcoinManager.sol";
import {RSK_BRIDGE_ADDRESS, Bridge} from "src/interfaces/Bridge.sol";
import {BridgeMock} from "./BridgeMock.sol";

abstract contract HelperContract is Test {
    BitcoinManager internal bitcoinManager;
    CommitteeRegistry internal registry;
    bytes32 internal committee1Key;
    Committee internal committee1;
    address[] internal memebersCommittee1;
    bytes32 internal committee2Key;
    Committee internal committee2;
    address[] internal memebersCommittee2;
    bytes32 internal committee3Key;
    Committee internal committee3;
    address[] internal memebersCommittee3;
    PegManager internal pm;
    BridgeMock internal bridgeMock;

    function setUpBitcoinManager() internal {
        bitcoinManager = new BitcoinManager();
    }

    function setUpCommittees() internal {
        committee1Key = hex"0908421cb37d204b0c68660d093534d50d01fa791a3313e5fd9c21da137785eb";
        committee1 = Committee({internalKey: committee1Key, leader: vm.addr(1), backupLeader: vm.addr(2)});
        memebersCommittee1 = new address[](2);
        memebersCommittee1[0] = vm.addr(1);
        memebersCommittee1[1] = vm.addr(2);

        committee2Key = hex"1908421cb37d204b0c68660d093534d50d01fa791a3313e5fd9c21da137785ec";
        committee2 = Committee({internalKey: committee2Key, leader: vm.addr(3), backupLeader: vm.addr(4)});
        memebersCommittee2 = new address[](2);
        memebersCommittee2[0] = vm.addr(3);
        memebersCommittee2[1] = vm.addr(4);

        committee3Key = hex"2908421cb37d204b0c68660d093534d50d01fa791a3313e5fd9c21da137785ed";
        committee3 = Committee({internalKey: committee3Key, leader: vm.addr(5), backupLeader: vm.addr(6)});
        memebersCommittee3 = new address[](2);
        memebersCommittee3[0] = vm.addr(5);
        memebersCommittee3[1] = vm.addr(6);
    }

    function setUpCommitteeRegistry() internal {
        setUpCommittees();

        registry = new CommitteeRegistry();
        registry.initialize();

        // Register committees with their mock keys. These are Bitcoin x-only public keys.
        registry.registerCommittee(committee1, memebersCommittee1);
        registry.registerCommittee(committee2, memebersCommittee2);
        registry.registerCommittee(committee3, memebersCommittee3);
    }

    function setUpPegManager() internal {
        setUpBitcoinManager();
        setUpCommitteeRegistry();

        // Deploy mock of the precompile
        // Set mock bytecode to the expected precompile address
        // https://book.getfoundry.sh/cheatcodes/etch
        vm.etch(RSK_BRIDGE_ADDRESS, address(new BridgeMock()).code);
        bridgeMock = BridgeMock(RSK_BRIDGE_ADDRESS);

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
        assertEq(
            actualCommittee.leader,
            expectedCommittee.leader,
            string(abi.encodePacked("expect", testName, "to have same leader"))
        );
        assertEq(
            actualCommittee.backupLeader,
            expectedCommittee.backupLeader,
            string(abi.encodePacked("expect", testName, "to have same backupLeader"))
        );
    }

    function assertEqCommitteeMembers(
        address[] memory actualMembers,
        address[] memory expectedMembers,
        string memory testName
    ) internal pure {
        assertEq(
            actualMembers.length,
            expectedMembers.length,
            string(abi.encodePacked("expect", testName, "to have same amount of memebers"))
        );
        for (uint256 i = 0; i < actualMembers.length; i++) {
            assertEq(
                actualMembers[i],
                expectedMembers[i],
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
            amount: 100_000,
            scriptPubKey: hex"51206d4e468ec692189e4a64f59cbb6224d4617bafff6b319def00f18c9ec2e5bb78"
        });
    }

    function getBtcOPReturnOut() internal pure returns (BtcTxOut memory) {
        return BtcTxOut({
            amount: 0,
            scriptPubKey: hex"6a0952534b5f504547494e080000000000000000147ac5496aee77c1ba1f0854206a26dda82a81d6d83e6263317068357979377a377578636e6c7a396c79396e783730357038797970767379667268396a66676373383636673571307a6c6d677371656e796d6b68"
        });
    }

    function getBtcPegInRequestTx() internal pure returns (BtcTransaction memory) {
        // Data from tx 0xc00e989a80847a9e2d3e605904ae24c097b1e5abcfa6805434ab802abfcfd079
        // https://www.blockchain.com/explorer/transactions/btc/c00e989a80847a9e2d3e605904ae24c097b1e5abcfa6805434ab802abfcfd079
        BtcTxIn[] memory btcInputs = new BtcTxIn[](1);
        btcInputs[0] = getBtcTxIn();
        // Output
        BtcTxOut[] memory btcOutputs = new BtcTxOut[](2);
        btcOutputs[0] = getBtcP2TROut();
        btcOutputs[1] = getBtcOPReturnOut();
        return BtcTransaction({version: 2, inputs: btcInputs, outputs: btcOutputs, locktime: 0});
    }

    function getExpectedTxHash() internal pure returns (bytes32) {
        return 0x6e2cd48ae052aa3e884d4bfa13f44867b2d510b62d20915ff55eb94560e4f188;
    }
}
