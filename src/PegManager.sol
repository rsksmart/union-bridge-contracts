// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import "forge-std/console.sol";
import {Committee, ICommitteeRegistry} from "./interfaces/ICommitteeRegistry.sol";
import {Stream, Packet, SlotState, StreamManager} from "./StreamManager.sol";
import {IBitcoinManager} from "./interfaces/IBitcoinManager.sol";
import {IPegManager} from "./interfaces/IPegManager.sol";
import {Bridge} from "./interfaces/Bridge.sol";
import {BtcHelper} from "./libraries/BtcHelper.sol";

/// @title PegManager
/// @notice Manages peg-in and peg-out operations between Bitcoin and Rootstock
contract PegManager is IPegManager, StreamManager {
    ICommitteeRegistry public committeeRegistry;
    IBitcoinManager public bitcoinManager;
    Bridge public bridge;

    error btcBlockBiggerThanBestBlock(uint256 bestBlockHeight, uint256 blockNumber);
    error notEnoughConfirmations(uint256 actual, uint256 expected);
    error incorrectBlockHashForHeight(bytes32 actualHash, bytes32 expected, uint256 height);

    function initialize(ICommitteeRegistry _committeeRegistry, IBitcoinManager _bitcoinManager, Bridge _bridge)
        public
        initializer
    {
        committeeRegistry = _committeeRegistry;
        bitcoinManager = _bitcoinManager;
        bridge = _bridge;
        Committee memory committee = committeeRegistry.getNextAvailableCommittee();
        StreamManager.initialize(committee.internalKey);
    }

    function getTemporaryPegInAddress(
        bytes calldata _rootstockDepositAddress,
        // bytes calldata bitcoinReimbursementAddress,
        uint64 _value
    ) external view returns (bytes memory bitcoinDepositAddress) {
        // Get the stream for this value
        Stream memory stream = getStream(_value);

        // Get the current packet's committee key
        Packet memory currentPacket = packets[stream.streamId][stream.peginPointer];
        bytes32 committeeKey = currentPacket.committeeInternalKey;

        return bitcoinManager.getTemporaryPegInAddress(_rootstockDepositAddress, _value, committeeKey);
    }

    struct PegInRequestTxSPVProof {
        uint256 packetNumber; // Packet Index in the Stream
        address destinationAddress; // destination Address in Rootstock
        bytes32 btcReinburstmentAddress; // Bitcoin reimburstment address
        uint64 value; // The denomination of the stream in satoshis
        bytes32 txHash; // The Bitcoin PegIn Transaction Hash
        bytes32 blockHash; // The Bitcoin Block Hash where the pegin tx happened
        uint256 blockNumber; // The Bitcoin Block Number where the pegin tx happened
        string utxo; // UTXO of the PegIn Transaction
    }

    function acceptPegInRequest(PegInRequestTxSPVProof calldata pegInRequestTxSPVProof) public {
        // TODO validate who can call this function

        // Validate data in transaction
        //  Check destination address from second output, after OP_RETURN, and compare it with the destination address from the first output script.
        //  Contains value bitcoin to the taproot temporary address

        // Validate transaction is in the Block

        Stream memory stream = getStream(pegInRequestTxSPVProof.value);
        _validateBlockConfirmations(pegInRequestTxSPVProof.blockNumber, stream.pegInConfirmations);

        _validateBlockInBtcBlockchain(pegInRequestTxSPVProof.blockNumber, pegInRequestTxSPVProof.blockHash);

        // Validate Committee Key against the bitcoin Tx
        Packet memory packet = getPacket(stream.streamId, pegInRequestTxSPVProof.packetNumber);
        packet.committeeInternalKey;

        // Store Tx in pegInSlot as Prepared
        preparePegInTx(
            stream.streamId,
            pegInRequestTxSPVProof.packetNumber,
            pegInRequestTxSPVProof.txHash,
            pegInRequestTxSPVProof.utxo
        );
        // Emit event to prepareTakeTransactions
    }

    /// @dev Validate Block has enough confirmations
    function _validateBlockConfirmations(uint256 _blockNumber, uint256 _pegInConfirmations) internal view {
        uint256 bestBlockHeight = uint256(bridge.getBtcBlockchainBestChainHeight());
        if (bestBlockHeight > _blockNumber) {
            revert btcBlockBiggerThanBestBlock(bestBlockHeight, _blockNumber);
        }
        uint256 confirmations = bestBlockHeight - _blockNumber;
        if (confirmations < _pegInConfirmations) {
            revert notEnoughConfirmations(confirmations, _pegInConfirmations);
        }
    }

    /// @dev Validate Block is in the BTC Blockchain
    function _validateBlockInBtcBlockchain(uint256 _blockNumber, bytes32 _blockHash) internal view {
        bytes32 btcBlockHash = BtcHelper.hash256(bridge.getBtcBlockchainBlockHeaderByHeight(_blockNumber));
        if (btcBlockHash != _blockHash) {
            revert incorrectBlockHashForHeight(btcBlockHash, _blockHash, _blockNumber);
        }
    }
}
