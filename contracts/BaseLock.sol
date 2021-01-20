// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity ^0.7.1;
import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";
import { ABDKMath64x64 } from "abdk-libraries-solidity/ABDKMath64x64.sol";
import { ERC1155WithTotals } from "./ERC1155/ERC1155WithTotals.sol";
import { IERC1155TokenReceiver } from "./ERC1155/IERC1155TokenReceiver.sol";
import { IERC1155 } from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

/// @author Victor Porton
/// @notice Not audited, not enough tested.
/// A base class to lock collaterals and distribute them proportional to an oracle result.
///
/// One can also donate/bequest a smart wallet (explain how).
///
/// Inheriting from here don't forget to create `createOracle()` external method.
abstract contract BaseLock is ERC1155WithTotals , IERC1155TokenReceiver {
    using ABDKMath64x64 for int128;
    using SafeMath for uint256;

    /// Emitted when an oracle is created.
    /// @param oracleId The ID of the created oracle.
    event OracleCreated(uint64 oracleId);

    /// Emitted when an oracle owner is set.
    /// @param oracleOwner Who created an oracle
    /// @param oracleId The ID of the oracle.
    event OracleOwnerChanged(address oracleOwner, uint64 oracleId);

    event ConditionCreated(address indexed sender, address indexed customer, uint256 indexed condition);

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
    uint64 public maxOracleId; // It doesn't really need to be public.
    uint64 public maxConditionId; // It doesn't really need to be public.

    // Mapping from oracleId to oracle owner.
    mapping(uint64 => address) private oracleOwnersMap;
    // Mapping (oracleId => time) the max time for first withdrawal.
    mapping(uint64 => uint) private gracePeriodEnds;
    // The user lost the right to transfer conditional tokens: (user => (conditionalToken => bool)).
    mapping(address => mapping(uint256 => bool)) private userUsedRedeemMap;
    // Mapping (token => (user => amount)) used to calculate withdrawal of collateral amounts.
    mapping(uint256 => mapping(address => uint256)) public lastCollateralBalanceFirstRoundMap;
    // Mapping (token => (user => amount)) used to calculate withdrawal of collateral amounts.
    mapping(uint256 => mapping(address => uint256)) public lastCollateralBalanceSecondRoundMap;
    /// Mapping (oracleId => amount user withdrew in first round) (see `docs/Calculations.md`).
    mapping(uint64 => uint256) public usersWithdrewInFirstRound;

    // Mapping (condition ID => original account)
    mapping(uint256 => address) public conditionOwners;
    /// Mapping (condition ID => first condition ID in the chain)
    ///
    /// I call _chain_ of conditions the list of conditions resulting from creating and recreating conditions.
    mapping(uint256 => uint256) public firstConditionInChain;
    /// Mapping (first condition ID in the chain => last condition ID in the chain)
    ///
    /// I call _chain_ of conditions the list of conditions resulting from creating and recreating conditions.
    mapping(uint256 => uint256) public firstToLastConditionInChain;

    /// Constructor.
    /// @param _uri Our ERC-1155 tokens description URI.
    constructor(string memory _uri) ERC1155WithTotals(_uri) {
        _registerInterface(
            BaseLock(0).onERC1155Received.selector ^
            BaseLock(0).onERC1155BatchReceived.selector
        );
    }

    /// No need for this function because it would produce a condition with zero tokens.
    // function createCondition() public returns (uint64) {
    //     return _createCondition();
    // }

    /// Modify the owner of an oracle.
    /// @param _newOracleOwner New owner.
    /// @param _oracleId The oracle whose owner to change.
    function changeOracleOwner(address _newOracleOwner, uint64 _oracleId) public _isOracle(_oracleId) {
        oracleOwnersMap[_oracleId] = _newOracleOwner;
        emit OracleOwnerChanged(_newOracleOwner, _oracleId);
    }

    /// Set the end time of the grace period.
    ///
    /// The first withdrawal can be done during the grace period.
    /// The second withdrawal can be done after the end of the grace period and only if the first withdrawal was done.
    ///
    /// The intention of the grace period is to check which of users are active ("alive").
    function updateGracePeriodEnds(uint64 _oracleId, uint _time) public _isOracle(_oracleId) {
        gracePeriodEnds[_oracleId] = _time;
    }

    /// Donate funds in a ERC1155 token.
    ///
    /// First, the collateral token need to be approved to be spent by this contract from the address `from`.
    ///
    /// It also mints a token (with a different ID), that counts donations in that token.
    ///
    /// If we put a DeFi collateral directly as a donation, the APY is lost.
    /// It can be worked around by bequesting a smart contract with the token.
    /// @param _collateralContractAddress The collateral ERC-1155 contract address.
    /// @param _collateralTokenId The collateral ERC-1155 token ID.
    /// @param _oracleId The oracle ID to whose ecosystem to donate to.
    /// @param _amount The amount to donate.
    /// @param _from From whom to take the donation.
    /// @param _to On whose account the donation amount is assigned.
    /// @param _data Additional transaction data.
    function donate(
        IERC1155 _collateralContractAddress,
        uint256 _collateralTokenId,
        uint64 _oracleId,
        uint256 _amount,
        address _from,
        address _to,
        bytes calldata _data) external
    {
        uint _donatedCollateralTokenId = _collateralDonatedTokenId(_collateralContractAddress, _collateralTokenId, _oracleId);
        _mint(_to, _donatedCollateralTokenId, _amount, _data);
        emit DonateCollateral(_collateralContractAddress, _collateralTokenId, _from, _amount, _to, _data);
        _collateralContractAddress.safeTransferFrom(_from, address(this), _collateralTokenId, _amount, _data); // last against reentrancy attack
    }

    function collateralOwingBase(
        IERC1155 _collateralContractAddress,
        uint256 _collateralTokenId,
        uint64 _oracleId,
        uint256 _condition,
        address _user,
        bool _inFirstRound
    )
        private view returns (uint _donatedCollateralTokenId, uint256 _donated)
    {
        uint256 _conditionalBalance = balanceOf(_user, _condition);
        uint256 _totalConditionalBalance =
            _inFirstRound ? totalBalanceOf(_condition) : usersWithdrewInFirstRound[_oracleId];
        _donatedCollateralTokenId = _collateralDonatedTokenId(_collateralContractAddress, _collateralTokenId, _oracleId);
        // Rounded to below for no out-of-funds:
        int128 _oracleShare = ABDKMath64x64.divu(_conditionalBalance, _totalConditionalBalance);
        uint256 _newDividendsDonated =
            totalBalanceOf(_donatedCollateralTokenId) -
            (_inFirstRound
                ? lastCollateralBalanceFirstRoundMap[_donatedCollateralTokenId][_user] 
                : lastCollateralBalanceSecondRoundMap[_donatedCollateralTokenId][_user]);
        int128 _multiplier = _calcMultiplier(_oracleId, _condition, _oracleShare);
        _donated = _multiplier.mulu(_newDividendsDonated);
    }

    /// Calculate how much collateral is owed to a user.
    /// @param _collateralContractAddress The ERC-1155 collateral token contract.
    /// @param _collateralTokenId The ERC-1155 collateral token ID.
    /// @param _oracleId From which oracle's "account" to withdraw.
    /// @param _condition The condition (the original receiver of a conditional token).
    /// @param _user The user to which we may owe.
    function collateralOwing(
        IERC1155 _collateralContractAddress,
        uint256 _collateralTokenId,
        uint64 _oracleId,
        uint256 _condition,
        address _user
    ) external view returns(uint256) {
        bool _inFirstRound = _isInFirstRound(_oracleId);
        (, uint256 _donated) =
            collateralOwingBase(_collateralContractAddress, _collateralTokenId, _oracleId, _condition, _user, _inFirstRound);
        return _donated;
    }

    function _isInFirstRound(uint64 _oracleId) internal view returns (bool) {
        return block.timestamp < gracePeriodEnds[_oracleId];
    }

    /// Transfer to `msg.sender` the collateral ERC-1155 token.
    ///
    /// The amount transfered is proportional to the score of `condition` by the oracle.
    /// @param _collateralContractAddress The ERC-1155 collateral token contract.
    /// @param _collateralTokenId The ERC-1155 collateral token ID.
    /// @param _oracleId From which oracle's "account" to withdraw.
    /// @param _condition The condition (the original receiver of a conditional token).
    /// @param _data Additional data.
    ///
    /// Notes:
    /// - It is made impossible to withdraw somebody's other collateral, as otherwise we can't mark non-active accounts.
    /// - We can't transfer to somebody other than `msg.sender` because anybody can transfer (needed for multi-level transfers).
    /// - After this function is called, it becomes impossible to transfer the corresponding conditional token of `msg.sender`
    ///   (to prevent its repeated withdrawal).
    function withdrawCollateral(
        IERC1155 _collateralContractAddress,
        uint256 _collateralTokenId,
        uint64 _oracleId,
        uint256 _condition,
        bytes calldata _data) external
    {
        require(isOracleFinished(_oracleId), "too early"); // to prevent the denominator or the numerators change meantime
        bool _inFirstRound = _isInFirstRound(_oracleId);
        userUsedRedeemMap[msg.sender][_condition] = true;
        // _burn(msg.sender, _condition, conditionalBalance); // Burning it would break using the same token for multiple markets.
        (uint _donatedCollateralTokenId, uint256 _owingDonated) =
            collateralOwingBase(_collateralContractAddress, _collateralTokenId, _oracleId, _condition, msg.sender, _inFirstRound);

        // Against rounding errors. Not necessary because of rounding down.
        // if(_owing > balanceOf(address(this), _collateralTokenId)) _owing = balanceOf(address(this), _collateralTokenId);

        if (_owingDonated != 0) {
            uint256 _newTotal = totalBalanceOf(_donatedCollateralTokenId);
            if (_inFirstRound) {
                lastCollateralBalanceFirstRoundMap[_donatedCollateralTokenId][msg.sender] = _newTotal;
            } else {
                lastCollateralBalanceSecondRoundMap[_donatedCollateralTokenId][msg.sender] = _newTotal;
            }
        }
        if (!_inFirstRound) {
            usersWithdrewInFirstRound[_oracleId] = usersWithdrewInFirstRound[_oracleId].add(_owingDonated);
        }
        // Last to prevent reentrancy attack:
        _collateralContractAddress.safeTransferFrom(address(this), msg.sender, _collateralTokenId, _owingDonated, _data);
        emit CollateralWithdrawn(
            _collateralContractAddress,
            _collateralTokenId,
            _oracleId,
            msg.sender,
            _owingDonated
        );
    }

    /// A ERC-1155 function.
    ///
    /// We disallow transfers of conditional tokens after redeem to prevent "gathering" them before redeeming each oracle.
    function safeTransferFrom(
        address _from,
        address _to,
        uint256 _id,
        uint256 _value,
        bytes calldata _data
    )
        public override
    {
        _checkTransferAllowed(_id, _from);
        _baseSafeTransferFrom(_from, _to, _id, _value, _data);
    }

    /// A ERC-1155 function.
    ///
    /// We disallow transfers of conditional tokens after redeem _to prevent "gathering" them before redeeming each oracle.
    function safeBatchTransferFrom(
        address _from,
        address _to,
        uint256[] calldata _ids,
        uint256[] calldata _values,
        bytes calldata _data
    )
        public override
    {
        for(uint _i = 0; _i < _ids.length; ++_i) {
            _checkTransferAllowed(_ids[_i], _from);
        }
        _baseSafeBatchTransferFrom(_from, _to, _ids, _values, _data);
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
    /// @param _oracleId The oracle ID.
    function oracleOwner(uint64 _oracleId) public view returns (address) {
        return oracleOwnersMap[_oracleId];
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
    /// @param _user Querying if locked for this user.
    /// @param _condition The condition (the original receiver of a conditional token).
    function isConditionalLocked(address _user, uint256 _condition) public view returns (bool) {
        return userUsedRedeemMap[_user][_condition];
    }

    /// Retrive the end of the grace period.
    /// @param _oracleId For which oracle.
    function gracePeriodEnd(uint64 _oracleId) public view returns (uint) {
        return gracePeriodEnds[_oracleId];
    }

    // Virtual functions //

    function currentAddress(address _originalAddress) internal virtual returns (address) {
        return _originalAddress;
    }

    function _mintToCustomer(address _customer, uint256 _condition, uint256 _amount, bytes calldata _data) internal virtual {
        require(conditionOwners[_condition] == _customer, "Other's salary get attempt.");
        _mint(currentAddress(_customer), _condition, _amount, _data);
    }

    /// Calculate the share of a conditon in an oracle's market.
    /// @param _oracleId The oracle ID.
    /// @return Uses `ABDKMath64x64` number ID.
    function _calcRewardShare(uint64 _oracleId, uint256 _condition) internal virtual view returns (int128);

    function _calcMultiplier(uint64 _oracleId, uint256 _condition, int128 _oracleShare) internal virtual view returns (int128) {
        int128 _rewardShare = _calcRewardShare(_oracleId, _condition);
        return _oracleShare.mul(_rewardShare);
    }

    // Internal //

    /// Generate the ERC-1155 token ID that counts amount of donations for a ERC-1155 collateral token.
    /// @param _collateralContractAddress The ERC-1155 contract of the collateral token.
    /// @param _collateralTokenId The ERC-1155 ID of the collateral token.
    /// @param _oracleId The oracle ID.
    /// Note: It does not conflict with other tokens kinds, becase the only other one is the uint64 conditional.
    function _collateralDonatedTokenId(IERC1155 _collateralContractAddress, uint256 _collateralTokenId, uint64 _oracleId)
        internal pure returns (uint256)
    {
        return uint256(keccak256(abi.encodePacked(_collateralContractAddress, _collateralTokenId, _oracleId)));
    }

    function _checkTransferAllowed(uint256 _id, address _from) internal view {
        require(!userUsedRedeemMap[_from][_id], "You can't trade conditional tokens after redeem.");
    }

    function _baseSafeTransferFrom(address _from, address _to, uint256 _id, uint256 _value, bytes memory _data) private {
        require(_to != address(0), "ERC1155: target address must be non-zero");
        require(
            _from == msg.sender || _operatorApprovals[_from][msg.sender] == true,
            "ERC1155: need operator approval for 3rd party transfers."
        );

        _doTransfer(_id, _from, _to, _value);

        emit TransferSingle(msg.sender, _from, _to, _id, _value);

        _doSafeTransferAcceptanceCheck(msg.sender, _from, _to, _id, _value, _data);
    }

    function _baseSafeBatchTransferFrom(
        address _from,
        address _to,
        uint256[] memory _ids,
        uint256[] memory _values,
        bytes memory _data
    )
        private
    {
        require(_ids.length == _values.length, "ERC1155: IDs and _values must have same lengths");
        require(_to != address(0), "ERC1155: target address must be non-zero");
        require(
            _from == msg.sender || _operatorApprovals[_from][msg.sender] == true,
            "ERC1155: need operator approval for 3rd party transfers."
        );

        for (uint256 _i = 0; _i < _ids.length; ++_i) {
            uint256 _id = _ids[_i];
            uint256 _value = _values[_i];

            _doTransfer(_id, _from, _to, _value);
        }

        emit TransferBatch(msg.sender, _from, _to, _ids, _values);

        _doSafeBatchTransferAcceptanceCheck(msg.sender, _from, _to, _ids, _values, _data);
    }

    function _doTransfer(uint256 _id, address _from, address _to, uint256 _value) internal virtual {
        _balances[_id][_from] = _balances[_id][_from].sub(_value);
        _balances[_id][_to] = _value.add(_balances[_id][_to]);
    }

    function _createOracle() internal returns (uint64) {
        uint64 _oracleId = ++maxOracleId;
        oracleOwnersMap[_oracleId] = msg.sender;
        emit OracleCreated(_oracleId);
        emit OracleOwnerChanged(msg.sender, _oracleId);
        return _oracleId;
    }

    /// Start with 1, not 0, to avoid glitch with `conditionalTokens`.
    ///
    /// TODO: Use uint64 variables instead?
    function _createCondition(address _customer) internal returns (uint256) {
        return _doCreateCondition(_customer);
    }

    /// Start with 1, not 0, to avoid glitch with `conditionalTokens`.
    ///
    /// TODO: Use uint64 variables instead?
    function _doCreateCondition(address _customer) internal virtual returns (uint256) {
        uint64 _conditionId = ++maxConditionId;

        conditionOwners[_conditionId] = _customer;
        firstConditionInChain[_conditionId] = _conditionId;
        firstToLastConditionInChain[_conditionId] = _conditionId;

        emit ConditionCreated(msg.sender, _customer, _conditionId);

        return _conditionId;
    }

    function _isConditional(uint256 _tokenId) internal pure returns (bool) {
        // Zero 2**-192 probability that tokenId < (1<<64) if it's not a conditional.
        // Note to auditor: It's a hack, check for no errors carefully.
        return _tokenId < (1<<64);
    }

    modifier _isOracle(uint64 _oracleId) {
        require(oracleOwnersMap[_oracleId] == msg.sender, "Not the oracle owner.");
        _;
    }

    modifier checkIsConditional(uint256 _tokenId) {
        require(_isConditional(_tokenId), "It's not your conditional.");
        _;
    }
}
