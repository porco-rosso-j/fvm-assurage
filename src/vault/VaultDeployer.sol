// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.17;

import {IAssurageProxyFactory} from "../interfaces/IAssurageProxyFactory.sol";
import {IAssurageGlobal} from "../interfaces/IAssurageGlobal.sol";
import {IVaultDeployer} from "../interfaces/IVaultDeployer.sol";
import {IAssurageManager} from "../interfaces/IAssurageManager.sol";
import {IAssurageManagerInitializer} from "../interfaces/IAssurageManagerInitializer.sol";

import {ERC20} from "solmate/mixins/ERC4626.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

contract VaultDeployer is IVaultDeployer {
    using SafeTransferLib for ERC20;

    address public override global;

    constructor(address _global) {
        require((global = _global) != address(0), "PD:C:ZEROADDRESS");
    }

    function deployVault(
        address[1] memory factories,
        address[1] memory initializers,
        address asset,
        string memory name,
        string memory symbol,
        uint256[5] memory configParams // _minProtection, _minPeriod, _liquidityCap, _delegateManagementFeeRate, _initialSupply,
    ) external override returns (address assurageManager) {
        address assurageDelegate = msg.sender;

        IAssurageGlobal _global = IAssurageGlobal(global);

        require(
            _global.isAssurageDelegate(assurageDelegate),
            "PD:DP:INVALIDPD"
        );
        require(
            _global.isFactory("POOLMANAGER", factories[0]),
            "PD:DP:INVALIDPMFACTORY"
        );

        // Avoid stack too deep error
        {
            IAssurageProxyFactory PMFactory = IAssurageProxyFactory(
                factories[0]
            );

            require(
                initializers[0] ==
                    PMFactory.migratorForPath(
                        PMFactory.defaultVersion(),
                        PMFactory.defaultVersion()
                    ),
                "PD:DP:INVALIDPMINITIALIZER"
            );
        }

        bytes32 salt = keccak256(abi.encode(assurageDelegate));

        // Deploy Pool Manager
        bytes memory arguments = IAssurageManagerInitializer(initializers[0])
            .encodeArguments(
                assurageDelegate,
                asset,
                configParams[4],
                name,
                symbol
            );

        assurageManager = IAssurageProxyFactory(factories[0]).createInstance(
            arguments,
            salt
        );
        address vault = IAssurageManager(assurageManager).vault();

        // Configure Pool Manager
        IAssurageManager(assurageManager).configure(
            configParams[0],
            configParams[1],
            configParams[2],
            configParams[3]
        );

        SafeTransferLib.safeTransfer(ERC20(asset), vault, configParams[4]);
    }
}
