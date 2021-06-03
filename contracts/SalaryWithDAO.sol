// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity ^0.7.1;
import { ABDKMath64x64 } from "abdk-libraries-solidity/ABDKMath64x64.sol";
import "./BaseRestorableSalary.sol";

/// Salary system with a "DAO" that can assign attorneys to restore lost Ethereum accounts.
/// @author Victor Porton
contract SalaryWithDAO is BaseRestorableSalary {
    using ABDKMath64x64 for int128;

    /// Mapping (current address => account has at least one salary).
    mapping (address => bool) public accountHasSalary;

    // DAO share will be zero to prevent theft by voters and because it can be done instead by future voting.
    // int128 public daoShare = int128(0).div(1); // zero by default

    /// Constructor.
    /// @param _salaryNFT The salary control contract.
    /// @param _uri The ERC-1155 token URI.
    constructor(NFTRestoreContract _salaryNFT, string memory _uri)
        BaseRestorableSalary(_salaryNFT, _uri)
    { }

    /// Create an oracle for caclcualting salary amounts.
    function createOracle(address _oracleOwner) external returns (uint64) {
        return _createOracle(_oracleOwner);
    }

    /// Register a salary recipient.
    ///
    /// Can be called both before or after the oracle finish. However registering after the finish is useless.
    ///
    /// Anyone can register anyone (useful for robots registering a person).
    ///
    /// Registering another person is giving him money against his will (forcing to hire bodyguards, etc.),
    /// but if one does not want, he can just not associate this address with his identity in his publications.
    /// @param _customer The original address.
    /// @param _data The current data.
    function registerCustomer(address _customer, bytes calldata _data)
        virtual public returns (uint256)
    {
        address _orig = _originalAddress(_customer);
        // Auditor: Check that this value is set to false, when (and if) necessary.
        accountHasSalary[_customer] = true;
        return super._registerCustomer(_orig, _data);
    }
}
