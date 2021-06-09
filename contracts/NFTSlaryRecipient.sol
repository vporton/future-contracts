// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity ^0.7.1;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

/// @notice The owner of this NFT receives a salary.
/// @author Victor Porton
contract NFTSalaryRecipient is ERC721 {
    constructor() ERC721("Your salary account.", "MySalary") { }

    function mintRestoreRight(bytes memory _data) public virtual {
        _mint(msg.sender, uint256(uint160(msg.sender)), _data); // FIXME: wrong token ID
    }
}
