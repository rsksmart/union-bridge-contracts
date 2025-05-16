// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {IStreamManager} from "./interfaces/IStreamManager.sol";

abstract contract SecurityBond {
    // Address of the Memeber => Amount provided
    mapping(address => uint256) public depositedSecurityBond;
    IStreamManager streamManager;

    event newSecurityBondDeposit(address indexed sender, uint64 indexed denomination, uint256 amount);
    event newSecurityBondWithdraw(address indexed sender, uint64 indexed denomination, uint256 amount);

    error despositBondTooLow(uint256 sent, uint256 minDeposit);
    error outOfBound(uint256 sent, uint256 max);
    error failToSend(address to, uint256 value);

    function setStreamManager(IStreamManager _streamManager) public {
        streamManager = _streamManager;
    }

    function getMinimumDeposit(uint64 _denomination) public view returns (uint256) {
        return streamManager.getStream(_denomination).securityBondValue;
    }

    function securityBondDeposit(uint64 _denomination) external payable {
        uint256 securityBondValue = getMinimumDeposit(_denomination);
        if (msg.value < securityBondValue) {
            revert despositBondTooLow(msg.value, securityBondValue);
        }
        if (msg.value > type(uint64).max) {
            revert outOfBound(msg.value, type(uint64).max);
        }

        depositedSecurityBond[msg.sender] = depositedSecurityBond[msg.sender] + msg.value;
        emit newSecurityBondDeposit(msg.sender, _denomination, msg.value);
    }

    function securityBondWithdraw(uint64 _denomination) external {
        // TODO should check that he is not part of the committee any more

        // TODO we are considering that he withdraws the minimum deposit
        // but he should be able to withdraw more if he deposited more
        uint256 securityBondValue = getMinimumDeposit(_denomination);

        depositedSecurityBond[msg.sender] = depositedSecurityBond[msg.sender] - securityBondValue;

        emit newSecurityBondWithdraw(msg.sender, _denomination, securityBondValue);

        // Call returns a boolean value indicating success or failure.
        (bool sent,) = msg.sender.call{value: securityBondValue}("");
        if (!sent) {
            revert failToSend(msg.sender, securityBondValue);
        }
    }
}
