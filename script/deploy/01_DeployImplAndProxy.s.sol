// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {CommitteeRegistry} from "src/CommitteeRegistry.sol";
import {BitcoinManager} from "src/BitcoinManager.sol";
import {PegManager} from "src/PegManager.sol";
import {StreamManager} from "src/StreamManager.sol";
import {SignatureManager} from "src/SignatureManager.sol";
import {RSK_BRIDGE_ADDRESS} from "src/interfaces/IBridge.sol";
import {BtcNetwork} from "src/libraries/Network.sol";
import {BridgeMock} from "test/helpers/BridgeMock.sol";
import {ChainIds} from "src/libraries/Network.sol";
import {ScriptUtils} from "script/helpers/ScriptUtils.sol";

///@dev We are using fundry-upgrades see https://github.com/OpenZeppelin/openzeppelin-foundry-upgrades
contract DeployImplAndProxy is ScriptUtils {
    // Contracts to be deployed
    address public upgradableOwner;
    BtcNetwork public btcBtcNetwork;
    uint64[] denominations;
    address payable public bridgeAddress;

    function setUp() internal {
        bridgeAddress = RSK_BRIDGE_ADDRESS;
        denominations = [
            uint64(100_000), // 0.001 BTC
            uint64(1_000_000), // 0.01 BTC
            uint64(10_000_000), // 0.1 BTC
            uint64(100_000_000), // 1 BTC
            uint64(1_000_000_000) // 10 BTC
        ];
        upgradableOwner = getDeployerAddress();
        // RSK Mainnet
        if (block.chainid == ChainIds.RSK_MAINNET) {
            btcBtcNetwork = BtcNetwork.MAINNET;
        } else if (block.chainid == ChainIds.RSK_TESTNET) {
            // RSK Testnet
            btcBtcNetwork = BtcNetwork.TESTNET;
        } else if (block.chainid == ChainIds.LOCAL) {
            // Foundry local chainid
            btcBtcNetwork = BtcNetwork.REGTEST;
            // Set Bridge Mock
            vm.startBroadcast(getDeployerKey());
            BridgeMock bridgeMock = new BridgeMock();
            vm.stopBroadcast();
            bridgeAddress = payable(address(bridgeMock));
        } else {
            revert("Blockchain is not RSK or regtest");
        }
    }

    function run()
        public
        returns (
            CommitteeRegistry,
            BitcoinManager,
            PegManager,
            StreamManager,
            SignatureManager,
            address,
            address payable
        )
    {
        setUp();
        printAddress(upgradableOwner, "upgradableOwner");
        printAddress(bridgeAddress, "Bridge");

        // Deploy contracts
        CommitteeRegistry committeeRegistry = deployCommitteeRegistry(upgradableOwner);
        if (committeeRegistry.owner() != upgradableOwner) {
            revert("CommitteeRegistry owner is not the upgradable owner");
        }
        BitcoinManager bitcoinManager = deployBitcoinManager(upgradableOwner, btcBtcNetwork);
        if (bitcoinManager.owner() != upgradableOwner) {
            revert("BitcoinManager owner is not the upgradable owner");
        }
        PegManager pegManager = deployPegManager(upgradableOwner, bridgeAddress, committeeRegistry, bitcoinManager);
        // Verify contracts are initialized
        if (pegManager.owner() != upgradableOwner) {
            revert("PegManager owner is not the upgradable owner");
        }
        if (payable(address(pegManager.bridge())) != bridgeAddress) {
            revert("PegManager bridge is not the bridge address");
        }

        StreamManager streamManager = deployStreamManager(upgradableOwner, address(pegManager), denominations);
        if (streamManager.owner() != upgradableOwner) {
            revert("StreamManager owner is not the upgradable owner");
        }
        if (streamManager.pegManager() != address(pegManager)) {
            revert("StreamManager pegManager is not the pegManager address");
        }

        SignatureManager signatureManager =
            deploySignatureManager(upgradableOwner, address(pegManager), committeeRegistry);
        if (signatureManager.owner() != upgradableOwner) {
            revert("SignatureManager owner is not the upgradable owner");
        }
        if (signatureManager.pegManager() != address(pegManager)) {
            revert("SignatureManager pegManager is not the pegManager address");
        }
        if (address(signatureManager.committeeRegistry()) != address(committeeRegistry)) {
            revert("SignatureManager committeeRegistry is not the committeeRegistry address");
        }

        // Set contracts references
        vm.startBroadcast(getDeployerKey());
        pegManager.setStreamManager(streamManager);
        vm.stopBroadcast();

        vm.startBroadcast(getDeployerKey());
        pegManager.setSignatureManager(signatureManager);
        vm.stopBroadcast();

        vm.startBroadcast(getDeployerKey());
        committeeRegistry.setPegManager(pegManager);
        vm.stopBroadcast();

        if (block.chainid == ChainIds.LOCAL) {
            vm.startBroadcast(getDeployerKey());
            BridgeMock(bridgeAddress).setBtcTransactionConfirmations(10);
            vm.stopBroadcast();
        }

        return (
            committeeRegistry,
            bitcoinManager,
            pegManager,
            streamManager,
            signatureManager,
            upgradableOwner,
            bridgeAddress
        );
    }

    function deployCommitteeRegistry(address _upgradableOwner) public returns (CommitteeRegistry) {
        string memory contractName = "CommitteeRegistry.sol";
        if (vm.isContext(VmSafe.ForgeContext.TestGroup)) {
            contractName = "CommitteeRegistryHarness.sol";
        }
        (, address proxyAdddress) =
            deployContractAndUUPSProxy(contractName, abi.encodeCall(CommitteeRegistry.initialize, (_upgradableOwner)));
        return CommitteeRegistry(proxyAdddress);
    }

    function deployBitcoinManager(address _upgradableOwner, BtcNetwork _btcBtcNetwork)
        public
        returns (BitcoinManager)
    {
        (, address proxyAdddress) = deployContractAndUUPSProxy(
            "BitcoinManager.sol", abi.encodeCall(BitcoinManager.initialize, (_upgradableOwner, _btcBtcNetwork))
        );
        return BitcoinManager(proxyAdddress);
    }

    function deployPegManager(
        address _upgradableOwner,
        address payable _bridgeAddress,
        CommitteeRegistry _committeeRegistry,
        BitcoinManager _bitcoinManager
    ) public returns (PegManager) {
        string memory contractName = "PegManager.sol";
        if (vm.isContext(VmSafe.ForgeContext.TestGroup)) {
            contractName = "PegManagerHarness.sol";
        }

        (, address proxyAdddress) = deployContractAndUUPSProxy(
            contractName,
            abi.encodeCall(
                PegManager.initialize, (_upgradableOwner, _bridgeAddress, _committeeRegistry, _bitcoinManager)
            )
        );
        return PegManager(proxyAdddress);
    }

    function deployStreamManager(address _upgradableOwner, address _pegManager, uint64[] memory _denominations)
        public
        returns (StreamManager)
    {
        string memory contractName = "StreamManager.sol";
        if (vm.isContext(VmSafe.ForgeContext.TestGroup)) {
            contractName = "StreamManagerHarness.sol";
        }

        (, address proxyAdddress) = deployContractAndUUPSProxy(
            contractName, abi.encodeCall(StreamManager.initialize, (_upgradableOwner, _pegManager, _denominations))
        );
        return StreamManager(proxyAdddress);
    }

    function deploySignatureManager(address _upgradableOwner, address _pegManager, CommitteeRegistry _committeeRegistry)
        public
        returns (SignatureManager)
    {
        (, address proxyAdddress) = deployContractAndUUPSProxy(
            "SignatureManager.sol",
            abi.encodeCall(SignatureManager.initialize, (_upgradableOwner, _pegManager, _committeeRegistry))
        );
        return SignatureManager(proxyAdddress);
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
        vm.startBroadcast(getDeployerKey());
        // Deploy the upgradeable contract
        address proxyAddress = Upgrades.deployUUPSProxy(
            _contractName, //"MyUpgradeableToken.sol",
            _initialCall // abi.encodeCall(MyUpgradeableToken.initialize, (msg.sender))
                //opts
        );
        vm.stopBroadcast();
        // Get the implementation address
        address implementationAddress = Upgrades.getImplementationAddress(proxyAddress);
        printAddress(proxyAddress, _contractName);
        return (implementationAddress, proxyAddress);
    }

    function printAddress(address _proxyAddress, string memory _contractName) public view {
        if (vm.isContext(VmSafe.ForgeContext.ScriptBroadcast)) {
            // execute when running `forge script --broadcast`
            // this is to avoid printing the address when running tests
            console.log(_contractName, " address: ", _proxyAddress);
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
