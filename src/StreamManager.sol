// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {Stream, Packet, Slot, SlotState, IStreamManager} from "./interfaces/IStreamManager.sol";
import {BaseProxy} from "./BaseProxy.sol";
import "forge-std/console.sol";

/// @title Stream Manager
/// @notice Manages streams
contract StreamManager is IStreamManager, BaseProxy {
    Stream[] internal streams;
    uint64[] internal denominations;
    uint64 internal constant SECURITY_BOND_MULTIPLYER = 2;
    uint64 public constant MAX_DENOMINATIONS_SIZE = 10;
    address public pegManager;

    // StreamId => Packet list
    mapping(uint64 => Packet[]) public packets;
    // StreamId => Packet.packetNumber => SlotId
    mapping(uint64 => mapping(uint64 => Slot[])) internal slots;
    // TODO check if we can use another key or a hash for the slots and packets as they are not unique through the streams

    /// @dev Initializes the streams with their denominations and parameters
    function initialize(address _initialOwner, address _pegManager, uint64[] memory _denominations)
        public
        virtual
        initializer
    {
        pegManager = _pegManager;
        uint256 length = _denominations.length;
        if (length > MAX_DENOMINATIONS_SIZE) {
            revert tooManyDenominations(MAX_DENOMINATIONS_SIZE);
        }
        denominations = _denominations;
        for (uint64 i = 0; i < length; i++) {
            streams.push(
                Stream({
                    streamId: i,
                    denomination: _denominations[i],
                    peginPointer: 0,
                    pegoutPointer: -1,
                    securityBondValue: _denominations[i] * SECURITY_BOND_MULTIPLYER,
                    pegInConfirmations: uint8(i + 1)
                })
            );
            emit StreamCreated(i, _denominations[i]);
        }
        __BaseProxy_init(_initialOwner);
    }

    /// @dev Adds one packet per stream and creates a 100 slots given committee
    function createPacketsAndSlots(bytes32 _committeePubKey) external onlyOwner {
        uint256 length = denominations.length;
        for (uint64 i = 0; i < length; i++) {
            uint64 streamId = streams[i].streamId;
            // Add a new packet
            uint64 packetNumber = uint64(packets[streamId].length);
            packets[streamId].push(Packet({packetNumber: packetNumber, committeePubKey: _committeePubKey}));
            emit PacketCreated(streamId, packetNumber);

            // Initialize slots directly in storage
            for (uint64 j = 0; j < 100; j++) {
                slots[i][packetNumber].push(
                    Slot({
                        slotId: j,
                        state: SlotState.PREPARED,
                        scriptPubKey: "",
                        acceptPegInTx: "",
                        acceptPegInAmount: 0,
                        take0Tx: "",
                        take1Tx: ""
                    })
                );
                emit SlotCreated(streamId, packetNumber, j);
            }
        }
    }

    function getStream(uint64 _denomination) external view returns (Stream memory) {
        uint256 length = denominations.length;
        for (uint256 i = 0; i < length; i++) {
            if (streams[i].denomination == _denomination) {
                return streams[i];
            }
        }
        revert StreamNotFoundByDenomination(_denomination);
    }

    function getStreamById(uint64 _streamId) external view returns (Stream memory) {
        return streams[_streamId];
    }

    function getStreamsLength() external view returns (uint64) {
        return uint64(streams.length);
    }

    function getPacket(uint64 _streamId, uint64 _packetNumber) public view returns (Packet memory) {
        if (packets[_streamId].length < _packetNumber) {
            revert PacketOutOfBound(_packetNumber);
        }
        return packets[_streamId][_packetNumber];
    }

    function getPreparedSlotId(uint64 _streamId, uint64 _packetNumber) public view returns (uint64) {
        Slot[] memory slotList = slots[_streamId][_packetNumber];
        uint256 length = slotList.length;
        for (uint64 i = 0; i < length; i++) {
            if (slotList[i].state == SlotState.PREPARED) {
                return i;
            }
        }
        // If i couldn't find any
        revert NoEmptySlot(_streamId, _packetNumber);
    }

    //TODO optimize lookup with a pointer to the first packet with ready to peg-out slot
    function getFirstFilledSlot(uint64 _streamId) external view returns (Slot memory slot, uint64 packetNumber) {
        uint256 packetCount = packets[_streamId].length;
        for (uint64 i = 0; i < packetCount; i++) {
            uint256 slotCount = slots[_streamId][i].length;
            for (uint64 j = 0; j < slotCount; j++) {
                if (slots[_streamId][i][j].state == SlotState.FILLED) {
                    return (slots[_streamId][i][j], i);
                }
            }
        }
        revert NoFilledSlot(_streamId, 0);
    }

    function getSlot(uint64 _streamId, uint64 _packetNumber, uint64 _slotNumber) external view returns (Slot memory) {
        if (_packetNumber >= packets[_streamId].length) {
            revert NonExistentSlot(_streamId, _packetNumber, _slotNumber);
        }
        if (_slotNumber >= slots[_streamId][_packetNumber].length) {
            revert NonExistentSlot(_streamId, _packetNumber, _slotNumber);
        }
        return slots[_streamId][_packetNumber][_slotNumber];
    }

    function lockSlot(uint64 _streamId, uint64 _packetNumber, uint64 _slotId) external onlyPegManager {
        Slot storage slot = slots[_streamId][_packetNumber][_slotId];
        slot.state = SlotState.LOCKED;
    }

    /// @dev Looks for the first empty slot and asigns the PegIn Tx in prepared state
    function fillAcceptPegInTx(
        uint64 _streamId,
        uint64 _packetNumber,
        uint64 _acceptPegInAmount,
        bytes32 _acceptPegInTx,
        bytes memory _scriptPubKey
    ) external onlyPegManager returns (uint64) {
        uint64 slotId = getPreparedSlotId(_streamId, _packetNumber);
        Slot storage slot = slots[_streamId][_packetNumber][slotId];
        slot.state = SlotState.FILLED;
        slot.acceptPegInTx = _acceptPegInTx;
        slot.acceptPegInAmount = _acceptPegInAmount;
        slot.scriptPubKey = _scriptPubKey;
        return slotId;
    }

    function getCommitteePubKey(uint64 _streamId, uint64 _packetNumber) external view returns (bytes32) {
        return getPacket(_streamId, _packetNumber).committeePubKey;
    }

    modifier onlyPegManager() {
        _checkPegManager();
        _;
    }

    /**
     * @dev Throws if the sender is not the pegManager.
     */
    function _checkPegManager() internal view virtual {
        if (pegManager != msg.sender) {
            revert UnauthorizedAccount(msg.sender);
        }
    }
}
