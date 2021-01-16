// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity ^0.7.1;
pragma abicoder v2;
import { ABDKMath64x64 } from "abdk-libraries-solidity/ABDKMath64x64.sol";
import { IERC1155 } from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import { BaseLock } from "./BaseLock.sol";

/// @title Locking a token for a collateral.
/// @author Victor Porton
/// @notice Not audited, not enough tested.
/// Lock a token to exchange it for a collateral in the future.
///
/// We have only one condition ID: `0`.
///
/// TODO: This contract is somehow gas-inefficient. Should we release it?
contract Lock is BaseLock {
    using ABDKMath64x64 for int128;

    struct ERC1155Token {
        IERC1155 contractAddress;
        uint256 tokenId;
    }

    event OracleToken(ERC1155Token token);

    /// Mapping (oracleId => external conditional token).
    mapping(uint64 => ERC1155Token) public externalConditionals;

    constructor(string memory uri_) BaseLock(uri_) { }

    /// Create a new oracle
    function createOracle(ERC1155Token calldata token) external returns (uint64) {
        uint64 oracleId = _createOracle();
        externalConditionals[oracleId] = token;
        emit OracleToken(token);
        return oracleId;
    }

    /// Reverts if called after redeem.
    /// TODO: Use `conditionalId` instead of `conditionalTokenId`?
    function mintConditional(uint64 oracleId, uint256 conditionalTokenId, uint256 amount, bytes calldata data)
        public myConditional(conditionalTokenId)
    {
        ERC1155Token storage externalConditional = externalConditionals[oracleId];
        _mintToCustomer(conditionalTokenId, amount, data);
        externalConditional.contractAddress.safeTransferFrom(msg.sender, address(this), externalConditional.tokenId, amount, data); // last against reentrancy attack
    }

    /// Reverts if called after redeem.
    /// TODO: Use `conditionalId` instead of `conditionalTokenId`?
    function burnConditional(uint64 oracleId, uint256 conditionalTokenId, address to, uint256 amount, bytes calldata data)
        public myConditional(conditionalTokenId)
    {
        ERC1155Token storage externalConditional = externalConditionals[oracleId];
        _burn(msg.sender, conditionalTokenId, amount);
        externalConditional.contractAddress.safeTransferFrom(address(this), to, externalConditional.tokenId, amount, data); // last against reentrancy attack
    }

    function _calcRewardShare(uint64 /*oracleId*/, uint256 condition)
        internal virtual override view returns (int128)
    {
        require(condition == 1, "We support only one condition.");
        return int128(1).div(1);
    }

    // We have just one token, so the multiplier is one.
    function _calcMultiplier(uint64 /*oracleId*/, uint256 /*condition*/, int128 oracleShare)
        internal virtual override view returns (int128)
    {
        return oracleShare;
    }
}
