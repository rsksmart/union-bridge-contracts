// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {CommitteeRegistry} from "src/CommitteeRegistry.sol";
import {BitcoinManager} from "src/BitcoinManager.sol";
import {PegManager} from "src/PegManager.sol";
import {Network} from "src/network.sol";

///@dev We are using fundry-upgrades see https://github.com/OpenZeppelin/openzeppelin-foundry-upgrades
contract DeployImplAndProxy is Script {
    // Contracts to be deployed
    address public upgradableOwner;
    Network public btcNetwork;
    uint64[] denominations;

    function setUp() internal {
        address[] memory wallets = vm.getWallets();
        denominations = [
            uint64(100_000), // 0.001 BTC
            uint64(1_000_000), // 0.01 BTC
            uint64(10_000_000), // 0.1 BTC
            uint64(100_000_000), // 1 BTC
            uint64(1_000_000_000) // 10 BTC
        ];
        // RSK Mainnet
        if (block.chainid == 30) {
            upgradableOwner = wallets[0];
            btcNetwork = Network.MAINNET;
        } else if (block.chainid == 31) {
            btcNetwork = Network.TESTNET;
            // RSK Testnet
            if (wallets.length > 0) {
                upgradableOwner = wallets[0];
            } else {
                upgradableOwner = vm.addr(777);
            }
            uint256 length = denominations.length;
            for (uint64 i = 0; i < length; i++) {
                // we reduce the denominations by a factor of 100
                // as it's hard to get the large values in the testnet
                denominations[i] = denominations[i] / 100;
            }
        } else if (block.chainid == 31337 || block.chainid == 1337) {
            // Foundry local chainid
            upgradableOwner = vm.addr(777);
            btcNetwork = Network.REGTEST;
        } else {
            revert("Blockchain is not RSK or regtest");
        }
    }

    function run() public returns (CommitteeRegistry, BitcoinManager, PegManager) {
        setUp();
        CommitteeRegistry committeeRegistry = deployCommitteeRegistry();
        BitcoinManager bitcoinManager = deployBitcoinManager();
        PegManager pegManager = deployPegManager(committeeRegistry, bitcoinManager);
        return (committeeRegistry, bitcoinManager, pegManager);
    }

    function deployCommitteeRegistry() public returns (CommitteeRegistry) {
        (address implementationAddress, address proxyAdddress) = deployContractAndUUPSProxy(
            "CommitteeRegistry.sol", abi.encodeCall(CommitteeRegistry.initialize, (upgradableOwner))
        );
        return CommitteeRegistry(proxyAdddress);
    }

    function deployBitcoinManager() public returns (BitcoinManager) {
        (address implementationAddress, address proxyAdddress) = deployContractAndUUPSProxy(
            "BitcoinManager.sol", abi.encodeCall(BitcoinManager.initialize, (upgradableOwner, btcNetwork))
        );
        return BitcoinManager(proxyAdddress);
    }

    function deployPegManager(CommitteeRegistry _committeeRegistry, BitcoinManager _bitcoinManager)
        public
        returns (PegManager)
    {
        (address implementationAddress, address proxyAdddress) = deployContractAndUUPSProxy(
            "PegManager.sol",
            abi.encodeCall(PegManager.initialize, (upgradableOwner, _committeeRegistry, _bitcoinManager, denominations))
        );
        return PegManager(proxyAdddress);
    }

    /**
     * @dev Deploys a UUPS proxy using the given contract as the implementation.
     *
     * @param _contractName Name of the contract to use as the implementation, e.g. "MyContract.sol" or "MyContract.sol:MyContract" or artifact path relative to the project root directory
     * @param _initialCall Encoded call data of the initializer function to call during creation of the proxy, or empty if no initialization is required
     * @return Implementation address
     * @return Proxy address
     */
    function deployContractAndUUPSProxy(string memory _contractName, bytes memory _initialCall)
        internal
        returns (address, address)
    {
        // Open zeppelin upgrades plugin currecntly does not support external libraries
        // See https://docs.openzeppelin.com/upgrades-plugins/faq#why-cant-i-use-external-libraries
        // Options memory opts;
        // opts.unsafeAllow = "unsafeAllowLinkedLibraries";
        vm.startBroadcast();
        // Deploy the upgradeable contract
        address proxyAddress = Upgrades.deployUUPSProxy(
            _contractName, //"MyUpgradeableToken.sol",
            _initialCall // abi.encodeCall(MyUpgradeableToken.initialize, (msg.sender))
                //opts
        );
        vm.stopBroadcast();
        // Get the implementation address
        address implementationAddress = Upgrades.getImplementationAddress(proxyAddress);
        printDeployAddress(proxyAddress, _contractName);
        return (implementationAddress, proxyAddress);
    }

    function printDeployAddress(address _proxyAddress, string memory _contractName) public view {
        if (vm.isContext(VmSafe.ForgeContext.ScriptBroadcast)) {
            // execute when running `forge script --broadcast`
            // this is to avoid printing the address when running tests
            console.log(_contractName, " proxy address: ", _proxyAddress);
        }
    }

    //     /**
    //      * @dev Upgrades a proxy to a new implementation contract. Only supported for UUPS or transparent proxies.
    //      *
    //      * Requires that either the `referenceContract` option is set, or the new implementation contract has a `@custom:oz-upgrades-from <reference>` annotation.
    //      *
    //      * @param _proxyAddress Address of the proxy to upgrade
    //      * @param _contractName Name of the new implementation contract to upgrade to, e.g. "MyContract.sol" or "MyContract.sol:MyContract" or artifact path relative to the project root directory
    //      * @param _callAfterUpgrade Encoded call data of an arbitrary function to call during the upgrade process, or empty if no function needs to be called during the upgrade
    //      */
    //     function upgradeProxy(address _proxyAddress, string memory _contractName, bytes memory _callAfterUpgrade)
    //         external
    //         returns (address)
    //     {
    //         vm.startBroadcast();
    //         // Deploy the upgradeable contract
    //         Upgrades.upgradeProxy(
    //             _proxyAddress,
    //             _contractName, //"MyContractV2.sol",
    //             _callAfterUpgrade // abi.encodeCall(MyContractV2.foo, ("arguments for foo"))
    //         );
    //         // Get the implementation address
    //         address newImplementationAddress = Upgrades.getImplementationAddress(_proxyAddress);
    //         vm.stopBroadcast();
    //         return (newImplementationAddress);
    //     }
}
