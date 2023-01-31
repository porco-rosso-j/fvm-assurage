// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.17;

interface IStrategy {
    //  function setManager(address _assurageManager) external;

    function deposit(uint256 _amount) external;

    function withdraw(uint256 _amount) external returns (uint256 FILAmount);

    function getAUM() external view returns (uint256);
}

interface ILidoStrategy is IStrategy {
    function wstFIL() external view returns (address);

    function stFIL() external view returns (address);

    function wFIL() external view returns (address);
}
