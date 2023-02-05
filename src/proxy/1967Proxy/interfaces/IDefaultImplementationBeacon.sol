// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.17;

/// @title An beacon that provides a default implementation for proxies, must implement IDefaultImplementationBeacon.
interface IDefaultImplementationBeacon {
    /// @dev The address of an implementation for proxies.
    function defaultImplementation()
        external
        view
        returns (address defaultImplementation_);
}
