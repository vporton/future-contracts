// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity ^0.7.1;
import "./Salary.sol";

abstract contract BaseRestorableSalary is Salary {
    /// The very first address an account had.
    mapping(address => address) public originalAddresses;

    // Mapping from old to new account addresses (created after every change of an address).
    mapping(address => address) public newToOldAccount;

    /// Constructor.
    /// @param uri_ Our ERC-1155 tokens description URI.
    constructor (string memory uri_) Salary(uri_) { }

    /// Below copied from https://github.com/vporton/restorable-funds/blob/f6192fd23cad529b84155d52ae202430cd97db23/contracts/RestorableERC1155.sol

    /// Give the user the "permission" to move funds from `oldAccount_` to `newAccount_`.
    /// FIXME: It should be allowed to DAO, not owner.
    /// TODO: Ability to remove the permit.
    function permitRestoreAccount(address oldAccount_, address newAccount_) public {
        checkAllowedRestoreAccount(oldAccount_, newAccount_);
        newToOldAccount[newAccount_] = oldAccount_;
        originalAddresses[newAccount_] = originalAddress(oldAccount_);
        emit AccountRestored(oldAccount_, newAccount_);
    }

    function restoreFunds(address oldAccount_, address newAccount_, uint256 token_) public
        checkMovedOwner(oldAccount_, newAccount_)
    {
        uint256 amount = _balances[token_][oldAccount_];

        _balances[token_][newAccount_] = _balances[token_][oldAccount_];
        _balances[token_][oldAccount_] = 0;

        emit TransferSingle(_msgSender(), oldAccount_, newAccount_, token_, amount);
    }

    function restoreFundsBatch(address oldAccount_, address newAccount_, uint256[] calldata tokens_) public
        checkMovedOwner(oldAccount_, newAccount_)
    {
        uint256[] memory amounts = new uint256[](tokens_.length);
        for (uint i = 0; i < tokens_.length; ++i) {
            uint256 token = tokens_[i];
            uint256 amount = _balances[token][oldAccount_];
            amounts[i] = amount;

            _balances[token][newAccount_] = _balances[token][oldAccount_];
            _balances[token][oldAccount_] = 0;
        }

        emit TransferBatch(_msgSender(), oldAccount_, newAccount_, tokens_, amounts);
    }

    function checkAllowedRestoreAccount(address /*oldAccount_*/, address /*newAccount_*/) public virtual;

    function originalAddress(address account) public view virtual returns (address) {
        address newAddress = originalAddresses[account];
        return newAddress != address(0) ? newAddress : account;
    }

    // Internal functions //

    function _upgradeAccounts(address[] memory accounts) view virtual internal {
        // assert(accounts.length == newAccounts.length);
        for (uint i = 0; i < accounts.length; ++i) {
            accounts[i] = originalAddress(accounts[i]);
        }
    }

    // Modifiers //

    modifier checkMovedOwner(address oldAccount_, address newAccount_) virtual {
        require(newAccount_ == _msgSender(), "Not account owner.");

        for (address account = oldAccount_; account != newAccount_; account = newToOldAccount[account]) {
            require(account != address(0), "Not a moved owner");
        }

        _;
    }

    // Events //

    event AccountRestored(address oldAccount, address newAccount);
}
