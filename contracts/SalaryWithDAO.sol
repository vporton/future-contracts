// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity ^0.7.1;
import { ABDKMath64x64 } from "abdk-libraries-solidity/ABDKMath64x64.sol";
import "./BaseRestorableSalary.sol";
import "./DAOInterface.sol";

contract SalaryWithDAO is BaseRestorableSalary {
    using ABDKMath64x64 for int128;

    DAOInterface public daoPlugin;

    /// Minimum allowed interval between adjanced salary token recreations triggered by the DAO.
    ///
    /// This is set once and can't be changed by the DAO:
    ///
    /// TODO: Remove the dictatorship ability to declare anyone dead, instead make possible to forcibly recreate his
    /// token. It's useful to punish someone for decreasing his work performance or an evil act.
    ///
    /// The same feature effectively prevents to register someone for salary before he is born or is a small child.
    ///
    /// However, if the DAO will recreate somebody's token very often, it can harden his life.
    /// So allow DAO to change it no more often than this value.
    /// Auditors: Recommend the exact diapason.
    ///
    /// Mapping (oracle ID => time)
    mapping (uint64 => uint) public minAllowedRecreate;

    /// When set to true, your account can't be moved to new address (by the DAO).
    /// FIXME: Is it original or current address?
    mapping (address => bool) public usersThatRefuseDAOControl;

    // TODO: Is it _original_ address.
    /// Mapping (original address => account has at least one salary).
    /// FIXME: Is it original or current address?
    mapping (address => bool) public accountHasSalary;

    // DAO share will be zero to prevent theft by voters and because it can be done instead by future voting.
    // int128 public daoShare = int128(0).div(1); // zero by default

    constructor(DAOInterface _daoPlugin, string memory uri_)
        BaseRestorableSalary(uri_)
    {
        daoPlugin = _daoPlugin;
    }

    function registerCustomer(address customer, uint64 oracleId, uint minRecreate, bytes calldata data) virtual public {
        address orig = originalAddress(customer);
        super._registerCustomer(orig, oracleId, data);
        // Auditor: Check that this value is set to false, when (and if) necessary.
        accountHasSalary[customer] = true;
        // Salary with refusal of DAO control makes no sense: DAO should be able to declare a salary recipient dead:
        usersThatRefuseDAOControl[customer] = false;
        minAllowedRecreate[oracleId] = minRecreate;
    }

    /// A user can refuse DAO control. Then his account cannot be restored by DAO.
    ///
    /// A user that has a salary can't call this method, because it would make him "deathless" for calculating salary.
    /// So refusing may be recommended only for traders, not for salary receivers.
    ///
    /// Be exteremely careful calling this method: If you refuse and lose your key, your funds are lost!
    ///
    /// DAO control refusal cannot be done by a salary receipient, so it can be done only by a "trader".
    /// Traders are expected to be crypto-responsive persons, so incidentally calling this method is not
    /// to be counted a fishing vulnerability. Thus a funny thing: all people (or rather all Ethereum accounts)
    /// are split into two classes: salary recipients and traders. Traders are free, salaries are under society control.
    ///
    /// TODO: Because there is no more declaring dead, it is reasonable to allow anyone (now only them who
    ///       don't have a salary) to resign from control.
    ///       But fishers may trick one to resign mistakenly. So, make two ERC-1155 contracts:
    ///       with and without the ability to resign?
    function refuseDAOControl(bool _refuse) public {
        address orig = originalAddress(msg.sender);
        require(accountHasSalary[orig], "Cannot resign account receiving a salary.");
        usersThatRefuseDAOControl[orig] = _refuse;
    }

    function setDAO(DAOInterface _daoPlugin) public onlyDAO {
        daoPlugin = _daoPlugin;
    }

    /// Set the token URI.
    function setURI(string memory newuri) public onlyDAO {
        _setURI(newuri);
    }

    function _mintToCustomer(address customer, uint256 conditionalTokenId, uint256 amount, bytes calldata data) internal virtual override {
        super._mintToCustomer(customer, conditionalTokenId, amount, data);
    }

    function forciblyRecalculateSalary(uint256 condition, address account) public onlyDAO {
        // TODO: Check that `minAllowedRecreate` seconds passed.
        _recreateCondition(condition);
    }

    // Overrides ///

    function checkAllowedRestoreAccount(address oldAccount_, address newAccount_) public virtual override {
        // Ensure the user has a salary to make impossible front-running by an evil DAO
        // moving an account to another address, when one tries to refuse DAO control for a new account.
        require(accountHasSalary[oldAccount_], "It isn't a salary account."); // TODO: duplicate code
        if (!usersThatRefuseDAOControl[oldAccount_]) {
            daoPlugin.checkAllowedRestoreAccount(oldAccount_, newAccount_);
        }
    }

    // FIXME: Which checks do we need?
    function checkAllowedUnrestoreAccount(address oldAccount_, address newAccount_) public virtual override {
        // Ensure the user has a salary to make impossible front-running by an evil DAO
        // moving an account to another address, when one tries to refuse DAO control for a new account.
        require(accountHasSalary[oldAccount_], "It isn't a salary account."); // TODO: duplicate code
        if (!usersThatRefuseDAOControl[oldAccount_]) {
            daoPlugin.checkAllowedUnrestoreAccount(oldAccount_, newAccount_);
        }
    }

    // Modifiers //

    modifier onlyDAO() {
        require(msg.sender == address(daoPlugin), "Only DAO can do.");
        _;
    }
}
