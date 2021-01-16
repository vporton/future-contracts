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
        address sender,
        address customer,
        bytes data
    );

    constructor(string memory uri_) BaseBidOnAddresses(uri_) {
        _registerInterface(
            BidOnAddresses(0).onERC1155Received.selector ^
            BidOnAddresses(0).onERC1155BatchReceived.selector
        );
    }

    /// Anyone can register anyone.
    ///
    /// This can be called both before or after the oracle finish. However registering after the finish is useless.
    ///
    /// We check that `oracleId` exists (we don't want "spammers" to register themselves for a million oracles).
    ///
    /// We allow anyone to register anyone. This is useful for being registered by robots.
    /// At first it seems to be harmful to make somebody a millionaire unwillingly (he then needs a fortress and bodyguards),
    /// but: Salary tokens will be worth real money, only if the registered person publishes his works together
    /// with his Ethereum address. So, he can be made rich against his will only by impersonating him. But if somebody
    /// impersonates him, then they are able to present him richer than he is anyway, so making him vulnerable to
    /// kidnappers anyway. So having somebody registered against his will seems not to be a problem at all
    /// (except that he will see superfluous worthless tokens in Etherscan data of his account.)
    ///
    /// An alternative way would be to make registration gasless but requiring a registrant signature.
    /// This is not very good, probably:
    /// - It requires to install MetaMask.
    /// - It bothers the person to sign something, when he could just be hesitant to get what he needs.
    /// - It somehow complicates this contract.
    function registerCustomer(address customer, uint64 oracleId, bytes calldata data) external {
        require(oracleId <= maxOracleId, "Oracle doesn't exist.");
        uint256 _conditionId = _createCondition(customer);
        _mintToCustomer(_conditionId, INITIAL_CUSTOMER_BALANCE, data); // TODO: If we register somebody other, mint not to msg.sender
        emit CustomerRegistered(msg.sender, customer, data); // TODO: Do we need also point here the `msg.sender`?
    }
}
