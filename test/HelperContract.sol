// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {PegManager} from "src/PegManager.sol";
import {Committee, CommitteeRegistry} from "src/CommitteeRegistry.sol";
import {BitcoinManager} from "src/BitcoinManager.sol";

abstract contract HelperContract is Test {
    BitcoinManager bitcoinManager;
    CommitteeRegistry registry;
    Committee committee1;
    address[] memebersCommittee1;
    Committee committee2;
    address[] memebersCommittee2;
    Committee committee3;
    address[] memebersCommittee3;
    PegManager pm;

    function setUpBitcoinManager() public {
        bitcoinManager = new BitcoinManager();
    }

    function setUpCommitteeRegistry() public {
        committee1 = Committee({
            internalKey: hex"0908421cb37d204b0c68660d093534d50d01fa791a3313e5fd9c21da137785eb",
            leader: vm.addr(1),
            backupLeader: vm.addr(2)
        });
        memebersCommittee1 = new address[](2);
        memebersCommittee1[0] = vm.addr(1);
        memebersCommittee1[1] = vm.addr(2);

        committee2 = Committee({
            internalKey: hex"1908421cb37d204b0c68660d093534d50d01fa791a3313e5fd9c21da137785ec",
            leader: vm.addr(3),
            backupLeader: vm.addr(4)
        });
        memebersCommittee2 = new address[](2);
        memebersCommittee2[0] = vm.addr(3);
        memebersCommittee2[1] = vm.addr(4);

        committee3 = Committee({
            internalKey: hex"2908421cb37d204b0c68660d093534d50d01fa791a3313e5fd9c21da137785ed",
            leader: vm.addr(5),
            backupLeader: vm.addr(6)
        });
        memebersCommittee3 = new address[](2);
        memebersCommittee3[0] = vm.addr(5);
        memebersCommittee3[1] = vm.addr(6);

        registry = new CommitteeRegistry();
        registry.initialize();

        // Register committees with their mock keys. These are Bitcoin x-only public keys.
        registry.registerCommittee(committee1, memebersCommittee1);
        registry.registerCommittee(committee2, memebersCommittee2);
        registry.registerCommittee(committee3, memebersCommittee3);
    }

    function setUpPegManager() public {
        this.setUpBitcoinManager();
        this.setUpCommitteeRegistry();
        pm = new PegManager();
        pm.initialize(registry, bitcoinManager);
    }
}
