// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity ^0.7.1;
import { BaseBaseLock } from "./BaseBaseLock.sol";

/// @title Bidding on Ethereum addresses
/// @author Victor Porton
/// @notice Not audited, not enough tested.
/// This allows anyone claim 1000 conditional tokens in order for him to transfer money from the future.
/// See `docs/future-money.rst`.
///
/// We have three kinds of ERC-1155 token ID
/// - a combination of market ID, collateral address, and customer address (conditional tokens)
/// - a combination of TOKEN_STAKED and collateral address (bequested collateral tokens)
/// - a combination of TOKEN_SUMMARY and collateral address (bequested + bequested collateral tokens)
///
/// In functions of this contact `condition` is always a customer's original address.
abstract contract BaseLock is BaseBaseLock {
    constructor(string memory uri_) BaseBaseLock(uri_) { }

    /// Create a new oracle
    function createOracle() external returns (uint64) {
        return _createOracle();
    }
}
