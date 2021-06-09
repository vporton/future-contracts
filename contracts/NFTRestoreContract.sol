// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity ^0.7.1;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

/// @notice Account restoration contract controlled by NFT.
/// @author Victor Porton
contract NFTRestoreContract is ERC721 {
    constructor() ERC721("Right to control your salary.", "TakeMySalary") { }

    /// We can mint only to msg.sender, because MetaMask does not warn about calling this function, that allows fishing.
    // FIXME: It should be associated with a condition not an account!
    function mintRestoreRight(bytes memory _data) public virtual {
        _safeMint(msg.sender, uint256(uint160(msg.sender)), _data);
    }

    function checkRestoreRight(address _origOldAccount) public view {
        require(ownerOf(uint256(_origOldAccount)) == msg.sender, "No restore right.");
    }
}
