// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {PegoutManager} from "src/PegoutManager.sol";
import {ICommitteeRegistry} from "src/interfaces/ICommitteeRegistry.sol";
import {IBitcoinManager} from "src/interfaces/IBitcoinManager.sol";
import {IMemberRegistry} from "src/interfaces/IMemberRegistry.sol";
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
        IMemberRegistry _memberRegistry,
        PegManagerSettings memory _settings
    ) public override initializer {
        PegoutManager.initialize(
            _initialOwner, _bridgeAddress, _committeeRegistry, _bitcoinManager, _memberRegistry, _settings
        );
    }

    // TODO: Add harness functions as needed for testing
    // Examples from old PegManagerHarness that may be useful:

    /*
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

    function setStreamPositionHarness(
        bytes32 _acceptPeginTxid,
        uint64 _streamId,
        uint64 _packetNumber,
        uint64 _slotId,
        PegStatus _pegStatus
    ) external {
        streamManager.setStreamPosition(
            _acceptPeginTxid,
            StreamPosition({streamId: _streamId, packetNumber: _packetNumber, slotId: _slotId, pegStatus: _pegStatus})
        );
    }
    */
}
