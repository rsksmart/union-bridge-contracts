// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {console} from "forge-std/console.sol";
import {StdStyle} from "forge-std/StdStyle.sol";
import {ScriptUtils} from "script/helpers/ScriptUtils.sol";
import {ContractAddressManager} from "script/helpers/ContractAddressManager.sol";
import {AccessManager} from "src/AccessManager.sol";
import {StreamManager} from "src/StreamManager.sol";
import {PegoutManager} from "src/PegoutManager.sol";
import {CommitteeRegistry} from "src/CommitteeRegistry.sol";
import {MemberRegistry} from "src/MemberRegistry.sol";
import {PeginManager} from "src/PeginManager.sol";
import {ChallengeManager} from "src/ChallengeManager.sol";
import {BitcoinManager} from "src/BitcoinManager.sol";
import {SignatureManager} from "src/SignatureManager.sol";
import {RbtcBridge} from "src/RbtcBridge.sol";
import {BaseProxy} from "src/BaseProxy.sol";

/// @title TransferOwnership
/// @notice Migration script to transfer ownership of all bridge contracts to a new owner address
/// @dev After running this script, the new owner must accept ownership manually
contract TransferOwnership is ScriptUtils, ContractAddressManager {

    /// @notice Struct to hold contract information
    struct ContractInfo {
        string name;
        address contractAddress;
        BaseProxy contractInstance;
        bool ownershipTransferred;
        bool ownershipAccepted;
    }

    /// @notice Array of all contracts that need ownership transfer
    ContractInfo[] public contracts;

    /// @notice Struct to hold all contract addresses
    struct ContractAddresses {
        address peginManager;
        address accessManager;
        address pegoutManager;
        address streamManager;
        address committeeRegistry;
        address memberRegistry;
        address bitcoinManager;
        address signatureManager;
        address rbtcBridge;
        address challengeManager;
    }

    /// @notice Setup function - initializes contracts
    function setUp() public {
        _initializeContracts();
    }

    /// @notice Discover contract addresses on-chain
    /// @dev Returns a struct with all contract addresses discovered from on-chain calls
    function _discoverContractAddresses() internal view returns (ContractAddresses memory addresses) {
        PeginManager peginManager = getPeginManager();
        addresses.peginManager = address(peginManager);
        
        addresses.accessManager = address(peginManager.pauser());
        AccessManager accessManager = AccessManager(addresses.accessManager);
        addresses.pegoutManager = accessManager.pegoutManager();
        addresses.challengeManager = accessManager.challengeManager();
        addresses.streamManager = address(peginManager.streamManager());
        addresses.committeeRegistry = address(peginManager.committeeRegistry());
        addresses.bitcoinManager = address(peginManager.bitcoinManager());
        addresses.rbtcBridge = address(peginManager.rbtcBridge());
        CommitteeRegistry committeeRegistry = CommitteeRegistry(addresses.committeeRegistry);
        addresses.memberRegistry = address(committeeRegistry.memberRegistry());
        PegoutManager pegoutManager = PegoutManager(addresses.pegoutManager);
        addresses.signatureManager = address(pegoutManager.signatureManager());
    }

    /// @notice Initialize the contracts array with all bridge contracts
    function _initializeContracts() internal {
        ContractAddresses memory addresses = _discoverContractAddresses();
        
        PeginManager peginManager = PeginManager(addresses.peginManager);
        AccessManager accessManager = AccessManager(addresses.accessManager);
        PegoutManager pegoutManager = PegoutManager(addresses.pegoutManager);
        StreamManager streamManager = StreamManager(addresses.streamManager);
        CommitteeRegistry committeeRegistry = CommitteeRegistry(addresses.committeeRegistry);
        MemberRegistry memberRegistry = MemberRegistry(addresses.memberRegistry);
        BitcoinManager bitcoinManager = BitcoinManager(addresses.bitcoinManager);
        SignatureManager signatureManager = SignatureManager(addresses.signatureManager);
        RbtcBridge rbtcBridge = RbtcBridge(payable(addresses.rbtcBridge));
        ChallengeManager challengeManager = ChallengeManager(addresses.challengeManager);

        // Add all contracts that need ownership transfer
        contracts.push(ContractInfo({
            name: "AccessManager",
            contractAddress: address(accessManager),
            contractInstance: BaseProxy(address(accessManager)),
            ownershipTransferred: false,
            ownershipAccepted: false
        }));

        contracts.push(ContractInfo({
            name: "PeginManager",
            contractAddress: address(peginManager),
            contractInstance: BaseProxy(address(peginManager)),
            ownershipTransferred: false,
            ownershipAccepted: false
        }));

        contracts.push(ContractInfo({
            name: "PegoutManager",
            contractAddress: address(pegoutManager),
            contractInstance: BaseProxy(address(pegoutManager)),
            ownershipTransferred: false,
            ownershipAccepted: false
        }));

        contracts.push(ContractInfo({
            name: "StreamManager",
            contractAddress: address(streamManager),
            contractInstance: BaseProxy(address(streamManager)),
            ownershipTransferred: false,
            ownershipAccepted: false
        }));

        contracts.push(ContractInfo({
            name: "CommitteeRegistry",
            contractAddress: address(committeeRegistry),
            contractInstance: BaseProxy(address(committeeRegistry)),
            ownershipTransferred: false,
            ownershipAccepted: false
        }));

        contracts.push(ContractInfo({
            name: "MemberRegistry",
            contractAddress: address(memberRegistry),
            contractInstance: BaseProxy(address(memberRegistry)),
            ownershipTransferred: false,
            ownershipAccepted: false
        }));

        contracts.push(ContractInfo({
            name: "BitcoinManager",
            contractAddress: address(bitcoinManager),
            contractInstance: BaseProxy(address(bitcoinManager)),
            ownershipTransferred: false,
            ownershipAccepted: false
        }));

        contracts.push(ContractInfo({
            name: "SignatureManager",
            contractAddress: address(signatureManager),
            contractInstance: BaseProxy(address(signatureManager)),
            ownershipTransferred: false,
            ownershipAccepted: false
        }));

        contracts.push(ContractInfo({
            name: "RbtcBridge",
            contractAddress: address(rbtcBridge),
            contractInstance: BaseProxy(address(rbtcBridge)),
            ownershipTransferred: false,
            ownershipAccepted: false
        }));

        contracts.push(ContractInfo({
            name: "ChallengeManager",
            contractAddress: address(challengeManager),
            contractInstance: BaseProxy(address(challengeManager)),
            ownershipTransferred: false,
            ownershipAccepted: false
        }));
    }

    /// @notice Transfer ownership of all contracts to new owner
    /// @param _newOwner The address that will become the new owner
    /// @dev This function can be run by the current owner
    /// @dev After this, ownership must be accepted by the new owner
    function transferAllOwnership(address _newOwner) public {
        if (_newOwner == address(0)) {
            revert("New owner address cannot be zero");
        }

        console.log("\n=== TRANSFERRING OWNERSHIP ===");
        console.log("New Owner Address:", _newOwner);

        vm.startBroadcast(getDeployerKey());

        for (uint256 i = 0; i < contracts.length; i++) {
            ContractInfo storage contractInfo = contracts[i];
            
            address currentOwner = contractInfo.contractInstance.owner();
            address pendingOwner = contractInfo.contractInstance.pendingOwner();
            
            console.log("");
            console.log("Contract:", contractInfo.name);
            console.log("  Address:", contractInfo.contractAddress);
            console.log("  Current Owner:", currentOwner);
            console.log("  Pending Owner:", pendingOwner);

            if (pendingOwner == _newOwner) {
                console.log(StdStyle.yellow("  Status: Already pending transfer to new owner. Skipping..."));
                contractInfo.ownershipTransferred = true;
                continue;
            }

            if (currentOwner == _newOwner) {
                console.log(StdStyle.green("  Status: New owner is already the owner. Skipping..."));
                contractInfo.ownershipTransferred = true;
                contractInfo.ownershipAccepted = true;
                continue;
            }

            console.log("  Transferring ownership...");
            contractInfo.contractInstance.transferOwnership(_newOwner);
            contractInfo.ownershipTransferred = true;
            console.log(StdStyle.blue("  Status: Ownership transfer initiated"));

        }

        vm.stopBroadcast();

        console.log("\n=== PROCESS COMPLETE ===");
        console.log("The new owner must call acceptOwnership() on each contract where the new owner's address is the pendingOwner");
        
    }

    /// @notice Transfer ownership of all contracts to new owner
    /// @param _newOwner The address that will become the new owner
    /// @dev This is a convenience function that calls transferAllOwnership
    function run(address _newOwner) public {
        transferAllOwnership(_newOwner);
    }
}
