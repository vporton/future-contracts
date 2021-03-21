// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity ^0.7.1;

import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

/// @notice Salary recipient NFT.
/// @author Victor Porton
contract NFTSalary is ERC721, Ownable {
    BaseRestorableSalary salary;

    constructor(address _salary, address _owner) ERC721("Salary recipient.", "MySalary") {
        salary = _salary;
    }

    /// We can mint only to msg.sender, because MetaMask does not warn about calling this function, that allows fishing.
    function mint(address _salaryOwner, uint64 _condition, bytes memory _data) public virtual onlyOwner {
        _safeMint(_salaryOwner, _condition, _data);
    }

    /// Move the entire balance of a token from an old account to a new account of the same user.
    /// @param _oldAccount Old account.
    /// @param _newAccount New account.
    /// @param _token The ERC-1155 token ID.
    ///
    /// Remark: We don't need to create new tokens like as on a regular transfer,
    /// because it isn't a transfer to a trader.
    function restoreFunds(address _oldAccount, address _newAccount, uint256 _token) internal
        checkMovedOwner(_oldAccount)
    {
        uint256 _amount = _balances[_token][_oldAccount];

        _balances[_token][_newAccount] = _balances[_token][_oldAccount];
        _balances[_token][_oldAccount] = 0;

        emit TransferSingle(_msgSender(), _oldAccount, _newAccount, _token, _amount);
    }

    function _transfer(address from, address to, uint256 tokenId) internal virtual {
        restoreFunds(from, to, tokenId);
        super._transfer(from, to, tokenId);
    }
}
