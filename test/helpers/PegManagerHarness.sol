// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {PegManager, PegOutInfo} from "src/PegManager.sol";
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

    function setPegOutTxInfoHarness(
        bytes32 _acceptPegInTxHash,
        bytes memory _userPubKey,
        uint64 _streamId,
        uint64 _packetNumber,
        uint64 _slotId
    ) external {
        pegOuts[_acceptPegInTxHash] = PegOutInfo({
            userPubKey: _userPubKey,
            streamId: _streamId,
            packetNumber: _packetNumber,
            slotId: _slotId,
            acceptPegInTxHash: _acceptPegInTxHash
        });
    }
}
