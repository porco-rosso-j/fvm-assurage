// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.17;

interface IStrategy {
    function isValidManager(address) external view returns (bool);

    function share() external view returns (address);

    function setValidManager(address _assurageManager) external;

    function approveManager() external;

    function deposit(uint256 _amount) external;

    function withdraw(uint256 _amount) external returns (uint256 filAmount);

    function getBalance(uint256 _amount) external view returns (uint256);
}

interface ILidoStrategy is IStrategy {
    function wstFIL() external view returns (address);

    function wFIL() external view returns (address);
}
