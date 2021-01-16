// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity ^0.7.1;
import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";
import { ABDKMath64x64 } from "abdk-libraries-solidity/ABDKMath64x64.sol";
import { BaseLock } from "./BaseLock.sol";

/// @title Bidding on Ethereum addresses
/// @author Victor Porton
/// @notice Not audited, not enough tested.
/// This allows anyone claim conditional tokens in order for him to transfer money from the future.
/// See `docs/future-money.rst`.
///
/// We have two kinds of ERC-1155 token IDs:
/// - a combination of market ID, collateral address, and customer address (conditional tokens)
/// - a combination of a collateral contract address and collateral token ID (a counter of donated amount of collateral tokens)
///
/// In functions of this contact `condition` is always a customer's original address.
abstract contract BaseBidOnAddresses is BaseLock {
    using ABDKMath64x64 for int128;
    using SafeMath for uint256;

    /// A condition score was stored in the chain by an oracle.
    /// @param oracleId The oracle ID.
    /// @param condition The conditional (customer addresses).
    /// @param numerator The relative score provided by the oracle.
    event ReportedNumerator(
        uint64 indexed oracleId,
        uint256 condition,
        uint256 numerator
    );

    /// Some condition scores were stored in the chain by an oracle.
    /// @param oracleId The oracle ID.
    /// @param conditions The conditionals (customer addresses).
    /// @param numerators The relative scores provided by the oracle.
    event ReportedNumeratorsBatch(
        uint64 indexed oracleId,
        uint64[] conditions,
        uint256[] numerators
    );

    // Whether an oracle finished its work.
    mapping(uint64 => bool) private oracleFinishedMap;
    // Mapping (oracleId => (condition => numerator)) for payout numerators.
    mapping(uint64 => mapping(uint256 => uint256)) private payoutNumeratorsMap;
    // Mapping (oracleId => denominator) for payout denominators.
    mapping(uint256 => uint) private payoutDenominatorMap;

    /// Constructor.
    /// @param uri_ Our ERC-1155 tokens description URI.
    constructor(string memory uri_) BaseLock(uri_) { }

    /// Retrieve the last stored payout numerator (relative score of a condition).
    /// @param oracleId The oracle ID.
    /// @param condition The condition (the original receiver of a conditional token).
    /// The result can't change if the oracle has finished.
    function payoutNumerator(uint64 oracleId, uint256 condition) public view returns (uint256) {
        return payoutNumeratorsMap[oracleId][condition];
    }

    /// Retrieve the last stored payout denominator (the sum of all numerators of the oracle).
    /// @param oracleId The oracle ID.
    /// The result can't change if the oracle has finished.
    function payoutDenominator(uint64 oracleId) public view returns (uint256) {
        return payoutDenominatorMap[oracleId];
    }

    /// Called by the oracle owner for reporting results of conditions.
    /// @param oracleId The oracle ID.
    /// @param condition The condition (the original receiver of a conditional token).
    /// @param numerator The relative score of the condition.
    function reportNumerator(uint64 oracleId, uint256 condition, uint256 numerator) external
        _isOracle(oracleId)
        _oracleNotFinished(oracleId) // otherwise an oracle can break data consistency
    {
        _updateNumerator(oracleId, numerator, condition);
        emit ReportedNumerator(oracleId, condition, numerator);
    }

    /// Called by the oracle owner for reporting results of several conditions.
    /// @param oracleId The oracle ID.
    /// @param conditions The conditions (the original receiver of a conditional token).
    /// @param numerators The relative scores of the condition.
    function reportNumeratorsBatch(uint64 oracleId, uint64[] calldata conditions, uint256[] calldata numerators) external
        _isOracle(oracleId)
        _oracleNotFinished(oracleId) // otherwise an oracle can break data consistency
    {
        require(conditions.length == numerators.length, "Length mismatch.");
        for (uint i = 0; i < conditions.length; ++i) {
            _updateNumerator(oracleId, numerators[i], conditions[i]);
        }
        emit ReportedNumeratorsBatch(oracleId, conditions, numerators);
    }

    /// Need to be called after all numerators were reported.
    /// @param oracleId The oracle ID.
    ///
    /// You should set grace period end time before calling this method.
    function finishOracle(uint64 oracleId) external
        _isOracle(oracleId)
    {
        oracleFinishedMap[oracleId] = true;
        emit OracleFinished(oracleId);
    }

    /// Check if an oracle has finished.
    /// @param oracleId The oracle ID.
    /// @return `true` if it has finished.
    function isOracleFinished(uint64 oracleId) public view override returns (bool) {
        return oracleFinishedMap[oracleId];
    }

    function _updateNumerator(uint64 oracleId, uint256 numerator, uint256 condition) private {
        payoutDenominatorMap[oracleId] = payoutDenominatorMap[oracleId].add(numerator).sub(payoutNumeratorsMap[oracleId][condition]);
        payoutNumeratorsMap[oracleId][condition] = numerator;
    }

    // Virtuals //

    function _calcRewardShare(uint64 oracleId, uint256 condition) internal virtual override view returns (int128) {
        uint256 numerator = payoutNumeratorsMap[oracleId][condition];
        uint256 denominator = payoutDenominatorMap[oracleId];
        return ABDKMath64x64.divu(numerator, denominator);
    }

    // Modifiers //

    modifier _oracleNotFinished(uint64 oracleId) {
        require(!isOracleFinished(oracleId), "Oracle is finished.");
        _;
    }
}
