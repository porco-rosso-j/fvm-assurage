// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;


interface IAssurageManager {

    function assurageDelegate() external view returns (address poolDelegate_);

    function setActive(bool active) external;

}