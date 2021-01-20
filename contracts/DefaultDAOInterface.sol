// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity ^0.7.1;
import "./DAOInterface.sol";

/// @author Victor Porton
/// @notice Not audited, not enough tested.
contract DefaultDAOInterface is DAOInterface {
    function checkAllowedRestoreAccount(address /*_oldAccount*/, address /*_newAccount*/) external pure override {
        revert("unimplemented");
    }

    function checkAllowedUnrestoreAccount(address /*_oldAccount*/, address /*_newAccount*/) external pure override {
        revert("unimplemented");
    }
}
