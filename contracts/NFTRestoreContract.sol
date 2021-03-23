// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity ^0.7.1;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "./DAOInterface.sol";

/// @notice Account restoration contract controlled by NFT.
/// @author Victor Porton
contract NFTRestoreContract is DAOInterface, ERC721 {
    constructor() ERC721("Right to control your salary", "TakeMySalary") { }

    /// We can mint only to msg.sender, because MetaMask does not warn about calling this function, that allows fishing.
    function mintRestoreRight(bytes memory _data) public virtual {
        _safeMint(msg.sender, uint256(uint160(msg.sender)), _data);
    }

    function checkAllowedRestoreAccount(address _sender, uint256 _conditionId)
        public view override right(_sender, _conditionId)
    { }

    modifier right(address _sender, uint256 _conditionId) {
        require(ownerOf(uint256(_conditionId)) == _sender, "No restore right.");
        _;
    }
}
