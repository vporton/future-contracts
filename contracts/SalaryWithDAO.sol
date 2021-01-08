// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity ^0.7.1;
import { ABDKMath64x64 } from "abdk-libraries-solidity/ABDKMath64x64.sol";
import "./BaseRestorableSalary.sol";
import "./DAOInterface.sol";

/// FIXME: Make impossible to register someone for salary before he is born. Also don't register like small children.
contract SalaryWithDAO is BaseRestorableSalary {
    using ABDKMath64x64 for int128;

    DAOInterface public daoPlugin;

    // DAO share will be zero to prevent theft by voters and because it can be done instead by future voting.
    // int128 public daoShare = int128(0).div(1); // zero by default

    constructor(DAOInterface _daoPlugin, string memory uri_) BaseRestorableSalary(uri_) {
        daoPlugin = _daoPlugin;
    }

    function setDAO(DAOInterface _daoPlugin) public onlyDAO {
        daoPlugin = _daoPlugin;
    }

    /// Set the token URI.
    function setURI(string memory newuri) public onlyDAO {
        _setURI(newuri);
    }

    function _mintToCustomer(uint256 conditionalTokenId, uint256 amount, bytes calldata data) internal virtual override {
        daoPlugin.checkPersonDead(msg.sender);
        super._mintToCustomer(conditionalTokenId, amount, data);
    }

    function checkAllowedRestoreAccount(address oldAccount_, address newAccount_) public virtual override {
        daoPlugin.checkAllowedRestoreAccount(oldAccount_, newAccount_);
    }

    modifier onlyDAO() {
        require(msg.sender == address(daoPlugin), "Only DAO can do.");
        _;
    }
}
