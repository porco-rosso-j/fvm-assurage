// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.17;

import {IProxied} from "../proxy/1967Proxy/interfaces/IProxied.sol";

/// @title A Assurage implementation that is to be proxied, must implement IAssurageProxied.
interface IAssurageProxied is IProxied {
    /**s
     *  @dev   The instance was upgraded.
     *  @param toVersion_ The new version of the loan.
     *  @param arguments_ The upgrade arguments, if any.
     */
    event Upgraded(uint256 toVersion_, bytes arguments_);

    /**
     *  @dev   Upgrades a contract implementation to a specific version.
     *         Access control logic critical since caller can force a selfdestruct via a malicious `migrator_` which is delegatecalled.
     *  @param toVersion_ The version to upgrade to.
     *  @param arguments_ Some encoded arguments to use for the upgrade.
     */
    function upgrade(uint256 toVersion_, bytes calldata arguments_) external;
}
