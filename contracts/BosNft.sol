// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import "./library/String.sol";
import "./interface/IMintPool.sol";
import "./interface/IToken.sol";

contract BOSNFT is ERC721EnumerableUpgradeable, OwnableUpgradeable{
    using String for uint256;

    string public _baseUri;
    string public _suffix;

    string public _sameUri;

    mapping(address => bool) public _minter;

    mapping(address => bool) public hasMinted;

    uint256 public _tokenId = 1;
    uint256 public _maxTotal;
    address public fundAddress;
    address public rewardToken;
    address public _mintPoolAddress;

    uint256 public accRewardPerShare;
    mapping(uint256 => uint256) public _nftRewardDebt;
    mapping(address => bool) public _rewardAdmin;
    uint256 public _totalReward;
    mapping(address => uint256) public _claimedReward;

    modifier onlyWhiteList() {
        require(msg.sender == fundAddress || msg.sender == owner(), "only white list");
        _;
    }

    function initialize(address _fundAddress, address _rewardToken, address _owner) external initializer{
        __ERC721_init("BOSNFT", "BOSNFT");
        fundAddress = _fundAddress;
        //CUSD
        rewardToken = _rewardToken;
        _maxTotal = 888;
        //
        _baseUri = "https://gateway.pinata.cloud/ipfs/QmUoiShZpvxknHWnS1vJK6nmGrKuBviz3HpqXFjy4Np7Ao/";
        _suffix = ".json";
        //
        _sameUri = "";
        _transferOwnership(_owner);
    }


    function mint(address to, uint256 num) external {
        require(_minter[msg.sender], "only minter");
        uint256 tokenId = _tokenId;
        for (uint256 i; i < num;) {
            _mint(to, tokenId);
            _nftRewardDebt[tokenId] = accRewardPerShare / 1e12;
        unchecked {
            ++tokenId;
            ++i;
        }
        }
        _tokenId = tokenId;
        require(totalSupply() <= _maxTotal, "total supply max");
    }

    function mint() external {
        require(tx.origin == msg.sender, "Only external user can call this function");
        require(!hasMinted[msg.sender], "You have already minted the NFT");

        uint256 userLevel = IMintPool(_mintPoolAddress).getUserNFTLevel(msg.sender);

        require(userLevel > 0, "No level");
        if (userLevel > 0) {
            uint256 tokenId = _tokenId;

            _mint(msg.sender, tokenId);
            _nftRewardDebt[tokenId] = accRewardPerShare / 1e12;
            unchecked {
                ++tokenId;
             }
            _tokenId = tokenId;
            require(totalSupply() <= _maxTotal, "total supply max");
            hasMinted[msg.sender] = true;
        }
    }

    function addTokenReward(uint256 rewardAmount) external {
        require(_rewardAdmin[msg.sender], "only reward admin");
        uint256 totalAmount = totalSupply();
        if (totalAmount > 0) {
            accRewardPerShare += (rewardAmount * 1e12) / totalAmount;
            _totalReward += rewardAmount;
        }
    }

    function claimReward() external {
        uint256 reward = pendingReward(msg.sender);
        IERC20 token = IERC20(rewardToken);
        require(token.balanceOf(address(this)) >= reward, "Insufficient balance");
        token.transfer(msg.sender, reward);

        uint256 num = balanceOf(msg.sender);
        for (uint256 i; i < num;) {
            _nftRewardDebt[tokenOfOwnerByIndex(msg.sender, i)] = accRewardPerShare / 1e12;
            unchecked {++i;}
        }
        _claimedReward[msg.sender] += reward;
    }

    function setBaseUri(string memory uri, string memory suffix) external onlyWhiteList {
        _baseUri = uri;
        _suffix = suffix;
    }

    function setSameUri(string memory uri) external onlyWhiteList {
        _sameUri = uri;
    }

    function setMinter(address minter, bool enable) external onlyWhiteList {
        _minter[minter] = enable;
    }

    function setMintpool(address mintPoolAddress) external onlyOwner {
        _mintPoolAddress = mintPoolAddress;
    }

    function claimBalance(address to, uint256 amount) external onlyWhiteList {
        safeTransferETH(to, amount);
    }

    function claimToken(address token, address to, uint256 amount) external onlyWhiteList {
        IERC20 tokenContract = IERC20(token);
        require(tokenContract.balanceOf(address(this)) >= amount, "Insufficient balance");
        tokenContract.transfer(to, amount);
    }

    function setMaxTotal(uint256 maxTotal) external onlyWhiteList {
        _maxTotal = maxTotal;
    }

    function setFundAddress(address a) external onlyWhiteList {
        fundAddress = a;
    }

    function setRewardToken(address _rewardToken) external onlyWhiteList {
        rewardToken = _rewardToken;
    }

    function setRewardAdmin(address a, bool enable) external onlyWhiteList {
        _rewardAdmin[a] = enable;
    }

    function tokenURI(uint256 id) public view virtual override returns (string memory){
        string memory baseURI = _baseUri;
        return
        bytes(baseURI).length != 0 ? string(abi.encodePacked(baseURI, id.toString(), _suffix)) : _sameUri;
    }

    function pendingNFTReward(uint256 nftId) public view returns (uint256 reward){
        reward = accRewardPerShare / 1e12 - _nftRewardDebt[nftId];
    }

    function pendingReward(address account) public view returns (uint256 reward){
        reward = 0;
        uint256 num = balanceOf(account);
        for (uint256 i; i < num; i++) {
            reward += pendingNFTReward(tokenOfOwnerByIndex(account, i));
        }
    }

    function getUserInfo(address account) external view
    returns (uint256 nftNum, uint256 claimedReward, uint256 pendingToken){
        nftNum = balanceOf(account);
        claimedReward = _claimedReward[account];
        pendingToken = pendingReward(account);
    }

    function safeTransferETH(address to, uint256 value) internal {
        (bool success,) = to.call{value : value}(new bytes(0));
        require(success, "transfer fail");
    }
}