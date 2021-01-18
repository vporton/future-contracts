// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity ^0.7.1;
import { ABDKMath64x64 } from "abdk-libraries-solidity/ABDKMath64x64.sol";
import "./BaseRestorableSalary.sol";
import "./DAOInterface.sol";

contract SalaryWithDAO is BaseRestorableSalary {
    using ABDKMath64x64 for int128;

    DAOInterface public daoPlugin;

    /// When set to true, your account can't be moved to new address (by the DAO).
    ///
    /// By default new users are not under DAO control to avoid front-running of resigning control
    /// by an evil DAO.
    /// FIXME: Is it original or current address?
    mapping (address => bool) public underDAOControl;

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

    function createOracle() external returns (uint64) {
        return _createOracle();
    }

    function registerCustomer(address customer, uint64 oracleId, bool _underDAOControl, bytes calldata data)
        virtual public returns (uint256)
    {
        address orig = originalAddress(customer);
        // Auditor: Check that this value is set to false, when (and if) necessary.
        accountHasSalary[customer] = true;
        underDAOControl[customer] = _underDAOControl; // We don't trigger and event to reduce gas usage.
        return super._registerCustomer(orig, oracleId, data);
    }

    /// A user can agree for DAO control. Then his account can be restored by DAO for the expense
    /// of the DAO assigned personnel or software being able to steal his funds.
    ///
    /// Be exteremely careful calling this method: If you refuse and lose your key, your funds are lost!
    ///
    /// Fishers may trick one to resign mistakenly. However, it's no much worse than just fishing for
    /// withdrawing the salary token, because a user could just register anew and notify traders/oracles
    /// that it's the same person.
    function setDAOControl(bool _underControl) public {
        address orig = originalAddress(msg.sender);
        require(accountHasSalary[orig], "Cannot resign account receiving a salary.");
        underDAOControl[orig] = _underControl; // We don't trigger and event to reduce gas usage.
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

    /// It's useful to punish someone for decreasing his work performance or an evil act.
    ///
    /// This is to be called among other when a person dies.
    ///
    /// TODO: Should be called directly by the DAO or by anyone who passes a check by the DAO?
    ///
    /// TODO: Maybe allow forcing recalculation by anybody, not just the DAO? We can wrap several tokens into one anyway,
    /// so it would not much disturb the user.
    function forciblyRecalculateSalary(uint256 condition) public onlyDAO {
        _recreateCondition(condition);
    }

    // Overrides ///

    function checkAllowedRestoreAccount(address oldAccount_, address newAccount_)
        public virtual override isUnderDAOControl(oldAccount_)
    {
        daoPlugin.checkAllowedRestoreAccount(oldAccount_, newAccount_);
    }

    // TODO: Do we need isUnderDAOControl(oldAccount_) here?
    // TODO: Allow the user to unrestore by himself?
    function checkAllowedUnrestoreAccount(address oldAccount_, address newAccount_)
        public virtual override isUnderDAOControl(oldAccount_)
    {
        daoPlugin.checkAllowedUnrestoreAccount(oldAccount_, newAccount_);
    }

    // Modifiers //

    modifier onlyDAO() {
        require(msg.sender == address(daoPlugin), "Only DAO can do.");
        _;
    }

    /// @param customer The current address.
    modifier isUnderDAOControl(address customer) {
        require(underDAOControl[customer], "Not under DAO control.");
        _;
    }
}
