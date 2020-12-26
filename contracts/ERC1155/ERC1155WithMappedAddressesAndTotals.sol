// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity ^0.7.1;
import "@openzeppelin/contracts/math/SafeMath.sol";
import { ERC1155WithMappedAddresses } from "restorable-funds/contracts/ERC1155WithMappedAddresses.sol";

abstract contract ERC1155WithMappedAddressesAndTotals is ERC1155WithMappedAddresses {
    using SafeMath for uint256;

    // Mapping (token => total).
    mapping(uint256 => uint256) private totalBalances;

    constructor (string memory uri_) ERC1155WithMappedAddresses(uri_) { }

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