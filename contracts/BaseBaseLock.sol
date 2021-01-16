// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity ^0.7.1;
import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";
import { ABDKMath64x64 } from "abdk-libraries-solidity/ABDKMath64x64.sol";
import { ERC1155WithTotals } from "./ERC1155/ERC1155WithTotals.sol";
import { IERC1155TokenReceiver } from "./ERC1155/IERC1155TokenReceiver.sol";
import { IERC1155 } from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

/// A base class to lock collaterals and distribute them proportional to an oracle result.
///
/// TODO: Ability to split/join conditionals?
/// TODO: If we recreate conditional tokens often, then it is no need to allow DAO to declare somebody dead.
///       The only way we can do this is to require somebody to pay gas for doing it.
abstract contract BaseBaseLock is ERC1155WithTotals , IERC1155TokenReceiver {
    using ABDKMath64x64 for int128;
    using SafeMath for uint256;

    /// Emitted when an oracle is created.
    /// @param oracleId The ID of the created oracle.
    event OracleCreated(uint64 oracleId);

    // TODO: ConditionCreated event with also `oracleId`

    /// Emitted when an oracle owner is set.
    /// @param oracleOwner Who created an oracle
    /// @param oracleId The ID of the oracle.
    event OracleOwnerChanged(address oracleOwner, uint64 oracleId);

    /// Emitted when a collateral is donated.
    /// @param collateralContractAddress The ERC-1155 contract of the donated token.
    /// @param collateralTokenId The ERC-1155 ID of the donated token.
    /// @param sender Who donated.
    /// @param amount The amount donated.
    /// @param to Whose account the donation is assigned to.
    /// @param data Additional transaction data.
    event DonateCollateral(
        IERC1155 collateralContractAddress,
        uint256 collateralTokenId,
        address sender,
        uint256 amount,
        address to,
        bytes data
    );

    /// Emitted when an oracle is marked as having finished its work.
    /// @param oracleId The oracle ID.
    event OracleFinished(uint64 indexed oracleId);

    /// Emitted when collateral is withdrawn.
    /// @param oracleId The ERC-1155 contract of the collateral token.
    /// @param collateralTokenId The ERC-1155 token ID of the collateral.
    /// @param oracleId The oracle ID for which withdrawal is done.
    /// @param user Who has withdrawn.
    /// @param amount The amount withdrawn.
    event CollateralWithdrawn(
        IERC1155 contractAddress,
        uint256 collateralTokenId,
        uint64 oracleId,
        address user,
        uint256 amount
    );

    // Next ID.
    uint64 internal maxOracleId; // TODO: Make public?
    uint64 internal maxConditionId; // TODO: Make public?

    // Mapping from oracleId to oracle owner.
    mapping(uint64 => address) private oracleOwnersMap;
    // Mapping (oracleId => time) the max time for first withdrawal.
    mapping(uint64 => uint) private gracePeriodEnds;
    // The user lost the right to transfer conditional tokens: (user => (conditionalToken => bool)).
    mapping(address => mapping(uint256 => bool)) private userUsedRedeemMap;
    // Mapping (token => (user => amount)) used to calculate withdrawal of collateral amounts.
    mapping(uint256 => mapping(address => uint256)) private lastCollateralBalanceFirstRoundMap; // TODO: Would getter be useful?
    // Mapping (token => (user => amount)) used to calculate withdrawal of collateral amounts.
    mapping(uint256 => mapping(address => uint256)) private lastCollateralBalanceSecondRoundMap; // TODO: Would getter be useful?
    /// Mapping (oracleId => amount user withdrew in first round) (see `docs/Calculations.md`).
    mapping(uint64 => uint256) public usersWithdrewInFirstRound;

    /// Mapping (condition ID => account) - salary recipients.
    mapping(uint64 => address) public customers; // TODO: rename

    /// Constructor.
    /// @param uri_ Our ERC-1155 tokens description URI.
    constructor(string memory uri_) ERC1155WithTotals(uri_) {
        _registerInterface(
            BaseBaseLock(0).onERC1155Received.selector ^
            BaseBaseLock(0).onERC1155BatchReceived.selector
        );
    }

    /// No need for this function because it would produce a condition with zero tokens.
    // function createCondition() public returns (uint64) {
    //     return _createCondition();
    // }

    /// Make a new condition that replaces the old one.
    /// It is useful to remove a trader's incentive to kill the issuer to reduce the circulating supply.
    /// The same can be done by transferring to yourself 0 tokens, but this method uses less gas.
    ///
    /// TODO: Should we recommend:
    /// - calling this function on each new project milestone?
    /// - calling this function regularly (e.g. every week)?
    ///
    /// Note: To sell N tokens need to create a new 1 token that we also need to sell in some future.
    function recreateCondition(uint256 condition) public returns (uint256) {
        return _recreateCondition(condition);
    }

    /// Modify the owner of an oracle.
    /// @param newOracleOwner New owner.
    /// @param oracleId The oracle whose owner to change.
    function changeOracleOwner(address newOracleOwner, uint64 oracleId) public _isOracle(oracleId) {
        oracleOwnersMap[oracleId] = newOracleOwner;
        emit OracleOwnerChanged(newOracleOwner, oracleId);
    }

    /// Set the end time of the grace period.
    ///
    /// The first withdrawal can be done during the grace period.
    /// The second withdrawal can be done after the end of the grace period and only if the first withdrawal was done.
    ///
    /// The intention of the grace period is to check which of users are active ("alive").
    function updateGracePeriodEnds(uint64 oracleId, uint time) public _isOracle(oracleId) {
        gracePeriodEnds[oracleId] = time;
    }

    /// Donate funds in a ERC1155 token.
    ///
    /// First, the collateral token need to be approved to be spent by this contract from the address `from`.
    ///
    /// It also mints a token (with a different ID), that counts donations in that token.
    /// @param collateralContractAddress The collateral ERC-1155 contract address.
    /// @param collateralTokenId The collateral ERC-1155 token ID.
    /// @param oracleId The oracle ID to whose ecosystem to donate to.
    /// @param amount The amount to donate.
    /// @param from From whom to take the donation.
    /// @param to On whose account the donation amount is assigned.
    /// @param data Additional transaction data.
    function donate(
        IERC1155 collateralContractAddress,
        uint256 collateralTokenId,
        uint64 oracleId,
        uint256 amount,
        address from,
        address to,
        bytes calldata data) external
    {
        uint donatedCollateralTokenId = _collateralDonatedTokenId(collateralContractAddress, collateralTokenId, oracleId);
        _mint(to, donatedCollateralTokenId, amount, data);
        emit DonateCollateral(collateralContractAddress, collateralTokenId, from, amount, to, data);
        collateralContractAddress.safeTransferFrom(from, address(this), collateralTokenId, amount, data); // last against reentrancy attack
    }

    function collateralOwingBase(
        IERC1155 collateralContractAddress,
        uint256 collateralTokenId,
        uint64 oracleId,
        uint256 condition,
        address user,
        bool inFirstRound
    )
        private view returns (uint donatedCollateralTokenId, uint256 donated)
    {
        uint256 conditionalBalance = balanceOf(user, condition);
        uint256 totalConditionalBalance =
            inFirstRound ? totalBalanceOf(condition) : usersWithdrewInFirstRound[oracleId];
        donatedCollateralTokenId = _collateralDonatedTokenId(collateralContractAddress, collateralTokenId, oracleId);
        // Rounded to below for no out-of-funds:
        int128 oracleShare = ABDKMath64x64.divu(conditionalBalance, totalConditionalBalance);
        uint256 _newDividendsDonated =
            totalBalanceOf(donatedCollateralTokenId) -
            (inFirstRound
                ? lastCollateralBalanceFirstRoundMap[donatedCollateralTokenId][user] 
                : lastCollateralBalanceSecondRoundMap[donatedCollateralTokenId][user]);
        int128 multiplier = _calcMultiplier(oracleId, condition, oracleShare);
        donated = multiplier.mulu(_newDividendsDonated);
    }

    /// Calculate how much collateral is owed to a user.
    /// @param collateralContractAddress The ERC-1155 collateral token contract.
    /// @param collateralTokenId The ERC-1155 collateral token ID.
    /// @param oracleId From which oracle's "account" to withdraw.
    /// @param condition The condition (the original receiver of a conditional token).
    /// @param user The user to which we may owe.
    function collateralOwing(
        IERC1155 collateralContractAddress,
        uint256 collateralTokenId,
        uint64 oracleId,
        uint256 condition,
        address user
    ) external view returns(uint256) {
        bool inFirstRound = _inFirstRound(oracleId);
        (, uint256 donated) =
            collateralOwingBase(collateralContractAddress, collateralTokenId, oracleId, condition, user, inFirstRound);
        return donated;
    }

    function _inFirstRound(uint64 oracleId) internal view returns (bool) {
        return block.timestamp < gracePeriodEnds[oracleId];
    }

    /// Transfer to `msg.sender` the collateral ERC-1155 token.
    ///
    /// The amount transfered is proportional to the score of `condition` by the oracle.
    /// @param collateralContractAddress The ERC-1155 collateral token contract.
    /// @param collateralTokenId The ERC-1155 collateral token ID.
    /// @param oracleId From which oracle's "account" to withdraw.
    /// @param condition The condition (the original receiver of a conditional token).
    /// @param data Additional data.
    ///
    /// Notes:
    /// - It is made impossible to withdraw somebody's other collateral, as otherwise we can't mark non-active accounts.
    /// - It uses _original_ user's address. It is assumed that this operation is done only by professional traders,
    ///   not "regular" users, and they are able to secure their account without account restoration.
    ///   (TODO: Or do we need to support mapped addresses?)
    /// - We can't transfer to somebody other than `msg.sender` because anybody can transfer (needed for multi-level transfers).
    /// - After this function is called, it becomes impossible to transfer the corresponding conditional token of `msg.sender`
    ///   (to prevent its repeated withdrawal).
    function withdrawCollateral(IERC1155 collateralContractAddress, uint256 collateralTokenId, uint64 oracleId, uint256 condition, bytes calldata data) external {
        require(isOracleFinished(oracleId), "too early"); // to prevent the denominator or the numerators change meantime
        bool inFirstRound = _inFirstRound(oracleId);
        userUsedRedeemMap[msg.sender][condition] = true;
        // _burn(msg.sender, condition, conditionalBalance); // Burning it would break using the same token for multiple markets.
        (uint donatedCollateralTokenId, uint256 _owingDonated) =
            collateralOwingBase(collateralContractAddress, collateralTokenId, oracleId, condition, msg.sender, inFirstRound);

        // Against rounding errors. Not necessary because of rounding down.
        // if(_owing > balanceOf(address(this), collateralTokenId)) _owing = balanceOf(address(this), collateralTokenId);

        if (_owingDonated != 0) {
            uint256 newTotal = totalBalanceOf(donatedCollateralTokenId);
            if (inFirstRound) {
                lastCollateralBalanceFirstRoundMap[donatedCollateralTokenId][msg.sender] = newTotal;
            } else {
                lastCollateralBalanceSecondRoundMap[donatedCollateralTokenId][msg.sender] = newTotal;
            }
        }
        if (!inFirstRound) {
            usersWithdrewInFirstRound[oracleId] = usersWithdrewInFirstRound[oracleId].add(_owingDonated);
        }
        // Last to prevent reentrancy attack:
        collateralContractAddress.safeTransferFrom(address(this), msg.sender, collateralTokenId, _owingDonated, data);
        emit CollateralWithdrawn(
            collateralContractAddress,
            collateralTokenId,
            oracleId,
            msg.sender,
            _owingDonated
        );
    }

    /// A ERC-1155 function.
    ///
    /// We disallow transfers of conditional tokens after redeem to prevent "gathering" them before redeeming each oracle.
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 value,
        bytes calldata data
    )
        public override
    {
        _checkTransferAllowed(id, from);
        _baseSafeTransferFrom(from, to, id, value, data);
    }

    /// A ERC-1155 function.
    ///
    /// We disallow transfers of conditional tokens after redeem to prevent "gathering" them before redeeming each oracle.
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    )
        public override
    {
        for(uint i = 0; i < ids.length; ++i) {
            _checkTransferAllowed(ids[i], from);
        }
        _baseSafeBatchTransferFrom(from, to, ids, values, data);
    }

    /// A ERC-1155 function.
    ///
    /// Don't send funds to us directy (they will be lost!), use the smart contract API.
    function onERC1155Received(address, address, uint256, uint256, bytes calldata) public pure override returns(bytes4) {
        return this.onERC1155Received.selector; // to accept transfers
    }

    /// A ERC-1155 function.
    ///
    /// Always reject batch transfers.
    function onERC1155BatchReceived(address, address, uint256[] calldata, uint256[] calldata, bytes calldata) public pure override returns(bytes4) {
        return bytes4(0); // We should never receive batch transfers.
    }

    // Getters //

    /// Get the oracle owner.
    /// @param oracleId The oracle ID.
    function oracleOwner(uint64 oracleId) public view returns (address) {
        return oracleOwnersMap[oracleId];
    }

    /// Is the oracle marked as having finished its work?
    ///
    /// `oracleId` is the oracle ID.
    function isOracleFinished(uint64 /*oracleId*/) public virtual view returns (bool) {
        return true;
    }

    /// Are transfers of a conditinal token locked?
    ///
    /// This is used to prevent its repeated withdrawal.
    /// @param user Querying if locked for this user.
    /// @param condition The condition (the original receiver of a conditional token).
    function isConditionalLocked(address user, uint256 condition) public view returns (bool) {
        return userUsedRedeemMap[user][condition];
    }

    /// Retrive the end of the grace period.
    /// @param oracleId For which oracle.
    function gracePeriodEnd(uint64 oracleId) public view returns (uint) {
        return gracePeriodEnds[oracleId];
    }

    // Virtual functions //

    function currentAddress(address originalAddress) internal virtual returns (address) {
        return originalAddress;
    }

    function _mintToCustomer(uint256 condition, uint256 amount, bytes calldata data) internal virtual {
        _mint(currentAddress(msg.sender), condition, amount, data);
    }

    /// Calculate the share of a conditon in an oracle's market.
    /// @param oracleId The oracle ID.
    /// @return Uses `ABDKMath64x64` number ID.
    function _calcRewardShare(uint64 oracleId, uint256 condition) internal virtual view returns (int128);

    function _calcMultiplier(uint64 oracleId, uint256 condition, int128 oracleShare) internal virtual view returns (int128) {
        int128 rewardShare = _calcRewardShare(oracleId, condition);
        return oracleShare.mul(rewardShare);
    }

    // Internal //

    /// Generate the ERC-1155 token ID that counts amount of donations for a ERC-1155 collateral token.
    /// @param collateralContractAddress The ERC-1155 contract of the collateral token.
    /// @param collateralTokenId The ERC-1155 ID of the collateral token.
    /// @param oracleId The oracle ID.
    /// Note: It does not conflict with other tokens kinds, becase the only other one is the uint64 conditional.
    function _collateralDonatedTokenId(IERC1155 collateralContractAddress, uint256 collateralTokenId, uint64 oracleId) internal pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(collateralContractAddress, collateralTokenId, oracleId)));
    }

    function _checkTransferAllowed(uint256 id, address from) internal view {
        require(!userUsedRedeemMap[from][id], "You can't trade conditional tokens after redeem.");
    }

    function _baseSafeTransferFrom(address from, address to, uint256 id, uint256 value, bytes memory data) private {
        require(to != address(0), "ERC1155: target address must be non-zero");
        require(
            from == msg.sender || _operatorApprovals[from][msg.sender] == true,
            "ERC1155: need operator approval for 3rd party transfers."
        );

        _doTransfer(id, from, to, value);

        if (id != 0) {
            // FIXME: Call this only when transferred by the conditional minter
            _recreateCondition(id); // FIXME: Only for the last token in the list.
        }

        emit TransferSingle(msg.sender, from, to, id, value);

        _doSafeTransferAcceptanceCheck(msg.sender, from, to, id, value, data);
    }

    function _baseSafeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values,
        bytes memory data
    )
        private
    {
        require(ids.length == values.length, "ERC1155: IDs and values must have same lengths");
        require(to != address(0), "ERC1155: target address must be non-zero");
        require(
            from == msg.sender || _operatorApprovals[from][msg.sender] == true,
            "ERC1155: need operator approval for 3rd party transfers."
        );

        for (uint256 i = 0; i < ids.length; ++i) {
            uint256 id = ids[i];
            uint256 value = values[i];

            _doTransfer(id, from, to, value);

            if (id != 0) {
                // FIXME: Call this only when transferred by the conditional minter
                _recreateCondition(id); // FIXME: Only for the last token in the list.
            }
        }

        emit TransferBatch(msg.sender, from, to, ids, values);

        _doSafeBatchTransferAcceptanceCheck(msg.sender, from, to, ids, values, data);
    }

    function _doTransfer(uint256 id, address from, address to, uint256 value) internal {
        _balances[id][from] = _balances[id][from].sub(value);
        _balances[id][to] = value.add(_balances[id][to]);
    }

    function _createOracle() internal returns (uint64) {
        uint64 oracleId = ++maxOracleId;
        oracleOwnersMap[oracleId] = msg.sender;
        emit OracleCreated(oracleId);
        emit OracleOwnerChanged(msg.sender, oracleId);
        return oracleId;
    }

    /// Start with 1, not 0, to avoid glitch with `conditionalTokens`.
    ///
    /// TODO: Use uint64 variables instead?
    function _createCondition(address customer) internal returns (uint256) {
        uint64 _conditionId = ++maxConditionId;
        customers[_conditionId] = customer; // TODO: Be able to mint for somebody other?
        // TODO
        // emit ConditionCreated(msg.sender, customer, oracleId); // TODO
        // emit ConditionOwnerChanged(customer, oracleId); // TODO
        return _conditionId;
    }

    /// Make a new condition that replaces the old one.
    /// The same can be done by transferring to yourself 0 tokens, but this method uses less gas.
    ///
    /// We need to create a new condition every time when an outgoimg transfer of a conditional token happens.
    /// Otherwise an investor would gain if he kills a scientist to reduce the circulating supply of his token to increase the price.
    /// Allowing old tokens to be exchangeable for new ones? (Allowing the reverse swap would create killer's gain.)
    /// Additional benefit of this solution: We can have different rewards at different stages of project,
    /// what may be benefical for early startups funding.
    /// TODO: There should be an advice to switch to a new token at each milestone of a project?
    ///
    /// TODO: What should this function return?
    ///
    /// Anyone can create a ERC-1155 contract that allows to use any of the tokens in the list
    /// by locking any of the tokens in the list as a new "general" token. We should recommend customers not to
    /// use such contracts, because it creates for them the killer exploit.
    ///
    /// If we would exchange the old and new tokens for the same amounts of collaterals, then it would be
    /// effectively the same token and therefore minting more new token would possibly devalue the old one,
    /// thus triggering the killer's exploit again. So we make old and new completely independent.
    ///
    /// FIXME: Allow to recreate only the last token in the list.
    function _recreateCondition(uint256 _condition) internal myConditional(_condition) returns (uint256) {
        uint256 _newCondition = _createCondition(msg.sender);
        // TODO: Store the linked list of conditional tokens for a condition.
        // TODO: misc
        // TODO: Event that related old and new condition for traders. Also relate them on-chain? (liked list? map to the first condition in the list?)
        return _newCondition;
    }

    modifier _isOracle(uint64 oracleId) {
        require(oracleOwnersMap[oracleId] == msg.sender, "Not the oracle owner.");
        _;
    }

    modifier myConditional(uint256 tokenId) {
        // Zero 2**-192 probability that tokenId < (1<<64) if it's not a conditional.
        // TODO: Check this hack carefully!
        require(tokenId < (1<<64), "It's not your conditional.");
        _;
    }
}
