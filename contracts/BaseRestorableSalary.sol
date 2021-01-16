// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity ^0.7.1;
import "./Salary.sol";

/// TODO: We can allow anyone to resign from DAO control. Then he becomes "deathless" (transferring his salary
///       to children or other friends) and this seems a trouble.
///       But if one dies, the price of his tokens will go down making it a stupid act to pass his private key to friends.
///       However, one could intentionally disclose (e.g. when expecting to die soon) his private key to somebody
///       to harm his investors.
///       Consequently, it makes sense to prevent fishing attacks on resigning from DAO control
///       to use two different contracts: One allows account restoration and the other doesn't.
///       Need to consider with care the case if one mistakenly discloses his private key.
/// FIXME: An investor may gain if he kills a scientist to reduce the circulating supply of his token to increase the price.
///        Possible solution: Create a new salary token after each outgoing transfer.
///        (Should old tokens be exchangeable for new ones? (Allowing the reverse swap would create killer's gain.))
///        Additional benefit of this solution: We can have different rewards at different stages of project,
///        what may be benefical for early startups funding.
///        TODO: There should be an advice to switch to a new token at each milestone of a project.
abstract contract BaseRestorableSalary is Salary {
    // INVARIANT: `originalAddress(newToOldAccount[newAccount]) == originalAddress(newAccount)`
    //            if `newToOldAccount[newAccount] != address(0)` for every `newAccount`
    // INVARIANT: originalAddresses and currentAddresses are mutually inverse. // FIXME: Formulate exactly.

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
    ///
    /// This function is intented to be called by an attorney.
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
    /// This function is intented to be called by an attorney.
    function dispermitRestoreAccount(address oldAccount_, address newAccount_) public {
        checkAllowedUnrestoreAccount(oldAccount_, newAccount_); // only authorized "attorneys" or attorney DAOs
        // FIXME: Need to check if `newToOldAccount[newAccount_] != address(0)` and/or `originalAddresses[newAccount_] != address(0)`?
        newToOldAccount[newAccount_] = address(0);
        currentAddresses[oldAccount_] = address(0);
        originalAddresses[newAccount_] = address(0);
        // TODO: Check that the above invariant holds.
        emit AccountUnrestored(oldAccount_, newAccount_);
    }

    /// Move the entire balance of a token from an old account to a new account of the same user.
    /// @param oldAccount_ Old account.
    /// @param newAccount_ New account.
    /// @param token_ The ERC-1155 token ID.
    /// This function can be called by the affected user. // TODO: Also allow to be called by an attorney?
    function restoreFunds(address oldAccount_, address newAccount_, uint256 token_) public
        checkMovedOwner(oldAccount_, newAccount_)
    {
        uint256 amount = _balances[token_][oldAccount_];

        _balances[token_][newAccount_] = _balances[token_][oldAccount_];
        _balances[token_][oldAccount_] = 0;

        emit TransferSingle(_msgSender(), oldAccount_, newAccount_, token_, amount);
    }

    /// Move the entire balance of tokens from an old account to a new account of the same user.
    /// @param oldAccount_ Old account.
    /// @param newAccount_ New account.
    /// @param tokens_ The ERC-1155 token IDs.
    /// This function can be called by the affected user. // TODO: Also allow to be called by an attorney?
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

    /// Check if `msg.sender` is an attorney allowed to restore a user's account.
    function checkAllowedRestoreAccount(address /*oldAccount_*/, address /*newAccount_*/) public virtual;

    /// Check if `msg.sender` is an attorney allowed to unrestore a user's account.
    function checkAllowedUnrestoreAccount(address /*oldAccount_*/, address /*newAccount_*/) public virtual;

    /// Find the original address of a given account.
    /// @param account The current address.
    function originalAddress(address account) public view virtual returns (address) {
        address newAddress = originalAddresses[account];
        return newAddress != address(0) ? newAddress : account;
    }

    // Virtual functions //

    /// Find the current address for an original address.
    /// @param conditional The original address.
    function currentAddress(address conditional) internal virtual override returns (address) {
        return currentAddresses[conditional];
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
