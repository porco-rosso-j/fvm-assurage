// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import { NonTransparentProxied } from "./NonTransparentProxied.sol";
import "../interfaces/IAssurageManager.sol";
import "../interfaces/IAssurageGlobal.sol";

contract AssurageGlobal is IAssurageGlobal {

    struct assurageDelegate {
        address delegate;
        address vault;
        bool isAssurageDelegate;
    }

    address public override migrationAdmin;

    mapping(address => bool) public override isMiner;
    mapping(address => bool) public override isVaultAsset;
    mapping(address => bool) public override isVaultDeployer;

    mapping(address => uint256) public override bootstrapMint;
    mapping(address => uint256) public override platformManagementFeeRate;
    mapping(bytes32 => mapping(address => bool)) public override isFactory;
    mapping(address => assurageDelegate) public override assurageDelegates;

    modifier isGovernor {
        require(msg.sender == admin(), "MG:NOTGOVERNOR");
        _;
    }

    function acceptGovernor() external override {
        require(msg.sender == pendingGovernor, "MG:NOTPENDINGGOVERNOR");
        emit GovernorshipAccepted(admin(), msg.sender);
        setAddress(ADMINSLOT, msg.sender);
    }

    /**************************************************************************************************************************************/
    /*** Global Setters                                                                                                                 ***/
    /**************************************************************************************************************************************/

    // NOTE: `minCoverAmount` is not enforced at activation time.
    function activateAssurageManager(address assurageManager) external override isGovernor {
        address delegate = IAssurageManager(assurageManager).assurageDelegate();
        require(assurageDelegates[delegate].delegate == address(0), "MG:APM:ALREADYOWNS");

        emit assurageManagerActivated(assurageManager, delegate);
        assurageDelegates[delegate].delegate = assurageManager;
        IAssurageManager(assurageManager).setActive(true);
    }

    function setMigrationAdmin(address migrationAdmin) external override isGovernor {
        emit MigrationAdminSet(migrationAdmin, migrationAdmin);
        migrationAdmin = migrationAdmin;
    }

    function setBootstrapMint(address asset, uint256 amount) external override isGovernor {
        emit BootstrapMintSet(asset, bootstrapMint[asset] = amount);
    }

    /**************************************************************************************************************************************/
    /*** Allowlist Setters                                                                                                              ***/
    /**************************************************************************************************************************************/

    function setValidMiner(address borrower, bool isValid) external override isGovernor {
        isBorrower[borrower] = isValid;
        emit ValidMinerSet(borrower, isValid);
    }

    function setValidFactory(bytes32 factoryKey, address factory, bool isValid) exfternal override isGovernor {
        isFactory[factoryKey][factory] = isValid;
        emit ValidFactorySet(factoryKey, factory, isValid);
    }

    function setValidVaultAsset(address vaultAsset, bool isValid) external override isGovernor {
        isVaultAsset[vaultAsset] = isValid;
        emit ValidVaultAssetSet(vaultAsset, isValid);
    }

    function setValidAssurageDelegate(address account, bool isValid) external override isGovernor {
        require(account != address(0),  "MG:SVPD:ZEROADDRESS");

        // Cannot remove pool delegates that own a pool manager.
        require(isValid || assurageDelegates[account].delegate == address(0), "MG:SVPD:OWNSassurageManager");

        assurageDelegates[account].isAssurageDelegate = isValid;
        emit ValidAssurageDelegateSet(account, isValid);
    }

    function setValidVaultDeployer(address vaultDeployer, bool isValid) external override isGovernor {
        isVaultDeployer[vaultDeployer] = isValid;
        emit ValidVaultDeployerSet(vaultDeployer, isValid);
    }

    function setPlatformManagementFeeRate(address assurageManager, uint256 platformManagementFeeRate) external override isGovernor {
        require(platformManagementFeeRate <= HUNDREDPERCENT, "MG:SPMFR:RATEGT100");
        platformManagementFeeRate[assurageManager] = platformManagementFeeRate;
        emit PlatformManagementFeeRateSet(assurageManager, platformManagementFeeRate);
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