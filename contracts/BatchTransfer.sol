// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


contract BatchTransfer{

    function BatchTranserToken(
        address payable[] memory _users,
        uint256[] memory _amounts,
        address _coinAddr
    )
    public
    returns(bool res, uint256 sucessNum)
    {
        require(_users.length == _amounts.length,"not same length");
        uint256 balance = IERC20(_coinAddr).balanceOf(msg.sender);
        uint256 allowBalance = IERC20(_coinAddr).allowance(msg.sender,address(this));

        for(uint8 i = 0; i < _users.length; i++){
            require(_users[i] != address(0),"address is zero");
            require(balance >= _amounts[i] && allowBalance >= _amounts[i],"not enough balance");
            balance = balance - _amounts[i];
            allowBalance = allowBalance - _amounts[i];
            require(IERC20(_coinAddr).transferFrom(msg.sender,_users[i],_amounts[i]) == true,"transferFrom error");

            sucessNum++;
        }
        res = true;
    }

    function BatchTransferMain (
        address payable[] memory _users,
        uint256[] memory _amounts
    )
    public
    payable
    returns(bool res, uint256 sucessNum)
    {
        uint256 balance = msg.value;
        require(_users.length == _amounts.length, "not same length");
        for (uint8 i = 0; i < _users.length; i++) {
            require(_users[i] != address(0),"address is zero");
            address payable user = _users[i];
            uint256 amount = _amounts[i];
            require(amount <= balance, "not have amount");
            balance -= amount;
            user.transfer(amount);

            sucessNum++ ;
        }
        if (balance > 0)
            payable(msg.sender).transfer(balance);

        res = true;
    }
}
