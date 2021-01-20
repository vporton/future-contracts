// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity ^0.7.1;
import { BaseLock } from "./BaseLock.sol";

/// @title A class to lock collaterals and distribute them later.
/// @author Victor Porton
/// @notice Not audited, not enough tested.
abstract contract BaseLockWithoutCreateOracle is BaseLock {
    /// Constructor.
    /// @param _uri Our ERC-1155 tokens description URI.
    constructor(string memory _uri) BaseLock(_uri) { }
}
