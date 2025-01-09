// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.19;

import "./IStreamManager.sol";

contract SecurityBond {
    // Address of the Memeber => Amount provided
    mapping(address => uint256) public depositedSecurityBond;
    IStreamManager streamManager;

    event newSecurityBondDeposit(address indexed sender, uint64 indexed denomination, uint256 amount);
    event newSecurityBondWithdraw(address indexed sender, uint64 indexed denomination, uint256 amount);

    error despositBondTooLow(uint256 sent, uint64 minDeposit);
    error outOfBound(uint256 sent, uint256 max);
    error failToSend(address to, uint256 value);

    constructor(IStreamManager _streamManager) {
        streamManager = _streamManager;
    }

    function getMinimumDeposit(uint64 denomination) public view returns (uint64) {
        return streamManager.getStream(denomination).securityBondValue;
    }

    function securityBondDeposit(uint64 denomination) external payable {
        uint64 securityBondValue = getMinimumDeposit(denomination);
        if (msg.value < securityBondValue) {
            revert despositBondTooLow(msg.value, securityBondValue);
        }
        if (msg.value > type(uint64).max) {
            revert outOfBound(msg.value, type(uint64).max);
        }

        depositedSecurityBond[msg.sender] = depositedSecurityBond[msg.sender] + msg.value;
        emit newSecurityBondDeposit(msg.sender, denomination, msg.value);
    }

    function securityBondWithdraw(uint64 denomination) external {
        // TODO should check that he is not part of the comittee any more

        // TODO we are considering that he withdraws the minimum deposit
        // but he should be able to withdraw more if he deposited more
        uint64 securityBondValue = getMinimumDeposit(denomination);

        depositedSecurityBond[msg.sender] = depositedSecurityBond[msg.sender] - securityBondValue;

        // Call returns a boolean value indicating success or failure.
        (bool sent,) = msg.sender.call{value: securityBondValue}("");
        if (!sent) {
            revert failToSend(msg.sender, securityBondValue);
        }

        emit newSecurityBondWithdraw(msg.sender, denomination, securityBondValue);
    }
}
