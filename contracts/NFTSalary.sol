// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity ^0.7.1;

import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

/// @notice Salary recipient NFT.
/// @author Victor Porton
contract NFTSalary is ERC721, Ownable {
    constructor(address _owner) ERC721("Salary recipient.", "MySalary") { }

    /// We can mint only to msg.sender, because MetaMask does not warn about calling this function, that allows fishing.
    function mint(address _salaryOwner, uint64 _condition, bytes memory _data) public virtual onlyOwner {
        _safeMint(_salaryOwner, _condition, _data);
    }
}
