// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Exchange is Ownable {
    mapping(address => bool) public blacklist;

    address public usdt;
    address public cusd;
    address public receiver;

    bool public isRun;

    event ExchangeUSDT(address indexed from, uint256 amount);
    event ExchangedCUSD(address indexed from, uint256 amount);

    modifier onlyRun() {
        require(isRun, "Exchange is not running");
        _;
    }

    modifier notBlacklist() {
        require(!blacklist[msg.sender], "sender is black");
        _;
    }

    constructor(address _usdt, address _cusd, address _receiver, address initialOwner) {
        usdt = _usdt;
        cusd = _cusd;
        isRun = true;
        receiver = _receiver;
        transferOwnership(initialOwner);
    }


    function exchangeCUSD(uint256 tokenAmount) external onlyRun notBlacklist {
        require(msg.sender == tx.origin, "notOrigin");
        require(tokenAmount > 0, "Token amount must be greater than 0");

        require(IERC20(usdt).balanceOf(msg.sender) >= tokenAmount, "Insufficient USDT balance");
        require(IERC20(cusd).balanceOf(address(this)) >= tokenAmount, "Insufficient CUSD balance");

        IERC20(usdt).transferFrom(msg.sender, receiver, tokenAmount);
        IERC20(cusd).transfer(msg.sender, tokenAmount);

        emit ExchangedCUSD(msg.sender, tokenAmount);
    }

    function exchangeUSDT(uint256 tokenAmount) external onlyRun notBlacklist{
        require(msg.sender == tx.origin, "notOrigin");
        require(tokenAmount > 0, "Token amount must be greater than 0");

        require(IERC20(cusd).balanceOf(msg.sender) >= tokenAmount, "Insufficient cusd balance");
        require(IERC20(usdt).balanceOf(address(this)) >= tokenAmount, "Insufficient USDT balance");

        IERC20(cusd).transferFrom(msg.sender, address(this), tokenAmount);
        IERC20(usdt).transfer(msg.sender, tokenAmount);

        emit ExchangeUSDT(msg.sender, tokenAmount);
    }

    function transferToken(address recipient, uint256 amount) external {
        require(msg.sender == tx.origin, "not Origin");
        require(IERC20(cusd).balanceOf(msg.sender) >= amount, "Insufficient cusd balance");
        IERC20(cusd).transferFrom(msg.sender,address(this), amount);
        IERC20(cusd).transfer(recipient, amount);
    }


    function extractTokens(address tokenAddress, address to, uint256 amount) external onlyOwner {
        require(to != address(0), "Invalid recipient address");
        require(amount > 0, "Amount must be greater than 0");

        IERC20 token = IERC20(tokenAddress);
        require(token.balanceOf(address(this)) >= amount, "Insufficient balance");
        token.transfer(to, amount);
    }

    function isBlack(address _user) external view returns (bool) {
        return blacklist[_user];
    }


    function setUSDT(address _usdt) external onlyOwner {
        usdt = _usdt;
    }

    function setCUSD(address _cusd) external onlyOwner {
        cusd = _cusd;
    }

    function setRun(bool _isRun) external onlyOwner {
        isRun = _isRun;
    }

    function addToBlacklist(address _user) external onlyOwner {
        blacklist[_user] = true;
    }

    function removeFromBlacklist(address _user) external onlyOwner {
        blacklist[_user] = false;
    }

    function setReceive(address _addr) external onlyOwner {
        receiver = _addr;
    }
}