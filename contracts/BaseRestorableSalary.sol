// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity ^0.7.1;
import "./Salary.sol";

abstract contract BaseRestorableSalary is Salary {
    // INVARIANT: `originalAddress(newToOldAccount[newAccount]) == originalAddress(newAccount)`
    //            if `newToOldAccount[newAccount] != address(0)` for every `newAccount`

    /// The very first address an account had.
    mapping(address => address) public originalAddresses;

    /// original address => current address
    mapping(address => address) public currentAddresses;

    // Mapping from old to new account addresses (created after every change of an address).
    mapping(address => address) public newToOldAccount;

    /// Constructor.
    /// @param uri_ Our ERC-1155 tokens description URI.
    constructor (string memory uri_) Salary(uri_) { }

    /// Below copied from https://github.com/vporton/restorable-funds/blob/f6192fd23cad529b84155d52ae202430cd97db23/contracts/RestorableERC1155.sol

    /// Give the user the "permission" to move funds from `oldAccount_` to `newAccount_`.
    /// FIXME: Is oldAccount_ an original or current address?
    function permitRestoreAccount(address oldAccount_, address newAccount_) public {
        checkAllowedRestoreAccount(oldAccount_, newAccount_); // only authorized "attorneys" or attorney DAOs
        // FIXME: Need to check if `newToOldAccount[newAccount_] == address(0)` and/or `originalAddresses[newAccount_] == address(0)`?
        newToOldAccount[newAccount_] = oldAccount_;
        address orig = originalAddress(oldAccount_);
        originalAddresses[newAccount_] = orig;
        currentAddresses[orig] = newAccount_;
        // TODO: Check that the above invariant holds.
        emit AccountRestored(oldAccount_, newAccount_);
    }

    /// FIXME: Is oldAccount_ an original or current address?
    /// FIXME: Is newAccount_ an original or current address?
    function dispermitRestoreAccount(address oldAccount_, address newAccount_) public {
        checkAllowedUnrestoreAccount(oldAccount_, newAccount_); // only authorized "attorneys" or attorney DAOs
        // FIXME: Need to check if `newToOldAccount[newAccount_] != address(0)` and/or `originalAddresses[newAccount_] != address(0)`?
        newToOldAccount[newAccount_] = address(0);
        currentAddresses[oldAccount_] = address(0);
        originalAddresses[newAccount_] = address(0);
        // TODO: Check that the above invariant holds.
        emit AccountUnrestored(oldAccount_, newAccount_);
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

    function checkAllowedUnrestoreAccount(address /*oldAccount_*/, address /*newAccount_*/) public virtual;

    function originalAddress(address account) public view virtual returns (address) {
        address newAddress = originalAddresses[account];
        return newAddress != address(0) ? newAddress : account;
    }

    // Virtual functions //

    function currentAddress(address conditional) internal virtual override returns (address) {
        return currentAddresses[conditional];
    }

    // Internal functions //

    function _upgradeAccounts(address[] memory accounts) view virtual internal {
        // assert(accounts.length == newAccounts.length);
        for (uint i = 0; i < accounts.length; ++i) {
            accounts[i] = originalAddress(accounts[i]);
        }
    }

    // Modifiers //

    // TODO: For clarity split this modifier into two ones.
    modifier checkMovedOwner(address oldAccount_, address newAccount_) virtual {
        require(newAccount_ == _msgSender(), "Not account owner.");

        for (address account = oldAccount_; account != newAccount_; account = newToOldAccount[account]) {
            require(account != address(0), "Not a moved owner");
        }

        _;
    }

    // Events //

    event AccountRestored(address oldAccount, address newAccount);

    event AccountUnrestored(address oldAccount, address newAccount);
}
