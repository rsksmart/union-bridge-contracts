// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {Upgrades, Options} from "openzeppelin-foundry-upgrades/Upgrades.sol";

///@dev We are using fundry-upgrades see https://github.com/OpenZeppelin/openzeppelin-foundry-upgrades
abstract contract BaseDeployer is Script {
    /**
     * @dev Deploys a transparent proxy using the given contract as the implementation.
     *
     * @param _contractName Name of the contract to use as the implementation, e.g. "MyContract.sol" or "MyContract.sol:MyContract" or artifact path relative to the project root directory
     * @param _proxyAdminOwner Address to set as the owner of the ProxyAdmin contract which gets deployed by the proxy
     * @param _initialCall Encoded call data of the initializer function to call during creation of the proxy, or empty if no initialization is required
     * @return Implementation address
     * @return Proxy address
     */
    function deployContractAndTransparentProxy(
        string memory _contractName,
        address _proxyAdminOwner,
        bytes memory _initialCall
    ) internal returns (address, address) {
        vm.startBroadcast();
        // Deploy the upgradeable contract
        address proxyAddress = Upgrades.deployTransparentProxy(
            _contractName, //"MyUpgradeableToken.sol",
            _proxyAdminOwner,
            _initialCall // abi.encodeCall(MyUpgradeableToken.initialize, (msg.sender))
        );
        vm.stopBroadcast();
        // Get the implementation address
        address implementationAddress = Upgrades.getImplementationAddress(proxyAddress);

        return (implementationAddress, proxyAddress);
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
        return (implementationAddress, proxyAddress);
    }

    /**
     * @dev Upgrades a proxy to a new implementation contract. Only supported for UUPS or transparent proxies.
     *
     * Requires that either the `referenceContract` option is set, or the new implementation contract has a `@custom:oz-upgrades-from <reference>` annotation.
     *
     * @param _proxyAddress Address of the proxy to upgrade
     * @param _contractName Name of the new implementation contract to upgrade to, e.g. "MyContract.sol" or "MyContract.sol:MyContract" or artifact path relative to the project root directory
     * @param _callAfterUpgrade Encoded call data of an arbitrary function to call during the upgrade process, or empty if no function needs to be called during the upgrade
     */
    function upgradeProxy(address _proxyAddress, string memory _contractName, bytes memory _callAfterUpgrade)
        external
        returns (address)
    {
        vm.startBroadcast();
        // Deploy the upgradeable contract
        Upgrades.upgradeProxy(
            _proxyAddress,
            _contractName, //"MyContractV2.sol",
            _callAfterUpgrade // abi.encodeCall(MyContractV2.foo, ("arguments for foo"))
        );
        // Get the implementation address
        address newImplementationAddress = Upgrades.getImplementationAddress(_proxyAddress);
        vm.stopBroadcast();
        return (newImplementationAddress);
    }
}
