// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import "./interface/INFT.sol";
import "./interface/ISwapRouter.sol";
import "./interface/ISwapFactory.sol";
import "./interface/ISwapPair.sol";
import "./interface/IToken.sol";
import "hardhat/console.sol";


contract MintPool is Ownable, Initializable {
    struct UserInfo {
        bool isActive;
        uint256 amount;
        uint256 rewardMintDebt;
        uint256 calMintReward;
    }

    struct PoolInfo {
        uint256 totalAmount;
        uint256 accMintPerShare;
        uint256 accMintReward;
        uint256 mintPerSec;
        uint256 lastMintTime;
        uint256 totalMintReward;
    }

    struct UserLPInfo {
        uint256 lockAmount;
        uint256 calAmount;
        uint256 claimedAmount;
        uint256 lastReleaseTime;
        uint256 releaseInitAmount;
        uint256 releaseDuration;
        uint256 speedUpTime;
    }

    PoolInfo public poolInfo;
    mapping(address => UserInfo) public userInfo;
    mapping(address => UserLPInfo) public _userLPInfo;

    ISwapRouter private _swapRouter;
    address private _usdt;
    uint256 private _minAmount;
    address private _mintRewardToken;
    address public  _lp;
    INFT public _nft;

    mapping(address => address) public _invitor;
    mapping(address => address[]) public _binder;
    mapping(uint256 => uint256) public _inviteFee;
    uint256 private immutable _inviteLen = 3;
    address private _defaultInvitor;

    mapping(address => uint256) public _inviteAmount;
    mapping(address => uint256) public _teamAmount;
    mapping(address => uint256) public _teamNum;

    bool public _pauseSell;
    uint256 public _sellSelfRate;
    uint256 public _sellJoinRate;
    uint256 public _sellNFTRate;
    address public _sellLPReceiver;
    mapping(address => uint256) private _sellJoinAmount;
    address public _fundAddress;

    mapping(address => address[]) public referrals;
    mapping(address => address) public superAccount;
    mapping(address => uint256) public referralAmount;
    mapping(address => uint256) public depositAmount;
    mapping(address => uint256) public referralReward;
    mapping(address => uint256) public userLevel;

    uint256 public immutable v1Amount = 2500 ether;
    uint256 public immutable v2Amount = 20000 ether;
    uint256 public immutable v3Amount = 50000 ether;
    uint256 public immutable v4Amount = 150000 ether;
    uint256 public immutable v5Amount = 500000 ether;

    bool private _pauseJoin;
    uint256 public _lastDailyUpTime;
    uint256 public _lastAmountRate;
    uint256 public _amountDailyUp;
    uint256 private immutable _divFactor = 10000;
    uint256 private immutable _dailyDuration = 1 days;

    uint256 public _lpReleaseDuration;
    //
    uint256 private _speedUpCost;
    uint256 public _speedUpDuration;
    address public _speedUpReceiver;
    uint256 private _speedUpMaxTime;
    uint256 private _totalUsdt;

    mapping(address => bool) public _inProject;
    uint256 private _lastDailyReward;


    event nftTokenReward(address indexed account, uint256 indexed level, uint256 indexed tokenAmount);
    event nftPowerReward(address indexed account, uint256 indexed level, uint256 indexed powerAmount);
    event Deposit(address indexed account, uint256 indexed amount);
    event Sell(address indexed account, uint256 indexed tokenAmount, uint256 indexed selfAmount);


    // ******** modifier *********

    modifier onlyWhiteList() {
        require(
            msg.sender == _fundAddress ||
            msg.sender == owner() ||
            msg.sender == address(_nft),
            "only white list"
        );
        _;
    }

    modifier onlyInProject() {
        require(_inProject[msg.sender] || msg.sender == owner(), "only project");
        _;
    }


    // ******** constructor *********
    function initialize(
        address swapRouter,
        address usdt,
        address mintRewardToken,
        address nft,
        address defaultInvitor,
        address fundAddress,
        address _owner
    ) external initializer {
        _pauseJoin = true;
        _swapRouter = ISwapRouter(swapRouter);
        _usdt = usdt;
        _minAmount = 10 ether;
        _nft = INFT(nft);
        _mintRewardToken = mintRewardToken;

        _lp = ISwapFactory(_swapRouter.factory()).getPair(usdt, mintRewardToken);

        poolInfo.lastMintTime = block.timestamp;
        _defaultInvitor = defaultInvitor;
        userInfo[defaultInvitor].isActive = true;

        _inviteFee[0] = 800;
        // 8%
        _inviteFee[1] = 500;
        // 5%
        _inviteFee[2] = 300;
        // 3%

        _speedUpCost = 300 ether;

        safeApprove(usdt, swapRouter, ~uint256(0));
        safeApprove(mintRewardToken, swapRouter, ~uint256(0));
        _sellLPReceiver = fundAddress;
        _fundAddress = fundAddress;
        _speedUpMaxTime = 3;
        _speedUpReceiver = 0x000000000000000000000000000000000000dEaD;

        _sellSelfRate = 5000;
        _sellJoinRate = 4000;
        _sellNFTRate = 500;

        _lastAmountRate = 10000;
        _amountDailyUp = 10100;
        _lpReleaseDuration = 90 days;
        _speedUpDuration = 10 days;

        _transferOwnership(_owner);
    }

    receive() external payable {}


    //         ******** public *********
    function sell(uint256 tokenAmount) public {
        require(msg.sender == tx.origin, "not Origin");
        require(!_pauseSell, "pause");

        _bindInvitor(msg.sender, _defaultInvitor);
        _takeToken(_mintRewardToken, msg.sender, address(this), tokenAmount);

        IERC20 USDT = IERC20(_usdt);
        uint256 usdtBalanceBefore = USDT.balanceOf(address(this));

        address[] memory path = new address[](2);
        path[0] = _mintRewardToken;
        path[1] = _usdt;

        _swapRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            address(this),
            block.timestamp
        );

        uint256 usdtAmount = USDT.balanceOf(address(this)) - usdtBalanceBefore;
        uint256 selfUsdt = (usdtAmount * _sellSelfRate) / 10000;
        _giveToken(_usdt, msg.sender, selfUsdt);

        uint256 sellJoinUsdt = (usdtAmount * _sellJoinRate) / 10000;
        addLP(msg.sender, sellJoinUsdt, 0, false);

        _updatePool();
        uint256 sellJoinAmount = (sellJoinUsdt * _lastAmountRate) / _divFactor;
        _addUserAmount(msg.sender, sellJoinAmount, false);
        _sellJoinAmount[msg.sender] += sellJoinAmount;

        uint256 nftUsdt = (usdtAmount * _sellNFTRate) / 10000;
        _giveToken(_usdt, address(_nft), nftUsdt);
        _nft.addTokenReward(nftUsdt);

        uint256 fundUsdt = usdtAmount - selfUsdt - sellJoinUsdt - nftUsdt;
        _giveToken(_usdt, _fundAddress, fundUsdt);

        IToken(_mintRewardToken).giveMintReward();

        emit Sell(msg.sender, tokenAmount, selfUsdt);
    }


    function deposit(uint256 amount, uint256 minTokenAmount, address invitor) external {
        require(!_pauseJoin, "deposit pause");
        require(amount >= _minAmount, "deposit too low");

        address account = msg.sender;
        require(account == msg.sender, "deposit not origin");

        _totalUsdt += amount;

        _bindInvitor(account, invitor);

        _takeToken(_usdt, account, address(this), amount);

        addLP(account, amount, minTokenAmount, true);

        _updatePool();

        _addUserAmount(account, (amount * _lastAmountRate) / _divFactor, true);

        IToken(_mintRewardToken).giveMintReward();

        distributeNFTRewards(invitor, amount);

        addReferral(amount, account, invitor);

        emit Deposit(account, amount);
    }


    function claim() public {
        UserInfo storage user = userInfo[msg.sender];

        _calReward(user, true);
        uint256 pendingMint = user.calMintReward;

        if (pendingMint > 0) {
            _giveToken(_mintRewardToken, msg.sender, pendingMint);
            user.calMintReward = 0;
        }

        IToken(_mintRewardToken).giveMintReward();
    }


    function claimLP() public {
        require(msg.sender == tx.origin, "claimLP not Origin");

        UserLPInfo storage userLPInfo = _userLPInfo[msg.sender];
        uint256 nowTime = block.timestamp;

        if (userLPInfo.lastReleaseTime > 0 && nowTime > userLPInfo.lastReleaseTime) {
            uint256 releaseAmount = (userLPInfo.releaseInitAmount * (nowTime - userLPInfo.lastReleaseTime)) / userLPInfo.releaseDuration;
            uint256 maxAmount = userLPInfo.lockAmount - userLPInfo.calAmount - userLPInfo.claimedAmount;
            if (releaseAmount > maxAmount) {
                releaseAmount = maxAmount;
            }
            userLPInfo.calAmount += releaseAmount;
        }

        uint256 calAmount = userLPInfo.calAmount;

        if (calAmount > 0) {
            _giveToken(_lp, msg.sender, calAmount);
            userLPInfo.calAmount = 0;
            userLPInfo.claimedAmount += calAmount;
            IToken(_mintRewardToken).addUserLPAmount(msg.sender, calAmount);
        }

        if (nowTime > userLPInfo.lastReleaseTime) {
            userLPInfo.lastReleaseTime = nowTime;
        }

        IToken(_mintRewardToken).giveMintReward();
    }


    function checkForLevelUp(address invitor) public {
        if (referrals[invitor].length > 1) {
            uint256 totalReferralAmount = referralAmount[invitor] + depositAmount[invitor];
            uint256 currentLevel = userLevel[invitor];
            uint256[5] memory amountCheckArray = [v1Amount * 2, v2Amount, v3Amount, v4Amount, v5Amount];
            if (currentLevel < 5){
                if (checkLevelCount(invitor, amountCheckArray, totalReferralAmount, currentLevel)) {
                    userLevel[invitor] = currentLevel + 1;
                }
            }
        }
    }

    function getPendingMintReward(address account) public view returns (uint256 reward) {
        PoolInfo storage pool = poolInfo;
        UserInfo storage user = userInfo[account];

        if (user.amount > 0) {
            uint256 blockTime = block.timestamp;
            uint256 lastRewardTime = pool.lastMintTime;

            if (blockTime > lastRewardTime) {
                uint256 poolPendingReward = pool.mintPerSec * (blockTime - lastRewardTime);
                uint256 totalReward = pool.totalMintReward;
                uint256 accReward = pool.accMintReward;
                uint256 remainReward = (totalReward > accReward) ? (totalReward - accReward) : 0;

                poolPendingReward = (poolPendingReward > remainReward) ? remainReward : poolPendingReward;

                reward = (user.amount * (pool.accMintPerShare + (poolPendingReward * 1e18) / pool.totalAmount)) / 1e18 - user.rewardMintDebt;
            }
        }

        return reward;
    }


    function updateDailyUpRate() public {
        uint256 lastDailyUpTime = _lastDailyUpTime;
        if (0 == lastDailyUpTime) {
            return;
        }
        uint256 dailyDuration = _dailyDuration;
        uint256 nowTime = block.timestamp;
        if (nowTime < lastDailyUpTime + dailyDuration) {
            return;
        }
        uint256 ds = (nowTime - lastDailyUpTime) / dailyDuration;
        _lastDailyUpTime = lastDailyUpTime + ds * dailyDuration;

        uint256 lastAmountRate = _lastAmountRate;
        lastAmountRate = (lastAmountRate * _amountDailyUp ** ds) / _divFactor ** ds;
        _lastAmountRate = lastAmountRate;
    }

    function speedUpLP(uint256 maxTokenAmount) public {
        require(msg.sender == tx.origin, "not Origin");
        UserLPInfo storage userLPInfo = _userLPInfo[msg.sender];
        uint256 lastReleaseTime = userLPInfo.lastReleaseTime;
        uint256 nowTime = block.timestamp;
        if (lastReleaseTime > 0 && nowTime > lastReleaseTime) {
            uint256 releaseAmount = (userLPInfo.releaseInitAmount *
            (nowTime - lastReleaseTime)) / userLPInfo.releaseDuration;
            uint256 maxAmount = userLPInfo.lockAmount -
            userLPInfo.calAmount -
            userLPInfo.claimedAmount;
            if (releaseAmount > maxAmount) {
                releaseAmount = maxAmount;
            }
            userLPInfo.calAmount += releaseAmount;
        }

        if (nowTime > lastReleaseTime) {
            userLPInfo.lastReleaseTime = nowTime;
        }

        require(userLPInfo.speedUpTime < _speedUpMaxTime, "speedUpTime is max");
        userLPInfo.speedUpTime++;
        uint256 tokenAmount = getSpeedUpTokenAmount();
        require(tokenAmount <= maxTokenAmount, "token amount is too much");
        _takeToken(_mintRewardToken, msg.sender, _speedUpReceiver, tokenAmount);

        //
        uint256 remainAmount = userLPInfo.lockAmount -
        userLPInfo.calAmount -
        userLPInfo.claimedAmount;
        uint256 remainDuration = (remainAmount * userLPInfo.releaseDuration) /
        userLPInfo.releaseInitAmount;

        //
        userLPInfo.releaseInitAmount = remainAmount;
        uint256 speedUpDuration = _speedUpDuration;
        require(remainDuration > speedUpDuration, "releaseDuration is too short");
        userLPInfo.releaseDuration = remainDuration - speedUpDuration;

        IToken(_mintRewardToken).giveMintReward();
    }

    // ******** private *********
    function checkLevelCount(address invitor, uint[5] memory amountCheckArray, uint totalReferralAmount, uint currentLevel)
    internal view returns (bool) {
        address[] memory referralArr = referrals[invitor];
        if (totalReferralAmount >= amountCheckArray[currentLevel]) {
            uint cnt = 0;
            for (uint256 i; i < referrals[invitor].length; ++i) {
                if (currentLevel == 0) {
                    if (referralAmount[referralArr[i]] + depositAmount[referralArr[i]] >= v1Amount) {
                        ++cnt;
                    }
                } else {
                    if (userLevel[referralArr[i]] >= 1) {
                        ++cnt;
                    }
                }
                if (cnt >= 2) {
                    return true;
                }
            }
        }
        return false;
    }
    // Give NFT reward
    function distributeNFTRewards(address invitor, uint256 amount) private {
        uint256 invLevel = userLevel[invitor];
        uint256 nBalance = _nft.balanceOf(invitor);
        uint256 rewardAmount = calculateNFTReward(invLevel, amount);

        if (invLevel > 0 && nBalance > 0) {
            distributeMainReward(invitor, rewardAmount);
            distributeSuperRewards(invitor, invLevel, amount);
        } else {
            // Loop super wallet
            address currentAccount = superAccount[invitor];
            bool hasNFT = false;
            while (currentAccount != address(0) && !hasNFT) {
                uint256 sLevel = userLevel[currentAccount];
                uint256 sBalance = _nft.balanceOf(currentAccount);
                if (sLevel > 0 && sBalance > 0) {
                    hasNFT = true;
                    rewardAmount = calculateNFTReward(sLevel, amount);
                    distributeMainReward(currentAccount, rewardAmount);
                    distributeSuperRewards(currentAccount, sLevel, amount);
                }
                if (currentAccount == superAccount[currentAccount]) {
                    currentAccount = address(0);
                } else {
                    currentAccount = superAccount[currentAccount];
                }
            }
        }
    }

    function distributeMainReward(address invitor, uint256 rewardAmount) private {
        // Add power
        uint256 addAmount = (rewardAmount * _lastAmountRate) / _divFactor;
        _addUserAmount(invitor, addAmount, false);

        uint256 level = userLevel[invitor];
        emit nftPowerReward(invitor, level, addAmount);

        // Give token
        _giveToken(_usdt, invitor, rewardAmount);

        emit nftTokenReward(invitor, level, rewardAmount);
    }

    function distributeSuperRewards(address invitor, uint256 invLevel, uint256 amount) private {
        address currentAccount = superAccount[invitor];
        uint256 nextLevel = invLevel;
        uint256 sameLevel = invLevel + 1;

        while (currentAccount != address(0) && nextLevel <= 5) {
            uint256 sLevel = userLevel[currentAccount];
            uint256 sAmount = calculateNFTReward(sLevel, amount);

            if (sLevel > nextLevel || sLevel == sameLevel) {
                distributeSuperReward(currentAccount, sAmount);
                nextLevel = sLevel;
                sameLevel = sLevel + 1;
            } else if (sLevel == nextLevel) {
                distributeSameLevelReward(currentAccount, sAmount);
                nextLevel = sLevel + 1;
            }
            if (currentAccount == superAccount[currentAccount]) {
                currentAccount = address(0);
            } else {
                currentAccount = superAccount[currentAccount];
            }
        }
    }

    function distributeSuperReward(address invitor, uint256 sAmount) private {
        // Add power
        uint256 srAmount = (sAmount * _lastAmountRate) / _divFactor;
        _addUserAmount(invitor, srAmount, false);

        uint256 level = userLevel[invitor];
        emit nftPowerReward(invitor, level, srAmount);

        // Give token
        _giveToken(_usdt, invitor, sAmount);

        emit nftTokenReward(invitor, level, sAmount);
    }

    function distributeSameLevelReward(address invitor, uint256 sAmount) private {
        // Same level 20% rewards
        uint256 srAmount = (sAmount * _lastAmountRate) / _divFactor;
        uint256 sameLevelAmount = (srAmount * 20) / 100;

        // Add power
        _addUserAmount(invitor, sameLevelAmount, false);

        uint256 level = userLevel[invitor];
        emit nftPowerReward(invitor, level, sameLevelAmount);

        // Token reward
        uint256 tokenAmount = (sAmount * 20) / 100;
        _giveToken(_usdt, invitor, tokenAmount);

        emit nftTokenReward(invitor, level, tokenAmount);
    }

    // NFT add ref
    function addReferral(uint256 amount, address account, address invitor) private {
        depositAmount[account] += amount;

        address currentAccount = invitor;
        while (currentAccount != address(0)) {
            referralAmount[currentAccount] += amount;
            checkForLevelUp(currentAccount);
            if (currentAccount == superAccount[currentAccount]) {
                currentAccount = address(0);
            }
            currentAccount = superAccount[currentAccount];
        }
    }

    function addLP(address account, uint256 usdtAmount, uint256 minTokenAmount, bool lockLP) private {
        address token = _mintRewardToken;
        IERC20 Token = IERC20(token);
        uint256 tokenBalanceBefore = Token.balanceOf(address(this));

        address usdt = _usdt;
        address[] memory path = new address[](2);
        path[0] = usdt;
        path[1] = token;
        _swapRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            usdtAmount / 2,
            minTokenAmount,
            path,
            address(this),
            block.timestamp
        );

        uint256 tokenAmount = Token.balanceOf(address(this)) - tokenBalanceBefore;

        address lpReceiver = lockLP ? address(this) : _sellLPReceiver;
        (, , uint256 liquidity) = _swapRouter.addLiquidity(
            usdt,
            token,
            usdtAmount / 2,
            tokenAmount,
            0,
            0,
            lpReceiver,
            block.timestamp
        );
        //
        if (lockLP) {
            _addLockLP(account, liquidity);
        } else {
            IToken(_mintRewardToken).addUserLPAmount(lpReceiver, liquidity);
        }
    }

    function _addLockLP(address account, uint256 liquidity) private {
        UserLPInfo storage userLPInfo = _userLPInfo[account];
        uint256 lastReleaseTime = userLPInfo.lastReleaseTime;
        uint256 nowTime = block.timestamp;
        if (lastReleaseTime > 0 && nowTime > lastReleaseTime) {
            uint256 releaseAmount = (userLPInfo.releaseInitAmount * (nowTime - lastReleaseTime)) / userLPInfo.releaseDuration;
            uint256 maxAmount = userLPInfo.lockAmount - userLPInfo.calAmount - userLPInfo.claimedAmount;
            if (releaseAmount > maxAmount) {
                releaseAmount = maxAmount;
            }
            userLPInfo.calAmount += releaseAmount;
        }
        uint256 remainAmount = userLPInfo.lockAmount - userLPInfo.calAmount - userLPInfo.claimedAmount;
        userLPInfo.lockAmount += liquidity;
        userLPInfo.releaseInitAmount = remainAmount + liquidity;
        userLPInfo.releaseDuration = _lpReleaseDuration;

        if (nowTime > lastReleaseTime) {
            userLPInfo.lastReleaseTime = nowTime;
        }
    }

    function _addUserAmount(address account, uint256 amount, bool calInvite) private {
        UserInfo storage user = userInfo[account];
        _calReward(user, false);

        uint256 userAmount = user.amount;
        userAmount += amount;
        user.amount = userAmount;

        uint256 poolTotalAmount = poolInfo.totalAmount;
        poolTotalAmount += amount;

        uint256 poolAccMintPerShare = poolInfo.accMintPerShare;
        user.rewardMintDebt = (userAmount * poolAccMintPerShare) / 1e18;

        if (calInvite) {
            uint256 len = _inviteLen;
            UserInfo storage invitorInfo;
            address current = account;
            address invitor;
            uint256 invitorTotalAmount;
            for (uint256 i; i < len; ++i) {
                invitor = _invitor[current];
                if (address(0) == invitor) {
                    break;
                }
                invitorInfo = userInfo[invitor];
                _calReward(invitorInfo, false);
                uint256 inviteAmount = (amount * _inviteFee[i]) / 10000;
                _inviteAmount[invitor] += inviteAmount;
                _teamAmount[invitor] += amount;

                invitorTotalAmount = invitorInfo.amount;
                invitorTotalAmount += inviteAmount;
                invitorInfo.amount = invitorTotalAmount;
                invitorInfo.rewardMintDebt = (invitorTotalAmount * poolAccMintPerShare) / 1e18;

                poolTotalAmount += inviteAmount;
                current = invitor;
            }
        }
        poolInfo.totalAmount = poolTotalAmount;
    }

    function _updatePool() private {
        updateDailyUpRate();
        PoolInfo storage pool = poolInfo;
        uint256 blockTime = block.timestamp;
        uint256 lastRewardTime = pool.lastMintTime;
        if (blockTime <= lastRewardTime) {
            return;
        }
        pool.lastMintTime = blockTime;

        uint256 accReward = pool.accMintReward;
        uint256 totalReward = pool.totalMintReward;
        if (accReward >= totalReward) {
            return;
        }

        uint256 totalAmount = pool.totalAmount;
        uint256 rewardPerSec = pool.mintPerSec;
        if (0 < totalAmount && 0 < rewardPerSec) {
            uint256 reward = rewardPerSec * (blockTime - lastRewardTime);
            uint256 remainReward = totalReward - accReward;
            if (reward > remainReward) {
                reward = remainReward;
            }
            pool.accMintPerShare += (reward * 1e18) / totalAmount;
            pool.accMintReward += reward;
        }
    }

    function _calReward(UserInfo storage user, bool updatePool) private {
        if (updatePool) {
            _updatePool();
        }
        if (user.amount > 0) {
            uint256 accMintReward = (user.amount * poolInfo.accMintPerShare) / 1e18;
            uint256 pendingMintAmount = accMintReward - user.rewardMintDebt;
            if (pendingMintAmount > 0) {
                user.rewardMintDebt = accMintReward;
                user.calMintReward += pendingMintAmount;
            }
        }
    }


    // ******** view *********
    function getDailyRate() private view returns (uint256) {
        uint256 lastAmountRate = _lastAmountRate;
        uint256 lastDailyUpTime = _lastDailyUpTime;
        if (0 == lastDailyUpTime) {
            return lastAmountRate;
        }
        uint256 dailyDuration = _dailyDuration;
        uint256 nowTime = block.timestamp;
        if (nowTime < lastDailyUpTime + dailyDuration) {
            return lastAmountRate;
        }
        uint256 ds = (nowTime - lastDailyUpTime) / dailyDuration;

        uint256 amountDailyUp = _amountDailyUp;
        for (uint256 i; i < ds; ++i) {
            lastAmountRate = (lastAmountRate * amountDailyUp) / _divFactor;
        }
        return lastAmountRate;
    }

    function calculateNFTReward(uint256 userRewardLevel, uint256 amount) public pure returns (uint256){
        if (userRewardLevel == 0 || userRewardLevel > 5) {
            return 0;
        }
        return (amount * userRewardLevel) / 100;
    }

    function getSpeedUpTokenAmount() private view returns (uint256 tokenAmount){
        (uint256 rUsdt, uint256 rToken) = _getReserves();
        tokenAmount = (_speedUpCost * rToken) / rUsdt;
    }

    function _getReserves() public view returns (uint256 rUsdt, uint256 rToken){
        ISwapPair pair = ISwapPair(_lp);
        (uint256 r0, uint256 r1,) = pair.getReserves();

        if (_usdt < _mintRewardToken) {
            rUsdt = r0;
            rToken = r1;
        } else {
            rUsdt = r1;
            rToken = r0;
        }
    }

    function getJoinTokenAmountOut(uint256 usdtAmount) public view returns (uint256 tokenAmount){
        address[] memory path = new address[](2);
        path[0] = _usdt;
        path[1] = _mintRewardToken;
        uint256[] memory amounts = _swapRouter.getAmountsOut(
            usdtAmount / 2,
            path
        );
        tokenAmount = amounts[1];
    }

    function getSellUsdtOut(uint256 tokenAmount) public view
    returns (uint256 usdtAmount, uint256 selfUsdt, uint256 mintAmount){
        address[] memory path = new address[](2);
        path[0] = _mintRewardToken;
        path[1] = _usdt;
        uint256[] memory amounts = _swapRouter.getAmountsOut(tokenAmount, path);
        usdtAmount = amounts[1];
        selfUsdt = (usdtAmount * _sellSelfRate) / 10000;
        mintAmount = (usdtAmount * _sellJoinRate) / 10000;
        mintAmount = (mintAmount * getDailyRate()) / 10000;
    }

    function getBinderLength(address account) public view returns (uint256) {
        return _binder[account].length;
    }

    // NFT level
    function getUserNFTLevel(address account) external view returns (uint256) {
        return userLevel[account];
    }

    //绑定邀请关系
    function _bindInvitor(address account, address invitor) private {
        UserInfo storage user = userInfo[account];
        if (!user.isActive) {
            require(address(0) != invitor, "invitor 0");
            require(userInfo[invitor].isActive, "invitor !Active");
            //nft refer
            referrals[invitor].push(account);
            superAccount[account] = invitor;

            _invitor[account] = invitor;
            _binder[invitor].push(account);
            for (uint256 i; i < _inviteLen;) {
                _teamNum[invitor] += 1;
                invitor = _invitor[invitor];
                if (address(0) == invitor) {
                    break;
                }
            unchecked {
                ++i;
            }
            }
            user.isActive = true;
        }
    }

    function getBinderList(address account, uint256 start, uint256 length) external view
    returns (uint256 returnCount, address[] memory binders) {
        address[] storage _binders = _binder[account];
        uint256 recordLen = _binders.length;
        if (0 == length) {
            length = recordLen;
        }
        returnCount = length;
        binders = new address[](length);
        uint256 index = 0;
        for (uint256 i = start; i < start + length; i++) {
            if (i >= recordLen) {
                return (index, binders);
            }
            binders[index] = _binders[i];
            index++;
        }
    }

    function getDirectList(address account) external view
    returns (address[] memory binders, uint256[] memory teamAmounts){
        address[] storage _binders = referrals[account];
        uint256 recordLen = _binders.length;
        binders = new address[](recordLen);
        teamAmounts = new uint256[](recordLen);
        uint256 index = 0;
        for (uint256 i = 0; i < recordLen; i++) {
            if (i >= recordLen) {
                return (binders, teamAmounts);
            }

            address binder = _binders[i];
            binders[index] = binder;
            teamAmounts[index] = depositAmount[binder] + referralAmount[binder];
            index++;
        }
    }


    function getUserLPInfo(address account)
    public
    view
    returns (
        uint256 lockAmount,
        uint256 calAmount,
        uint256 claimedAmount,
        uint256 lastReleaseTime,
        uint256 releaseInitAmount,
        uint256 releaseDuration,
        uint256 speedUpTime,
        uint256 tokenBalance,
        uint256 tokenAllowance
    ){
        UserLPInfo storage userLPInfo = _userLPInfo[account];
        lockAmount = userLPInfo.lockAmount;
        calAmount = userLPInfo.calAmount;
        claimedAmount = userLPInfo.claimedAmount;
        releaseInitAmount = userLPInfo.releaseInitAmount;
        releaseDuration = userLPInfo.releaseDuration;
        speedUpTime = userLPInfo.speedUpTime;
        lastReleaseTime = userLPInfo.lastReleaseTime;
        tokenBalance = IERC20(_mintRewardToken).balanceOf(account);
        tokenAllowance = IERC20(_mintRewardToken).allowance(
            account,
            address(this)
        );
    }

    function getUserInfo(address account)
    public
    view
    returns (
        uint256 amount,
        uint256 usdtBalance,
        uint256 usdtAllowance,
        uint256 pendingMintReward,
        uint256 inviteAmount,
        uint256 sellJoinAmount,
        uint256 teamNum,
        uint256 teamAmount
    )
    {
        UserInfo storage user = userInfo[account];
        amount = user.amount;
        usdtBalance = IERC20(_usdt).balanceOf(account);
        usdtAllowance = IERC20(_usdt).allowance(account, address(this));
        pendingMintReward = getPendingMintReward(account) + user.calMintReward;
        inviteAmount = _inviteAmount[account];
        sellJoinAmount = _sellJoinAmount[account];
        teamNum = _teamNum[account];
        teamAmount = _teamAmount[account];
    }

    function getBaseInfo()
    external
    view
    returns (
        address usdt,
        uint256 usdtDecimals,
        address mintRewardToken,
        uint256 mintRewardTokenDecimals,
        uint256 totalUsdt,
        uint256 totalAmount,
        uint256 lastDailyReward,
        uint256 dailyAmountRate,
        uint256 minAmount,
        address defaultInvitor,
        bool pauseJoin
    )
    {
        usdt = _usdt;
        usdtDecimals = 18;
        mintRewardToken = _mintRewardToken;
        mintRewardTokenDecimals = 18;
        totalUsdt = _totalUsdt;
        totalAmount = poolInfo.totalAmount;
        lastDailyReward = _lastDailyReward;
        dailyAmountRate = getDailyRate();
        minAmount = _minAmount;
        defaultInvitor = _defaultInvitor;
        pauseJoin = _pauseJoin;
    }

    function getLPInfo()
    external
    view
    returns (
        uint256 totalLP,
        uint256 lockLP,
        uint256 speedUpMaxTime,
        uint256 speedCostUsdt,
        uint256 speedCostToken
    )
    {
        totalLP = IERC20(_lp).totalSupply();
        lockLP = IERC20(_lp).balanceOf(address(this));
        speedUpMaxTime = _speedUpMaxTime;
        speedCostUsdt = _speedUpCost;
        speedCostToken = getSpeedUpTokenAmount();
    }


    // ******** owner *********
    function setNFTAddress(address _nftAddress) external onlyWhiteList {
        _nft = INFT(_nftAddress);
    }

    function setUserLevel(address account, uint256 level) external onlyWhiteList {
        userLevel[account] = level;
    }

    // Batch userInfo
    function batchInsertUserInfo(address[] memory users, UserInfo[] memory userInfos) external onlyWhiteList {
        require(users.length == userInfos.length, "Array lengths do not match");
        for (uint256 i = 0; i < users.length; i++) {
            userInfo[users[i]] = userInfos[i];
        }
    }

    function setPauseSell(bool p) external onlyWhiteList {
        _pauseSell = p;
    }

    function setSellSelfRate(uint256 r) external onlyWhiteList {
        _sellSelfRate = r;
        require(_sellSelfRate + _sellJoinRate + _sellNFTRate <= 10000, "rate overflow");
    }

    function setSellJoinRate(uint256 r) external onlyWhiteList {
        _sellJoinRate = r;
        require(_sellSelfRate + _sellJoinRate + _sellNFTRate <= 10000, "rate overflow");
    }

    function setSellNFTRate(uint256 r) external onlyWhiteList {
        _sellNFTRate = r;
        require(_sellSelfRate + _sellJoinRate + _sellNFTRate <= 10000, "rate overflow");
    }

    function setSellLPReceiver(address a) external onlyWhiteList {
        _sellLPReceiver = a;
    }

    function setFundAddress(address a) external onlyWhiteList {
        _fundAddress = a;
    }

    function setSpeedUpMaxTime(uint256 mt) external onlyWhiteList {
        _speedUpMaxTime = mt;
    }

    function setSpeedUpCost(uint256 c) external onlyWhiteList {
        _speedUpCost = c;
    }

    function setSpeedUpDuration(uint256 d) external onlyWhiteList {
        _speedUpDuration = d;
    }

    function setSeedUpReceiver(address a) external onlyWhiteList {
        _speedUpReceiver = a;
    }

    function setLPReleaseDuration(uint256 d) external onlyWhiteList {
        require(d > 0, "release duration must > 0");
        _lpReleaseDuration = d;
    }

    function setAmountDailyUp(uint256 r) external onlyWhiteList {
        _amountDailyUp = r;
    }

    function setLastDailyUpTime(uint256 t) external onlyWhiteList {
        _lastDailyUpTime = t;
    }

    function setLastAmountRate(uint256 r) external onlyWhiteList {
        _lastAmountRate = r;
    }

    function open() external onlyWhiteList {
        if (0 == _lastDailyUpTime) {
            _lastDailyUpTime = block.timestamp;
        }
        _pauseJoin = false;
    }

    function close() external onlyWhiteList {
        _pauseJoin = true;
    }

    function addMintAmount(address account, uint256 amount) external onlyWhiteList {
        _bindInvitor(account, _defaultInvitor);
        _updatePool();
        _addUserAmount(account, amount, false);
    }

    function setMintPerSec(uint256 mintPerSec) external onlyWhiteList {
        _updatePool();
        poolInfo.mintPerSec = mintPerSec;
    }

    function setInviteFee(uint256 i, uint256 fee) external onlyWhiteList {
        _inviteFee[i] = fee;
    }

    function claimBalance(address to, uint256 amount) external onlyWhiteList {
        safeTransferETH(to, amount);
    }

    function claimToken(address token, address to, uint256 amount) external onlyWhiteList {
        _giveToken(token, to, amount);
    }

    function setDefaultInvitor(address adr) external onlyWhiteList {
        _defaultInvitor = adr;
        userInfo[adr].isActive = true;
    }

    function setInProject(address adr, bool enable) external onlyWhiteList {
        _inProject[adr] = enable;
    }

    function addTotalMintReward(uint256 reward) external onlyInProject {
        _updatePool();
        poolInfo.totalMintReward += reward;
        poolInfo.mintPerSec = reward / _dailyDuration;
        _lastDailyReward = reward;
    }

    function bindInvitor(address account, address invitor) public onlyInProject {
        _bindInvitor(account, invitor);
    }

    //    function bindInvitors(address[] memory account, address[] memory invitor) public onlyInProject {
    //        for (uint256 i = 0; i < account.length; i++) {
    //            _bindInvitor(account[i], invitor[i]);
    //        }
    //    }

    function addUserAmount(address account, uint256 amount, bool calInvite) public onlyInProject {
        _bindInvitor(account, _defaultInvitor);
        _updatePool();
        _addUserAmount(account, amount, calInvite);
    }


    // ******** utils *********
    function safeApprove(address token, address to, uint256 value) internal {
        //bytes4(keccak256(bytes('approve(address,uint256)')));
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(0x095ea7b3, to, value)
        );

        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "approve fail"
        );
    }

    function safeTransferETH(address to, uint256 value) internal {
        (bool success,) = to.call{value : value}(new bytes(0));
        require(success, "eth transfer fail");
    }

    function _giveToken(address tokenAddress, address account, uint256 amount) private {
        if (0 == amount) {
            return;
        }
        IERC20 token = IERC20(tokenAddress);
        require(token.balanceOf(address(this)) >= amount, "balance not enough");
        token.transfer(account, amount);
    }

    function _takeToken(address tokenAddress, address from, address to, uint256 tokenNum) private {
        IERC20 token = IERC20(tokenAddress);
        require(token.balanceOf(address(from)) >= tokenNum, "balance not enough");
        token.transferFrom(from, to, tokenNum);
    }

    // ********* setting *********
    //    function setPoolInfo(uint256 totalAmount, uint256 accMintPerShare, uint256 accMintReward, uint256 mintPerSec,
    //        uint256 lastMintTime, uint256 totalMintReward) external onlyWhiteList {
    //        poolInfo.totalAmount = totalAmount;
    //        poolInfo.accMintPerShare = accMintPerShare;
    //        poolInfo.accMintReward = accMintReward;
    //        poolInfo.mintPerSec = mintPerSec;
    //        poolInfo.lastMintTime = lastMintTime;
    //        poolInfo.totalMintReward = totalMintReward;
    //    }
    //
    //    function setUserLpInfos(address[] memory account, UserLPInfo[] memory lpInfos) external onlyWhiteList {
    //        for (uint256 i = 0; i < account.length; i++) {
    //            _userLPInfo[account[i]] = lpInfos[i];
    //        }
    //    }
    //
    //    function setInviteAmount(address[] memory account, uint256[] memory amount) external onlyWhiteList {
    //        for (uint256 i = 0; i < account.length; i++) {
    //            _inviteAmount[account[i]] = amount[i];
    //        }
    //    }
    //
    //    function setTeamAmount(address[] memory account, uint256[] memory amount) external onlyWhiteList {
    //        for (uint256 i = 0; i < account.length; i++) {
    //            _teamAmount[account[i]] = amount[i];
    //        }
    //    }
    //
    //    function setSellJoinAmount(address[] memory account, uint256[] memory amount) external onlyWhiteList {
    //        for (uint256 i = 0; i < account.length; i++) {
    //            _sellJoinAmount[account[i]] = amount[i];
    //        }
    //    }
    //
    //    function setReferralAmount(address[] memory account, uint256[] memory amount) external onlyWhiteList {
    //        for (uint256 i = 0; i < account.length; i++) {
    //            referralAmount[account[i]] = amount[i];
    //        }
    //    }
    //
    //    function setDepositAmount(address[] memory account, uint256[] memory amount) external onlyWhiteList {
    //        for (uint256 i = 0; i < account.length; i++) {
    //            depositAmount[account[i]] = amount[i];
    //        }
    //    }
    //
    //    function setReferralReward(address[] memory account, uint256[] memory amount) external onlyWhiteList {
    //        for (uint256 i = 0; i < account.length; i++) {
    //            referralReward[account[i]] = amount[i];
    //        }
    //    }
    //
    //    function setUserLevels(address[] memory account, uint256[] memory level) external onlyWhiteList {
    //        for (uint256 i = 0; i < account.length; i++) {
    //            userLevel[account[i]] = level[i];
    //        }
    //    }
    //
    //    function setTotalUsd(uint256 amount) external onlyWhiteList {
    //        _totalUsdt = amount;
    //    }
    //
    //    function setLastDailyReward(uint256 reward) external onlyWhiteList {
    //        _lastDailyReward = reward;
    //    }
}