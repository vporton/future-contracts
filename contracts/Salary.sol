// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity ^0.7.1;
import "./BaseSalary.sol";

/// @author Victor Porton
/// @notice Not audited, not enough tested.
contract Salary is BaseSalary {
    constructor(string memory _uri) BaseSalary(_uri) { }

    /// Can be called both before or after the oracle finish. However registering after the finish is useless.
    /// @param _customer The original address.
    /// @param _oracleId The oracle ID.
    /// @param _data The current data.
    function registerCustomer(address _customer, uint64 _oracleId, bytes calldata _data)
        virtual public returns (uint256)
    {
        return _registerCustomer(_customer, _oracleId, _data);
    }
}