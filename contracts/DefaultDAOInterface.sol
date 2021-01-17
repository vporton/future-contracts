// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity ^0.7.1;
import "./DAOInterface.sol";

contract DefaultDAOInterface is DAOInterface {
    function checkAllowedRestoreAccount(address /*oldAccount_*/, address /*newAccount_*/) external pure override {
        revert("unimplemented");
    }

    function checkAllowedUnrestoreAccount(address /*oldAccount_*/, address /*newAccount_*/) external pure override {
        revert("unimplemented");
    }
}
