// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.17;

interface IERC20 {
    function approve(address spender, uint256 value) external;

    function balanceOf(address account) external view returns (uint256);

    function transfer(address recipient, uint256 amount)
        external
        returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);
}

interface IWFIL is IERC20 {
    function withdraw(uint256) external payable;

    function deposit() external payable;
}
