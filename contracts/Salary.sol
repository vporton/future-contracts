// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity ^0.7.1;
import "./BaseBidOnAddresses.sol";

/// TODO: Allow the DAO to addjust registration date to pay salary retrospectively?
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

    /// Mapping from original address to last salary block time.
    mapping(address => uint) public lastSalaryDates;

    constructor(string memory uri_) BaseBidOnAddresses(uri_) { }

    /// Anyone can register himself.
    /// Can be called both before or after the oracle finish. However registering after the finish is useless.
    function registerCustomer(uint64 oracleId, bytes calldata data) external {
        address orig = originalAddress(msg.sender); // FIXME: Do we need `originalAddress()` here?
        require(lastSalaryDates[orig] == 0, "You are already registered.");
        lastSalaryDates[orig] = block.timestamp;
        emit CustomerRegistered(msg.sender, oracleId, data);
    }

    function mintSalary(uint64 oracleId, bytes calldata data) external {
        address orig = originalAddress(msg.sender);
        uint lastSalaryDate = lastSalaryDates[orig];
        require(lastSalaryDate != 0, "You are not registered.");
        uint256 conditionalTokenId = _conditionalTokenId(oracleId, originalAddress(msg.sender));
        // FIXME: One token per second produces huge numbers inconveniet for humans. Reduce.
        uint256 amount = (lastSalaryDate - block.timestamp) * 10**18; // one token per second
        _mintToCustomer(conditionalTokenId, amount, data);
        lastSalaryDates[orig] = block.timestamp;
        emit SalaryMinted(msg.sender, oracleId, amount, data);
    }
}
