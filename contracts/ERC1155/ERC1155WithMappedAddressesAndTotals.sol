// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity ^0.7.1;
import "@openzeppelin/contracts/math/SafeMath.sol";
import { ERC1155 } from "./ERC1155.sol";

/// @title A base contract for an ERC-1155 contract with the abilitity to change user's addresses and with calculation of totals.
/// To each address it corresponds an _original address_.
///
/// BUG: This contract and dependent ones (TODO: enumerate here) may not emit events it should by ERC-1155 specification
/// when called with `_upgradeAccounts()`. No reasonable way to fix it.
/// It can be worked around by creatign a locker contract.
abstract contract ERC1155WithMappedAddressesAndTotals is ERC1155 {
    using SafeMath for uint256;

    /// mapping from old to new account addresses
    mapping(address => address) public originalAddresses;

    // Mapping (token => total).
    mapping(uint256 => uint256) private totalBalances;

    /// Construct a token with given description URI.
    /// @param uri_ Description URI.
    constructor (string memory uri_) ERC1155(uri_) { }

    /// Virtual function to return the original wallet address for a given current wallet address.
    ///
    /// When overriding this function, don't forget to override also `_upgradeAccounts()`.
    ///
    /// @param account The current wallet address.
    ///
    /// The default implementation returns `account`.
    function originalAddress(address account) public virtual view returns (address) {
        return account;
    }

    // Internal functions //

    /// The function that upgrades (like `originalAddress()`) an array of accounts
    function _upgradeAccounts(address[] memory accounts) internal virtual view {
    }

    // Overrides //

    function balanceOf(address account, uint256 id) public view override returns (uint256) {
        return super.balanceOf(originalAddress(account), id);
    }

    function balanceOfBatch(address[] memory accounts, uint256[] memory ids)
        public view override returns (uint256[] memory)
    {
        _upgradeAccounts(accounts);
        return super.balanceOfBatch(accounts, ids);
    }

    function setApprovalForAll(address operator, bool approved) public virtual override {
        return super.setApprovalForAll(originalAddress(operator), approved);
    }

    function isApprovedForAll(address account, address operator) public view override returns (bool) {
        return super.isApprovedForAll(originalAddress(account), operator);
    }

    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes memory data)
        public virtual override
    {
        return super.safeTransferFrom(originalAddress(from), originalAddress(to), id, amount, data);
    }

    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    )
        public virtual override
    {
        return super.safeBatchTransferFrom(originalAddress(from), originalAddress(to), ids, amounts, data);
    }
    
    // Need also update totals - commented out
    // function _mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) internal virtual override {
    //     return super._mintBatch(originalAddress(to), ids, amounts, data);
    // }

    // Need also update totals - commented out
    // function _burnBatch(address account, uint256[] memory ids, uint256[] memory amounts) internal virtual override {
    //     return super._burnBatch(originalAddress(account), ids, amounts);
    // }

    function totalBalanceOf(uint256 id) public view returns (uint256) {
        return totalBalances[id];
    }

    function _mint(address to, uint256 id, uint256 value, bytes memory data) internal override {
        require(to != address(0), "ERC1155: mint to the zero address");

        _doMint(to, id, value);
        emit TransferSingle(msg.sender, address(0), to, id, value);

        _doSafeTransferAcceptanceCheck(msg.sender, address(0), to, id, value, data);
    }

    function _batchMint(address to, uint256[] memory ids, uint256[] memory values, bytes memory data) internal {
        require(to != address(0), "ERC1155: batch mint to the zero address");
        require(ids.length == values.length, "ERC1155: IDs and values must have same lengths");

        for(uint i = 0; i < ids.length; i++) {
            _doMint(to, ids[i], values[i]);
        }

        emit TransferBatch(msg.sender, address(0), to, ids, values);

        _doSafeBatchTransferAcceptanceCheck(msg.sender, address(0), to, ids, values, data);
    }

    function _burn(address owner, uint256 id, uint256 value) internal override {
        _doBurn(owner, id, value);
        emit TransferSingle(msg.sender, owner, address(0), id, value);
    }

    function _batchBurn(address owner, uint256[] memory ids, uint256[] memory values) internal {
        require(ids.length == values.length, "ERC1155: IDs and values must have same lengths");

        for(uint i = 0; i < ids.length; i++) {
            _doBurn(owner, ids[i], values[i]);
        }

        emit TransferBatch(msg.sender, owner, address(0), ids, values);
    }

    function _doMint(address to, uint256 id, uint256 value) private {
        address originalTo = originalAddress(to);
        totalBalances[id] = totalBalances[id].add(value);
        _balances[id][originalTo] = _balances[id][originalTo] + value; // The previous didn't overflow, therefore this doesn't overflow.
    }

    function _doBurn(address from, uint256 id, uint256 value) private {
        address originalFrom = originalAddress(from);
        _balances[id][originalFrom] = _balances[id][originalFrom].sub(value);
        totalBalances[id] = totalBalances[id] - value; // The previous didn't overflow, therefore this doesn't overflow.
    }
}