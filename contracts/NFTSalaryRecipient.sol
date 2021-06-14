// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity ^0.7.1;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @notice The owner of this NFT receives a salary.
/// @author Victor Porton
contract NFTSalaryRecipient is ERC721 {
    ERC721 public notaries;

    constructor() ERC721("Your salary account.", "MySalary") {
        notaries = ERC721(msg.sender);
    }

    /// For internal use.
    function setNotaries(ERC721 _notaries) public virtual onlyNotaries {
        notaries = _notaries;
    }

    function mint(address _account, uint256 _tokenId) public virtual onlyNotaries {
        _mint(_account, _tokenId);
    }

    function transferFrom(address from, address to, uint256 tokenId) public virtual override {
        _requireApproved(tokenId);

        _transfer(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory _data) public virtual override {
        _requireApproved(tokenId);

        _safeTransfer(from, to, tokenId, _data);
    }

    // The owner or notary can transfer
    function _requireApproved(uint256 tokenId) internal virtual {
        //solhint-disable-next-line max-line-length
        require(_isApprovedOrOwner(_msgSender(), tokenId) || notaries.ownerOf(tokenId) == _msgSender(), "ERC721: transfer caller is not owner nor approved");
    }

    modifier onlyNotaries {
        require(msg.sender == address(notaries), "Only system");
        _;
    }
}
