// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity ^0.7.1;
import "./Salary.sol";

/// @author Victor Porton
/// @notice Not audited, not enough tested.
abstract contract BaseRestorableSalary is BaseSalary {
    // INVARIANT: `_originalAddress(newToOldAccount[newAccount]) == _originalAddress(newAccount)`
    //            if `newToOldAccount[newAccount] != address(0)` for every `newAccount`
    // INVARIANT: originalAddresses and currentAddresses are mutually inverse.
    //            That is:
    //            - `originalAddresses[currentAddresses[x]] == x` if `currentAddresses[x] != address(0)`
    //            - `currentAddresses[originalAddresses[x]] == x` if `originalAddresses[x] != address(0)`

    /// The very first address an account had.
    mapping(address => address) public originalAddresses;

    /// original address => current address
    mapping(address => address) public currentAddresses;

    // Mapping from old to new account addresses (created after every change of an address).
    mapping(address => address) public newToOldAccount;

    /// Constructor.
    /// @param _uri Our ERC-1155 tokens description URI.
    constructor (string memory _uri) BaseSalary(_uri) { }

    /// Below copied from https://github.com/vporton/restorable-funds/blob/f6192fd23cad529b84155d52ae202430cd97db23/contracts/RestorableERC1155.sol

    /// Give the user the "permission" to move funds from `_oldAccount` to `_newAccount`.
    ///
    /// This function is intented to be called by an attorney or the user to move to a new account.
    /// @param _oldAccount is a current address.
    /// @param _newAccount is a new address.
    function permitRestoreAccount(address _oldAccount, address _newAccount) public {
        if (msg.sender != _oldAccount) {
            checkAllowedRestoreAccount(_oldAccount, _newAccount); // only authorized "attorneys" or attorney DAOs
        }
        _avoidZeroAddressManipulatins(_oldAccount, _newAccount);
        address _orig = _originalAddress(_oldAccount);

        // We don't disallow joining several accounts together to consolidate salaries for different projects.
        // require(originalAddresses[_newAccount] == 0, "Account is taken.")

        newToOldAccount[_newAccount] = _oldAccount;
        originalAddresses[_newAccount] = _orig;
        currentAddresses[_orig] = _newAccount;
        // Auditor: Check that the above invariant hold.
        emit AccountRestored(_oldAccount, _newAccount);
    }

    /// This function is intented to be called by an attorney.
    /// @param _oldAccount is an old current address.
    /// @param _newAccount is a new address.
    /// We don't allow this to be called by `msg.sender == _oldAccount`, because
    /// it would allow to keep stealing the salary by hijacked old account.
    function dispermitRestoreAccount(address _oldAccount, address _newAccount) public {
        checkAllowedUnrestoreAccount(_oldAccount, _newAccount); // only authorized "attorneys" or attorney DAOs
        _avoidZeroAddressManipulatins(_oldAccount, _newAccount);
        newToOldAccount[_newAccount] = address(0);
        currentAddresses[_oldAccount] = address(0);
        originalAddresses[_newAccount] = address(0);
        // Auditor: Check that the above invariants hold.
        emit AccountUnrestored(_oldAccount, _newAccount);
    }

    /// Move the entire balance of a token from an old account to a new account of the same user.
    /// @param _oldAccount Old account.
    /// @param _newAccount New account.
    /// @param _token The ERC-1155 token ID.
    /// This function can be called by the affected user.
    ///
    /// Remark: We intentionally create no new tokens as on a regular transfer, because it isn't a transfer to a trader.
    function restoreFunds(address _oldAccount, address _newAccount, uint256 _token) public
        checkMovedOwner(_oldAccount, _newAccount)
    {
        uint256 _amount = _balances[_token][_oldAccount];

        _balances[_token][_newAccount] = _balances[_token][_oldAccount];
        _balances[_token][_oldAccount] = 0;

        emit TransferSingle(_msgSender(), _oldAccount, _newAccount, _token, _amount);
    }

    /// Move the entire balance of tokens from an old account to a new account of the same user.
    /// @param _oldAccount Old account.
    /// @param _newAccount New account.
    /// @param _tokens The ERC-1155 token IDs.
    /// This function can be called by the affected user.
    ///
    /// Remark: We intentionally create no new tokens as on a regular transfer, because it isn't a transfer to a trader.
    function restoreFundsBatch(address _oldAccount, address _newAccount, uint256[] calldata _tokens) public
        checkMovedOwner(_oldAccount, _newAccount)
    {
        uint256[] memory _amounts = new uint256[](_tokens.length);
        for (uint _i = 0; _i < _tokens.length; ++_i) {
            uint256 _token = _tokens[_i];
            uint256 _amount = _balances[_token][_oldAccount];
            _amounts[_i] = _amount;

            _balances[_token][_newAccount] = _balances[_token][_oldAccount];
            _balances[_token][_oldAccount] = 0;
        }

        emit TransferBatch(_msgSender(), _oldAccount, _newAccount, _tokens, _amounts);
    }

    /// Check if `msg.sender` is an attorney allowed to restore a user's account.
    function checkAllowedRestoreAccount(address /*_oldAccount*/, address /*_newAccount*/) public virtual;

    /// Check if `msg.sender` is an attorney allowed to unrestore a user's account.
    function checkAllowedUnrestoreAccount(address /*_oldAccount*/, address /*_newAccount*/) public virtual;

    /// Find the original address of a given account.
    /// @param _account The current address.
    function _originalAddress(address _account) internal view virtual returns (address) {
        address _newAddress = originalAddresses[_account];
        return _newAddress != address(0) ? _newAddress : _account;
    }

    // Internal functions //

    function _avoidZeroAddressManipulatins(address _oldAccount, address _newAccount) internal view {
        // To avoid make-rich-quick manipulations with lost funds:
        require(_oldAccount != address(0) && _newAccount != address(0) &&
                originalAddresses[_newAccount] != address(0) && newToOldAccount[_newAccount] != address(0),
                "Trying to get nobody's funds.");
    }

    // Virtual functions //

    /// Find the current address for an original address.
    /// @param _conditional The original address.
    function currentAddress(address _conditional) internal virtual override returns (address) {
        return currentAddresses[_conditional];
    }

    // Modifiers //

    /// We also allow funds restoration by attorneys for convenience of users.
    /// This is not an increased security risk, because a dishonest attorney can anyway tranfer money to himself.
    modifier checkMovedOwner(address _oldAccount, address _newAccount) virtual {
        if (_msgSender() != _newAccount) {
            checkAllowedRestoreAccount(_oldAccount, _newAccount); // only authorized "attorneys" or attorney DAOs
        }

        for (address _account = _oldAccount; _account != _newAccount; _account = newToOldAccount[_account]) {
            require(_account != address(0), "Not a moved owner");
        }

        _;
    }

    // Events //

    event AccountRestored(address oldAccount, address newAccount);

    event AccountUnrestored(address oldAccount, address newAccount);
}
