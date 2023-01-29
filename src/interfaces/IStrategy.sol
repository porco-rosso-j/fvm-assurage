// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.7;

interface IStrategy {
    //  function setManager(address _assurageManager) external;

     function deposit(uint _amount) external;

     function withdraw(uint _amount) external returns(uint FILAmount);

      function getAUM() external view returns(uint);
}

interface ILidoStrategy is IStrategy {

    function wstFIL() external view returns(address);

    function stFIL() external view returns(address);

    function wFIL() external view returns(address);
}