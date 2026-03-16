// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {OperatorTakeManager} from "src/OperatorTakeManager.sol";
import {ICommitteeRegistry} from "src/interfaces/ICommitteeRegistry.sol";
import {IBitcoinManager} from "src/interfaces/IBitcoinManager.sol";
import {IRbtcBridge} from "src/interfaces/IRbtcBridge.sol";
import {IPegoutManager} from "src/interfaces/IPegoutManager.sol";
import {IStreamManager} from "src/interfaces/IStreamManager.sol";
import {ISignatureManager} from "src/interfaces/ISignatureManager.sol";
import {TakeTimeout} from "src/interfaces/IOperatorTakeManager.sol";

/// @title OperatorTakeManagerHarness
/// @notice Test harness for OperatorTakeManager to allow setting pegoutId for BitVMX compatibility testing
contract OperatorTakeManagerHarness is OperatorTakeManager {
    function initialize(
        address _initialOwner,
        address _accessManager,
        ICommitteeRegistry _committeeRegistry,
        IBitcoinManager _bitcoinManager,
        IRbtcBridge _rbtcBridge,
        IPegoutManager _pegoutManager,
        IStreamManager _streamManager,
        ISignatureManager _signatureManager,
        TakeTimeout[] memory _takeTimeouts
    ) public override initializer {
        OperatorTakeManager.initialize(
            _initialOwner,
            _accessManager,
            _committeeRegistry,
            _bitcoinManager,
            _rbtcBridge,
            _pegoutManager,
            _streamManager,
            _signatureManager,
            _takeTimeouts
        );
    }

    /// @notice Sets the pegoutId for an operator take (test harness only)
    /// @dev Used to simulate BitVMX's pegoutId=0 which our _generatePegoutId cannot naturally produce
    /// @param _acceptPeginTxid The accept peg-in transaction id
    /// @param _pegoutId The pegout id to set
    function setOperatorTakePegoutIdHarness(bytes32 _acceptPeginTxid, bytes32 _pegoutId) external {
        operatorTakeInfo[_acceptPeginTxid].pegoutId = _pegoutId;
    }
}
