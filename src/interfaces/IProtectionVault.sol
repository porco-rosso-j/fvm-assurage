// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.17;

//import {IERC4626} from "../interfaces/IERC4626.sol";
interface IProtectionVault {
    function setAssurageManager(address _assurageManager) external;

    function setApproval() external;

    function withdrawFromAssurageManager(uint256 _amount) external;
}
