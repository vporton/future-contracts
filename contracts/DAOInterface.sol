// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity ^0.7.1;

interface DAOInterface {
    function checkAllowedRestoreAccount(address _oldAccount, address _newAccount) external;

    function checkAllowedUnrestoreAccount(address _oldAccount, address _newAccount) external;
}
