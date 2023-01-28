// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.7.5;

import "solmate/utils/SafeTransferLib.sol";

/**
 @title Periphery Payments
 @notice Immutable state used by periphery contracts
 Largely Forked from https://github.com/Uniswap/v3-periphery/blob/main/contracts/base/PeripheryPayments.sol 
 Changes:
 * no interface
 * no inheritdoc
 * add immutable FIL in constructor instead of PeripheryImmutableState
 * receive from any address
 * Solmate interfaces and transfer lib
 * casting
 * add approve, wrapFIL and pullToken
*/ 
abstract contract PeripheryPayments {
    using SafeTransferLib for *;

    IFIL public immutable FIL;

    constructor(IFIL _FIL) {
        FIL = _FIL;
    }

    receive() external payable {}

    function approve(ERC20 token, address to, uint256 amount) public payable {
        token.safeApprove(to, amount);
    }

    function unwrapFIL(uint256 amountMinimum, address recipient) public payable {
        uint256 balanceFIL = FIL.balanceOf(address(this));
        require(balanceFIL >= amountMinimum, 'Insufficient FIL');

        if (balanceFIL > 0) {
            FIL.withdraw(balanceFIL);
            recipient.safeTransferETH(balanceFIL);
        }
    }

    function wrapFIL() public payable {
        if (address(this).balance > 0) FIL.deposit{value: address(this).balance}(); // wrap everything
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

    function refundETH() external payable {
        if (address(this).balance > 0) SafeTransferLib.safeTransferETH(msg.sender, address(this).balance);
    }
}

abstract contract IFIL is ERC20 {
    /// @notice Deposit ether to get wrapped ether
    function deposit() external payable virtual;

    /// @notice Withdraw wrapped ether to get ether
    function withdraw(uint256) external virtual;
}