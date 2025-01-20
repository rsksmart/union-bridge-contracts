// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import "forge-std/console.sol";
import {Committee, ICommitteeRegistry} from "./interfaces/ICommitteeRegistry.sol";
import {Stream, Packet, SlotState, StreamManager} from "./StreamManager.sol";
import {IBitcoinManager} from "./interfaces/IBitcoinManager.sol";
import {PegInRequestTxSPVProof, IPegManager} from "./interfaces/IPegManager.sol";
import {
    Bridge,
    RSK_BRIDGE_ADDRESS,
    BTC_TRANSACTION_CONFIRMATION_MAX_DEPTH,
    BTC_TRANSACTION_CONFIRMATION_INEXISTENT_BLOCK_HASH_ERROR_CODE,
    BTC_TRANSACTION_CONFIRMATION_BLOCK_NOT_IN_BEST_CHAIN_ERROR_CODE,
    BTC_TRANSACTION_CONFIRMATION_INCONSISTENT_BLOCK_ERROR_CODE,
    BTC_TRANSACTION_CONFIRMATION_BLOCK_TOO_OLD_ERROR_CODE,
    BTC_TRANSACTION_CONFIRMATION_INVALID_MERKLE_BRANCH_ERROR_CODE
} from "./interfaces/Bridge.sol";
import {BtcHelper} from "./libraries/BtcHelper.sol";

/// @title PegManager
/// @notice Manages peg-in and peg-out operations between Bitcoin and Rootstock
contract PegManager is IPegManager, StreamManager {
    ICommitteeRegistry public committeeRegistry;
    IBitcoinManager public bitcoinManager;
    Bridge public bridge;

    // error btcBlockBiggerThanBestBlock(uint256 bestBlockHeight, uint256 blockNumber);
    // error notEnoughConfirmations(uint256 actual, uint256 expected);
    // error incorrectBlockHashForHeight(bytes32 actualHash, bytes32 expected, uint256 height);
    error bridgeBtcInexistantBlockHash(bytes32 blockHash);
    error bridgeBtcBlockNotInBestChain(bytes32 blockHash);
    error bridgeBtcInconsistentBlock(bytes32 blockHash);
    error bridgeBtcBlockTooOld(bytes32 blockHash, uint256 maxDepth);
    error bridgeBtcTxInvalidMerkleBranch(uint256 merkleBranchPath, bytes32[] merkleBranchHashes);
    error bridgeBtcUnknownError(int256 errorCode);

    function initialize(ICommitteeRegistry _committeeRegistry, IBitcoinManager _bitcoinManager) public initializer {
        committeeRegistry = _committeeRegistry;
        bitcoinManager = _bitcoinManager;
        bridge = Bridge(RSK_BRIDGE_ADDRESS);
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

    function acceptPegInRequest(PegInRequestTxSPVProof calldata pegInRequestTxSPVProof) public {
        // TODO validate who can call this function

        // TODO Validate data in transaction
        //  Check destination address from second output, after OP_RETURN, and compare it with the destination address from the first output script.
        //  Contains value bitcoin to the taproot temporary address

        // Validate transaction is in the Block 
        // Validate block is in the Mainchain
        // Validate block has enough Confirmations
        int256 confirmations = bridge.getBtcTransactionConfirmations(
            pegInRequestTxSPVProof.txHash,
            pegInRequestTxSPVProof.blockHash,
            pegInRequestTxSPVProof.merkleBranchPath,
            pegInRequestTxSPVProof.merkleBranchHashes
        );
        if (confirmations == BTC_TRANSACTION_CONFIRMATION_INEXISTENT_BLOCK_HASH_ERROR_CODE) {
            revert bridgeBtcInexistantBlockHash(pegInRequestTxSPVProof.blockHash);
        }
        if (confirmations == BTC_TRANSACTION_CONFIRMATION_BLOCK_NOT_IN_BEST_CHAIN_ERROR_CODE) {
            revert bridgeBtcBlockNotInBestChain(pegInRequestTxSPVProof.blockHash);
        }
        if (confirmations == BTC_TRANSACTION_CONFIRMATION_INCONSISTENT_BLOCK_ERROR_CODE) {
            revert bridgeBtcInconsistentBlock(pegInRequestTxSPVProof.blockHash);
        }
        if (confirmations == BTC_TRANSACTION_CONFIRMATION_BLOCK_TOO_OLD_ERROR_CODE) {
            revert bridgeBtcBlockTooOld(BTC_TRANSACTION_CONFIRMATION_MAX_DEPTH);
        }
        if (confirmations == BTC_TRANSACTION_CONFIRMATION_INVALID_MERKLE_BRANCH_ERROR_CODE) {
            revert bridgeBtcTxInvalidMerkleBranch(
                pegInRequestTxSPVProof.merkleBranchPath, pegInRequestTxSPVProof.merkleBranchHashes
            );
        }
        if (confirmations < 0) {
            revert bridgeBtcUnknownError(confirmations);
        }

        Stream memory stream = getStream(pegInRequestTxSPVProof.value);
        // _validateBlockConfirmations(pegInRequestTxSPVProof.blockNumber, stream.pegInConfirmations);

        // _validateBlockInBtcBlockchain(pegInRequestTxSPVProof.blockNumber, pegInRequestTxSPVProof.blockHash);

        // TODO Validate Committee Key against the bitcoin Tx
        Packet memory packet = getPacket(stream.streamId, pegInRequestTxSPVProof.packetNumber);
        packet.committeeInternalKey;

        // Store Tx in pegInSlot as Prepared
        // TODO corroborate if state should be prepared with Diego
        preparePegInTx(
            stream.streamId,
            pegInRequestTxSPVProof.packetNumber,
            pegInRequestTxSPVProof.txHash,
            pegInRequestTxSPVProof.utxo
        );
        // TODO Emit event to prepareTakeTransactions
    }

    // /// @dev Validate Block has enough confirmations
    // function _validateBlockConfirmations(uint256 _blockNumber, uint256 _pegInConfirmations) internal view {
    //     uint256 bestBlockHeight = uint256(bridge.getBtcBlockchainBestChainHeight());
    //     if (bestBlockHeight < _blockNumber) {
    //         revert btcBlockBiggerThanBestBlock(bestBlockHeight, _blockNumber);
    //     }
    //     uint256 confirmations = bestBlockHeight - _blockNumber;
    //     if (confirmations < _pegInConfirmations) {
    //         revert notEnoughConfirmations(confirmations, _pegInConfirmations);
    //     }
    // }

    // /// @dev Validate Block is in the BTC Blockchain
    // function _validateBlockInBtcBlockchain(uint256 _blockNumber, bytes32 _blockHash) internal view {
    //     bytes32 btcBlockHash = BtcHelper.hash256(bridge.getBtcBlockchainBlockHeaderByHeight(_blockNumber));
    //     if (btcBlockHash != _blockHash) {
    //         revert incorrectBlockHashForHeight(btcBlockHash, _blockHash, _blockNumber);
    //     }
    // }
}
