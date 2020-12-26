// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity ^0.7.1;
import "@openzeppelin/contracts/math/SafeMath.sol";
import "abdk-libraries-solidity/ABDKMath64x64.sol";
import { ERC1155WithMappedAddressesAndTotals } from "./ERC1155/ERC1155WithMappedAddressesAndTotals.sol"; // FIXME: exclude?
import { IERC1155TokenReceiver } from "./ERC1155/IERC1155TokenReceiver.sol";
import { IERC1155 } from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

// TODO