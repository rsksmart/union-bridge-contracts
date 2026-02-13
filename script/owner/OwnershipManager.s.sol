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

/// @title OwnershipManager
/// @notice Script to manage ownership of all bridge contracts
/// @dev Provides functions to transfer ownership and check ownership status
contract OwnershipManager is ScriptUtils, ContractAddressManager {
    /// @notice Struct to hold contract information
    struct ContractInfo {
        string name;
        address contractAddress;
    }

    /// @notice Array of all contracts that need ownership transfer
    ContractInfo[] public contracts;

    /// @notice Setup function - initializes contracts
    function setUp() public {
        // Add all contracts that need ownership transfer
        contracts.push(ContractInfo({name: "AccessManager", contractAddress: address(getAccessManager())}));
        contracts.push(ContractInfo({name: "PeginManager", contractAddress: address(getPeginManager())}));
        contracts.push(ContractInfo({name: "PegoutManager", contractAddress: address(getPegoutManager())}));
        contracts.push(ContractInfo({name: "StreamManager", contractAddress: address(getStreamManager())}));
        contracts.push(
            ContractInfo({name: "CommitteeRegistry", contractAddress: address(CommitteeRegistry(address(getCommitteeRegistry())))})
        );
        contracts.push(
            ContractInfo({name: "MemberRegistry", contractAddress: address(MemberRegistry(address(getMemberRegistry())))})
        );
        contracts.push(
            ContractInfo({name: "BitcoinManager", contractAddress: address(BitcoinManager(address(getBitcoinManager())))})
        );
        contracts.push(
            ContractInfo({name: "SignatureManager", contractAddress: address(SignatureManager(address(getSignatureManager())))})
        );
        contracts.push(ContractInfo({name: "RbtcBridge", contractAddress: address(RbtcBridge(payable(address(getRbtcBridge()))))}));
        contracts.push(
            ContractInfo({name: "ChallengeManager", contractAddress: address(ChallengeManager(address(getChallengeManager())))})
        );
    }

    /// @notice Check ownership status of all contracts
    /// @dev This is a view function that reads on-chain state
    function checkOwnershipStatus() public view {
        console.log("\n=== OWNERSHIP STATUS ===");

        for (uint256 i = 0; i < contracts.length; i++) {
            ContractInfo storage contractInfo = contracts[i];
            BaseProxy contractInstance = BaseProxy(contractInfo.contractAddress);

            address currentOwner = contractInstance.owner();
            address pendingOwner = contractInstance.pendingOwner();

            console.log("");
            console.log("Contract:", contractInfo.name);
            console.log("  Address:", contractInfo.contractAddress);
            console.log("  Current Owner:", currentOwner);
            console.log("  Pending Owner:", pendingOwner);

            if (pendingOwner != address(0)) {
                console.log(StdStyle.yellow("  Status: Pending transfer - new owner must call acceptOwnership()"));
            } else {
                console.log(StdStyle.green("  Status: No pending transfer"));
            }
        }

        console.log("\n=== STATUS CHECK COMPLETE ===");
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

        for (uint256 i = 0; i < contracts.length; i++) {
            ContractInfo storage contractInfo = contracts[i];
            BaseProxy contractInstance = BaseProxy(contractInfo.contractAddress);

            address currentOwner = contractInstance.owner();
            address pendingOwner = contractInstance.pendingOwner();

            console.log("");
            console.log("Contract:", contractInfo.name);
            console.log("  Address:", contractInfo.contractAddress);
            console.log("  Current Owner:", currentOwner);
            console.log("  Pending Owner:", pendingOwner);

            if (pendingOwner == _newOwner) {
                console.log(StdStyle.yellow("  Status: Already pending transfer to new owner. Skipping..."));
                continue;
            }

            if (currentOwner == _newOwner) {
                console.log(StdStyle.green("  Status: New owner is already the owner. Skipping..."));
                continue;
            }

            console.log("  Transferring ownership...");
            vm.startBroadcast();
            // msg.sender is the address derived from the interactive key
            address owner = msg.sender;
            if (owner != currentOwner) {
                vm.stopBroadcast();
                revert("Sender is not the current owner");
            }
            contractInstance.transferOwnership(_newOwner);
            vm.stopBroadcast();
            console.log(StdStyle.blue("  Status: Ownership transfer initiated"));
        }

        console.log("\n=== PROCESS COMPLETE ===");
        console.log(
            "The new owner must call acceptOwnership() on each contract where the new owner's address is the pendingOwner"
        );
    }

    /// @notice Transfer ownership of all contracts to new owner
    /// @param _newOwner The address that will become the new owner
    /// @dev This is a convenience function that calls transferAllOwnership
    function run(address _newOwner) public {
        transferAllOwnership(_newOwner);
    }
}
