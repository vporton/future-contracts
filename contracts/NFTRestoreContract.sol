// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity ^0.7.1;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @notice Account restoration contract controlled by NFT.
/// @author Victor Porton
/// FIXME: Combine both NFTs to one ERC-1155 for better interoperability?
contract NFTRestoreContract is ERC721 {
    ERC721 public recipients;
    
    constructor() ERC721("Right to control your salary.", "TakeMySalary") {
        recipients = msg.sender;
    }

    /// For internal use.
    function setRecipients(ERC721 _recipients) public virtual onlyRecipients {
        recipients = _recipients;
    }

    function mint(address _account, uint256 _tokenId) public virtual onlyRecipients {
        require(recipients.ownerOf(_tokenId) == _account, "You are not owner.");
        _mint(_account, _tokenId);
    }

    /// It's useful for transfers of the recipient token, to avoid transferring both tokens.
    function burn(uint256 tokenId) public virtual {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");
        _burn(tokenId);
    }

    function checkRestoreRight(address _origOldAccount) public view {
        require(ownerOf(uint256(_origOldAccount)) == msg.sender, "No restore right.");
    }

    modifier onlyRecipients {
        require(msg.sender == address(recipients), "Only system");
        _;
    }
}
