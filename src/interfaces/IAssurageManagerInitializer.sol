// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.7;

interface IAssurageManagerInitializer {

    event Initialized(address owner, address asset, address vault);

    function decodeArguments(bytes calldata encodedArguments) external pure
        returns (address owner, address asset, uint256 initialSupply, string memory name, string memory symbol);

    function encodeArguments(
        address owner,
        address asset,
        uint256 initialSupply,
        string memory name,
        string memory symbol
    )
        external pure returns (bytes memory encodedArguments);

}