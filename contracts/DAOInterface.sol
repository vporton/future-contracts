// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity ^0.7.1;

interface DAOInterface {
    function checkAllowedRestoreAccount(address oldAccount_, address newAccount_) external;

    function checkAllowedUnrestoreAccount(address oldAccount_, address newAccount_) external;
}
