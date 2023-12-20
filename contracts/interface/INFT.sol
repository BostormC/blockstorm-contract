// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;


interface INFT {
    function addTokenReward(uint256 rewardAmount) external;

    function balanceOf(address owner) external view returns (uint256 balance);
}