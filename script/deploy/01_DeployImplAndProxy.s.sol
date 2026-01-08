// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {console} from "forge-std/console.sol";
import {VmSafe} from "forge-std/Vm.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {CommitteeRegistry} from "src/CommitteeRegistry.sol";
import {MemberRegistry} from "src/MemberRegistry.sol";
import {BitcoinManager} from "src/BitcoinManager.sol";
import {PeginManager} from "src/PeginManager.sol";
import {PegoutManager} from "src/PegoutManager.sol";
import {StreamManager} from "src/StreamManager.sol";
import {SignatureManager} from "src/SignatureManager.sol";
import {PauseManager} from "src/PauseManager.sol";
import {RSK_BRIDGE_ADDRESS, IBridge} from "src/interfaces/IBridge.sol";
import {BtcNetwork} from "src/libraries/Network.sol";
import {BridgeMock} from "test/helpers/BridgeMock.sol";
import {ChainIds} from "src/libraries/Network.sol";
import {ScriptUtils} from "script/helpers/ScriptUtils.sol";
import {ICommitteeRegistry} from "src/interfaces/ICommitteeRegistry.sol";
import {IMemberRegistry} from "src/interfaces/IMemberRegistry.sol";
import {PegoutManagerSettings} from "src/interfaces/IPegoutManager.sol";
import {StreamManagerSettings, StreamSettings, StreamDenomination} from "src/interfaces/IStreamManager.sol";
import {StreamManagerSettingsConfig} from "script/helpers/StreamManagerSettingsConfig.sol";
import {PegManagerSettingsConfig} from "script/helpers/PegManagerSettingsConfig.sol";
import {IRbtcBridge} from "src/interfaces/IRbtcBridge.sol";
import {RbtcBridge} from "src/RbtcBridge.sol";

/// @notice Struct to return deployed contracts and avoid stack too deep error
struct DeployedContracts {
    CommitteeRegistry committeeRegistry;
    MemberRegistry memberRegistry;
    BitcoinManager bitcoinManager;
    IRbtcBridge rbtcBridge;
    PeginManager peginManager;
    PegoutManager pegoutManager;
    StreamManager streamManager;
    SignatureManager signatureManager;
    PauseManager pauseManager;
    address upgradableOwner;
    address pauser;
    address payable bridgeAddress;
}

