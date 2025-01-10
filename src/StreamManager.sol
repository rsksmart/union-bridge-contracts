// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {Stream, Packet, Slot, SlotState, IStreamManager} from "./interfaces/IStreamManager.sol";

/// @title Stream Manager
/// @notice Manages streams
abstract contract StreamManager is IStreamManager, Initializable {
    Stream[5] internal streams;
    uint64[5] internal denominations;
    uint64 internal constant SECURITY_BOND_MULTIPLYER = 2;

    // StreamId => Packet list
    mapping(uint256 => Packet[]) public packets; // TODO see how to handle it in a mapping instead of an array
    // StreamId => Packet.sequenceNumber => SlotId
    mapping(uint256 => mapping(uint256 => Slot[])) public slots; // TODO see how to handle it in a mapping instead of an array

    error StreamNotFoundByDenomination(uint256 denomination);

    /// @dev Initializes the streams with their denominations and parameters
    function initialize(uint256 _committeeId, bytes32 _committeeInternalKey) public onlyInitializing {
        denominations = [
            uint64(100_000), // 0.001 BTC
            uint64(1_000_000), // 0.01 BTC
            uint64(10_000_000), // 0.1 BTC
            uint64(100_000_000), // 1 BTC
            uint64(1_000_000_000) // 10 BTC
        ];

        for (uint256 i = 0; i < 5; i++) {
            streams[i].streamId = i;
            streams[i].denomination = denominations[i];
            streams[i].peginPointer = 0;
            streams[i].pegoutPointer = -1;
            streams[i].securityBondValue = denominations[i] * SECURITY_BOND_MULTIPLYER;

            // Create initial packet

            // First push an empty packet to storage
            packets[i].push();
            uint256 sequenceNumber = packets[i].length - 1;

            // Then modify it in place
            Packet storage newPacket = packets[i][sequenceNumber];
            newPacket.sequenceNumber = sequenceNumber;
            newPacket.committeeId = _committeeId;
            newPacket.committeeInternalKey = _committeeInternalKey;

            // Initialize slots directly in storage
            for (uint256 j = 0; j < 100; j++) {
                slots[i][sequenceNumber].push(
                    Slot({slotId: j, state: SlotState.EMPTY, utxo: "", peginTx: "", take0Tx: "", take1TX: ""})
                );
            }
        }
    }

    function getStream(uint64 _denomination) public view returns (Stream memory) {
        for (uint256 i = 0; i < 5; i++) {
            if (streams[i].denomination == _denomination) {
                return streams[i];
            }
        }
        revert StreamNotFoundByDenomination(_denomination);
    }

    function getStreamById(uint256 _streamId) external view returns (Stream memory) {
        return streams[_streamId];
    }

    function getStreamsLength() external view returns (uint256) {
        return streams.length;
    }
}
