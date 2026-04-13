// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

// Import the PegManagerSettings struct definition from the correct interface
import {CommitteeRegistrySettings} from "src/interfaces/ICommitteeRegistry.sol";
import {ChainIds} from "src/libraries/Network.sol";

library CommitteeRegistrySettingsConfig {
    function getSettings(uint256 chainId, bool isTest)
        internal
        pure
        returns (CommitteeRegistrySettings memory settings)
    {
        // Default values this are used in unit tests
        settings = CommitteeRegistrySettings({
            pendingCommitteeTimeout: 1 days,
            minCommitteeWatchtowers: 2,
            minCommitteeOperators: 2,
            committeeMemberCount: 4
        });
        if (chainId == ChainIds.RSK_MAINNET) {
            // Default values for mainnet
        } else if (chainId == ChainIds.RSK_TESTNET) {
            // Default values for testnet or alphaner
        } else if (chainId == ChainIds.LOCAL || chainId == ChainIds.RSK_REGTEST) {
            if (isTest) {
                // Default values for unit tests
            } else {
                // Default values for local anvil or rsk regtest
                settings.minCommitteeWatchtowers = 2;
                settings.minCommitteeOperators = 2;
                settings.committeeMemberCount = 4;
            }
        } else {
            revert("Unsupported chainId");
        }
    }
}
