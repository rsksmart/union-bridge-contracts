// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {PegManager, PegoutTempInfo, PegStatus, PegManagerSettings} from "src/PegManager.sol";
import {ICommitteeRegistry} from "src/interfaces/ICommitteeRegistry.sol";
import {IBitcoinManager} from "src/interfaces/IBitcoinManager.sol";
import {StreamPosition} from "src/interfaces/IPegManager.sol";

/// @notice Wrapper for testing PegManager
contract PegManagerHarness is PegManager {
    function initialize(
        address _initialOwner,
        address payable _bridgeAddress,
        ICommitteeRegistry _committeeRegistry,
        IBitcoinManager _bitcoinManager,
        PegManagerSettings memory _settings
    ) internal virtual override initializer {
        //replaced by Review_public_methods
        //public override initializer {
        PegManager.initialize(_initialOwner, _bridgeAddress, _committeeRegistry, _bitcoinManager, _settings);
    }

    function setPegoutTempInfoHarness(bytes32 _acceptPeginTxHash, bytes memory _userPubKey) external {
        pegoutTempInfo[_acceptPeginTxHash] = PegoutTempInfo({
            userPubKey: _userPubKey,
            createdAt: block.timestamp,
            operatorTakeUpdatedAt: 0,
            committeeId: 0,
            takeOperatorAddress: address(0),
            takeOperatorPubKey: bytes32(0)
        });
    }

    function setStreamPositionHarness(
        bytes32 _acceptPeginTxhash,
        uint64 _streamId,
        uint64 _packetNumber,
        uint64 _slotId,
        PegStatus _pegStatus
    ) external {
        streamPosition[_acceptPeginTxhash] =
            StreamPosition({streamId: _streamId, packetNumber: _packetNumber, slotId: _slotId, pegStatus: _pegStatus});
    }
}
