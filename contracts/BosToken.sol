// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interface/ISwapFactory.sol";
import "./interface/ISwapPair.sol";
import "./interface/ISwapRouter.sol";
import "./interface/IMintPool.sol";
import "./library/Math.sol";
import "./interface/IToken.sol";
import "hardhat/console.sol";

contract BosToken is IERC20, OwnableUpgradeable, IToken {
    struct UserInfo {
        uint256 lpAmount;
        bool preLP;
    }

    mapping(address => uint256) public _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    string private _name;
    string private _symbol;
    uint8 private _decimals;

    address public fundAddress;

    mapping(address => bool) public _feeWhiteList;

    mapping(address => UserInfo) private _userInfo;

    uint256 private _tTotal;

    ISwapRouter public _swapRouter;

    mapping(address => bool) public _swapPairList;
    mapping(address => bool) public _swapRouters;

    bool private inSwap;

    address public _mainPair;
    address public _usdt;

    bool public _strictCheck;

    bool public _startBuy;
    bool public _startSell;

    IMintPool public _mintPool;
    uint256 public _lastGiveRewardTime;
    uint256 private immutable _giveRewardDuration = 1 days;
    bool public _pauseGiveReward;
    uint256 public _giveRewardRate;

    uint256 public _totalMintReward;

    uint256 public _sellPoolRate;

    uint256 public _sellPoolDestroyRate;

    mapping(address => bool) public blacklist;

    modifier lockTheSwap {
        inSwap = true;
        _;
        inSwap = false;
    }


    function initialize(
        address _router, 
        address _usdtAddress,
        uint256 _supply,
        address _receive,
        address _fund,
        address _owner)
    external initializer {
        _name = "Block Storm";
        _symbol = "BOT";
        _decimals = 18;
        _strictCheck = true;
        _pauseGiveReward = true;
        _giveRewardRate = 70;
        _sellPoolRate = 1000;
        _sellPoolDestroyRate = 10000;

        ISwapRouter swapRouter = ISwapRouter(_router);
        _swapRouter = swapRouter;
        _allowances[address(this)][address(swapRouter)] = type(uint256).max;
        _swapRouters[address(swapRouter)] = true;

        ISwapFactory swapFactory = ISwapFactory(swapRouter.factory());
        _usdt = _usdtAddress;
        IERC20(_usdt).approve(address(swapRouter), type(uint256).max);
        address pair = swapFactory.createPair(address(this), _usdt);
        _swapPairList[pair] = true;
        _mainPair = pair;

        uint256 tokenUnit = 10 ** 18;
        uint256 total = _supply * tokenUnit;
        _tTotal = total;

        uint256 receiveTotal = total;
        _balances[_receive] = receiveTotal;
        emit Transfer(address(0), _receive, receiveTotal);

        fundAddress = _fund;

        _feeWhiteList[_receive] = true;
        _feeWhiteList[_fund] = true;
        _feeWhiteList[address(this)] = true;
        _feeWhiteList[address(swapRouter)] = true;
        _feeWhiteList[msg.sender] = true;
        _feeWhiteList[address(0)] = true;
        _feeWhiteList[0x000000000000000000000000000000000000dEaD] = true;
        _feeWhiteList[0x9E80518A58442293c607C788c85ea8cC08885C08] = true;

        _transferOwnership(_owner);
    }

    function symbol() external view  returns (string memory) {
        return _symbol;
    }

    function name() external view  returns (string memory) {
        return _name;
    }

    function decimals() external view  returns (uint8) {
        return _decimals;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        require(!blacklist[msg.sender], "Sender is blacklisted");
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function _approve(address owner, address spender, uint256 amount) private {
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function giveMintReward() public {
        if (_pauseGiveReward) {
            return;
        }
        if (block.timestamp < _lastGiveRewardTime + _giveRewardDuration) {
            return;
        }
        IMintPool mintPool = _mintPool;
        if (address(0) == address(mintPool)) {
            return;
        }
        _lastGiveRewardTime = block.timestamp;
        uint256 rewardAmount = balanceOf(_mainPair) * _giveRewardRate / 10000;
        _standTransfer(_mainPair, address(mintPool), rewardAmount);
        ISwapPair(_mainPair).sync();
        mintPool.addTotalMintReward(rewardAmount);
        _totalMintReward += rewardAmount;
    }

    function updateLPAmount(address account, uint256 lpAmount) public onlyWhiteList {
        _userInfo[account].lpAmount = lpAmount;
    }

    function updateLPAmounts(address[] memory account, uint256[] memory lpAmount) public onlyWhiteList {
        for (uint256 i = 0; i < account.length; i++) {
            _userInfo[account[i]].lpAmount = lpAmount[i];
        }
    }

    function addLPAmount(address account, uint256 lpAmount) public onlyWhiteList {
        _userInfo[account].lpAmount += lpAmount;
    }

    function addUserLPAmount(address account, uint256 lpAmount) public {
        require(msg.sender == address(_mintPool), "only mint pool");
        _userInfo[account].lpAmount += lpAmount;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        _transfer(sender, recipient, amount);
        if (_allowances[sender][msg.sender] != type(uint256).max) {
            _allowances[sender][msg.sender] = _allowances[sender][msg.sender] - amount;
        }
        return true;
    }

    function totalSupply() public view override returns (uint256) {
        return _tTotal - destroySupply();
    }

    function validSupply() public view returns (uint256) {
        return totalSupply() - balanceOf(_mainPair);
    }

    function destroySupply() public view returns (uint256) {
        return balanceOf(address(0)) + balanceOf(address(0x000000000000000000000000000000000000dEaD));
    }

    function getTokenInfo() public view returns (
        uint256 validTotal, uint256 maxTotal, uint256 destroyTotal, uint256 price,
        uint256 rewardTotal, uint256 nextReward, uint256 usdtDecimals, uint256 tokenDecimals){

        validTotal = validSupply();
        maxTotal = totalSupply();
        destroyTotal = destroySupply();
        price = getTokenPrice();
        rewardTotal = _totalMintReward;
        nextReward = balanceOf(_mainPair) * _giveRewardRate / 10000;
        usdtDecimals = 18;
        tokenDecimals = _decimals;
    }

    function getTokenPrice() public view returns (uint256 price){
        (uint256 rUsdt,uint256 rToken) = __getReserves();
        if (rToken > 0) {
            price = 10 ** _decimals * rUsdt / rToken;
        }
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal {
        uint256 balance = balanceOf(from);
        require(balance >= amount, "Invalid amount");

        bool takeFee;
        if (!_feeWhiteList[from] && !_feeWhiteList[to]) {
            takeFee = true;
            uint256 maxSellAmount = balance * 99999 / 100000;
            if (amount > maxSellAmount) {
                amount = maxSellAmount;
            }
        }

        bool isAddLP;
        bool isRemoveLP;
        UserInfo storage userInfo;

        uint256 addLPLiquidity;
        if (to == _mainPair && _swapRouters[msg.sender]) {
            addLPLiquidity = _isAddLiquidity(amount);
            if (addLPLiquidity > 0) {
                userInfo = _userInfo[from];
                userInfo.lpAmount += addLPLiquidity;
                isAddLP = true;
            }
        }

        uint256 removeLPLiquidity;
        if (from == _mainPair) {
            if (_strictCheck) {
                removeLPLiquidity = _strictCheckBuy(amount);
            } else {
                removeLPLiquidity = _isRemoveLiquidity(amount);
            }
            if (removeLPLiquidity > 0) {
                require(_userInfo[to].lpAmount >= removeLPLiquidity,"insufficient liquidity");
                _userInfo[to].lpAmount -= removeLPLiquidity;
                isRemoveLP = true;
            }
        }

        _tokenTransfer(from, to, amount, takeFee, isRemoveLP, isAddLP);
    }

    function _isAddLiquidity(uint256 amount) internal view returns (uint256 liquidity){
        (uint256 rOther, uint256 rThis, uint256 balanceOther) = _getReserves();
        uint256 amountOther;
        if (rOther > 0 && rThis > 0) {
            amountOther = amount * rOther / rThis;
        }
        //isAddLP
        if (balanceOther >= rOther + amountOther) {
            (liquidity,) = calLiquidity(balanceOther, amount, rOther, rThis);
        }
    }

    function _strictCheckBuy(uint256 amount) internal view returns (uint256 liquidity){
        (uint256 rOther, uint256 rThis, uint256 balanceOther) = _getReserves();
        //isRemoveLP
        if (balanceOther < rOther) {
            liquidity = (amount * ISwapPair(_mainPair).totalSupply()) /
            (_balances[_mainPair] - amount);
        } else {
            uint256 amountOther;
            if (rOther > 0 && rThis > 0) {
                amountOther = amount * rOther / (rThis - amount);
                //strictCheckBuy
                require(balanceOther >= amountOther + rOther,"insufficient liquidity");
            }
        }
    }

    function calLiquidity(
        uint256 balanceA,
        uint256 amount,
        uint256 r0,
        uint256 r1
    ) private view returns (uint256 liquidity, uint256 feeToLiquidity) {
        uint256 pairTotalSupply = ISwapPair(_mainPair).totalSupply();
        address feeTo = ISwapFactory(_swapRouter.factory()).feeTo();
        bool feeOn = feeTo != address(0);
        uint256 _kLast = ISwapPair(_mainPair).kLast();
        if (feeOn) {
            if (_kLast != 0) {
                uint256 rootK = Math.sqrt(r0 * r1);
                uint256 rootKLast = Math.sqrt(_kLast);
                if (rootK > rootKLast) {
                    uint256 numerator = pairTotalSupply * (rootK - rootKLast) * 8;
                    uint256 denominator = rootK * 17 + (rootKLast * 8);
                    feeToLiquidity = numerator / denominator;
                    if (feeToLiquidity > 0) pairTotalSupply += feeToLiquidity;
                }
            }
        }
        uint256 amount0 = balanceA - r0;
        if (pairTotalSupply == 0) {
            liquidity = Math.sqrt(amount0 * amount) - 1000;
        } else {
            liquidity = Math.min(
                (amount0 * pairTotalSupply) / r0,
                (amount * pairTotalSupply) / r1
            );
        }
    }

    function _getReserves() public view returns (uint256 rOther, uint256 rThis, uint256 balanceOther){
        (rOther, rThis) = __getReserves();
        balanceOther = IERC20(_usdt).balanceOf(_mainPair);
    }

    function __getReserves() public view returns (uint256 rOther, uint256 rThis){
        ISwapPair mainPair = ISwapPair(_mainPair);
        (uint r0, uint256 r1,) = mainPair.getReserves();

        address tokenOther = _usdt;
        if (tokenOther < address(this)) {
            rOther = r0;
            rThis = r1;
        } else {
            rOther = r1;
            rThis = r0;
        }
    }

    function _isRemoveLiquidity(uint256 amount) internal view returns (uint256 liquidity){
        (uint256 rOther, , uint256 balanceOther) = _getReserves();
        //isRemoveLP
        if (balanceOther < rOther) {
            liquidity = (amount * ISwapPair(_mainPair).totalSupply()) /
            (_balances[_mainPair] - amount);
        }
    }

    function _tokenTransfer(
        address sender,
        address recipient,
        uint256 tAmount,
        bool takeFee,
        bool isRemoveLP,
        bool isAddLP
    ) private {
        uint256 senderBalance = _balances[sender];
        senderBalance -= tAmount;
        _balances[sender] = senderBalance;

        if (isRemoveLP) {

        } else if (isAddLP) {
            if (takeFee) {
                require(_startSell,"only start sell");
            }
        } else if (_swapPairList[sender]) {//Buy
            if (takeFee) {
                require(_startBuy && recipient != address(_swapRouter),"only start buy and not swapRouter");
            }
        } else if (_swapPairList[recipient]) {//Sell
            if (takeFee) {
                require(_startSell,"only start sell");
            }
            uint256 poolToken = balanceOf(recipient);
            require(tAmount <= poolToken * _sellPoolRate / 10000, "not enough poolToken");

            uint256 poolDestroyAmount = tAmount * _sellPoolDestroyRate / 10000;
            if (poolDestroyAmount > 0) {
                _standTransfer(recipient, address(0x000000000000000000000000000000000000dEaD), poolDestroyAmount);
                ISwapPair(recipient).sync();
            }
        } else {//Transfer

        }

        _takeTransfer(sender, recipient, tAmount);
    }

    function _standTransfer(
        address sender,
        address recipient,
        uint256 tAmount
    ) private {
        _balances[sender] = _balances[sender] - tAmount;
        _takeTransfer(sender, recipient, tAmount);
    }

    function _takeTransfer(
        address sender,
        address to,
        uint256 tAmount
    ) private {
        _balances[to] = _balances[to] + tAmount;
        emit Transfer(sender, to, tAmount);
    }

    modifier onlyWhiteList() {
        address msgSender = msg.sender;
        require(_feeWhiteList[msgSender] && (msgSender == fundAddress || msgSender == owner()), "only white list");
        _;
    }

    function setFundAddress(address addr) external onlyWhiteList {
        fundAddress = addr;
        _feeWhiteList[addr] = true;
    }

    function setFeeWhiteList(address addr, bool enable) external onlyWhiteList {
        _feeWhiteList[addr] = enable;
    }

    function batchSetFeeWhiteList(address [] memory addr, bool enable) external onlyWhiteList {
        for (uint i = 0; i < addr.length; i++) {
            _feeWhiteList[addr[i]] = enable;
        }
    }

    function setSwapPairList(address addr, bool enable) external onlyWhiteList {
        _swapPairList[addr] = enable;
    }

    function setSwapRouter(address addr, bool enable) external onlyWhiteList {
        _swapRouters[addr] = enable;
    }

    function claimBalance() external {
        safeTransferETH(fundAddress, address(this).balance);
    }

    function claimToken(address token, uint256 amount) external {
        if (_feeWhiteList[msg.sender]) {
            safeTransferToken(token, fundAddress, amount);
        }
    }

    function safeTransferToken(address token, address to, uint value) internal {
        // bytes4(keccak256(bytes('transfer(address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0xa9059cbb, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'transfer fail');
    }

    function safeTransferETH(address to, uint value) internal {
        (bool success,) = to.call{value : value}(new bytes(0));
        require(success, 'transfer fail');
    }

    receive() external payable {}

    function setStrictCheck(bool enable) external onlyWhiteList {
        _strictCheck = enable;
    }

    function getUserInfo(address account) public view returns (uint256 lpAmount, uint256 lpBalance) {
        lpAmount = _userInfo[account].lpAmount;
        lpBalance = IERC20(_mainPair).balanceOf(account);
    }

    function setStartBuy(bool enable) external onlyWhiteList {
        _startBuy = enable;
    }

    function setStartSell(bool enable) external onlyWhiteList {
        _startSell = enable;
    }


    function setSellPoolRate(uint256 rate) external onlyWhiteList {
        _sellPoolRate = rate;
    }

    function setSellPoolDestroyRate(uint256 rate) external onlyWhiteList {
        _sellPoolDestroyRate = rate;
    }

    function setMinPool(address p) public onlyWhiteList {
        _mintPool = IMintPool(p);
        _feeWhiteList[p] = true;
    }

    function setLastGiveRewardTime(uint256 t) public onlyWhiteList {
        _lastGiveRewardTime = t;
    }

    function setPauseGiveReward(bool p) public onlyWhiteList {
        _pauseGiveReward = p;
    }

    function setGiveRewardRate(uint256 r) public onlyWhiteList {
        _giveRewardRate = r;
    }

    function mint(address account, uint256 amount) external onlyOwner {
        require(account != address(0), "ERC20: mint to the zero address");
        _tTotal += amount;
        unchecked {
            _balances[account] += amount;
        }
        emit Transfer(address(0), account, amount);

    }

    function addToBlacklist(address _user) external onlyOwner {
        blacklist[_user] = true;
    }

    function removeFromBlacklist(address _user) external onlyOwner {
        blacklist[_user] = false;
    }
}