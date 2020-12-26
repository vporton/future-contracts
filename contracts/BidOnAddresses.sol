// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity ^0.7.1;
import "./BaseBidOnAddresses.sol";

/// @title Bidding on Ethereum addresses
/// @author Victor Porton
/// @notice Not audited, not enough tested.
/// This allows anyone claim 1000 conditional tokens in order for him to transfer money from the future.
/// See `docs/future-money.rst` and anyone to donate or bequest.
///
/// We have three kinds of ERC-1155 token ID
/// - a combination of market ID, collateral address, and customer address (conditional tokens)
/// - a combination of TOKEN_DONATED and collateral address (donated collateral tokens)
/// - a combination of TOKEN_BEQUESTED and collateral address (bequested collateral tokens)
///
/// In functions of this contact `condition` is always a customer's original address.
///
/// We receive funds in ERC-1155, see also https://github.com/vporton/wrap-tokens
contract BidOnAddresses is BaseBidOnAddresses {
    using ABDKMath64x64 for int128;
    using SafeMath for uint256;

    uint constant INITIAL_CUSTOMER_BALANCE = 1000 * 10**18; // an arbitrarily choosen value

    event CustomerRegistered(
        address customer,
        uint64 marketId,
        bytes data
    );

    // All conditional tokens.
    mapping(uint256 => bool) private conditionalTokensMap;

    constructor(string memory uri_) BaseBidOnAddresses(uri_) {
        _registerInterface(
            BidOnAddresses(0).onERC1155Received.selector ^
            BidOnAddresses(0).onERC1155BatchReceived.selector
        );
    }

    /// Anyone can register himself.
    /// Can be called both before or after the oracle finish. However registering after the finish is useless.
    function registerCustomer(uint64 marketId, bytes calldata data) external {
        uint256 conditionalTokenId = _conditionalTokenId(marketId, originalAddress(msg.sender));
        require(!conditionalTokensMap[conditionalTokenId], "customer already registered");
        conditionalTokensMap[conditionalTokenId] = true;
        _mintToCustomer(conditionalTokenId, INITIAL_CUSTOMER_BALANCE, data);
        emit CustomerRegistered(msg.sender, marketId, data);
    }
}
