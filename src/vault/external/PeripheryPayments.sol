// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.7;

import "solmate/utils/SafeTransferLib.sol";
import {IWFIL} from "../../interfaces/IWFIL.sol";

abstract contract PeripheryPayments {
    using SafeTransferLib for *;

    IWFIL public immutable WFIL;

    constructor(IWFIL _WFIL) {
        WFIL = _WFIL;
    }

    receive() external payable {}

    function approve(ERC20 token, address to, uint256 amount) public payable {
        token.safeApprove(to, amount);
    }

    function unwrapWFIL(uint256 amountMinimum, address recipient) public payable {
        uint256 balanceWFIL = WFIL.balanceOf(address(this));
        require(balanceWFIL >= amountMinimum, 'Insufficient WFIL');

        if (balanceWFIL > 0) {
            WFIL.withdraw(balanceWFIL);
            recipient.safeTransferETH(balanceWFIL);
        }
    }

    function wrapWFIL() public payable {
        if (address(this).balance > 0) WFIL.deposit{value: address(this).balance}(); // wrap everything
    }

    function pullToken(ERC20 token, uint256 amount, address recipient) public payable {
        token.safeTransferFrom(msg.sender, recipient, amount);
    }

    function sweepToken(
        ERC20 token,
        uint256 amountMinimum,
        address recipient
    ) public payable {
        uint256 balanceToken = token.balanceOf(address(this));
        require(balanceToken >= amountMinimum, 'Insufficient token');

        if (balanceToken > 0) {
            token.safeTransfer(recipient, balanceToken);
        }
    }

    function refundFIL() external payable {
        if (address(this).balance > 0) SafeTransferLib.safeTransferETH(msg.sender, address(this).balance);
    }
}