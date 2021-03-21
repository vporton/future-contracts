// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity ^0.7.1;

import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IRestorable } from "./IRestorable.sol";

/// @notice Salary recipient NFT.
/// @author Victor Porton
/// The NFT holder is a salary's recipient.
/// Owner of this contract is `BaseRestorableSalary`.
contract NFTSalary is ERC721, Ownable {
    IRestorable salary;

    constructor(IRestorable _salary) ERC721("Salary recipient.", "MySalary") {
        salary = _salary;
    }

    function mint(address _salaryOwner, uint64 _condition, bytes memory _data) public virtual onlyOwner {
        _safeMint(_salaryOwner, _condition, _data);
    }

    function _transfer(address from, address to, uint256 tokenId) internal virtual override {
        super._transfer(from, to, tokenId);
        salary.restoreFunds(from, to, tokenId);
    }
}
