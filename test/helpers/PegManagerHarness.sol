// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {PegManager, PegOutTempInfo} from "src/PegManager.sol";
import {ICommitteeRegistry} from "src/interfaces/ICommitteeRegistry.sol";
import {IBitcoinManager} from "src/interfaces/IBitcoinManager.sol";

/// @notice Wrapper for testing PegManager
contract PegManagerHarness is PegManager {
    function initialize(
        address _initialOwner,
        address payable _bridgeAddress,
        ICommitteeRegistry _committeeRegistry,
        IBitcoinManager _bitcoinManager
    ) public override initializer {
        PegManager.initialize(_initialOwner, _bridgeAddress, _committeeRegistry, _bitcoinManager);
    }

    function setPegOutTempInfoHarness(bytes32 _acceptPegInTxHash, bytes memory _userPubKey) external {
        pegOutTempInfo[_acceptPegInTxHash] = PegOutTempInfo({userPubKey: _userPubKey});
    }
}
