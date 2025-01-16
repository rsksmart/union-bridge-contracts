// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title Btc Helper
 * @notice Usefull functions for Bitcoin parsin/encoding/decoding
 * @author Fairgate
 */
library BtcHelper {
    function hash256(bytes memory _toHash) internal pure returns (bytes32) {
        return sha256(abi.encode(sha256(_toHash)));
    }
}
