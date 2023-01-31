// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.17;

interface IMinerActor {
    function getBeneficiary() external view returns (bytes memory);

    function getAvailableBalance() external view returns (uint256);

    function withdrawBalance(address _vault, uint256 _amount) external;
}
