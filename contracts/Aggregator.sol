// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity ^0.7.1;
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { IERC1155 } from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
// import { BequestModule } from "@vporton/safe-bequest-module/contracts/BequestModule.sol";
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

contract Aggregator {
    BaseLock locker;
    IBequestModule bequest;

    constructor(BaseLock _locker, IBequestModule _bequest) {
        locker = _locker;
        bequest = _bequest;
    }

    /// Can be called by anybody.
    function takeDonationERC1155(ModuleManager _safe, IERC1155 _erc1155Contract, uint256 _tokenId, bytes calldata data) public {
        uint256 _amount = _erc1155Contract.balanceOf(address(_safe), _tokenId);
        bytes memory txData = abi.encodeWithSelector(
            bytes4(keccak256("safeTransferFrom(address,address,uint256,uint256,bytes)")),
            address(_safe), address(this), _tokenId, _amount, data);
        bequest.execute(_safe, address(_erc1155Contract), 0, txData, Enum.Operation.CALL);
    }

    /// Can be called by anybody.
    ///
    /// FIXME: Can the Locker take ERC-20?
    function takeDonationERC20(ModuleManager _safe, IERC20 _erc20Contract) public {
        uint256 _amount = _erc20Contract.balanceOf(address(_safe));
        bytes memory txData = abi.encodeWithSelector(
            bytes4(keccak256("transfer(address,uint256)")),
            address(this), _amount);
        bytes memory resultData = bequest.executeReturnData(_safe, address(_erc20Contract), 0, txData, Enum.Operation.CALL);
        bool result = resultData[0] != 0; // may use non-optimal gas
        require(result, "Transfer failed");
    }

    // TODO: ERC-721

    /// Can be called by anybody.
    ///
    /// FIXME: We should not send to an arbitrary oracle!
    function sendDonation(IERC1155 _contractAddress, uint256 _tokenId, uint64 _oracleId, bytes calldata _data) public {
        uint256 _amount = _contractAddress.balanceOf(address(this), _tokenId);
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
