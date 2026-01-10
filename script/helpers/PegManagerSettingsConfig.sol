// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

// Import the PegManagerSettings struct definition from the correct interface
import {PegManagerSettings} from "src/interfaces/IPegManager.sol";
import {ChainIds} from "src/libraries/Network.sol";

library PegManagerSettingsConfig {
    function getSettings(uint256 chainId, bool isTest) internal pure returns (PegManagerSettings memory) {
        if (chainId == ChainIds.RSK_MAINNET) {
            return PegManagerSettings({userTakeTimeout: 2 hours, operatorTakeTimeout: 2 hours});
        } else if (chainId == ChainIds.RSK_TESTNET) {
            return PegManagerSettings({userTakeTimeout: 10 minutes, operatorTakeTimeout: 10 minutes});
        } else if (chainId == ChainIds.LOCAL || chainId == ChainIds.RSK_REGTEST) {
            if (isTest) {
                // Default values for unit tests
                return PegManagerSettings({userTakeTimeout: 2 hours, operatorTakeTimeout: 2 hours});
            } else {
                // Default values for local anvil or rsk regtest
                return PegManagerSettings({userTakeTimeout: 10 minutes, operatorTakeTimeout: 10 minutes});
            }
        } else {
            revert("Unsupported chainId");
        }
    }
}
