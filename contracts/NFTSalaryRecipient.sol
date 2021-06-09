// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity ^0.7.1;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @notice The owner of this NFT receives a salary.
/// @author Victor Porton
contract NFTSalaryRecipient is ERC721, Ownable {
    constructor() ERC721("Your salary account.", "MySalary") { }

    function mint(address _account, uint256 _tokenId) public virtual onlyOwner {
        _mint(_account, _tokenId);
    }
}
