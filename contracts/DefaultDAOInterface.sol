// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity ^0.7.1;
import "@openzeppelin/contracts/access/Ownable.sol";
import "./DAOInterface.sol";

contract DefaultDAOInterface is DAOInterface, Ownable {
    function checkPersonDead(address /*account*/) external pure override { }

    function checkAllowedRestoreAccount(address /*oldAccount_*/, address /*newAccount_*/) external pure override {
        revert("unimplemented");
    }
}
