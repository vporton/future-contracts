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
    ///
    /// By default new users are not under DAO control to avoid front-running of resigning control
    /// by an evil DAO.
    /// FIXME: Is it original or current address?
    mapping (address => bool) public underDAOControl;

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

    // FIXME: Mistakenly overloads with the same named function in a base contract.
    function createOracle(uint minRecreate) external returns (uint64) {
        uint64 oracleId = _createOracle();
        minAllowedRecreate[oracleId] = minRecreate;
        return oracleId;
    }

    function registerCustomer(address customer, uint64 oracleId, bool _underDAOControl, bytes calldata data) virtual public {
        address orig = originalAddress(customer);
        super._registerCustomer(orig, oracleId, data);
        // Auditor: Check that this value is set to false, when (and if) necessary.
        accountHasSalary[customer] = true;
        underDAOControl[customer] = _underDAOControl; // TODO: Every assignment to `underDAOControl` should trigger an event?
    }

    /// A user can agree for DAO control. Then his account can be restored by DAO for the expense
    /// of the DAO assigned personnel or software being able to steal his funds.
    ///
    /// Be exteremely careful calling this method: If you refuse and lose your key, your funds are lost!
    ///
    /// TODO: Fishers may trick one to resign mistakenly. So, make two ERC-1155 contracts:
    ///       with and without the ability to resign?
    function setDAOControl(bool _underControl) public {
        address orig = originalAddress(msg.sender);
        require(accountHasSalary[orig], "Cannot resign account receiving a salary.");
        underDAOControl[orig] = _underControl;
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

    /// This is to be called among other when a person dies.
    // TODO: Should be called directly by the DAO or by anyone who passes a check by the DAO?
    function forciblyRecalculateSalary(uint256 condition, address account) public onlyDAO {
        // TODO: Check that `minAllowedRecreate` seconds passed.
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
