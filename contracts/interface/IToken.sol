// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;


interface IToken {
    function giveMintReward() external;

    function addUserLPAmount(address account, uint256 lpAmount) external;
}
