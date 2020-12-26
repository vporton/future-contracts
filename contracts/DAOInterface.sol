// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity ^0.7.1;

interface DAOInterface {
    /// Revert if the person is dead.
    /// @param account the current account (not the original account)
    /// TODO: Maybe better to use original account as the argument?
    function checkPersonDead(address account) external;

    function checkAllowedRestoreAccount(address oldAccount_, address newAccount_) external;
}
