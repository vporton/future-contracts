// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity ^0.7.1;
import "./Salary.sol";
import "./NFTRestoreContract.sol";

/// @author Victor Porton
/// A base class for salary with receiver accounts that can be restored by an "attorney".
abstract contract BaseRestorableSalary is BaseSalary {
    // INVARIANT: `_originalAddress(newToOldAccounts[newAccount]) == _originalAddress(newAccount)`
    //            if `newToOldAccounts[newAccount] != address(0)` for every `newAccount`
    // INVARIANT: originalAddresses and originalToCurrentAddresses are mutually inverse.
    //            That is:
    //            - `originalAddresses[originalToCurrentAddresses[x]] == x` if `originalToCurrentAddresses[x] != address(0)`
    //            - `originalToCurrentAddresses[originalAddresses[x]] == x` if `originalAddresses[x] != address(0)`

    NFTRestoreContract public salaryNFT;

    /// Mapping (current address => very first address an account had).
    mapping(address => address) public originalAddresses;

    /// Mapping (very first address an account had => current address).
    mapping(address => address) public originalToCurrentAddresses;

    /// Constructor.
    /// @param _uri Our ERC-1155 tokens description URI.
    constructor (NFTRestoreContract _salaryNFT, string memory _uri)
        BaseSalary(_uri)
    {
        salaryNFT = _salaryNFT;
    }

    /// Below copied from https://github.com/vporton/restorable-funds/blob/f6192fd23cad529b84155d52ae202430cd97db23/contracts/RestorableERC1155.sol

    /// Move the entire balance of a token from an old account to a new account of the same user.
    /// @param _oldAccount Old account.
    /// @param _newAccount New account.
    /// @param _token The ERC-1155 token ID.
    /// This function can be called by the affected user.
    ///
    /// Remark: We don't need to create new tokens like as on a regular transfer,
    /// because it isn't a transfer to a trader.
    function restoreFunds(address _oldAccount, address _newAccount, uint256 _token) public {
        salaryNFT.checkRestoreRight(originalAddresses[_oldAccount]);

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
    /// Remark: We don't need to create new tokens like as on a regular transfer,
    /// because it isn't a transfer to a trader.
    function restoreFundsBatch(address _oldAccount, address _newAccount, uint256[] calldata _tokens) public {
        salaryNFT.checkRestoreRight(originalAddresses[_oldAccount]);

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

    // Virtual functions //

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

    // Events //

    event AccountRestored(address indexed oldAccount, address indexed newAccount);

    event AccountUnrestored(address indexed oldAccount, address indexed newAccount);
}
