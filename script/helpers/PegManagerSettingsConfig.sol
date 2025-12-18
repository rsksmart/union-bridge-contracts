// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

// Import the PegManagerSettings struct definition from the correct interface
import {PegManagerSettings} from "src/interfaces/IPegManager.sol";
import {ChainIds} from "src/libraries/Network.sol";

library PegManagerSettingsConfig {
    function getSettings(uint256 chainId) internal pure returns (PegManagerSettings memory) {
        if (chainId == ChainIds.RSK_MAINNET) {
            return PegManagerSettings({userTakeTimeout: 2 hours, operatorTakeTimeout: 2 hours});
        } else if (chainId == ChainIds.RSK_TESTNET) {
            return PegManagerSettings({userTakeTimeout: 10 minutes, operatorTakeTimeout: 10 minutes});
        } else if (chainId == ChainIds.RSK_REGTEST) {
            return PegManagerSettings({userTakeTimeout: 30 seconds, operatorTakeTimeout: 30 seconds});
        } else if (chainId == ChainIds.LOCAL) {
            return PegManagerSettings({userTakeTimeout: 30 seconds, operatorTakeTimeout: 30 seconds});
        } else {
            revert("Unsupported chainId");
        }
    }
}
