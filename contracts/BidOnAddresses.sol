// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity ^0.7.1;
import "./BaseBidOnAddresses.sol";

/// @title Bidding on Ethereum addresses
/// @author Victor Porton
/// @notice Not audited, not enough tested.
/// This allows anyone claim 1000 conditional tokens in order for him to transfer money from the future.
/// See `docs/future-money.rst` and anyone to donate.
///
/// We have three kinds of ERC-1155 token ID
/// - a combination of market ID, collateral address, and customer address (conditional tokens)
/// - a combination of TOKEN_DONATED and collateral address (donated collateral tokens)
///
/// In functions of this contact `condition` is always a customer's original address.
///
/// We receive funds in ERC-1155, see also https://github.com/vporton/wrap-tokens
contract BidOnAddresses is BaseBidOnAddresses {
    uint constant INITIAL_CUSTOMER_BALANCE = 1000 * 10**18; // an arbitrarily choosen value

    event CustomerRegistered(
        address customer,
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
    ///
    /// We check that `oracleId` exists (we don't want "spammers" to register themselves for a million oracles).
    ///
    /// FIXME: Add ability to register somebody other?
    function registerCustomer(uint64 oracleId, bytes calldata data) external {
        require(oracleId <= maxId, "Oracle doesn't exist."); // FIXME: Using maxId both for oracles and conditions is an error (here an in other places?)
        uint64 _conditionId = _createCondition();
        conditionalTokensMap[_conditionId] = true; // FIXME: Remove this map field. Use the principle of myConditional modifier instead
        _mintToCustomer(_conditionId, INITIAL_CUSTOMER_BALANCE, data);
        emit CustomerRegistered(msg.sender, data);
    }
}
