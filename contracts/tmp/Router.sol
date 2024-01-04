// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

import "../interface/ISwapRouter.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


contract Router {

    // function addLiquidity(
    //     address tokenA,
    //     address tokenB,
    //     uint amountADesired,
    //     uint amountBDesired,
    //     uint amountAMin,
    //     uint amountBMin,
    //     address to,
    //     uint deadline
    // ) external returns (uint amountA, uint amountB, uint liquidity);


    // usdtAmount / 2,
    //         tokenAmount,
    //         0,
    //         0,
    //         lpReceiver,
    //         block.timestamp

    

    function addLiquidity(address _router,address _tokenA,address _tokenB) public  {
        IERC20(_tokenA).approve(_router, type(uint256).max);
        IERC20(_tokenB).approve(_router, type(uint256).max);
       ISwapRouter(_router).addLiquidity(
        _tokenA, 
        _tokenB,
        100000 * 1e18,
        1000000 * 1e18,
        0,
        0,
        msg.sender,
        block.timestamp);
    }
}