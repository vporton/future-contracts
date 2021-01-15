// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity ^0.7.1;
import "./BaseBidOnAddresses.sol";

/// TODO: Allow the DAO to adjust registration date to pay salary retrospectively?
/// It would cause this effect: A scientist who is already great may register then his date is moved back
/// in time and instantly he or she receives a very big sum of money to his account.
/// If it is done erroneously, there may be no way to move the registration date again forward in time,
/// because the tokens may be already withdrawn. And it cannot be done in a fully decentralized way because
/// it needs oracles. So errors are seem inevitable. If there may be errors, maybe better not to allow it at all?
/// On the other hand, somebody malicious may create and register in my system a pool of Ethereum addresses that
// individuals can receive from them as if they themselves registered in the past.
/// So it in some cases (if the registration date is past the contract deployment) this issue is impossible to
/// mitigate.
/// But should we decide what to disallow to the global voters?
contract Salary is BaseBidOnAddresses {
    event CustomerRegistered(
        address customer,
        uint64 oracleId,
        bytes data
    );

    event SalaryMinted(
        address customer,
        uint64 oracleId,
        uint256 amount,
        bytes data
    );

    /// Mapping from original address to registration time.
    mapping(address => uint) public registrationDates;
    /// Mapping from original address to last salary block time.
    mapping(address => uint) public lastSalaryDates;

    constructor(string memory uri_) BaseBidOnAddresses(uri_) { }

    /// Anyone can register himself.
    /// Can be called both before or after the oracle finish. However registering after the finish is useless.
    function registerCustomer(uint64 oracleId, bytes calldata data) virtual public {
        address orig = originalAddress(msg.sender); // FIXME: Do we need `originalAddress()` here?
        require(registrationDates[orig] == 0, "You are already registered.");
        registrationDates[orig] = block.timestamp;
        lastSalaryDates[orig] = block.timestamp;
        emit CustomerRegistered(msg.sender, oracleId, data);
    }

    function mintSalary(uint64 oracleId, bytes calldata data) external {
        address orig = originalAddress(msg.sender);
        uint lastSalaryDate = lastSalaryDates[orig];
        require(lastSalaryDate != 0, "You are not registered.");
        uint256 conditionalTokenId = _conditionalTokenId(oracleId, originalAddress(msg.sender));
        // FIXME: One token per second produces huge numbers inconvenient for humans. Reduce (how much?)
        uint256 amount = (lastSalaryDate - block.timestamp) * 10**18; // one token per second
        _mintToCustomer(conditionalTokenId, amount, data);
        lastSalaryDates[orig] = block.timestamp;
        emit SalaryMinted(msg.sender, oracleId, amount, data);
    }
}
