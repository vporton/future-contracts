// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity ^0.7.1;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @notice Account restoration contract controlled by NFT.
/// @author Victor Porton
/// FIXME: Combine both NFTs to one ERC-1155 for better interoperability?
contract NFTRestoreContract is ERC721, Ownable {
    constructor() ERC721("Right to control your salary.", "TakeMySalary") { }

    function mint(address _account, uint256 _tokenId) public virtual onlyOwner {
        _mint(_account, _tokenId);
    }

    // function burn(uint256 tokenId) public virtual {
    //     require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");
    //     _burn(tokenId);
    // }

    // FIXME: It's wrong: If the condition owner transfers his NFTSalaryRecipient but not his NFTRestoreContract to another person, technology
    // then he would not be able to restore lost funds this way. Need to modify the logic.
    // Possible solution: be able to burn notary token (by the notary) and mint it again (by the recipient).
    function checkRestoreRight(address _origOldAccount) public view {
        require(ownerOf(uint256(_origOldAccount)) == msg.sender, "No restore right.");
    }
}
