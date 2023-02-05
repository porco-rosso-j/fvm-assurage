// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.17;

import {NonTransparentProxied} from "./NonTransparentProxied.sol";
import "../interfaces/IAssurageManager.sol";
import "../interfaces/IAssurageGlobal.sol";

contract AssurageGlobal is IAssurageGlobal, NonTransparentProxied {
    uint256 public constant HUNDRED_PERCENT = 100_0000;

    struct AssurageDelegate {
        address assurageManager;
        bool isAssurageDelegate;
    }

    address public override migrationAdmin;

    mapping(address => bool) public override isVaultAsset;
    mapping(address => bool) public override isVaultDeployer;
    mapping(address => bool) public override isStrategy;

    mapping(address => uint256) public override bootstrapMint;
    mapping(address => uint256) public override platformManagementFeeRate;
    mapping(bytes32 => mapping(address => bool)) public override isFactory;
    mapping(address => AssurageDelegate) public override assurageDelegates;

    modifier isGovernor() {
        require(msg.sender == admin(), "MG:NOTGOVERNOR");
        _;
    }

    /**************************************************************************************************************************************/
    /*** Global Setters                                                                                                                 ***/
    /**************************************************************************************************************************************/

    // NOTE: `minCoverAmount` is not enforced at activation time.
    function activateAssurageManager(address _assurageManager)
        external
        override
        isGovernor
    {
        address delegate = IAssurageManager(_assurageManager)
            .assurageDelegate();
        require(
            assurageDelegates[delegate].assurageManager == address(0),
            "MG:APM:ALREADYOWNS"
        );

        emit AssurageManagerActivated(_assurageManager, delegate);
        assurageDelegates[delegate].assurageManager = _assurageManager;
        IAssurageManager(_assurageManager).setActive(true);
    }

    function setMigrationAdmin(address _migrationAdmin)
        external
        override
        isGovernor
    {
        emit MigrationAdminSet(migrationAdmin, _migrationAdmin);
        migrationAdmin = _migrationAdmin;
    }

    function setBootstrapMint(address asset, uint256 amount)
        external
        override
        isGovernor
    {
        emit BootstrapMintSet(asset, bootstrapMint[asset] = amount);
    }

    /**************************************************************************************************************************************/
    /*** Allowlist Setters                                                                                                              ***/
    /**************************************************************************************************************************************/

    function setValidFactory(
        bytes32 factoryKey,
        address factory,
        bool isValid
    ) external override isGovernor {
        isFactory[factoryKey][factory] = isValid;
        emit ValidFactorySet(factoryKey, factory, isValid);
    }

    function setValidVaultAsset(address vaultAsset, bool isValid)
        external
        override
        isGovernor
    {
        isVaultAsset[vaultAsset] = isValid;
        emit ValidVaultAssetSet(vaultAsset, isValid);
    }

    function setValidAssurageDelegate(address account, bool isValid)
        external
        override
        isGovernor
    {
        require(account != address(0), "MG:SVPD:ZEROADDRESS");

        // Cannot remove pool delegates that own a pool manager.
        require(
            isValid || assurageDelegates[account].assurageManager == address(0),
            "MG:SVPD:OWNSassurageManager"
        );

        assurageDelegates[account].isAssurageDelegate = isValid;
        emit ValidAssurageDelegateSet(account, isValid);
    }

    function setValidVaultDeployer(address vaultDeployer, bool isValid)
        external
        override
        isGovernor
    {
        isVaultDeployer[vaultDeployer] = isValid;
        emit ValidVaultDeployerSet(vaultDeployer, isValid);
    }

    function setValidStrategy(address strategy, bool isValid)
        external
        override
        isGovernor
    {
        isStrategy[strategy] = isValid;
        emit ValidStrategySet(strategy, isValid);
    }

    function setPlatformManagementFeeRate(
        address _assurageManager,
        uint256 _platformManagementFeeRate
    ) external override isGovernor {
        require(
            _platformManagementFeeRate <= HUNDRED_PERCENT,
            "MG:SPMFR:RATEGT100"
        );
        platformManagementFeeRate[
            _assurageManager
        ] = _platformManagementFeeRate;
        emit PlatformManagementFeeRateSet(
            _assurageManager,
            _platformManagementFeeRate
        );
    }

    function governor() external view override returns (address governor_) {
        governor_ = admin();
    }

    function isAssurageDelegate(address account_)
        external
        view
        override
        returns (bool _isAssurageDelegate)
    {
        _isAssurageDelegate = assurageDelegates[account_].isAssurageDelegate;
    }

    function assurageManager(address account_)
        external
        view
        override
        returns (address _assurageManager)
    {
        _assurageManager = assurageDelegates[account_].assurageManager;
    }

    /**************************************************************************************************************************************/
    /*** Helper Functions                                                                                                               ***/
    /**************************************************************************************************************************************/

    function setAddress(bytes32 slot, address value) private {
        assembly {
            sstore(slot, value)
        }
    }
}
