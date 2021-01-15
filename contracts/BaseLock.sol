// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity ^0.7.1;
import { BaseBaseLock } from "./BaseBaseLock.sol";

/// A class to lock collaterals and distribute them later.
///
/// @author Victor Porton
/// @notice Not audited, not enough tested.
/// This allows anyone claim conditional tokens in order for him to transfer money from the future.
/// See `docs/future-money.rst`.
///
/// We have two kinds of ERC-1155 token IDs:
/// - a combination of market ID, collateral address, and customer address (conditional tokens)
/// - a combination of a collateral contract address and collateral token ID (a counter of donated amount of collateral tokens)
///
/// In functions of this contact `condition` is always a customer's original address.
abstract contract BaseLock is BaseBaseLock {
    /// Constructor.
    /// @param uri_ Our ERC-1155 tokens description URI.
    constructor(string memory uri_) BaseBaseLock(uri_) { }

    /// Create a new oracle
    /// @return Oracle ID.
    function createOracle() external returns (uint64) {
        return _createOracle();
    }
}
