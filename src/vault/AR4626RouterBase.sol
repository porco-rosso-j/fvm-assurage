// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.17;

import {IERC4626, IAR4626RouterBase, ERC20} from "../interfaces/IAR4626RouterBase.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

import {SelfPermit} from "./external/SelfPermit.sol";
import {Multicall} from "./external/Multicall.sol";
import {PeripheryPayments} from "./external/PeripheryPayments.sol";

/// @title ERC4626 Router Base Contract
abstract contract AR4626RouterBase is
    IAR4626RouterBase,
    SelfPermit,
    Multicall,
    PeripheryPayments
{
    using SafeTransferLib for ERC20;

    function mint(
        IERC4626 vault,
        address to,
        uint256 shares,
        uint256 maxAmountIn
    ) public payable virtual override returns (uint256 amountIn) {
        if ((amountIn = vault.mint(shares, to)) > maxAmountIn) {
            revert MaxAmountError();
        }
    }

    function deposit(
        IERC4626 vault,
        address to,
        uint256 amount,
        uint256 minSharesOut
    ) public payable virtual override returns (uint256 sharesOut) {
        if ((sharesOut = vault.deposit(amount, to)) < minSharesOut) {
            revert MinSharesError();
        }
    }

    function withdraw(
        IERC4626 vault,
        address to,
        uint256 amount,
        uint256 maxSharesOut
    ) public payable virtual override returns (uint256 sharesOut) {
        if (
            (sharesOut = vault.withdraw(amount, to, msg.sender)) > maxSharesOut
        ) {
            revert MaxSharesError();
        }
    }

    function redeem(
        IERC4626 vault,
        address to,
        uint256 shares,
        uint256 minAmountOut
    ) public payable virtual override returns (uint256 amountOut) {
        if ((amountOut = vault.redeem(shares, to, msg.sender)) < minAmountOut) {
            revert MinAmountError();
        }
    }
}
