// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity ^0.7.1;
import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";
import { ABDKMath64x64 } from "abdk-libraries-solidity/ABDKMath64x64.sol";
import { ERC1155WithMappedAddressesAndTotals } from "./ERC1155/ERC1155WithMappedAddressesAndTotals.sol";
import { IERC1155TokenReceiver } from "./ERC1155/IERC1155TokenReceiver.sol";
import { IERC1155 } from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

abstract contract BaseBaseLock is ERC1155WithMappedAddressesAndTotals, IERC1155TokenReceiver {
    using ABDKMath64x64 for int128;
    using SafeMath for uint256;

    // Condditional tokens vs collaterals.
    enum TokenKind { TOKEN_CONDITIONAL, TOKEN_DONATED }

    /// Emitted when an oracle is created.
    /// @param oracleId The ID of the created oracle.
    event OracleCreated(uint64 oracleId);

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
    
    uint64 internal maxId; // TODO: Make public?

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
    /// Mapping (oracleId => user withdrew in first round) (see `docs/Calculations.md`).
    mapping(uint64 => uint256) public usersWithdrewInFirstRound;

    constructor(string memory uri_) ERC1155WithMappedAddressesAndTotals(uri_) {
        _registerInterface(
            BaseBaseLock(0).onERC1155Received.selector ^
            BaseBaseLock(0).onERC1155BatchReceived.selector
        );
    }

    function changeOracleOwner(address newOracleOwner, uint64 oracleId) public _isOracle(oracleId) {
        oracleOwnersMap[oracleId] = newOracleOwner;
        emit OracleOwnerChanged(newOracleOwner, oracleId);
    }

    function updateGracePeriodEnds(uint64 oracleId, uint time) public _isOracle(oracleId) {
        gracePeriodEnds[oracleId] = time;
    }

    /// Donate funds in a ERC1155 token.
    /// First need to approve the contract to spend the token.
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
        address condition,
        address user,
        bool inFirstRound
    )
        private view returns (uint donatedCollateralTokenId, uint256 donated)
    {
        uint256 conditionalToken = _conditionalTokenId(oracleId, condition);
        uint256 conditionalBalance = balanceOf(user, conditionalToken);
        uint256 totalConditionalBalance =
            inFirstRound ? totalBalanceOf(conditionalToken) : usersWithdrewInFirstRound[oracleId];
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
 
    function collateralOwing(
        IERC1155 collateralContractAddress,
        uint256 collateralTokenId,
        uint64 oracleId,
        address condition,
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

    /// Transfer to `msg.sender` the collateral ERC-20 token (we can't transfer to somebody other, because anybody can transfer).
    /// accordingly to the score of `condition` by the oracle.
    /// After this function is called, it becomes impossible to transfer the corresponding conditional token of `msg.sender`
    /// (to prevent its repeated withdraw).
    ///
    /// Notes:
    /// - It is made impossible to withdraw somebody's other collateral, as otherwise we can't mark non-active accounts.
    /// - It uses _original_ user's address. It is assumed that this operation is done only by professional traders,
    ///   not "regular" users, and they are able to secure their account without account restoration.
    ///   (If we would use restorable account, then we need or don't need `originalAddress()`?)
    function withdrawCollateral(IERC1155 collateralContractAddress, uint256 collateralTokenId, uint64 oracleId, address condition, bytes calldata data) external {
        require(isOracleFinished(oracleId), "too early"); // to prevent the denominator or the numerators change meantime
        bool inFirstRound = _inFirstRound(oracleId);
        uint256 conditionalTokenId = _conditionalTokenId(oracleId, condition);
        userUsedRedeemMap[msg.sender][conditionalTokenId] = true;
        // _burn(msg.sender, conditionalTokenId, conditionalBalance); // Burning it would break using the same token for multiple markets.
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

    /// Disallow transfers of conditional tokens after redeem to prevent "gathering" them before redeeming each oracle.
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

    /// Disallow transfers of conditional tokens after redeem to prevent "gathering" them before redeeming each oracle.
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

    /// Don't send funds to us directy (they will be lost!), use smart contract API.
    function onERC1155Received(address, address, uint256, uint256, bytes calldata) public pure override returns(bytes4) {
        return this.onERC1155Received.selector; // to accept transfers
    }

    function onERC1155BatchReceived(address, address, uint256[] calldata, uint256[] calldata, bytes calldata) public pure override returns(bytes4) {
        return bytes4(0); // We should never receive batch transfers.
    }

    // Getters //

    function oracleOwner(uint64 oracleId) public view returns (address) {
        return oracleOwnersMap[oracleId];
    }

    function isOracleFinished(uint64 /*oracleId*/) public virtual view returns (bool) {
        return true;
    }

    function isConditionalLocked(address condition, uint256 conditionalTokenId) public view returns (bool) {
        return userUsedRedeemMap[condition][conditionalTokenId];
    }

    function gracePeriodEnd(uint64 oracleId) public view returns (uint) {
        return gracePeriodEnds[oracleId];
    }

    // Virtual functions //

    function _mintToCustomer(uint256 conditionalTokenId, uint256 amount, bytes calldata data) internal virtual {
        _mint(msg.sender, conditionalTokenId, amount, data);
    }

    function _calcRewardShare(uint64 oracleId, address condition) internal virtual view returns (int128);

    function _calcMultiplier(uint64 oracleId, address condition, int128 oracleShare) internal virtual view returns (int128) {
        int128 rewardShare = _calcRewardShare(oracleId, condition);
        return oracleShare.mul(rewardShare);
    }

    // Internal //

    function _conditionalTokenId(uint64 oracleId, address condition) internal pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(uint8(TokenKind.TOKEN_CONDITIONAL), oracleId, condition)));
    }

    function _collateralDonatedTokenId(IERC1155 collateralContractAddress, uint256 collateralTokenId, uint64 oracleId) internal pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(uint8(TokenKind.TOKEN_DONATED), collateralContractAddress, collateralTokenId, oracleId)));
    }

    function _checkTransferAllowed(uint256 id, address from) internal view {
        require(!userUsedRedeemMap[originalAddress(from)][id], "You can't trade conditional tokens after redeem.");
    }

    function _baseSafeTransferFrom(address from, address to, uint256 id, uint256 value, bytes memory data) private {
        require(to != address(0), "ERC1155: target address must be non-zero");
        require(
            from == msg.sender || _operatorApprovals[from][msg.sender] == true,
            "ERC1155: need operator approval for 3rd party transfers."
        );

        _doTransfer(id, from, to, value);

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
        }

        emit TransferBatch(msg.sender, from, to, ids, values);

        _doSafeBatchTransferAcceptanceCheck(msg.sender, from, to, ids, values, data);
    }

    function _doTransfer(uint256 id, address from, address to, uint256 value) internal {
        address originalFrom = originalAddress(from);
        _balances[id][originalFrom] = _balances[id][originalFrom].sub(value);
        address originalTo = originalAddress(to);
        _balances[id][originalTo] = value.add(_balances[id][originalTo]);
    }

    function _createOracle() internal returns (uint64) {
        uint64 oracleId = maxId++;
        oracleOwnersMap[oracleId] = msg.sender;
        emit OracleCreated(oracleId);
        emit OracleOwnerChanged(msg.sender, oracleId);
        return oracleId;
    }

    modifier _isOracle(uint64 oracleId) {
        require(oracleOwnersMap[oracleId] == msg.sender, "Not the oracle owner.");
        _;
    }
}
