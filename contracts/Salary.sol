// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity ^0.7.1;
import "./BaseSalary.sol";

contract Salary is BaseSalary {
    constructor(string memory uri_) BaseSalary(uri_) { }

    /// Can be called both before or after the oracle finish. However registering after the finish is useless.
    /// TODO: Should we have a linked list of all customer's IDs for an oracle?
    /// @param customer The original address.
    /// @param oracleId The oracle ID.
    /// @param data The current data.
    function registerCustomer(address customer, uint64 oracleId, bytes calldata data)
        virtual public returns (uint256)
    {
        return _registerCustomer(customer, oracleId, data);
    }
}