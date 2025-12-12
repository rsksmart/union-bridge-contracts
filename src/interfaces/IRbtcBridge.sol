// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

/// @title IRbtcBridge
/// @notice Interface for the RbtcBridge contract that acts as the single authorized intermediary
///         between the Union Bridge system and the RSK PowPeg Bridge for RBTC minting/burning operations
/// @dev This contract is required because RSKIP-502 only allows ONE contract address to be authorized
///      for minting and burning RBTC from the PowPeg bridge. Since PegManager is split into
///      PeginManager and PegoutManager, we need this intermediary to be the single authorized address.
interface IRbtcBridge {
    // ===================== Events =====================

    /// @notice Emitted when RBTC is minted and sent to a user
    /// @param to The address that received the RBTC
    /// @param amount The amount of RBTC minted in wei
    event RbtcMinted(address indexed to, uint256 amount);

    /// @notice Emitted when RBTC is burned back to the PowPeg bridge
    /// @param amount The amount of RBTC burned in wei
    event RbtcBurned(uint256 amount);

    // ===================== Errors =====================

    /// @notice Thrown when an unauthorized address attempts to call a restricted function
    /// @param caller The address that attempted the unauthorized call
    error UnauthorizedCaller(address caller);

    /// @notice Thrown when RBTC transfer to recipient fails
    /// @param to The intended recipient address
    /// @param amount The amount that failed to transfer
    error FailedToSendRBTC(address to, uint256 amount);

    /// @notice Thrown when the PowPeg bridge rejects the request due to unauthorized caller (error code -1)
    error BridgeUnauthorizedCaller();

    /// @notice Thrown when the requested amount exceeds the PowPeg bridge locking cap (error code -2)
    /// @param amount The amount that exceeded the cap
    error BridgeExceededLockingCap(uint256 amount);

    /// @notice Thrown when RBTC transfers are currently disabled in the PowPeg bridge (error code -3)
    error BridgeTransfersDisabled();

    /// @notice Thrown when the burn amount exceeds the previously minted amount (error code -2)
    /// @param amount The invalid burn amount
    error BridgeReleaseInvalidValue(uint256 amount);

    /// @notice Thrown when the PowPeg bridge returns an unknown error code
    /// @param errorCode The error code returned by the bridge
    error BridgeBtcUnknownError(int256 errorCode);

    /// @notice Thrown when the bridge address is set to zero during initialization
    error BridgeAddressZero();

    /// @notice Thrown when the peginManager address is set to zero during initialization
    error PeginManagerAddressZero();

    /// @notice Thrown when the pegoutManager address is set to zero during initialization
    error PegoutManagerAddressZero();

    // ===================== Functions =====================

    /// @notice Initializes the RbtcBridge contract
    /// @param _initialOwner The initial owner of the contract
    /// @param _bridge The RSK PowPeg Bridge contract address
    function initialize(address _initialOwner, address _bridge) external;

    /// @notice Sets the PeginManager contract address
    /// @param _peginManager The PeginManager contract address
    /// @dev Only callable by owner
    function setPeginManager(address _peginManager) external;

    /// @notice Sets the PegoutManager contract address
    /// @param _pegoutManager The PegoutManager contract address
    /// @dev Only callable by owner
    function setPegoutManager(address _pegoutManager) external;

    /// @notice Mints RBTC from the PowPeg bridge and sends it to the specified address
    /// @param _to The address to receive the minted RBTC
    /// @param _amount The amount of RBTC to mint in wei
    /// @dev Only callable by the peginManager
    /// @dev Requests RBTC from PowPeg bridge via requestUnionBridgeRbtc
    /// @dev Transfers RBTC to recipient with 100k gas limit
    function mintRbtc(address payable _to, uint256 _amount) external;

    /// @notice Burns RBTC back to the PowPeg bridge
    /// @dev Only callable by the pegoutManager
    /// @dev The pegoutManager must send the RBTC amount via msg.value
    /// @dev Returns RBTC to PowPeg bridge via releaseUnionBridgeRbtc
    function burnRbtc() external payable;

    /// @notice Gets the locking cap of the Union Bridge for RBTC minting operations
    /// @return The locking cap of the Union Bridge
    function getUnionBridgeLockingCap() external view returns (uint256);
}
