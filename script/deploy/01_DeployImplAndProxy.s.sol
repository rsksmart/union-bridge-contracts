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
import {RSK_BRIDGE_ADDRESS, IBridge} from "src/interfaces/IBridge.sol";
import {BtcNetwork} from "src/libraries/Network.sol";
import {BridgeMock} from "test/helpers/BridgeMock.sol";
import {ChainIds} from "src/libraries/Network.sol";
import {ScriptUtils} from "script/helpers/ScriptUtils.sol";
import {AccessManager} from "src/AccessManager.sol";
import {CommitteeRegistrySettings} from "src/interfaces/ICommitteeRegistry.sol";
import {CommitteeRegistrySettingsConfig} from "script/helpers/CommitteeRegistrySettingsConfig.sol";
import {IMemberRegistry} from "src/interfaces/IMemberRegistry.sol";

import {TakeTimeout} from "src/interfaces/IOperatorTakeManager.sol";
import {StreamManagerSettings, StreamSettings, StreamDenomination} from "src/interfaces/IStreamManager.sol";
import {StreamManagerSettingsConfig} from "script/helpers/StreamManagerSettingsConfig.sol";
import {OperatorTakeManagerConfig} from "script/helpers/OperatorTakeManagerConfig.sol";
import {RbtcBridge} from "src/RbtcBridge.sol";
import {ChallengeManager} from "src/ChallengeManager.sol";
import {OperatorTakeManager} from "src/OperatorTakeManager.sol";

/// @notice Struct to return deployed contracts and avoid stack too deep error
struct DeployedContracts {
    CommitteeRegistry committeeRegistry;
    MemberRegistry memberRegistry;
    BitcoinManager bitcoinManager;
    RbtcBridge rbtcBridge;
    PeginManager peginManager;
    PegoutManager pegoutManager;
    StreamManager streamManager;
    SignatureManager signatureManager;
    AccessManager accessManager;
    ChallengeManager challengeManager;
    OperatorTakeManager operatorTakeManager;
    address upgradableOwner;
    address payable bridgeAddress;
}

