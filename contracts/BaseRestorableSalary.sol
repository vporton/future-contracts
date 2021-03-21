// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity ^0.7.1;
import "./Salary.sol";
import { NFTSalary } from "./NFTSalary.sol";

/// @author Victor Porton
/// A base class for salary with receiver accounts that can be restored by an "attorney".
abstract contract BaseRestorableSalary is BaseSalary {
    // INVARIANT: originalAddresses and originalToCurrentAddresses are mutually inverse.
    //            That is:
    //            - `originalAddresses[originalToCurrentAddresses[x]] == x` if `originalToCurrentAddresses[x] != address(0)`
    //            - `originalToCurrentAddresses[originalAddresses[x]] == x` if `originalAddresses[x] != address(0)`

    /// Mapping (current address => very first address an account had).
    mapping(address => address) public originalAddresses;

    /// Mapping (very first address an account had => current address).
    mapping(address => address) public originalToCurrentAddresses;

    /// Constructor.
    /// @param _uri Our ERC-1155 tokens description URI.
    constructor (NFTSalary _nftSalary, string memory _uri) BaseSalary(_nftSalary, _uri) { }

    /// Below copied from https://github.com/vporton/restorable-funds/blob/f6192fd23cad529b84155d52ae202430cd97db23/contracts/RestorableERC1155.sol

    /// Move the entire balance of a token from an old account to a new account of the same user.
    /// @param _oldAccount Old account.
    /// @param _newAccount New account.
    /// @param _token The ERC-1155 token ID.
    ///
    /// Remark: We don't need to create new tokens like as on a regular transfer,
    /// because it isn't a transfer to a trader.
    function restoreFunds(address _oldAccount, address _newAccount, uint256 _token) public
        checkMovedOwner(_oldAccount)
    {
        uint256 _amount = _balances[_token][_oldAccount];

        salaryReceivers[_token] = _newAccount;
        _balances[_token][_newAccount] = _balances[_token][_oldAccount];
        _balances[_token][_oldAccount] = 0;

        emit TransferSingle(_msgSender(), _oldAccount, _newAccount, _token, _amount);
    }

    /// Move the entire balance of tokens from an old account to a new account of the same user.
    /// @param _oldAccount Old account.
    /// @param _newAccount New account.
    /// @param _tokens The ERC-1155 token IDs.
    ///
    /// Remark: We don't need to create new tokens like as on a regular transfer,
    /// because it isn't a transfer to a trader.
    function restoreFundsBatch(address _oldAccount, address _newAccount, uint256[] calldata _tokens) public
        checkMovedOwner(_oldAccount)
    {
        uint256[] memory _amounts = new uint256[](_tokens.length);
        for (uint _i = 0; _i < _tokens.length; ++_i) {
            restoreFunds(_oldAccount, _newAccount, _tokens[_i]);
        }

        emit TransferBatch(_msgSender(), _oldAccount, _newAccount, _tokens, _amounts);
    }

    // Virtual functions //

    /// Check if `msg.sender` is an attorney allowed to restore a user's account.
    function checkAllowedRestoreAccount(address _sender, address /*_oldAccount*/) public virtual;

    /// Find the original address of a given account.
    /// This function is internal, because it can be calculated off-chain.
    /// @param _account The current address.
    function _originalAddress(address _account) internal view virtual returns (address) {
        address _newAddress = originalAddresses[_account];
        return _newAddress != address(0) ? _newAddress : _account;
    }

    // Find the current address for an original address.
    // @param _conditional The original address.
    function originalToCurrentAddress(address _customer) internal virtual override returns (address) {
        address current = originalToCurrentAddresses[_customer];
        return current != address(0) ? current : _customer;
    }

    // TODO: Is the following function useful to save gas in other contracts?
    // function getCurrent(address _account) public returns (uint256) {
    //     address _original = originalAddresses[_account];
    //     return _original == 0 ? 0 : originalToCurrentAddress(_original);
    // }

    // Modifiers //

    /// Check that `_newAccount` is the user that has the right to restore funds from `_oldAccount`.
    ///
    /// We also allow funds restoration by attorneys for convenience of users.
    /// This is not an increased security risk, because a dishonest attorney can anyway transfer money to himself.
    modifier checkMovedOwner(address _oldAccount) virtual {
        checkAllowedRestoreAccount(msg.sender, _oldAccount); // only authorized "attorneys" or attorney DAOs
        _;
    }

    // Events //

    event AccountRestored(address indexed oldAccount, address indexed newAccount);

    event AccountUnrestored(address indexed oldAccount, address indexed newAccount);
}
