// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {IStreamManager, StreamDenomination} from "./interfaces/IStreamManager.sol";
import {Member, Role, Balance} from "./interfaces/ICommitteeRegistry.sol";

abstract contract SecurityBond {
    IStreamManager streamManager;

    error despositBondTooLow(uint256 sent, uint256 minDeposit);

    function setStreamManager(IStreamManager _streamManager) public {
        streamManager = _streamManager;
    }

    function getMinimumDeposit(uint64 _denomination) public view returns (uint256) {
        return streamManager.getStream(_denomination).securityBondValue;
    }

    function getMinimumDepositById(StreamDenomination _denomination) public view returns (uint256) {
        return streamManager.getStreamById(uint8(_denomination)).securityBondValue;
    }

    function _initMemberBalance(Member storage _member) internal {
        uint64 streams = streamManager.getStreamsLength();
        _member.balance.available = 0;
        _member.balance.preStaked = new uint256[](streams);
        for (uint64 i = 0; i < streams; i++) {
            _member.balance.preStaked[i] = 0;
        }
        for (uint256 i = 0; i < streams; i++) {
            _member.balance.staked.push();
        }
    }
}