///@dev We are using fundry-upgrades see https://github.com/OpenZeppelin/openzeppelin-foundry-upgrades
contract DeployImplAndProxy is ScriptUtils {
    // Contracts to be deployed
    address public upgradableOwner;
    address public whitelister;
    BtcNetwork public btcBtcNetwork;
    address payable public bridgeAddress;
    StreamManagerSettings public streamManagerSettings;
    StreamSettings[] public streamSettings;
    TakeTimeout[] internal operatorTakeTimeoutSettings;
    CommitteeRegistrySettings public committeeRegistrySettings;

    function setUp() internal {
        bridgeAddress = RSK_BRIDGE_ADDRESS;
        upgradableOwner = getDeployerAddress();
        whitelister = getWhitelisterAddress();

        uint64[] memory denominations = StreamManagerSettingsConfig.getDenominations();
        // Get configurations for the chain and test group
        bool isTest = vm.isContext(VmSafe.ForgeContext.TestGroup) || vm.envOr("IS_TEST", false);
        streamManagerSettings = StreamManagerSettingsConfig.getStreamManagerSettings(block.chainid, isTest);
        for (uint64 i = 0; i < denominations.length; i++) {
            streamSettings.push(
                StreamManagerSettingsConfig.getStreamSettings(block.chainid, i, denominations[i], isTest)
            );
        }
        TakeTimeout[] memory takeTimeoutSettings = OperatorTakeManagerConfig.getSettings(block.chainid, isTest);
        delete operatorTakeTimeoutSettings;
        for (uint256 i = 0; i < takeTimeoutSettings.length; i++) {
            operatorTakeTimeoutSettings.push(takeTimeoutSettings[i]);
        }
        committeeRegistrySettings = CommitteeRegistrySettingsConfig.getSettings(block.chainid, isTest);
        // RSK Mainnet
        if (block.chainid == ChainIds.RSK_MAINNET) {
            btcBtcNetwork = BtcNetwork.MAINNET;
        } else if (block.chainid == ChainIds.RSK_TESTNET) {
            // RSK Testnet
            btcBtcNetwork = BtcNetwork.TESTNET;
        } else if (block.chainid == ChainIds.LOCAL || block.chainid == ChainIds.RSK_REGTEST) {
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
        printAddress(whitelister, "whitelister");
        printAddress(bridgeAddress, "Bridge");

        // Deploy contracts
        AccessManager accessManager = deployAccessManager(upgradableOwner);
        if (accessManager.owner() != upgradableOwner) {
            revert("AccessManager owner is not the upgradable owner");
        }

        BitcoinManager bitcoinManager = deployBitcoinManager(upgradableOwner, btcBtcNetwork);
        if (bitcoinManager.owner() != upgradableOwner) {
            revert("BitcoinManager owner is not the upgradable owner");
        }

        StreamManager streamManager =
            deployStreamManager(upgradableOwner, accessManager, bitcoinManager, streamManagerSettings);
        if (streamManager.owner() != upgradableOwner) {
            revert("StreamManager owner is not the upgradable owner");
        }
        if (address(streamManager.accessManager()) != address(accessManager)) {
            revert("StreamManager accessManager is not the accessManager address");
        }
        if (address(streamManager.bitcoinManager()) != address(bitcoinManager)) {
            revert("StreamManager bitcoinManager is not the bitcoinManager address");
        }
        // Initialize the streams
        initializeStreams(streamManager, streamSettings);
        if (streamManager.getStreamsLength() != streamSettings.length) {
            revert("StreamManager streams not initialized correctly");
        }

        RbtcBridge rbtcBridge = deployRbtcBridge(upgradableOwner, bridgeAddress, accessManager);
        if (rbtcBridge.owner() != upgradableOwner) {
            revert("RbtcBridge owner is not the upgradable owner");
        }
        if (address(rbtcBridge.accessManager()) != address(accessManager)) {
            revert("RbtcBridge accessManager is not the accessManager address");
        }
        if (address(rbtcBridge.bridge()) != bridgeAddress) {
            revert("RbtcBridge bridge is not the bridge address");
        }

        MemberRegistry memberRegistry = deployMemberRegistry(upgradableOwner, accessManager, rbtcBridge, streamManager);
        if (memberRegistry.owner() != upgradableOwner) {
            revert("MemberRegistry owner is not the upgradable owner");
        }
        if (address(memberRegistry.accessManager()) != address(accessManager)) {
            revert("MemberRegistry accessManager is not the accessManager address");
        }

        CommitteeRegistry committeeRegistry = deployCommitteeRegistry(
            upgradableOwner, accessManager, memberRegistry, streamManager, committeeRegistrySettings
        );
        if (committeeRegistry.owner() != upgradableOwner) {
            revert("CommitteeRegistry owner is not the upgradable owner");
        }
        if (address(committeeRegistry.accessManager()) != address(accessManager)) {
            revert("CommitteeRegistry accessManager is not the accessManager address");
        }

        SignatureManager signatureManager = deploySignatureManager(upgradableOwner, accessManager, committeeRegistry);
        if (signatureManager.owner() != upgradableOwner) {
            revert("SignatureManager owner is not the upgradable owner");
        }
        if (address(signatureManager.accessManager()) != address(accessManager)) {
            revert("SignatureManager accessManager is not the accessManager address");
        }
        if (address(signatureManager.committeeRegistry()) != address(committeeRegistry)) {
            revert("SignatureManager committeeRegistry is not the committeeRegistry address");
        }

        PeginManager peginManager = deployPeginManager(
            upgradableOwner,
            accessManager,
            committeeRegistry,
            bitcoinManager,
            rbtcBridge,
            streamManager,
            signatureManager
        );
        if (peginManager.owner() != upgradableOwner) {
            revert("PeginManager owner is not the upgradable owner");
        }
        if (payable(address(peginManager.rbtcBridge())) != address(rbtcBridge)) {
            revert("PeginManager bridge is not the bridge address");
        }
        if (address(peginManager.pauser()) != address(accessManager)) {
            revert("PeginManager pauser is not the accessManager address");
        }
        if (address(peginManager.signatureManager()) != address(signatureManager)) {
            revert("PeginManager signatureManager is not the signatureManager address");
        }

        PegoutManager pegoutManager = deployPegoutManager(
            upgradableOwner,
            accessManager,
            committeeRegistry,
            bitcoinManager,
            rbtcBridge,
            streamManager,
            signatureManager
        );
        if (pegoutManager.owner() != upgradableOwner) {
            revert("PegoutManager owner is not the upgradable owner");
        }
        if (address(pegoutManager.rbtcBridge()) != address(rbtcBridge)) {
            revert("PegoutManager bridge is not the bridge address");
        }
        if (address(pegoutManager.pauser()) != address(accessManager)) {
            revert("PegoutManager pauser is not the accessManager address");
        }
        if (address(pegoutManager.signatureManager()) != address(signatureManager)) {
            revert("PegoutManager signatureManager is not the signatureManager address");
        }

        OperatorTakeManager operatorTakeManager = deployOperatorTakeManager(
            upgradableOwner,
            accessManager,
            committeeRegistry,
            bitcoinManager,
            rbtcBridge,
            pegoutManager,
            streamManager,
            signatureManager,
            operatorTakeTimeoutSettings
        );
        if (operatorTakeManager.owner() != upgradableOwner) {
            revert("OperatorTakeManager owner is not the upgradable owner");
        }
        if (address(operatorTakeManager.pegoutManager()) != address(pegoutManager)) {
            revert("OperatorTakeManager pegoutManager is not the pegoutManager address");
        }

        ChallengeManager challengeManager = deployChallengeManager(
            upgradableOwner,
            accessManager,
            committeeRegistry,
            bitcoinManager,
            rbtcBridge,
            streamManager,
            operatorTakeManager
        );
        if (challengeManager.owner() != upgradableOwner) {
            revert("ChallengeManager owner is not the upgradable owner");
        }
        if (payable(address(challengeManager.rbtcBridge())) != address(rbtcBridge)) {
            revert("ChallengeManager bridge is not the bridge address");
        }
        if (address(challengeManager.pauser()) != address(accessManager)) {
            revert("ChallengeManager pauser is not the accessManager address");
        }
        if (address(challengeManager.operatorTakeManager()) != address(operatorTakeManager)) {
            revert("ChallengeManager operatorTakeManager is not the operatorTakeManager address");
        }

        // set contracts references for accessManager
        vm.startBroadcast(getDeployerKey());
        accessManager.setPeginManager(address(peginManager));
        accessManager.setPegoutManager(address(pegoutManager));
        accessManager.setChallengeManager(address(challengeManager));
        accessManager.setOperatorTakeManager(address(operatorTakeManager));
        accessManager.setCommitteeRegistry(address(committeeRegistry));
        accessManager.setMemberRegistry(address(memberRegistry));
        accessManager.setRbtcBridge(address(rbtcBridge));
        vm.stopBroadcast();
        if (address(accessManager.peginManager()) != address(peginManager)) {
            revert("AccessManager peginManager is not the peginManager address");
        }
        if (address(accessManager.pegoutManager()) != address(pegoutManager)) {
            revert("AccessManager pegoutManager is not the pegoutManager address");
        }
        if (address(accessManager.challengeManager()) != address(challengeManager)) {
            revert("AccessManager challengeManager is not the challengeManager address");
        }
        if (address(accessManager.operatorTakeManager()) != address(operatorTakeManager)) {
            revert("AccessManager operatorTakeManager is not the operatorTakeManager address");
        }
        if (address(accessManager.committeeRegistry()) != address(committeeRegistry)) {
            revert("AccessManager committeeRegistry is not the committeeRegistry address");
        }
        if (address(accessManager.memberRegistry()) != address(memberRegistry)) {
            revert("AccessManager memberRegistry is not the memberRegistry address");
        }
        if (address(accessManager.rbtcBridge()) != address(rbtcBridge)) {
            revert("AccessManager rbtcBridge is not the rbtcBridge address");
        }

        // Set BridgeMock values if on local chain
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
            accessManager: accessManager,
            challengeManager: challengeManager,
            operatorTakeManager: operatorTakeManager,
            upgradableOwner: upgradableOwner,
            bridgeAddress: bridgeAddress
        });
    }

    // ===================== Deploy Implementation and Proxy Contracts =====================

    function deployAccessManager(address _upgradableOwner) public returns (AccessManager) {
        (, address proxyAdddress) = deployContractAndUUPSProxy(
            "AccessManager.sol", abi.encodeCall(AccessManager.initialize, (_upgradableOwner))
        );
        return AccessManager(proxyAdddress);
    }

    function deployCommitteeRegistry(
        address _upgradableOwner,
        AccessManager _accessManager,
        IMemberRegistry _memberRegistry,
        StreamManager _streamManager,
        CommitteeRegistrySettings memory _settings
    ) public returns (CommitteeRegistry) {
        string memory contractName = "CommitteeRegistry.sol";
        if (vm.isContext(VmSafe.ForgeContext.TestGroup)) {
            contractName = "CommitteeRegistryHarness.sol";
        }
        (, address proxyAdddress) = deployContractAndUUPSProxy(
            contractName,
            abi.encodeCall(
                CommitteeRegistry.initialize,
                (_upgradableOwner, _accessManager, _memberRegistry, _streamManager, _settings)
            )
        );
        return CommitteeRegistry(proxyAdddress);
    }

    function deployMemberRegistry(
        address _upgradableOwner,
        AccessManager _accessManager,
        RbtcBridge _rbtcBridge,
        StreamManager _streamManager
    ) public returns (MemberRegistry) {
        string memory contractName = "MemberRegistry.sol";
        if (vm.isContext(VmSafe.ForgeContext.TestGroup)) {
            contractName = "MemberRegistryHarness.sol";
        }
        (, address proxyAdddress) = deployContractAndUUPSProxy(
            contractName,
            abi.encodeCall(MemberRegistry.initialize, (_upgradableOwner, _accessManager, _rbtcBridge, _streamManager))
        );
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

    function deployRbtcBridge(address _upgradableOwner, address payable _bridgeAddress, AccessManager _accessManager)
        public
        returns (RbtcBridge)
    {
        (, address proxyAdddress) = deployContractAndUUPSProxy(
            "RbtcBridge.sol",
            abi.encodeCall(RbtcBridge.initialize, (_upgradableOwner, IBridge(_bridgeAddress), _accessManager))
        );
        return RbtcBridge(payable(proxyAdddress));
    }

    function deployPeginManager(
        address _upgradableOwner,
        AccessManager _accessManager,
        CommitteeRegistry _committeeRegistry,
        BitcoinManager _bitcoinManager,
        RbtcBridge _rbtcBridge,
        StreamManager _streamManager,
        SignatureManager _signatureManager
    ) public returns (PeginManager) {
        string memory contractName = "PeginManager.sol";
        if (vm.isContext(VmSafe.ForgeContext.TestGroup)) {
            contractName = "PeginManagerHarness.sol";
        }
        (, address proxyAdddress) = deployContractAndUUPSProxy(
            contractName,
            abi.encodeCall(
                PeginManager.initialize,
                (
                    _upgradableOwner,
                    address(_accessManager),
                    _committeeRegistry,
                    _bitcoinManager,
                    _rbtcBridge,
                    _streamManager,
                    _signatureManager
                )
            )
        );
        return PeginManager(proxyAdddress);
    }

    function deployPegoutManager(
        address _upgradableOwner,
        AccessManager _accessManager,
        CommitteeRegistry _committeeRegistry,
        BitcoinManager _bitcoinManager,
        RbtcBridge _rbtcBridge,
        StreamManager _streamManager,
        SignatureManager _signatureManager
    ) public returns (PegoutManager) {
        string memory contractName = "PegoutManager.sol";
        if (vm.isContext(VmSafe.ForgeContext.TestGroup)) {
            contractName = "PegoutManagerHarness.sol";
        }
        (, address proxyAdddress) = deployContractAndUUPSProxy(
            contractName,
            abi.encodeCall(
                PegoutManager.initialize,
                (
                    _upgradableOwner,
                    address(_accessManager),
                    _committeeRegistry,
                    _bitcoinManager,
                    _rbtcBridge,
                    _streamManager,
                    _signatureManager
                )
            )
        );
        return PegoutManager(proxyAdddress);
    }

    function deployChallengeManager(
        address _upgradableOwner,
        AccessManager _accessManager,
        CommitteeRegistry _committeeRegistry,
        BitcoinManager _bitcoinManager,
        RbtcBridge _rbtcBridge,
        StreamManager _streamManager,
        OperatorTakeManager _operatorTakeManager
    ) public returns (ChallengeManager) {
        string memory contractName = "ChallengeManager.sol";

        (, address proxyAdddress) = deployContractAndUUPSProxy(
            contractName,
            abi.encodeCall(
                ChallengeManager.initialize,
                (
                    _upgradableOwner,
                    address(_accessManager),
                    _committeeRegistry,
                    _bitcoinManager,
                    _rbtcBridge,
                    _streamManager,
                    _operatorTakeManager
                )
            )
        );
        return ChallengeManager(proxyAdddress);
    }

    function deployOperatorTakeManager(
        address _upgradableOwner,
        AccessManager _accessManager,
        CommitteeRegistry _committeeRegistry,
        BitcoinManager _bitcoinManager,
        RbtcBridge _rbtcBridge,
        PegoutManager _pegoutManager,
        StreamManager _streamManager,
        SignatureManager _signatureManager,
        TakeTimeout[] memory _timeoutSettings
    ) public returns (OperatorTakeManager) {
        string memory contractName = "OperatorTakeManager.sol";
        (, address proxyAdddress) = deployContractAndUUPSProxy(
            contractName,
            abi.encodeCall(
                OperatorTakeManager.initialize,
                (
                    _upgradableOwner,
                    address(_accessManager),
                    _committeeRegistry,
                    _bitcoinManager,
                    _rbtcBridge,
                    _pegoutManager,
                    _streamManager,
                    _signatureManager,
                    _timeoutSettings
                )
            )
        );
        return OperatorTakeManager(proxyAdddress);
    }

    function deployStreamManager(
        address _upgradableOwner,
        AccessManager _accessManager,
        BitcoinManager _bitcoinManager,
        StreamManagerSettings memory _settings
    ) public returns (StreamManager) {
        string memory contractName = "StreamManager.sol";
        if (vm.isContext(VmSafe.ForgeContext.TestGroup)) {
            contractName = "StreamManagerHarness.sol";
        }

        (, address proxyAdddress) = deployContractAndUUPSProxy(
            contractName,
            abi.encodeCall(StreamManager.initialize, (_upgradableOwner, _accessManager, _bitcoinManager, _settings))
        );
        return StreamManager(proxyAdddress);
    }

    function initializeStreams(StreamManager _streamManager, StreamSettings[] memory _streamSettings) public {
        uint256 length = _streamSettings.length;
        if (length == 0 || length > uint64(StreamDenomination.LENGTH)) {
            revert("StreamManager settings length does not match denominations length or is zero");
        }

        vm.startBroadcast(getDeployerKey());
        // Set a high gas limit to avoid out of gas exception as RSK does not estimate correctly the gas needed for this transaction
        _streamManager.initializeStreams{gas: 1200000}(_streamSettings);
        vm.stopBroadcast();
    }

    function deploySignatureManager(
        address _upgradableOwner,
        AccessManager _accessManager,
        CommitteeRegistry _committeeRegistry
    ) public returns (SignatureManager) {
        (, address proxyAdddress) = deployContractAndUUPSProxy(
            "SignatureManager.sol",
            abi.encodeCall(SignatureManager.initialize, (_upgradableOwner, _accessManager, _committeeRegistry))
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
