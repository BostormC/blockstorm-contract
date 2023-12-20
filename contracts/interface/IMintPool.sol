// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;


interface IMintPool {
    function addTotalMintReward(uint256 reward) external;
    function getUserNFTLevel(address account) external view returns (uint256);
}