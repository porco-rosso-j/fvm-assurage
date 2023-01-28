// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

interface IProtectionVault {

    function payPremium(address _miner, uint _premium) external;
    function sendClaimETH(address _miner, uint _compensation) external payable;

}