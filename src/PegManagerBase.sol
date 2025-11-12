// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {BaseProxy} from "./BaseProxy.sol";
import {Pausable} from "./Pausable.sol";
import {ProofValidator} from "./ProofValidator.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {IPegManagerBase} from "./interfaces/IPegManagerBase.sol";
import {IBitcoinManager} from "./interfaces/IBitcoinManager.sol";
import {IStreamManager} from "./interfaces/IStreamManager.sol";
import {ICommitteeRegistry} from "./interfaces/ICommitteeRegistry.sol";
import {ISignatureManager} from "./interfaces/ISignatureManager.sol";
import {IRbtcBridge} from "./interfaces/IRbtcBridge.sol";

/// @title PegManagerBase
/// @notice Abstract base contract for shared functionality between PeginManager and PegoutManager
/// @dev Contains common state variables, initialization logic, and setter functions
abstract contract PegManagerBase is IPegManagerBase, BaseProxy, ProofValidator, ReentrancyGuardUpgradeable, Pausable {
    /// @notice Bitcoin manager contract for Bitcoin transaction validation and address generation
    IBitcoinManager public bitcoinManager;

    /// @notice Stream manager contract for managing union bridge streams and slots
    IStreamManager public streamManager;

    /// @notice Committee registry contract for managing committee and members
    ICommitteeRegistry public committeeRegistry;

    /// @notice Signature manager contract for handling multi-signature operations
    ISignatureManager public signatureManager;

    /// @notice The RbtcBridge contract for minting RBTC
    IRbtcBridge public rbtcBridge;

    /// @notice Initializes the base PegManager contract
    /// @param _initialOwner The initial owner of the contract
    /// @param _bridgeAddress The address of the pow-peg bridge contract
    /// @param _committeeRegistry The committee registry contract address
    /// @param _bitcoinManager The Bitcoin manager contract address
    /// @dev This function should be called by child contracts during their initialization
    function __PegManagerBase_init(
        address _initialOwner,
        address payable _bridgeAddress,
        ICommitteeRegistry _committeeRegistry,
        IBitcoinManager _bitcoinManager,
        IRbtcBridge _rbtcBridge
    ) internal onlyInitializing {
        // Validate that the bitcoin manager is not zero address
        if (address(_bitcoinManager) == address(0)) {
            revert BitcoinManagerAddressZero();
        }
        bitcoinManager = _bitcoinManager;

        if (address(_committeeRegistry) == address(0)) {
            revert CommitteeRegistryAddressZero();
        }
        committeeRegistry = _committeeRegistry;

        if (address(_rbtcBridge) == address(0)) {
            revert RbtcBridgeAddressZero();
        }
        rbtcBridge = _rbtcBridge;

        __BaseProxy_init(_initialOwner);
        __ProofValidator_init(_bridgeAddress);
        __ReentrancyGuard_init();
        __Pauser_init();
    }

    /// @notice Sets the stream manager contract address
    /// @param _streamManager The stream manager contract address
    /// @dev Only callable by the contract owner
    function setStreamManager(IStreamManager _streamManager) external onlyOwner {
        if (address(_streamManager) == address(0)) {
            revert StreamManagerAddressZero();
        }
        streamManager = _streamManager;
        emit StreamManagerUpdated(_streamManager);
    }

    /// @notice Sets the signature manager contract address
    /// @param _signatureManager The signature manager contract address
    /// @dev Only callable by the contract owner
    function setSignatureManager(ISignatureManager _signatureManager) external onlyOwner {
        if (address(_signatureManager) == address(0)) {
            revert SignatureManagerAddressZero();
        }
        signatureManager = _signatureManager;
        emit SignatureManagerUpdated(_signatureManager);
    }

    /// @notice Sets a new pauser address
    /// @param _newPauser The new pauser address
    /// @dev Only callable by the contract owner
    function setPauser(address _newPauser) public override onlyOwner {
        super.setPauser(_newPauser);
    }
}
