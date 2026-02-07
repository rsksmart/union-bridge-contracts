// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {PegoutManager} from "src/PegoutManager.sol";
import {ICommitteeRegistry} from "src/interfaces/ICommitteeRegistry.sol";
import {IBitcoinManager} from "src/interfaces/IBitcoinManager.sol";
import {PegoutManagerSettings, PegoutTempInfo} from "src/interfaces/IPegoutManager.sol";
import {IRbtcBridge} from "src/interfaces/IRbtcBridge.sol";
import {IStreamManager} from "src/interfaces/IStreamManager.sol";
import {ISignatureManager} from "src/interfaces/ISignatureManager.sol";

/// @title PegoutManagerHarness
/// @notice Test harness for PegoutManager to expose internal functions and state for testing
contract PegoutManagerHarness is PegoutManager {
    function initialize(
        address _initialOwner,
        address _accessManager,
        ICommitteeRegistry _committeeRegistry,
        IBitcoinManager _bitcoinManager,
        IRbtcBridge _rbtcBridge,
        IStreamManager _streamManager,
        ISignatureManager _signatureManager,
        PegoutManagerSettings memory _settings
    ) public override initializer {
        PegoutManager.initialize(
            _initialOwner,
            _accessManager,
            _committeeRegistry,
            _bitcoinManager,
            _rbtcBridge,
            _streamManager,
            _signatureManager,
            _settings
        );
    }

    function setPegoutTempInfoHarness(bytes32 _acceptPeginTxid, bytes memory _userPubKey) external {
        pegoutTempInfo[_acceptPeginTxid] = PegoutTempInfo({
            userPubKey: _userPubKey,
            createdAt: block.timestamp,
            operatorTakeUpdatedAt: 0,
            committeeId: 0,
            takeOperatorAddress: address(0),
            operatorTakePubKey: bytes32(0),
            operatorDisputePubKey: bytes32(0),
            pegoutId: bytes32(0),
            advanceFundsBlockNumber: 0,
            reimbursementKickoffTxid: bytes32(0)
        });
    }
}
