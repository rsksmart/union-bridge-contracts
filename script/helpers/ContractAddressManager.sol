// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {ChainIds} from "src/libraries/Network.sol";
import {PeginManager} from "src/PeginManager.sol";
import {PegoutManager} from "src/PegoutManager.sol";
import {StreamManager} from "src/StreamManager.sol";
import {ICommitteeRegistry} from "src/interfaces/ICommitteeRegistry.sol";
import {IBridge} from "src/interfaces/IBridge.sol";
import {IMemberRegistry} from "src/interfaces/IMemberRegistry.sol";
import {IBitcoinManager} from "src/interfaces/IBitcoinManager.sol";
import {ISignatureManager} from "src/interfaces/ISignatureManager.sol";
import {AccessManager} from "src/AccessManager.sol";
import {IRbtcBridge} from "src/interfaces/IRbtcBridge.sol";
import {IChallengeManager} from "src/interfaces/IChallengeManager.sol";
import {IOperatorTakeManager} from "src/interfaces/IOperatorTakeManager.sol";
import {BytesHelper} from "src/libraries/BytesHelper.sol";

/// @title ContractAddressManager
/// @notice Helper library to get contract addresses based on the current network
/// @dev Uses environment variables to determine which network's addresses to use
abstract contract ContractAddressManager is Script {
    /// @notice Get the PeginManager contract address for the current network
    /// @return The PeginManager address
    function getPeginManager() internal view returns (PeginManager) {
        address peginManagerAddress = address(0);
        if (block.chainid == ChainIds.LOCAL) {
            peginManagerAddress = vm.envAddress("LOCAL_PEGIN_MANAGER");
        } else if (block.chainid == ChainIds.RSK_REGTEST) {
            peginManagerAddress = vm.envAddress("REGTEST_PEGIN_MANAGER");
        } else if (block.chainid == ChainIds.RSK_MAINNET) {
            peginManagerAddress = vm.envAddress("MAINNET_PEGIN_MANAGER");
        } else if (block.chainid == ChainIds.RSK_TESTNET) {
            // For testnet/alphanet (both chain ID 31), check NETWORK env var
            string memory network = vm.envString("NETWORK");
            if (BytesHelper.compare(bytes(network), bytes("alphanet"))) {
                peginManagerAddress = vm.envAddress("ALPHANET_PEGIN_MANAGER");
            } else if (BytesHelper.compare(bytes(network), bytes("testnet"))) {
                peginManagerAddress = vm.envAddress("TESTNET_PEGIN_MANAGER");
            }
        } else {
            revert("Unsupported chainId");
        }
        return PeginManager(peginManagerAddress);
    }

    /// @notice Get the PegoutManager contract address for the current network
    /// @return The PegoutManager contract
    function getPegoutManager() internal view returns (PegoutManager) {
        return PegoutManager(getAccessManager().pegoutManager());
    }

    /// @notice Get the ChallengeManager contract address for the current network
    /// @return The ChallengeManager contract
    function getChallengeManager() internal view returns (IChallengeManager) {
        return IChallengeManager(getAccessManager().challengeManager());
    }

    /// @notice Get the OperatorTakeManager contract address for the current network
    /// @return The OperatorTakeManager contract
    function getOperatorTakeManager() internal view returns (IOperatorTakeManager) {
        return IOperatorTakeManager(getAccessManager().operatorTakeManager());
    }

    /// @notice Get the StreamManager contract for the current network
    /// @return The StreamManager contract
    function getStreamManager() internal view returns (StreamManager) {
        return StreamManager(address(getPeginManager().streamManager()));
    }

    /// @notice Get the CommitteeRegistry contract for the current network
    /// @return The CommitteeRegistry contract
    function getCommitteeRegistry() internal view returns (ICommitteeRegistry) {
        return getPeginManager().committeeRegistry();
    }

    /// @notice Get the Bridge contract for the current network
    /// @return The RSK pow-peg Bridge  (mock for local only, real bridge for alphanet/testnet/mainnet)
    function getBridge() internal view returns (IBridge) {
        return getRbtcBridge().bridge();
    }

    /// @notice Get the Bridge contract for the current network
    /// @return The RbtcBridge contract
    function getRbtcBridge() internal view returns (IRbtcBridge) {
        return getPeginManager().rbtcBridge();
    }

    /// @notice Get the MemberRegistry contract for the current network
    /// @return The MemberRegistry contract
    function getMemberRegistry() internal view returns (IMemberRegistry) {
        return getCommitteeRegistry().memberRegistry();
    }

    /// @notice Get the BitcoinManager contract for the current network
    /// @return The BitcoinManager contract
    function getBitcoinManager() internal view returns (IBitcoinManager) {
        return getPeginManager().bitcoinManager();
    }

    /// @notice Get the SignatureManager contract for the current network
    /// @return The SignatureManager contract
    function getSignatureManager() internal view returns (ISignatureManager) {
        return getPegoutManager().signatureManager();
    }

    /// @notice Get the AccessManager contract for the current network
    /// @return The AccessManager contract
    function getAccessManager() internal view returns (AccessManager) {
        return AccessManager(address(getPeginManager().pauser()));
    }
}
