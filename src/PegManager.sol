// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.19;

import "forge-std/console.sol";
import "./CommitteeRegistry.sol";
import "./StreamManager.sol";
import "./interfaces/IBitcoinManager.sol";
import "./interfaces/IPegManager.sol";

/// @title PegManager
/// @notice Manages peg-in and peg-out operations between Bitcoin and Rootstock
contract PegManager is StreamManager, IPegManager {
    CommitteeRegistry public immutable committeeRegistry;
    IBitcoinManager public immutable bitcoinManager;

    constructor(CommitteeRegistry _committeeRegistry, IBitcoinManager _bitcoinManager) {
        committeeRegistry = _committeeRegistry;
        bitcoinManager = _bitcoinManager;
        (uint256 committeeId, Committee memory committee) = committeeRegistry.getNextAvailableCommittee();
        initializeStreams(committeeId, committee.internalKey);
    }

    function getTemporaryPegInAddress(
        bytes calldata rootstockDepositAddress,
        // bytes calldata bitcoinReimbursementAddress,
        uint64 value
    ) external view returns (bytes memory bitcoinDepositAddress) {
        // Get the stream for this value
        Stream memory stream = getStream(value);

        // Get the current packet's committee key
        Packet memory currentPacket = packets[stream.streamId][stream.peginPointer];
        bytes32 committeeKey = currentPacket.committeeInternalKey;

        return bitcoinManager.getTemporaryPegInAddress(rootstockDepositAddress, value, committeeKey);
    }
}
