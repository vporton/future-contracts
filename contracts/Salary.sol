// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity ^0.7.1;
import "./BaseSalary.sol";

contract Salary is BaseSalary {
    constructor(string memory _uri_) BaseSalary(_uri) { }

    /// Can be called both before or after the oracle finish. However registering after the finish is useless.
    /// @param customer The original address.
    /// @param oracleId The oracle ID.
    /// @param data The current data.
    function registerCustomer(address _customer, uint64 _oracleId, bytes calldata _data)
        virtual public returns (uint256)
    {
        return _registerCustomer(_customer, _oracleId, _data);
    }
}