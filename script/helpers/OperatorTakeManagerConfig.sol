// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {TakeTimeout} from "src/interfaces/IOperatorTakeManager.sol";
import {ChainIds} from "src/libraries/Network.sol";
import {StreamDenomination} from "src/interfaces/IStreamManager.sol";

library OperatorTakeManagerConfig {
    function getSettings(uint256 chainId, bool isTest) internal pure returns (TakeTimeout[] memory) {
        if (chainId == ChainIds.RSK_MAINNET) {
            return _buildSettings(2 hours, 2 hours);
        } else if (chainId == ChainIds.RSK_TESTNET) {
            return _buildSettings(10 minutes, 10 minutes);
        } else if (chainId == ChainIds.LOCAL || chainId == ChainIds.RSK_REGTEST) {
            if (isTest) {
                // Default values for unit tests
                return _buildSettings(2 hours, 2 hours);
            } else {
                // Default values for local anvil or rsk regtest
                return _buildSettings(10 minutes, 10 minutes);
            }
        } else {
            revert("Unsupported chainId");
        }
    }

    function _buildSettings(uint256 userTimeout, uint256 operatorTimeout) private pure returns (TakeTimeout[] memory) {
        uint64 numStreams = uint64(StreamDenomination.LENGTH);
        TakeTimeout[] memory settings = new TakeTimeout[](numStreams);
        for (uint64 i = 0; i < numStreams; i++) {
            settings[i] = TakeTimeout({userTake: userTimeout, operatorTake: operatorTimeout});
        }
        return settings;
    }
}
