// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity ^0.7.1;
import "./BaseBidOnAddresses.sol";

/// @title "Salary" that is paid one token per second using minted conditionals.
/// @author Victor Porton
/// @notice Not audited, not enough tested.
/// It was considered to allow the DAO to adjust registration date to pay salary retrospectively,
/// but this seems giving too much rights to the DAO similarly as if it had the right to declare anyone dead.
///
/// It would cause this effect: A scientist who is already great may register then his date is moved back
/// in time and instantly he or she receives a very big sum of money to his account.
/// If it is done erroneously, there may be no way to move the registration date again forward in time,
/// because the tokens may be already withdrawn. And it cannot be done in a fully decentralized way because
/// it needs oracles. So errors are seem inevitable.
/// On the other hand, somebody malicious may create and register in my system a pool of Ethereum addresses that
/// individuals can receive from them as if they themselves registered in the past.
/// So it in some cases (if the registration date is past the contract deployment) this issue is impossible to
/// mitigate.
contract BaseSalary is BaseBidOnAddresses {
    /// Salary receiver registered.
    /// @param customer The customer address.
    /// @param oracleId The oracle ID for which he registers.
    /// @param data Additional data.
    event CustomerRegistered(
        address customer,
        uint64 oracleId,
        bytes data
    );

    /// Salary tokens minted.
    /// @param customer The customer address.
    /// @param oracleId The oracle ID.
    /// @param amount The minted amount.
    /// @param data Additional data.
    event SalaryMinted(
        address customer,
        uint64 oracleId,
        uint256 amount,
        bytes data
    );

    /// Salary token recreated.
    /// @param customer The customer address.
    /// @param oldCondition The old token ID.
    /// @param newCondition The new token ID.
    event ConditionReCreate(
        address indexed customer,
        uint256 indexed oldCondition,
        uint256 indexed newCondition
    );

    // Mapping (original address => (condition ID => registration time)).
    mapping(address => mapping(uint256 => uint)) private conditionCreationDates;
    // Mapping (original address => (condition ID => salary block time)).
    mapping(address => mapping(uint256 => uint)) private lastSalaryDates;
    /// Mapping (condition ID => account) - salary recipients.
    mapping(uint256 => address) public salaryReceivers;

    constructor(string memory _uri) BaseBidOnAddresses(_uri) { }

    function mintSalary(uint64 _oracleId, uint64 _condition, bytes calldata _data)
        ensureLastConditionInChain(_condition) external
    {
        uint _lastSalaryDate = lastSalaryDates[msg.sender][_condition];
        require(_lastSalaryDate != 0, "You are not registered.");
        // Note: Even if you withdraw once per 20 years, you will get only 630,720,000 tokens.
        // This number is probably not to big to be displayed well in UIs.
        uint256 _amount = (_lastSalaryDate - block.timestamp) * 10**18; // one token per second
        _mintToCustomer(msg.sender, _condition, _amount, _data);
        lastSalaryDates[msg.sender][_condition] = block.timestamp;
        emit SalaryMinted(msg.sender, _oracleId, _amount, _data);
    }

    /// Make a new condition that replaces the old one.
    /// It is useful to remove a trader's incentive to kill the issuer to reduce the circulating supply.
    /// It's also useful to punish someone for decreasing his work performance or an evil act.
    /// This is to be called among other when a person dies.
    /// The same can be done by transferring to yourself 0 tokens, but this method uses less gas.
    ///
    /// Issue to solve later: Should we recommend:
    /// - calling this function on each new project milestone?
    /// - calling this function regularly (e.g. every week)?
    ///
    /// This function also withdraws the old token.
    function recreateCondition(uint256 _condition) public returns (uint256) {
        return _recreateCondition(_condition);
    }

    /// Get the condition creation time.
    /// @param _customer Original address of the customer.
    /// @param _condition The conditon ID.
    function getConditionCreationDate(address _customer, uint256 _condition) public view returns (uint) {
        return conditionCreationDates[_customer][_condition];
    }

    /// Get the last salary date for a condition.
    /// @param _customer Original address of the customer.
    /// @param _condition The conditon ID.
    function getLastSalaryDate(address _customer, uint256 _condition) public view returns (uint) {
        return lastSalaryDates[_customer][_condition];
    }

    function _doCreateCondition(address _customer) internal virtual override returns (uint256) {
        uint256 _condition = super._doCreateCondition(_customer);
        salaryReceivers[_condition] = _customer;
        conditionCreationDates[_customer][_condition] = block.timestamp;
        return _condition;
    }

    /// Make a new condition that replaces the old one.
    /// The same can be done by transferring to yourself 0 tokens, but this method uses less gas.
    ///
    /// We need to create a new condition every time when an outgoimg transfer of a conditional token happens.
    /// Otherwise an investor would gain if he kills a scientist to reduce the circulating supply of his token to increase the price.
    /// Allowing old tokens to be exchangeable for new ones? (Allowing the reverse swap would create killer's gain.)
    /// Additional benefit of this solution: We can have different rewards at different stages of project,
    /// what may be benefical for early startups funding.
    ///
    /// Problem to be solved later: There should be an advice to switch to a new token at each milestone of a project?
    ///
    /// Anyone can create a ERC-1155 contract that allows to use any of the tokens in the list
    /// by locking any of the tokens in the list as a new "general" token. We should recommend customers not to
    /// use such contracts, because it creates for them the killer exploit.
    ///
    /// If we would exchange the old and new tokens for the same amounts of collaterals, then it would be
    /// effectively the same token and therefore minting more new token would possibly devalue the old one,
    /// thus triggering the killer's exploit again. So we make old and new completely independent.
    ///
    /// Old token is 1:1 converted to the new token.
    ///
    /// Remark: To make easy to exchange the token even if it is recreated, we can make a wrapper or locker
    /// token that uses `firstConditionInChain[]` to aggregate several tokens together.
    /// A similar wrapper (the customer need to `setApprovalForAll()` on it) that uses
    /// `firstToLastConditionInChain[]` can be used to transfer away recreated tokens
    /// even if an evil DAO tries to frontrun the customer by recreating his tokens very often.
    ///
    /// Note: That wrapper could be carelessly used to create the investor's killing customer incentive
    /// by the customer using it to transfer to an investor. Even if the customer uses it only for
    /// exchanges, an investor can buy at an exchange and be a killer.
    /// To make it safe, it must stop accepting any new tokens after a transfer.
    /// It can determine if a token is new just comparing by `<` operator.
    /// It's strongly recommended that an app that uses this contract provides its own swap/exchange UI
    /// and warns the user not to use arbitrary exchanges as being an incentive to kill the user.
    ///
    /// We allow anybody (not just the account owner or DAO) to recreate a condition, because:
    /// - Exchanges can create a "composite" token that allows to withdraw any of the tokens in the chain
    ///   up to a certain period of time (using on-chain `conditionCreationDates`).
    /// - Therefore somebody's token can be withdrawn even if its ID changes arbitrarily often.
    function _recreateCondition(uint256 _condition)
        internal ensureLastConditionInChain(_condition) returns (uint256)
    {
        address _customer = salaryReceivers[_condition];
        uint256 _newCondition = _doCreateCondition(_customer);
        firstConditionInChain[_newCondition] = firstConditionInChain[_condition];

        uint256 _amount = _balances[_condition][_customer];
        _balances[_newCondition][_customer] = _amount;
        _balances[_condition][_customer] = 0;

        // TODO: Should we swap two following lines?
        emit TransferSingle(msg.sender, _customer, address(0), _condition, _amount);
        emit TransferSingle(msg.sender, address(0), _customer, _newCondition, _amount);

        lastSalaryDates[_customer][_newCondition] = lastSalaryDates[_customer][_condition];
        // TODO: Should we here set `lastSalaryDates[_customer][oracleId][_condition] = 0` to save storage space?

        emit ConditionReCreate(_customer, _condition, _newCondition);
        return _newCondition;
    }

    /// Must be called with `id != 0`.
    function isLastConditionInChain(uint256 _id) internal view returns (bool) {
        return firstToLastConditionInChain[firstConditionInChain[_id]] == _id;
    }

    function _doTransfer(uint256 _id, address _from, address _to, uint256 _value) internal virtual override {
        super._doTransfer(_id, _from, _to, _value);

        if (_id != 0 && salaryReceivers[_id] == msg.sender) {
            if (isLastConditionInChain(_id)) { // correct because `_id != 0`
                _recreateCondition(_id);
            }
        }
    }

    function _registerCustomer(address _customer, uint64 _oracleId, bytes calldata _data)
        virtual internal returns (uint256)
    {
        uint256 _condition = _doCreateCondition(_customer);
        require(conditionCreationDates[_customer][_condition] == 0, "You are already registered.");
        lastSalaryDates[_customer][_condition] = block.timestamp;
        emit CustomerRegistered(msg.sender, _oracleId, _data);
        return _condition;
    }

    modifier ensureLastConditionInChain(uint256 _id) {
        require(_isConditional(_id) && _id != 0 && isLastConditionInChain(_id), "Only for the last salary token.");
        _;
    }
}
