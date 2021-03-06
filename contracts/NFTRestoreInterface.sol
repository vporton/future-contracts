// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity ^0.7.1;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "./DAOInterface.sol";

/// @notice Account restoration contract controlled by NFT.
/// @author Victor Porton
/// @notice Not audited, not enough tested.
contract NFTRestoreInterface is DAOInterface, ERC721 {
    constructor() ERC721("Right to restore my account", "RESTORE") { }

    function mintRestoreRight(address to, bytes memory _data) public virtual {
        _safeMint(to, uint256(uint160(msg.sender)), _data);
    }

    function checkAllowedRestoreAccount(address _oldAccount, address /*_newAccount*/)
        public view override right(_oldAccount)
    { }

    function checkAllowedUnrestoreAccount(address _oldAccount, address /*_newAccount*/)
        public view override right(_oldAccount)
    { }

    modifier right(address _oldAccount) {
        address orig = _oldAccount;
        require(ownerOf(uint256(orig)) == msg.sender, "No restore right.");
        _;
    }
}
