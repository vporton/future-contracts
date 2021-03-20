// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity ^0.7.1;

/// @notice The "DAO plugin" interface.
/// @author Victor Porton
interface DAOInterface {
    /// Check if `msg.sender` is an attorney allowed to restore a given account.
    function checkAllowedRestoreAccount(address _sender, address _oldAccount) external;
}
