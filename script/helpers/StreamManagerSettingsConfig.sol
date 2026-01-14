// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {
    StreamDenomination,
    StreamManagerSettings,
    StreamSettings,
    TimelockSettings
} from "src/interfaces/IStreamManager.sol";
import {ChainIds} from "src/libraries/Network.sol";

library StreamManagerSettingsConfig {
    function getDenominations() internal pure returns (uint64[] memory denominations) {
        denominations = new uint64[](uint64(StreamDenomination.LENGTH));
        denominations[uint64(StreamDenomination._0_001BTC)] = 100_000; // 0.001 BTC
        denominations[uint64(StreamDenomination._0_01BTC)] = 1_000_000; // 0.01 BTC
        denominations[uint64(StreamDenomination._0_1BTC)] = 10_000_000; // 0.1 BTC
        denominations[uint64(StreamDenomination._1BTC)] = 100_000_000; // 1 BTC
        denominations[uint64(StreamDenomination._10BTC)] = 1_000_000_000; // 10 BTC

        for (uint64 i = 0; i < uint64(StreamDenomination.LENGTH); i++) {
            if (denominations[i] == 0) {
                revert("Invalid denomination");
            }
        }

        return denominations;
    }

    /// @dev This function is used to get the default settings for a denomination
    /// @param _chainId The chain id
    /// @param _streamId The index of the stream to get the settings for
    /// @param _denomination The denomination of the stream to get the settings for
    /// @return streamSettings The default settings for the stream
    function getStreamSettings(uint256 _chainId, uint64 _streamId, uint64 _denomination, bool isTest)
        internal
        pure
        returns (StreamSettings memory streamSettings)
    {
        if (_streamId >= uint64(StreamDenomination.LENGTH)) {
            revert("Invalid streamId");
        }
        // Current default values are the same for all denominations but this may change in the future
        streamSettings = StreamSettings({
            denomination: _denomination,
            peginConfirmations: 12,
            pegoutConfirmations: 12,
            // Obtained from https://github.com/FairgateLabs/rust-bitvmx-client/blob/ff0e44255d45ac07e668171cc70668a08e819441/examples/union/participants/common.rs#L89
            timelockSettings: TimelockSettings({
                shortTimelock: 6,
                longTimelock: 12,
                requestPeginTimelock: 12,
                opWonTimelock: 150,
                claimGateTimelock: 6,
                inputNotRevealedTimelock: 8,
                opNoCosignTimelock: 12,
                wtNoChallengeTimelock: 12
            })
        });
        // Override settings for the chain
        if (_chainId == ChainIds.RSK_MAINNET) {
            // Currently mainnet settings are the same as default settings
        } else if (_chainId == ChainIds.RSK_TESTNET) {
            // we use 1 for testnet to speed up testing TODO: this should be changed before final deployment
            streamSettings.peginConfirmations = 1;
            streamSettings.pegoutConfirmations = 1;
        } else if (_chainId == ChainIds.LOCAL || _chainId == ChainIds.RSK_REGTEST) {
            if (isTest) {
                // reduce pegin confirmations to 2 for faster testing
                streamSettings.peginConfirmations = 2;
                streamSettings.pegoutConfirmations = 2;
            } else {
                // Default values for local anvil or rsk regtest
                streamSettings.peginConfirmations = 2;
                streamSettings.pegoutConfirmations = 2;
            }
        } else {
            revert("Unsupported chainId");
        }

        return streamSettings;
    }

    /// @notice This function is used to get the stream manager settings for a chain and denominations
    /// @dev this functions does not return the streamSettings, because copying of type struct StreamSettings memory[] memory to storage is not supported
    /// @param _chainId The chain id
    /// @return settings The stream manager settings without streamSettings
    function getStreamManagerSettings(uint256 _chainId, bool isTest)
        internal
        pure
        returns (StreamManagerSettings memory settings)
    {
        // Default settings for each denomination

        // Current default values are the same for all denominations but this may change in the future
        settings = StreamManagerSettings({
            securityBondPercentageOperator: 1000, // 10 percent
            securityBondPercentageWatchtower: 200, // 2 percent
            minimumSecurityDeposit: 22500000 gwei, // 2250 USD
            disablementPaymentsPerChallenge: 2500000 gwei // 250 USD
        });

        // Override settings for the chain
        if (_chainId == ChainIds.RSK_MAINNET) {
            // Currently mainnet settings are the same as default settings
        } else if (_chainId == ChainIds.RSK_TESTNET) {
            // security bond are cheaper on testnet to avoid draining the faucet.
            settings.securityBondPercentageOperator = 800;
            settings.securityBondPercentageWatchtower = 100;
        } else if (_chainId == ChainIds.LOCAL || _chainId == ChainIds.RSK_REGTEST) {
            // Currently local settings are the same except for the confirmations inside stream settings
            if (isTest) {
                // Default values for unit tests
                settings.securityBondPercentageOperator = 1000;
                settings.securityBondPercentageWatchtower = 200;
            } else {
                // Default values for local anvil or rsk regtest
            }
        } else {
            revert("Unsupported _chainId");
        }

        return settings;
    }
}
