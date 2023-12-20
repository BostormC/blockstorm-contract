// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';

contract CusdToken is ERC20Upgradeable, ERC20PausableUpgradeable, OwnableUpgradeable, ERC20PermitUpgradeable {
    mapping(address => bool) public blacklist;
    mapping(address => bool) public whitelist;
    bool public whitelistEnabled = true;

    event WhitelistUpdated(address indexed account, bool isWhitelisted);

    event WhitelistEnabledUpdated(bool isEnabled);


     function initialize(address _owner) external initializer {
        __ERC20_init("CUSD", "CUSD");
        __ERC20Permit_init("CUSD");
         _mint(msg.sender, 10000000 * 10 ** decimals());
        _transferOwnership(_owner);
    }


    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    function addToBlacklist(address _user) external onlyOwner {
        blacklist[_user] = true;
    }

    function removeFromBlacklist(address _user) external onlyOwner {
        blacklist[_user] = false;
    }

    function transfer(address to, uint256 value)
    public
    override
    returns (bool)
    {
        require(
            !whitelistEnabled || whitelist[msg.sender] || whitelist[to],
            "One of the addresses must be whitelisted"
        );
        require(!blacklist[msg.sender], "Sender is blacklisted");
        require(!blacklist[to], "Recipient is blacklisted");
        bool success = super.transfer(to, value);
        return success;
    }

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) public override returns (bool) {
        require(
            !whitelistEnabled || whitelist[from] || whitelist[to],
            "One of the addresses must be whitelisted"
        );

        require(!blacklist[msg.sender], "Sender is blacklisted");
        require(!blacklist[to], "Recipient is blacklisted");
        bool success = super.transferFrom(from, to, value);
        return success;
    }

    function updateWhitelist(address account, bool isWhitelisted)
    external
    onlyOwner
    {
        require(whitelistEnabled, "Whitelist is not enabled");
        whitelist[account] = isWhitelisted;
        emit WhitelistUpdated(account, isWhitelisted);
    }

    function updateWhitelistEnabled(bool isEnabled) external onlyOwner {
        whitelistEnabled = isEnabled;
        emit WhitelistEnabledUpdated(isEnabled);
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override(ERC20PausableUpgradeable, ERC20Upgradeable) {
        super._beforeTokenTransfer(from, to, amount);
    }
}