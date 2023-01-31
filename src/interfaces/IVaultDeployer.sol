// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.17;

interface IVaultDeployer {
    function global() external view returns (address global);

    function deployVault(
        address[1] memory factories,
        address[1] memory initializers,
        address asset,
        string memory name,
        string memory symbol,
        uint256[5] memory configParams
    ) external returns (address assurageManager);
}
