// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ICommitteeRegistry} from "src/interfaces/ICommitteeRegistry.sol";
import {IBitcoinManager} from "src/interfaces/IBitcoinManager.sol";
import {BtcTaprootParser} from "src/libraries/BtcTaprootParser.sol";
import {SlotState} from "src/StreamManager.sol";
import {PegManager} from "src/PegManager.sol";
import "forge-std/console.sol";

/// @notice Wrapper for testing PegManager
contract PegManagerHarness is PegManager {
    function initialize(
        address _initialOwner,
        address payable _bridgeAddress,
        ICommitteeRegistry _committeeRegistry,
        IBitcoinManager _bitcoinManager,
        uint64[] memory _denominations
    ) public override initializer {
        PegManager.initialize(_initialOwner, _bridgeAddress, _committeeRegistry, _bitcoinManager, _denominations);
    }

    function setSlotAsFilledHarness(uint64 _streamId, uint64 _packet, uint64 _slot) external {
        if (_packet >= packets[_streamId].length) {
            console.log("No packets %d for streamId: %d", _packet, _streamId);
        }
        if (_slot >= slots[_streamId][0].length) {
            console.log("No slot %d in packet %d for streamId: %d", _slot, _packet, _streamId);
        }
        slots[_streamId][_packet][_slot].state = SlotState.FILLED;
        slots[_streamId][_packet][_slot].txId = 0xb24858ade3e5be49ae63facb93524ddf460d0771f093525dae328b6c435516a2;
        slots[_streamId][_packet][_slot].scriptPubKey =
            BtcTaprootParser.getP2TRScriptPubKey(0x62f519f51e435c20d38af683ea86862f4591ce8cda248077c2d9a72a76b62f32);
    }
}
