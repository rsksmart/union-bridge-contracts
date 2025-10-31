// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {PegoutManager} from "src/PegoutManager.sol";
import {ICommitteeRegistry} from "src/interfaces/ICommitteeRegistry.sol";
import {IBitcoinManager} from "src/interfaces/IBitcoinManager.sol";
import {StreamPosition, PegStatus, PegManagerSettings, PegoutTempInfo} from "src/interfaces/IPegCommonTypes.sol";

/// @title PegoutManagerHarness
/// @notice Test harness for PegoutManager to expose internal functions and state for testing
/// @dev TODO: Uncomment and implement harness functions as needed when updating tests
contract PegoutManagerHarness is PegoutManager {
    function initialize(
        address _initialOwner,
        address payable _bridgeAddress,
        ICommitteeRegistry _committeeRegistry,
        IBitcoinManager _bitcoinManager,
        PegManagerSettings memory _settings
    ) public override initializer {
        PegoutManager.initialize(_initialOwner, _bridgeAddress, _committeeRegistry, _bitcoinManager, _settings);
    }

    function setPegoutTempInfoHarness(bytes32 _acceptPeginTxid, bytes memory _userPubKey) external {
        pegoutTempInfo[_acceptPeginTxid] = PegoutTempInfo({
            userPubKey: _userPubKey,
            createdAt: block.timestamp,
            operatorTakeUpdatedAt: 0,
            committeeId: 0,
            takeOperatorAddress: address(0),
            takeOperatorPubKey: bytes32(0)
        });
    }
}
