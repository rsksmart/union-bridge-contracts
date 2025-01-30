// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BtcHelper} from "./BtcHelper.sol";
import {BtcTransaction, BtcTxIn, BtcTxOut} from "../interfaces/IBitcoinManager.sol";

/**
 * @title Bitcoin Transaction Parser
 * @notice Allows to encode / decode Bitcoin hex transactions
 * @author Fairgate
 */
library BtcTxParser {
    function encodeTxIn(bytes32 _txId, uint32 _vout, uint32 _sequence, bytes memory _scriptSig)
        internal
        pure
        returns (bytes memory)
    {
        // See struct values https://learnmeabitcoin.com/technical/transaction/#structure-input-count
        // See hex format https://learnmeabitcoin.com/technical/transaction/wtxid/#segwit
        return abi.encodePacked(
            BtcHelper.reverseBytes32(_txId), // txId needs to be converted to little Endian
            BtcHelper.reverseUint32(_vout), // vout needs to be converted to little Endian
            BtcHelper.toCompactSize(_scriptSig.length), // scriptSigSize is compact-_size
            _scriptSig, // scriptSig should be empty for non-legacy transactions
            BtcHelper.reverseUint32(_sequence) // sequence needs to be converted to little Endian
        );
    }

    /// @dev Convert TxInputs to raw vin hex using Bitcoin format
    function encodeTxInputs(BtcTxIn[] memory _inputs) internal pure returns (bytes memory) {
        // [inputs count]
        // [txid0][vout0][script sig _size 0][script sig 0][sequence0]
        // [txid1][vout1][script sig _size 1][script sig 1][sequence1]...
        bytes memory hexInputs = BtcHelper.toCompactSize(_inputs.length);
        for (uint64 i = 0; i < _inputs.length; i++) {
            hexInputs = abi.encodePacked(
                hexInputs, encodeTxIn(_inputs[i].txId, _inputs[i].vout, _inputs[i].sequence, _inputs[i].scriptSig)
            );
        }
        return hexInputs;
    }

    function encodeTxOut(uint64 _amount, bytes memory _scriptPubKey) internal pure returns (bytes memory) {
        // See struct values https://learnmeabitcoin.com/technical/transaction/#structure-outputs
        // See hex format https://learnmeabitcoin.com/technical/transaction/wtxid/#segwit
        return abi.encodePacked(
            BtcHelper.reverseUint64(_amount), // amount needs to be converted to little Endian
            BtcHelper.toCompactSize(_scriptPubKey.length), // scriptPubKeySize is compact-_size
            _scriptPubKey
        );
    }

    /// @dev Convert TxOutputs to raw vout hex using Bitcoin format
    function encodeTxOutputs(BtcTxOut[] memory _outputs) internal pure returns (bytes memory) {
        // [output count]
        // [amount0][script pubkey _size 0][script pubkey 0]
        // [amount1][script pubkey _size 1][script pubkey 1]...
        bytes memory hexOutputs = BtcHelper.toCompactSize(_outputs.length);
        for (uint64 i = 0; i < _outputs.length; i++) {
            hexOutputs = abi.encodePacked(hexOutputs, encodeTxOut(_outputs[i].amount, _outputs[i].scriptPubKey));
        }
        return hexOutputs;
    }

    /// @dev Convert Tx to raw tx hex using Bitcoin format for getting the tx hash
    /// https://learnmeabitcoin.com/technical/transaction/#structure
    function encodeTx(BtcTransaction memory _btcTx) internal pure returns (bytes memory) {
        // [version][inputs][outputs][locktime]
        return abi.encodePacked(
            BtcHelper.reverseUint32(_btcTx.version), // version needs to be converted to little Endian
            encodeTxInputs(_btcTx.inputs),
            encodeTxOutputs(_btcTx.outputs),
            BtcHelper.reverseUint32(_btcTx.locktime) // locktime needs to be converted to little Endian
        );
    }
}
