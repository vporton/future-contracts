// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity ^0.7.1;
import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";
import { ABDKMath64x64 } from "abdk-libraries-solidity/ABDKMath64x64.sol";
import { BaseLock } from "./BaseLock.sol";

/// @title Bidding on Ethereum addresses
/// @author Victor Porton
/// @notice Not audited, not enough tested.
/// This allows anyone claim 1000 conditional tokens in order for him to transfer money from the future.
/// See `docs/future-money.rst`.
///
/// We have three kinds of ERC-1155 token ID
/// - a combination of market ID, collateral address, and customer address (conditional tokens)
/// - a combination of TOKEN_STAKED and collateral address (bequested collateral tokens)
/// - a combination of TOKEN_SUMMARY and collateral address (bequested + bequested collateral tokens)
///
/// In functions of this contact `condition` is always a customer's original address.
abstract contract BaseBidOnAddresses is BaseLock {
    using ABDKMath64x64 for int128;
    using SafeMath for uint256;

    event ReportedNumerator(
        uint64 indexed oracleId,
        address customer,
        uint256 numerator
    );

    event ReportedNumeratorsBatch(
        uint64 indexed oracleId,
        address[] addresses,
        uint256[] numerators
    );

    // Mapping (oracleId => time) the least allowed time of oracles to finish.
    mapping(uint64 => uint) private minFinishTimes;
    // Whether an oracle finished its work.
    mapping(uint64 => bool) private oracleFinishedMap;
    // Mapping (oracleId => (customer => numerator)) for payout numerators.
    mapping(uint64 => mapping(address => uint256)) private payoutNumeratorsMap;
    // Mapping (oracleId => denominator) for payout denominators.
    mapping(uint64 => uint) private payoutDenominatorMap;

    constructor(string memory uri_) BaseLock(uri_) { }

    /// Don't forget to call `updateGracePeriodEnds()` before calling this!
    function updateMinFinishTime(uint64 oracleId, uint time) public _isOracle(oracleId) {
        require(time >= minFinishTimes[oracleId], "Can't break trust of bequestors.");
        minFinishTimes[oracleId] = time;
    }

    function minFinishTime(uint64 oracleId) public view returns (uint) {
        return minFinishTimes[oracleId];
    }

    function payoutNumerator(uint64 oracleId, address condition) public view returns (uint256) {
        return payoutNumeratorsMap[oracleId][condition];
    }

    function payoutDenominator(uint64 oracleId) public view returns (uint256) {
        return payoutDenominatorMap[oracleId];
    }

    /// @dev Called by the oracle owner for reporting results of conditions.
    function reportNumerator(uint64 oracleId, address condition, uint256 numerator) external
        _isOracle(oracleId)
    {
        _updateNumerator(oracleId, numerator, condition);
        emit ReportedNumerator(oracleId, condition, numerator);
    }

    /// @dev Called by the oracle owner for reporting results of conditions.
    function reportNumeratorsBatch(uint64 oracleId, address[] calldata addresses, uint256[] calldata numerators) external
        _isOracle(oracleId)
    {
        require(addresses.length == numerators.length, "Length mismatch.");
        for (uint i = 0; i < addresses.length; ++i) {
            _updateNumerator(oracleId, numerators[i], addresses[i]);
        }
        emit ReportedNumeratorsBatch(oracleId, addresses, numerators);
    }

    /// Need to be called after all numerators were reported.
    function finishOracle(uint64 oracleId) external
        _isOracle(oracleId)
    {
        oracleFinishedMap[oracleId] = true;
        emit OracleFinished(msg.sender);
    }

    function isOracleFinished(uint64 oracleId) public view override returns (bool) {
        return oracleFinishedMap[oracleId] && block.timestamp >= minFinishTimes[oracleId];
    }

    function _updateNumerator(uint64 oracleId, uint256 numerator, address condition) private {
        payoutDenominatorMap[oracleId] = payoutDenominatorMap[oracleId].add(numerator).sub(payoutNumeratorsMap[oracleId][condition]);
        payoutNumeratorsMap[oracleId][condition] = numerator;
    }

    // Virtuals //

    function _calcRewardShare(uint64 oracleId, address condition) internal virtual override view returns (int128) {
        uint256 numerator = payoutNumeratorsMap[oracleId][condition];
        uint256 denominator = payoutDenominatorMap[oracleId];
        return ABDKMath64x64.divu(numerator, denominator);
    }
}
