// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.7;

interface IMinerActor {

    function getBeneficiary() external view returns(bytes memory);
    function getAvailableBalance() external view returns(uint);
    function withdrawBalance(address _vault, uint _amount) external;

}