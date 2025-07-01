// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {StreamManagerSettings} from "src/interfaces/IStreamManager.sol";
import {ChainIds} from "src/libraries/Network.sol";

library StreamManagerSettingsConfig {
    function getSettings(uint256 chainId) internal pure returns (StreamManagerSettings memory) {
        if (chainId == ChainIds.RSK_MAINNET) {
            return StreamManagerSettings({
                peginConfirmations: 12,
                pegoutConfirmations: 12,
                securityBondPercentageOperator: 1000,
                securityBondPercentageWatchtower: 200,
                minimumSecurityDeposit: 22500000 gwei, // 2250 USD
                disablementPaymentsPerChallenge: 2500000 gwei // 250 USD
            });
        } else if (chainId == ChainIds.RSK_TESTNET) {
            return StreamManagerSettings({
                peginConfirmations: 6,
                pegoutConfirmations: 6,
                securityBondPercentageOperator: 800,
                securityBondPercentageWatchtower: 100,
                minimumSecurityDeposit: 22500000 gwei, // 2250 USD
                disablementPaymentsPerChallenge: 2500000 gwei // 250 USD
            });
        } else if (chainId == ChainIds.LOCAL) {
            return StreamManagerSettings({
                peginConfirmations: 2,
                pegoutConfirmations: 2,
                securityBondPercentageOperator: 1000, // 10 percent
                securityBondPercentageWatchtower: 200, // 2 percent
                minimumSecurityDeposit: 22500000 gwei, // 2250 USD
                disablementPaymentsPerChallenge: 2500000 gwei // 250 USD
            });
        } else {
            revert("Unsupported chainId");
        }
    }
}
