// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.17;

import {IAssurageProxyFactory} from "../interfaces/IAssurageProxyFactory.sol";
import {IAssurageGlobal} from "../interfaces/IAssurageGlobal.sol";
import {IAssurageManagerInitializer} from "../interfaces/IAssurageManagerInitializer.sol";

import {ProtectionVault} from "../Vault/ProtectionVault.sol";
import {AssurageManagerStorage} from "./AssurageManagerStorage.sol";

contract AssurageManagerInitializer is
    IAssurageManagerInitializer,
    AssurageManagerStorage
{
    function decodeArguments(bytes calldata encodedArguments)
        public
        pure
        override
        returns (
            address assurageDelegate,
            address asset,
            uint256 initialSupply,
            string memory name,
            string memory symbol
        )
    {
        (assurageDelegate, asset, initialSupply, name, symbol) = abi.decode(
            encodedArguments,
            (address, address, uint256, string, string)
        );
    }

    function encodeArguments(
        address assurageDelegate,
        address asset,
        uint256 initialSupply,
        string memory name,
        string memory symbol
    ) external pure override returns (bytes memory encodedArguments) {
        encodedArguments = abi.encode(
            assurageDelegate,
            asset,
            initialSupply,
            name,
            symbol
        );
    }

    fallback() external {
        _locked = 1;

        (
            address assurageDelegate,
            address asset,
            uint256 initialSupply,
            string memory name,
            string memory symbol
        ) = decodeArguments(msg.data);

        initialize(assurageDelegate, asset, initialSupply, name, symbol);
    }

    function initialize(
        address _assurageDelegate,
        address asset,
        uint256 initialSupply,
        string memory name,
        string memory symbol
    ) internal {
        address global = IAssurageProxyFactory(msg.sender).assurageGlobal();

        require(
            (assurageDelegate = _assurageDelegate) != address(0),
            "PMI:I:ZEROPD"
        );
        require((asset = asset) != address(0), "PMI:I:ZEROASSET");

        require(
            IAssurageGlobal(global).isAssurageDelegate(_assurageDelegate),
            "PMI:I:NOTPD"
        );
        require(
            IAssurageGlobal(global).assurageManager(_assurageDelegate) ==
                address(0),
            "PMI:I:POOLOWNER"
        );
        require(
            IAssurageGlobal(global).isVaultAsset(asset),
            "PMI:I:ASSETNOTALLOWED"
        );

        address migrationAdmin = IAssurageGlobal(global).migrationAdmin();

        require(
            initialSupply == 0 || migrationAdmin != address(0),
            "PMI:I:INVALIDPOOLPARAMS"
        );

        vault = address(
            new ProtectionVault(
                address(this),
                asset,
                migrationAdmin,
                IAssurageGlobal(global).bootstrapMint(asset),
                initialSupply,
                name,
                symbol
            )
        );

        emit Initialized(assurageDelegate, asset, address(vault));
    }
}