///@dev We are using fundry-upgrades see https://github.com/OpenZeppelin/openzeppelin-foundry-upgrades
contract DeployImplAndProxy is ScriptUtils {
    // Contracts to be deployed
    address public upgradableOwner;
    address public pauser;
    BtcNetwork public btcBtcNetwork;
    address payable public bridgeAddress;
    StreamManagerSettings public streamManagerSettings;
    StreamSettings[] public streamSettings;
    PegoutManagerSettings public pegoutManagerSettings;

    function setUp() internal {
        bridgeAddress = RSK_BRIDGE_ADDRESS;
        upgradableOwner = getDeployerAddress();
        pauser = getPauserAddress();
        uint64[] memory denominations = StreamManagerSettingsConfig.getDenominations();
        streamManagerSettings = StreamManagerSettingsConfig.getStreamManagerSettings(block.chainid);

        for (uint64 i = 0; i < denominations.length; i++) {
            streamSettings.push(StreamManagerSettingsConfig.getStreamSettings(block.chainid, i, denominations[i]));
        }
        pegoutManagerSettings = PegManagerSettingsConfig.getSettingsForChain(block.chainid);
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

    function run() public returns (DeployedContracts memory) {
        setUp();
        printAddress(upgradableOwner, "upgradableOwner");
        printAddress(pauser, "pauser");
        printAddress(bridgeAddress, "Bridge");

        // Deploy contracts
        MemberRegistry memberRegistry = deployMemberRegistry(upgradableOwner);
        if (memberRegistry.owner() != upgradableOwner) {
            revert("MemberRegistry owner is not the upgradable owner");
        }
        CommitteeRegistry committeeRegistry = deployCommitteeRegistry(upgradableOwner, memberRegistry);
        if (committeeRegistry.owner() != upgradableOwner) {
            revert("CommitteeRegistry owner is not the upgradable owner");
        }
        BitcoinManager bitcoinManager = deployBitcoinManager(upgradableOwner, btcBtcNetwork);
        if (bitcoinManager.owner() != upgradableOwner) {
            revert("BitcoinManager owner is not the upgradable owner");
        }

        RbtcBridge rbtcBridge = deployRbtcBridge(upgradableOwner, bridgeAddress);
        if (rbtcBridge.owner() != upgradableOwner) {
            revert("RbtcBridge owner is not the upgradable owner");
        }
        if (address(rbtcBridge.bridge()) != bridgeAddress) {
            revert("RbtcBridge bridge is not the bridge address");
        }

        PeginManager peginManager =
            deployPeginManager(upgradableOwner, bridgeAddress, committeeRegistry, bitcoinManager, rbtcBridge);
        if (peginManager.owner() != upgradableOwner) {
            revert("PeginManager owner is not the upgradable owner");
        }
        if (payable(address(peginManager.bridge())) != bridgeAddress) {
            revert("PeginManager bridge is not the bridge address");
        }

        PegoutManager pegoutManager = deployPegoutManager(
            upgradableOwner, bridgeAddress, committeeRegistry, bitcoinManager, pegoutManagerSettings, rbtcBridge
        );
        if (pegoutManager.owner() != upgradableOwner) {
            revert("PegoutManager owner is not the upgradable owner");
        }
        if (payable(address(pegoutManager.bridge())) != bridgeAddress) {
            revert("PegoutManager bridge is not the bridge address");
        }

        StreamManager streamManager = deployStreamManager(
            upgradableOwner,
            address(peginManager),
            address(pegoutManager),
            committeeRegistry,
            streamManagerSettings,
            streamSettings
        );
        if (streamManager.owner() != upgradableOwner) {
            revert("StreamManager owner is not the upgradable owner");
        }
        if (streamManager.peginManager() != address(peginManager)) {
            revert("StreamManager peginManager is not the peginManager address");
        }
        if (streamManager.pegoutManager() != address(pegoutManager)) {
            revert("StreamManager pegoutManager is not the pegoutManager address");
        }

        SignatureManager signatureManager =
            deploySignatureManager(upgradableOwner, address(peginManager), address(pegoutManager), committeeRegistry);
        if (signatureManager.owner() != upgradableOwner) {
            revert("SignatureManager owner is not the upgradable owner");
        }
        if (signatureManager.peginManager() != address(peginManager)) {
            revert("SignatureManager peginManager is not the peginManager address");
        }
        if (signatureManager.pegoutManager() != address(pegoutManager)) {
            revert("SignatureManager pegoutManager is not the pegoutManager address");
        }
        if (address(signatureManager.committeeRegistry()) != address(committeeRegistry)) {
            revert("SignatureManager committeeRegistry is not the committeeRegistry address");
        }

        PauseManager pauseManager = deployPauseManager(
            pauser, address(peginManager), address(pegoutManager), address(committeeRegistry), address(memberRegistry)
        );
        if (pauseManager.owner() != pauser) {
            revert("PauseManager owner is not the pauser owner");
        }
        if (address(pauseManager.peginManager()) != address(peginManager)) {
            revert("PauseManager peginManager is not the peginManager address");
        }
        if (address(pauseManager.pegoutManager()) != address(pegoutManager)) {
            revert("PauseManager pegoutManager is not the pegoutManager address");
        }
        if (address(pauseManager.committeeRegistry()) != address(committeeRegistry)) {
            revert("PauseManager committeeRegistry is not the committeeRegistry address");
        }
        if (address(pauseManager.memberRegistry()) != address(memberRegistry)) {
            revert("PauseManager memberRegistry is not the memberRegistry address");
        }

        // Set contracts references
        vm.startBroadcast(getDeployerKey());
        rbtcBridge.setPeginManager(address(peginManager));
        rbtcBridge.setPegoutManager(address(pegoutManager));
        peginManager.setStreamManager(streamManager);
        peginManager.setSignatureManager(signatureManager);
        pegoutManager.setStreamManager(streamManager);
        pegoutManager.setSignatureManager(signatureManager);
        bitcoinManager.setPeginManager(peginManager);
        committeeRegistry.setStreamManager(streamManager);
        committeeRegistry.setPeginManager(peginManager);
        committeeRegistry.setPegoutManager(pegoutManager);
        memberRegistry.setStreamManager(streamManager);
        memberRegistry.setCommitteeRegistry(address(committeeRegistry));
        memberRegistry.setBridge(IBridge(bridgeAddress));
        // Set PauseManager as the pauser for all pausable contracts
        peginManager.setPauser(address(pauseManager));
        pegoutManager.setPauser(address(pauseManager));
        committeeRegistry.setPauser(address(pauseManager));
        memberRegistry.setPauser(address(pauseManager));
        vm.stopBroadcast();

        if (block.chainid == ChainIds.LOCAL) {
            vm.startBroadcast(getDeployerKey());
            BridgeMock(bridgeAddress).setBtcTransactionConfirmations(CONFIRMATIONS);
            // Set RbtcBridge as the authorized union bridge contract for testing
            BridgeMock(bridgeAddress).setUnionBridgeContractAddressForTestnet(address(rbtcBridge));
            // Fund BridgeMock with RBTC so it can mint
            vm.deal(bridgeAddress, 400 ether);
            vm.stopBroadcast();

            // Transfer enough RBTC to the bridge to cover the locking cap (400 RBTC)
            if (vm.isContext(VmSafe.ForgeContext.TestGroup)) {
                vm.deal(bridgeAddress, BridgeMock(bridgeAddress).getUnionBridgeLockingCap());
            } else {
                vm.startBroadcast(getDeployerKey());
                payable(bridgeAddress).transfer(BridgeMock(bridgeAddress).getUnionBridgeLockingCap());
                vm.stopBroadcast();
            }
        }

        uint256 streamLen = streamManager.getStreamsLength();
        if (streamLen == 0) {
            revert("StreamManager streams not created");
        }

        return DeployedContracts({
            committeeRegistry: committeeRegistry,
            memberRegistry: memberRegistry,
            bitcoinManager: bitcoinManager,
            rbtcBridge: rbtcBridge,
            peginManager: peginManager,
            pegoutManager: pegoutManager,
            streamManager: streamManager,
            signatureManager: signatureManager,
            pauseManager: pauseManager,
            upgradableOwner: upgradableOwner,
            pauser: pauser,
            bridgeAddress: bridgeAddress
        });
    }

    function deployCommitteeRegistry(address _upgradableOwner, IMemberRegistry _memberRegistry)
        public
        returns (CommitteeRegistry)
    {
        string memory contractName = "CommitteeRegistry.sol";
        if (vm.isContext(VmSafe.ForgeContext.TestGroup)) {
            contractName = "CommitteeRegistryHarness.sol";
        }
        (, address proxyAdddress) = deployContractAndUUPSProxy(
            contractName, abi.encodeCall(CommitteeRegistry.initialize, (_upgradableOwner, _memberRegistry))
        );
        return CommitteeRegistry(proxyAdddress);
    }

    function deployMemberRegistry(address _upgradableOwner) public returns (MemberRegistry) {
        string memory contractName = "MemberRegistry.sol";
        if (vm.isContext(VmSafe.ForgeContext.TestGroup)) {
            contractName = "MemberRegistryHarness.sol";
        }
        (, address proxyAdddress) =
            deployContractAndUUPSProxy(contractName, abi.encodeCall(MemberRegistry.initialize, (_upgradableOwner)));
        return MemberRegistry(proxyAdddress);
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

    function deployRbtcBridge(address _upgradableOwner, address payable _bridgeAddress) public returns (RbtcBridge) {
        (, address proxyAdddress) = deployContractAndUUPSProxy(
            "RbtcBridge.sol", abi.encodeCall(RbtcBridge.initialize, (_upgradableOwner, _bridgeAddress))
        );
        return RbtcBridge(payable(proxyAdddress));
    }

    function deployPeginManager(
        address _upgradableOwner,
        address payable _bridgeAddress,
        CommitteeRegistry _committeeRegistry,
        BitcoinManager _bitcoinManager,
        IRbtcBridge _rbtcBridge
    ) public returns (PeginManager) {
        string memory contractName = "PeginManager.sol";
        if (vm.isContext(VmSafe.ForgeContext.TestGroup)) {
            contractName = "PeginManagerHarness.sol";
        }
        (, address proxyAdddress) = deployContractAndUUPSProxy(
            contractName,
            abi.encodeCall(
                PeginManager.initialize,
                (_upgradableOwner, _bridgeAddress, _committeeRegistry, _bitcoinManager, _rbtcBridge)
            )
        );
        return PeginManager(proxyAdddress);
    }

    function deployPegoutManager(
        address _upgradableOwner,
        address payable _bridgeAddress,
        CommitteeRegistry _committeeRegistry,
        BitcoinManager _bitcoinManager,
        PegoutManagerSettings memory _settings,
        IRbtcBridge _rbtcBridge
    ) public returns (PegoutManager) {
        string memory contractName = "PegoutManager.sol";
        if (vm.isContext(VmSafe.ForgeContext.TestGroup)) {
            contractName = "PegoutManagerHarness.sol";
        }
        (, address proxyAdddress) = deployContractAndUUPSProxy(
            contractName,
            abi.encodeCall(
                PegoutManager.initialize,
                (_upgradableOwner, _bridgeAddress, _committeeRegistry, _bitcoinManager, _settings, _rbtcBridge)
            )
        );
        return PegoutManager(proxyAdddress);
    }

    function deployStreamManager(
        address _upgradableOwner,
        address _peginManager,
        address _pegoutManager,
        ICommitteeRegistry _committeeRegistry,
        StreamManagerSettings memory _settings,
        StreamSettings[] memory _streamSettings
    ) public returns (StreamManager) {
        uint256 length = _streamSettings.length;
        if (length == 0 || length > uint64(StreamDenomination.LENGTH)) {
            revert("StreamManager settings length does not match denominations length or is zero");
        }

        string memory contractName = "StreamManager.sol";
        if (vm.isContext(VmSafe.ForgeContext.TestGroup)) {
            contractName = "StreamManagerHarness.sol";
        }

        (, address proxyAdddress) = deployContractAndUUPSProxy(
            contractName,
            abi.encodeCall(
                StreamManager.initialize,
                (_upgradableOwner, _peginManager, _pegoutManager, _committeeRegistry, _settings, _streamSettings)
            )
        );
        return StreamManager(proxyAdddress);
    }

    function deploySignatureManager(
        address _upgradableOwner,
        address _peginManager,
        address _pegoutManager,
        CommitteeRegistry _committeeRegistry
    ) public returns (SignatureManager) {
        (, address proxyAdddress) = deployContractAndUUPSProxy(
            "SignatureManager.sol",
            abi.encodeCall(
                SignatureManager.initialize, (_upgradableOwner, _peginManager, _pegoutManager, _committeeRegistry)
            )
        );
        return SignatureManager(proxyAdddress);
    }

    function deployPauseManager(
        address _upgradableOwner,
        address _peginManager,
        address _pegoutManager,
        address _committeeRegistry,
        address _memberRegistry
    ) public returns (PauseManager) {
        (, address proxyAdddress) = deployContractAndUUPSProxy(
            "PauseManager.sol",
            abi.encodeCall(
                PauseManager.initialize,
                (_upgradableOwner, _peginManager, _pegoutManager, _committeeRegistry, _memberRegistry)
            )
        );
        return PauseManager(proxyAdddress);
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
        returns (address, address payable)
    {
        // Open zeppelin upgrades plugin currecntly does not support external libraries
        // See https://docs.openzeppelin.com/upgrades-plugins/faq#why-cant-i-use-external-libraries
        // Options memory opts;
        // opts.unsafeAllow = "unsafeAllowLinkedLibraries";
        vm.startBroadcast(getDeployerKey());
        // Deploy the upgradeable contract
        address payable proxyAddress = payable(
            Upgrades.deployUUPSProxy(
                _contractName, //"MyUpgradeableToken.sol",
                _initialCall // abi.encodeCall(MyUpgradeableToken.initialize, (msg.sender))
                    //opts
            )
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
