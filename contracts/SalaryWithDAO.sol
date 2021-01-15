// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity ^0.7.1;
import { ABDKMath64x64 } from "abdk-libraries-solidity/ABDKMath64x64.sol";
import "./BaseRestorableSalary.sol";
import "./DAOInterface.sol";

/// We could introduce measures to make impossible to register someone for salary before he is born or is a small child,
/// but that makes no sense, as we can instead just store (e.g. offchain) the hint that his salary to be zero.
contract SalaryWithDAO is BaseRestorableSalary {
    using ABDKMath64x64 for int128;

    DAOInterface public daoPlugin;

    /// When set to true, your account can't be moved to new address (by the DAO).
    mapping (address => bool) public usersThatRefuseDAOControl;

    // DAO share will be zero to prevent theft by voters and because it can be done instead by future voting.
    // int128 public daoShare = int128(0).div(1); // zero by default

    constructor(DAOInterface _daoPlugin, string memory uri_) BaseRestorableSalary(uri_) {
        daoPlugin = _daoPlugin;
    }

    /// A user can refuse DAO control. Then his account cannot be restored by DAO.
    ///
    /// A user that has a salary can't call this method, because it would make him "deathless" for calculating salary.
    /// So refusing may be recommended only for traders, not for salary receivers.
    ///
    /// Be exteremely careful calling this method: If you refuse and lose your key, your salary is lost!
    ///
    /// FIXME: A user may call it under influence of a fisher. How to prevent this possibility?
    /// Maybe better remove "DAO refusal" functionality and just trust the DAO?
    function refuseDAOControl(bool _refuse) public {
        address orig = originalAddress(msg.sender);
        require(registrationDates[orig] == 0, "Cannot resign account receiving a salary.");
        usersThatRefuseDAOControl[orig] = _refuse;
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
        // Ensure the user has a salary to make impossible front-running by an evil DAO
        // moving an account to another address, when one tries to refuse DAO control for a new account.
        require(registrationDates[oldAccount_] != 0, "It isn't a salary account.");
        if (!usersThatRefuseDAOControl[oldAccount_]) {
            daoPlugin.checkAllowedRestoreAccount(oldAccount_, newAccount_);
        }
    }

    // Overrides ///

    function registerCustomer(uint64 oracleId, bytes calldata data) virtual override public {
        address orig = originalAddress(msg.sender); // FIXME: Do we need `originalAddress()` here?
        // Salary with refusal of DAO control makes no sense: DAO should be able to declare a salary recipient dead:
        usersThatRefuseDAOControl[orig] = false;
        super.registerCustomer(oracleId, data);
    }

    // Modifiers //

    modifier onlyDAO() {
        require(msg.sender == address(daoPlugin), "Only DAO can do.");
        _;
    }
}
