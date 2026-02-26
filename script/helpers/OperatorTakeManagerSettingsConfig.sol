// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {TakeTimeout} from "src/interfaces/IOperatorTakeManager.sol";
import {ChainIds} from "src/libraries/Network.sol";

library OperatorTakeManagerSettingsConfig {
    function getTakeTimeoutSettings(uint256 chainId, bool isTest) internal pure returns (TakeTimeout memory) {
        if (chainId == ChainIds.RSK_MAINNET) {
            return TakeTimeout({userTake: 2 hours, operatorTake: 2 hours});
        } else if (chainId == ChainIds.RSK_TESTNET) {
            return TakeTimeout({userTake: 10 minutes, operatorTake: 10 minutes});
        } else if (chainId == ChainIds.LOCAL || chainId == ChainIds.RSK_REGTEST) {
            if (isTest) {
                // Default values for unit tests
                return TakeTimeout({userTake: 2 hours, operatorTake: 2 hours});
            } else {
                // Default values for local anvil or rsk regtest
                return TakeTimeout({userTake: 10 minutes, operatorTake: 10 minutes});
            }
        } else {
            revert("Unsupported chainId");
        }
    }
}
