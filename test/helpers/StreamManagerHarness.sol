// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {SlotState, Slot, StreamManager} from "src/StreamManager.sol";
import {ICommitteeRegistry, Role} from "src/interfaces/ICommitteeRegistry.sol";
import {StreamManagerSettings, StreamSettings, TimelockSettings} from "src/interfaces/IStreamManager.sol";

/// @notice Wrapper for testing StreamManager
contract StreamManagerHarness is StreamManager {
    function initialize(
        address _initialOwner,
        address _peginManager,
        address _pegoutManager,
        ICommitteeRegistry _committeeRegistry,
        StreamManagerSettings memory _settings,
        StreamSettings[] memory _streamSettings
    ) public override initializer {
        StreamManager.initialize(
            _initialOwner, _peginManager, _pegoutManager, _committeeRegistry, _settings, _streamSettings
        );
    }

    function setSlotHarness(
        uint64 _streamId,
        uint64 _packet,
        bytes memory _scriptPubKey,
        bytes32 _txId,
        uint64 _amount,
        SlotState _state
    ) external returns (uint64) {
        uint64 slotId = uint64(slots[_streamId][_packet].length);
        slots[_streamId][_packet].push(
            Slot({
                slotId: slotId,
                state: _state,
                acceptPeginTx: _txId,
                acceptPeginAmount: _amount,
                scriptPubKey: _scriptPubKey,
                takeTx: "",
                enablerScriptPubKey: ""
            })
        );

        return slotId;
    }

    function setPegoutPointersHarness(uint64 _streamId, uint64 _packet, uint16 _slot) external {
        streams[_streamId].pegoutPacketPointer = _packet;
        streams[_streamId].pegoutSlotPointer = _slot;
    }

    function pushSlotsHarness(uint64 _streamId, uint64 _packet, uint64 _slotsAmount, SlotState _slotState) external {
        for (uint64 i = 0; i < _slotsAmount; i++) {
            slots[_streamId][_packet].push(
                Slot({
                    slotId: i,
                    state: _slotState,
                    scriptPubKey: hex"00",
                    acceptPeginTx: bytes32(0),
                    acceptPeginAmount: 0,
                    takeTx: "",
                    enablerScriptPubKey: ""
                })
            );
        }
    }

    function getSlotsLengthHarness(uint64 _streamId, uint64 _packet) external view returns (uint256) {
        return slots[_streamId][_packet].length;
    }

    function setSlotStateHarness(uint64 _streamId, uint64 _packet, uint64 _slotId, SlotState _state) external {
        if (_packet >= packets[_streamId].length) {
            revert NoPacketsHarness(_streamId, _packet);
        }
        if (_slotId >= slots[_streamId][_packet].length) {
            revert NoSlotsHarness(_streamId, _packet, _slotId);
        }
        slots[_streamId][_packet][_slotId].state = _state;
    }

    /// @dev Returns the security bond percentage for a given role
    /// @param _role The role for which to get the security bond percentage
    /// @return The security bond percentage in 10_000 format (e.g. 1000 = 10%)
    /// @notice Reverts if the role is NONE
    function getSecurityBondPercentage(Role _role) external view returns (uint16) {
        if (_role == Role.NONE) {
            revert InvalidRole(_role);
        }
        return securityBondPercentage[_role];
    }

    error NoSlotsHarness(uint64 streamId, uint64 packet, uint64 slot);
    error NoPacketsHarness(uint64 streamId, uint64 packet);
}
