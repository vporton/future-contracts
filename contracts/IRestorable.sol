// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity ^0.7.1;

interface IRestorable {
    function restoreFunds(address _oldAccount, address _newAccount, uint256 _token) external;
}