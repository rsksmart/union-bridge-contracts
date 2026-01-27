// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {BaseProxy} from "./BaseProxy.sol";
import {Pausable} from "./Pausable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {IRbtcBridge} from "./interfaces/IRbtcBridge.sol";
import {IBridge} from "./interfaces/IBridge.sol";
import {IAccessManager} from "./interfaces/IAccessManager.sol";

/// @title RbtcBridge
/// @notice Intermediary contract that acts as the single authorized address for RBTC minting/burning
///         with the RSK PowPeg Bridge, serving both PeginManager and PegoutManager
/// @dev This contract is necessary because RSKIP-502 only allows ONE contract address to be authorized
///      for minting and burning RBTC. Since PegManager was split into PeginManager and PegoutManager,
///      this bridge serves as the single authorized intermediary.
/// @dev Implements RSKIP-502: https://github.com/rsksmart/RSKIPs/blob/master/IPs/RSKIP502.md
contract RbtcBridge is IRbtcBridge, BaseProxy, ReentrancyGuardUpgradeable, Pausable {
    /// @notice The RSK PowPeg Bridge contract
    IBridge public bridge;

    /// @notice The access manager contract that manages access control
    /// @dev Used to check access control for sensitive operations
    IAccessManager public accessManager;

    /// @notice Initializes the RbtcBridge contract
    /// @param _initialOwner The initial owner of the contract
    /// @param _bridge The RSK PowPeg Bridge contract address
    /// @param _accessManager The access manager contract address
    function initialize(address _initialOwner, address _bridge, IAccessManager _accessManager) external initializer {
        if (_bridge == address(0) || address(_accessManager) == address(0)) {
            revert InvalidZeroAddress();
        }
        accessManager = _accessManager;
        bridge = IBridge(_bridge);

        __BaseProxy_init(_initialOwner);
        __ReentrancyGuard_init();
        __Pauser_init(address(accessManager));
    }

    /// @notice Allows the contract to receive RBTC from the PowPeg bridge
    /// @dev This function is called when the PowPeg bridge mints RBTC to this contract
    receive() external payable {}

    /// @notice Mints RBTC from the PowPeg bridge and sends it to the specified address
    /// @param _to The address to receive the minted RBTC
    /// @param _amount The amount of RBTC to mint in wei
    /// @dev Only callable by peginManager when contract is not paused
    /// @dev Follows checks-effects-interactions pattern
    function mintRbtc(address payable _to, uint256 _amount) external nonReentrant whenNotPaused {
        // Verify that the caller has permission to mint RBTC
        accessManager.requireCanMintRbtc(_msgSender());

        _mintRbtc(_to, _amount);

        emit RbtcMinted(_to, _amount);
    }

    /// @notice Burns RBTC back to the PowPeg bridge
    /// @dev Only callable by pegoutManager when contract is not paused
    /// @dev The pegoutManager must send the RBTC amount via msg.value
    function burnRbtc() external payable nonReentrant whenNotPaused {
        // Verify that the caller has permission to burn RBTC
        accessManager.requireCanBurnRbtc(_msgSender());

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

    /// @notice Gets the locking cap of the Union Bridge for RBTC minting operations
    /// @dev This method is new in RSKIP-502
    /// @return The locking cap of the Union Bridge
    function getUnionBridgeLockingCap() external view returns (uint256) {
        return bridge.getUnionBridgeLockingCap();
    }
}
