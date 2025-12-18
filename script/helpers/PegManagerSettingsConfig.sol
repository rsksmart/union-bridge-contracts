// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

// Import the PegoutManagerSettings struct definition from the correct interface
import {PegoutManagerSettings} from "src/interfaces/IPegoutManager.sol";
import {ChainIds} from "src/libraries/Network.sol";

library PegManagerSettingsConfig {
    function getSettingsForChain(uint256 chainId) internal pure returns (PegoutManagerSettings memory) {
        if (chainId == ChainIds.RSK_MAINNET) {
            return PegoutManagerSettings({userTakeTimeout: 2 hours, operatorTakeTimeout: 2 hours});
        } else if (chainId == ChainIds.RSK_TESTNET) {
            return PegoutManagerSettings({userTakeTimeout: 10 minutes, operatorTakeTimeout: 10 minutes});
        } else if (chainId == ChainIds.LOCAL || chainId == ChainIds.RSK_REGTEST) {
            return PegoutManagerSettings({userTakeTimeout: 30 seconds, operatorTakeTimeout: 30 seconds});
        } else {
            revert("Unsupported chainId");
        }
    }
}
