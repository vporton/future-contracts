// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity ^0.7.1;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @notice Account restoration contract controlled by NFT.
/// @author Victor Porton
contract NFTRestoreContract is ERC721, Ownable {
    constructor() ERC721("Right to control your salary.", "TakeMySalary") { }

    function mint(address _account, uint256 _tokenId) public virtual onlyOwner {
        _mint(_account, _tokenId);
    }

    function checkRestoreRight(address _origOldAccount) public view {
        require(ownerOf(uint256(_origOldAccount)) == msg.sender, "No restore right.");
    }
}
