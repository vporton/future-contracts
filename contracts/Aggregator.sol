// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity ^0.7.1;
import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { IERC1155 } from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import { ERC1155Holder } from "@openzeppelin/contracts/token/ERC1155/ERC1155Holder.sol";
import { ERC721Holder } from "@openzeppelin/contracts/token/ERC721/ERC721Holder.sol";
import { BaseLock } from "./BaseLock.sol";

contract Enum {
    enum Operation {
        CALL,
        DELEGATE_CALL
    }
}

interface ModuleManager {
}

interface IBequestModule {
    function execute(ModuleManager safe, address to, uint256 value, bytes memory data, Enum.Operation operation)
        external;
    function executeReturnData(ModuleManager safe, address to, uint256 value, bytes memory data, Enum.Operation operation)
        external returns (bytes memory returnData);
}

// FIXME: One this contract for several lockers.
contract Aggregator is ERC721Holder, ERC1155Holder {
    using SafeMath for uint256;

    BaseLock locker;
    IBequestModule bequest;
    IERC1155 erc20Wrapper;
    IERC1155 erc721Wrapper;

    mapping(uint64 => uint256) public oracleBalances;

    constructor(BaseLock _locker, IBequestModule _bequest, IERC1155 _erc20Wrapper, IERC1155 _erc721Wrapper) {
        locker = _locker;
        bequest = _bequest;
        erc20Wrapper = _erc20Wrapper;
        erc721Wrapper = _erc721Wrapper;
        _erc20Wrapper.setApprovalForAll(address(_erc20Wrapper), true);
        _erc721Wrapper.setApprovalForAll(address(_erc721Wrapper), true);
    }

    /// Can be called by anybody.
    function takeDonationERC1155(uint64 _oracleId, ModuleManager _safe, IERC1155 _erc1155Contract, uint256 _tokenId, bytes memory data)
        public
    {
        uint256 _amount = _erc1155Contract.balanceOf(address(_safe), _tokenId);
        oracleBalances[_oracleId] = oracleBalances[_oracleId].add(_amount);
        bytes memory txData = abi.encodeWithSelector(
            bytes4(keccak256("safeTransferFrom(address,address,uint256,uint256,bytes)")),
            address(_safe), address(this), _tokenId, _amount, data);
        bequest.execute(_safe, address(_erc1155Contract), 0, txData, Enum.Operation.CALL);
    }

    /// Can be called by anybody.
    function takeDonationERC20(uint64 _oracleId, ModuleManager _safe, IERC20 _erc20Contract) public {
        bytes memory _data;
        takeDonationERC1155(_oracleId, _safe, erc20Wrapper, uint256(address(_erc20Contract)), _data);
    }

    /// Can be called by anybody.
    function takeDonationERC721(uint64 _oracleId, ModuleManager _safe, IERC721 _erc721Contract) public {
        bytes memory _data;
        takeDonationERC1155(_oracleId, _safe, erc721Wrapper, uint256(address(_erc721Contract)), _data);
    }

    /// Can be called by anybody.
    function sendDonation(uint64 _oracleId, IERC1155 _contractAddress, uint256 _tokenId, bytes calldata _data) public {
        uint256 _amount = _contractAddress.balanceOf(address(this), _tokenId);
        oracleBalances[_oracleId] = oracleBalances[_oracleId].sub(_amount); // reverts on underflow
        locker.donate(
            _contractAddress,
            _tokenId,
            _oracleId,
            _amount,
            address(this),
            address(locker),
            _data);
    }
}
