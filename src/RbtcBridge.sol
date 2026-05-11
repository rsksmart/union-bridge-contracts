// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {BaseProxy} from "./BaseProxy.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {IRbtcBridge} from "./interfaces/IRbtcBridge.sol";
import {IBridge} from "./interfaces/IBridge.sol";
import {IAccessManager} from "./interfaces/IAccessManager.sol";
import {
    IBridge,
    BTC_TRANSACTION_CONFIRMATION_MAX_DEPTH,
    BTC_TRANSACTION_CONFIRMATION_INEXISTENT_BLOCK_HASH_ERROR_CODE,
    BTC_TRANSACTION_CONFIRMATION_BLOCK_NOT_IN_BEST_CHAIN_ERROR_CODE,
    BTC_TRANSACTION_CONFIRMATION_INCONSISTENT_BLOCK_ERROR_CODE,
    BTC_TRANSACTION_CONFIRMATION_BLOCK_TOO_OLD_ERROR_CODE,
    BTC_TRANSACTION_CONFIRMATION_INVALID_MERKLE_BRANCH_ERROR_CODE
} from "./interfaces/IBridge.sol";
import {Pausable} from "./Pausable.sol";
import {BtcHelper} from "./libraries/BtcHelper.sol";

/// @title RbtcBridge
/// @notice Intermediary contract that acts as the single authorized address for RBTC minting/burning
///         with the RSK PowPeg Bridge, serving both PeginManager and PegoutManager
/// @dev This contract is necessary because RSKIP-502 only allows ONE contract address to be authorized
///      for minting and burning RBTC. Since PegManager was split into PeginManager and PegoutManager,
///      this bridge serves as the single authorized intermediary.
/// @dev Implements RSKIP-502: https://github.com/rsksmart/RSKIPs/blob/master/IPs/RSKIP502.md
contract RbtcBridge is IRbtcBridge, ReentrancyGuardUpgradeable, BaseProxy, Pausable {
    /// @notice The RSK Bridge contract used for Bitcoin transaction verification
    /// @dev This contract provides access to Bitcoin transaction confirmation data
    IBridge public bridge;

    /// @notice The access manager contract that manages access control
    /// @dev Used to check access control for sensitive operations
    IAccessManager public accessManager;

    uint256 public latestBaseEventBlock;

    /// @notice Initializes the RbtcBridge contract
    /// @param _initialOwner The initial owner of the contract
    /// @param _bridge The RSK PowPeg Bridge contract address
    /// @param _accessManager The access manager contract address
    function initialize(address _initialOwner, IBridge _bridge, IAccessManager _accessManager) external initializer {
        if (_initialOwner == address(0) || address(_bridge) == address(0) || address(_accessManager) == address(0)) {
            revert InvalidZeroAddress();
        }

        bridge = _bridge;
        accessManager = _accessManager;

        __ReentrancyGuard_init();
        __BaseProxy_init(_initialOwner);
        __Pauser_init(address(_accessManager));
    }

    /// @notice Allows the contract to receive RBTC from the PowPeg bridge
    /// @dev This function is called when the PowPeg bridge mints RBTC to this contract
    receive() external payable {}

    /// @inheritdoc IRbtcBridge
    function mintRbtc(address payable _to, uint256 _amount) external nonReentrant whenNotPaused {
        // Verify that the caller has permission to mint RBTC
        accessManager.canMintRbtc(_msgSender());

        _mintRbtc(_to, _amount);

        emit RbtcMinted(_to, _amount);
    }

    /// @inheritdoc IRbtcBridge
    function burnRbtc() external payable nonReentrant whenNotPaused {
        // Verify that the caller has permission to burn RBTC
        accessManager.canBurnRbtc(_msgSender());

        _releaseRbtc(msg.value);

        emit RbtcBurned(msg.value);
    }

    /// @notice Internal function to mint RBTC from the PowPeg bridge and send to recipient
    /// @param _to The address to receive the RBTC
    /// @param _amount The amount of RBTC to mint in wei
    /// @dev Requests RBTC from PowPeg bridge via RSKIP-502 requestUnionBridgeRbtc
    /// @dev Then transfers the RBTC to the recipient with a 100k gas limit
    function _mintRbtc(address payable _to, uint256 _amount) internal {
        // Request RBTC from the PowPeg Bridge
        int256 result = bridge.requestUnionBridgeRbtc(_amount);

        // Handle error codes from the bridge
        if (result == -1) {
            revert BridgeUnauthorizedCaller();
        }
        if (result == -2) {
            revert BridgeExceededLockingCap(_amount);
        }
        if (result == -3) {
            revert BridgeTransfersDisabled();
        }
        if (result != 0) {
            revert BridgeBtcUnknownError(result);
        }

        // Transfer the RBTC to the recipient
        _sendRbtc(_to, _amount);
    }

    /// @notice Internal function to send RBTC to a recipient with a gas limit
    /// @param _to The address to send RBTC to
    /// @param _amount The amount of RBTC to send in wei
    /// @dev Uses a 100k gas limit to prevent DoS attacks while allowing some DeFi operations
    /// @dev Gas limit prevents malicious receive() functions from consuming all gas
    // slither-disable-next-line arbitrary-send-eth,return-bomb
    function _sendRbtc(address payable _to, uint256 _amount) internal {
        (bool sent,) = _to.call{value: _amount, gas: 100_000}("");
        if (!sent) {
            revert FailedToSendRBTC(_to, _amount);
        }
    }

    /// @notice Internal function to release RBTC back to the PowPeg bridge
    /// @param _amountToReturn The amount of RBTC to return to the bridge in wei
    /// @dev Burns RBTC back to PowPeg bridge via RSKIP-502 releaseUnionBridgeRbtc
    function _releaseRbtc(uint256 _amountToReturn) internal {
        // Transfer RBTC back to the PowPeg Bridge and update tracking
        int256 result = bridge.releaseUnionBridgeRbtc{value: _amountToReturn}();

        // Handle error codes from the bridge
        if (result == -1) {
            revert BridgeUnauthorizedCaller();
        }
        if (result == -2) {
            revert BridgeReleaseInvalidValue(_amountToReturn);
        }
        if (result == -3) {
            revert BridgeTransfersDisabled();
        }
        if (result != 0) {
            revert BridgeBtcUnknownError(result);
        }
    }

    /// @inheritdoc IRbtcBridge
    function getUnionBridgeLockingCap() external view returns (uint256) {
        return bridge.getUnionBridgeLockingCap();
    }

    /// @inheritdoc IRbtcBridge
    function verifyTxConfirmations(
        uint256 _minConfirmations,
        bytes32 _txid,
        bytes32 _blockHash,
        uint256 _merkleBranchPath,
        bytes32[] memory _merkleBranchHashes
    ) external view {
        // slither-disable-next-line unused-return
        _verifyTxConfirmations(_minConfirmations, _txid, _blockHash, _merkleBranchPath, _merkleBranchHashes);
    }

    function _verifyTxConfirmations(
        uint256 _minConfirmations,
        bytes32 _txid,
        bytes32 _blockHash,
        uint256 _merkleBranchPath,
        bytes32[] memory _merkleBranchHashes
    ) internal view returns (int256) {
        // Get tx confirmations using RSK bridge precompiled contract
        int256 confirmations =
            bridge.getBtcTransactionConfirmations(_txid, _blockHash, _merkleBranchPath, _merkleBranchHashes);
        // Validate block is in the Mainchain
        if (confirmations == BTC_TRANSACTION_CONFIRMATION_INEXISTENT_BLOCK_HASH_ERROR_CODE) {
            revert BridgeBtcInexistantBlockHash(_blockHash);
        }
        if (confirmations == BTC_TRANSACTION_CONFIRMATION_BLOCK_NOT_IN_BEST_CHAIN_ERROR_CODE) {
            revert BridgeBtcBlockNotInBestChain(_blockHash);
        }
        if (confirmations == BTC_TRANSACTION_CONFIRMATION_INCONSISTENT_BLOCK_ERROR_CODE) {
            revert BridgeBtcInconsistentBlock(_blockHash);
        }
        // Rsk only allows to retrieve blocks up to 1 month
        if (confirmations == BTC_TRANSACTION_CONFIRMATION_BLOCK_TOO_OLD_ERROR_CODE) {
            revert BridgeBtcBlockTooOld(BTC_TRANSACTION_CONFIRMATION_MAX_DEPTH);
        }
        // Validate transaction is in the Block
        if (confirmations == BTC_TRANSACTION_CONFIRMATION_INVALID_MERKLE_BRANCH_ERROR_CODE) {
            revert BridgeBtcTxInvalidMerkleBranch(_txid, _merkleBranchPath, _merkleBranchHashes);
        }
        if (confirmations < 0) {
            revert BridgeBtcUnknownError(confirmations);
        }
        // Validate block has enough Confirmations
        if (uint256(confirmations) < _minConfirmations) {
            revert NotEnoughConfirmations(confirmations, _minConfirmations);
        }
        return confirmations;
    }

    /// @inheritdoc IRbtcBridge
    function getTxBlockNumberAndVerifyConfirmations(
        uint256 _minConfirmations,
        bytes32 _txid,
        bytes32 _blockHash,
        uint256 _merkleBranchPath,
        bytes32[] memory _merkleBranchHashes
    ) external view returns (int256) {
        int256 confirmations =
            _verifyTxConfirmations(_minConfirmations, _txid, _blockHash, _merkleBranchPath, _merkleBranchHashes);
        return bridge.getBtcBlockchainBestChainHeight() - confirmations;
    }

    /// @inheritdoc IRbtcBridge
    function getBestBlockHash() external view returns (bytes32) {
        return BtcHelper.hash256(bridge.getBtcBlockchainBestBlockHeader());
    }

    /// @inheritdoc IRbtcBridge
    function setBaseEvent(bytes memory _baseEvent) external nonReentrant whenNotPaused {
        // Validate the caller
        accessManager.canSetBaseEvent(_msgSender());

        // Validate the base event
        if (_baseEvent.length == 0) {
            revert BaseEventEmpty();
        }
        if (_baseEvent.length > 128) {
            revert BaseEventTooLong();
        }
        // Validate that the base event is not already set in this block
        if (latestBaseEventBlock == block.number) {
            revert BaseEventAlreadySet();
        }
        latestBaseEventBlock = block.number;
        // Set the base event
        bridge.setBaseEvent(_baseEvent);

        emit BaseEventSet(_baseEvent);
    }
}
