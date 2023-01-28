// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { INonTransparentProxied } from "../core/NonTransparentProxied.sol";

interface IAssurageGlobal is INonTransparentProxied {

    /**************************************************************************************************************************************/
    /*** Events                                                                                                                         ***/
    /**************************************************************************************************************************************/

    /**
     *  @dev   The governorship has been accepted.
     *  @param previousGovernor The previous governor.
     *  @param currentGovernor  The new governor.
     */
    event GovernorshipAccepted(address indexed previousGovernor, address indexed currentGovernor);

    /**
     *  @dev   The migration admin has been set.
     *  @param previousMigrationAdmin The previous migration admin.
     *  @param nextMigrationAdmin     The new migration admin.
     */
    event MigrationAdminSet(address indexed previousMigrationAdmin, address indexed nextMigrationAdmin);

    /**
     *  @dev   A virtualized first mint that acts as as offset to `totalAssets` and `totalSupply`.
     *  @param asset         The address of the Vault asset.
     *  @param bootstrapMint The amount of shares that will offset `totalAssets` and `totalSupply`.
     */
    event BootstrapMintSet(address indexed asset, uint256 bootstrapMint);

    /**
     *  @dev   The platform management fee rate for the given Vault manager has been set.
     *  @param delegate               The address of the Vault manager.
     *  @param platformManagementFeeRate The new value for the platform management fee rate.
     */
    event PlatformManagementFeeRateSet(address indexed delegate, uint256 platformManagementFeeRate);

    /**
     *  @dev   The Vault manager was activated.
     *  @param delegate  The address of the Vault manager.
     *  @param VaultDelegate The address of the Vault delegate.
     */
    event AssurageManagerActivated(address indexed delegate, address indexed VaultDelegate);

    /**
     *  @dev   A valid borrower was set.
     *  @param miner The address of the borrower.
     *  @param isValid  The validity of the borrower.
     */
    event ValidMinerSet(address indexed miner, bool indexed isValid);

    /**
     *  @dev   A valid factory was set.
     *  @param factoryKey The key of the factory.
     *  @param factory    The address of the factory.
     *  @param isValid    The validity of the factory.
     */
    event ValidFactorySet(bytes32 indexed factoryKey, address indexed factory, bool indexed isValid);

    /**
     *  @dev   A valid asset was set.
     *  @param VaultAsset The address of the asset.
     *  @param isValid   The validity of the asset.
     */
    event ValidVaultAssetSet(address indexed VaultAsset, bool indexed isValid);

    /**
     *  @dev   A valid Vault delegate was set.
     *  @param account The address the account.
     *  @param isValid The validity of the asset.
     */
    event ValidAssurageDelegateSet(address indexed account, bool indexed isValid);

    /**
     *  @dev   A valid Vault deployer was set.
     *  @param VaultDeployer The address the account.
     *  @param isValid      The validity of the asset.
     */
    event ValidVaultDeployerSet(address indexed VaultDeployer, bool indexed isValid);

    /**************************************************************************************************************************************/
    /*** State Variables                                                                                                                ***/
    /**************************************************************************************************************************************/

    /**
     *  @dev    Gets the validity of a borrower.
     *  @param  miner The address of the borrower to query.
     *  @return isValid  A boolean indicating the validity of the borrower.
     */
    function isMiner(address miner) external view returns (bool isValid);

    /**
     *  @dev    Gets the validity of a factory.
     *  @param  factoryId The address of the factory to query.
     *  @param  factory   The address of the factory to query.
     *  @return isValid   A boolean indicating the validity of the factory.
     */
    function isFactory(bytes32 factoryId, address factory) external view returns (bool isValid);

    /**
     *  @dev    Gets the validity of a Vault asset.
     *  @param  VaultAsset The address of the VaultAsset to query.
     *  @return isValid   A boolean indicating the validity of the Vault asset.
     */
    function isVaultAsset(address VaultAsset) external view returns (bool isValid);

    /**
     *  @dev    Gets the validity of a Vault delegate.
     *  @param  account  The address of the account to query.
     *  @return isValid  A boolean indicating the validity of the Vault delegate.
     */
    function isAssurageDelegate(address account) external view returns (bool isValid);

    /**
     *  @dev    Gets the validity of a Vault deployer.
     *  @param  account  The address of the account to query.
     *  @return isValid  A boolean indicating the validity of the Vault deployer.
     */
    function isVaultDeployer(address account) external view returns (bool isValid);
    /**
     *  @dev    Gets governor address.
     *  @return governor The address of the governor.
     */
    function governor() external view returns (address governor);

    /**
     *  @dev    Gets migration admin address.
     *  @return migrationAdmin The address of the migration admin.
     */
    function migrationAdmin() external view returns (address migrationAdmin);

    /**
     *  @dev    Gets the virtualized first mint that acts as as offset to `totalAssets` and `totalSupply` for a given Vault asset.
     *  @param  asset         The address of the Vault asset to query
     *  @return bootstrapMint The amount of shares that will offset `totalAssets` and `totalSupply`.
     */
    function bootstrapMint(address asset) external view returns (uint256 bootstrapMint);
    /**
     *  @dev    Gets the address of the owner Vault manager.
     *  @param  account     The address of the account to query.
     *  @return delegate The address of the Vault manager.
     */
    function delegate(address account) external view returns (address delegate);

    /**
     *  @dev    Gets the platform management fee rate for a given Vault manager.
     *  @param  delegate               The address of the Vault manager to query.
     *  @return platformManagementFeeRate The platform management fee rate.
     */
    function platformManagementFeeRate(address delegate) external view returns (uint256 platformManagementFeeRate);

    /**
     *  @dev    Gets Vault delegate address information.
     *  @param  VaultDelegate    The address of the Vault delegate to query.
     *  @return owneddelegate The address of the Vault manager owned by the Vault delegate.
     *  @return isVaultDelegate   A boolean indication weather or not the address passed is a current Vault delegate.
     */
    function VaultDelegates(address VaultDelegate) external view returns (address delegate, bool isVaultDelegate);

    function acceptGovernor() external;

    /**************************************************************************************************************************************/
    /*** Global Setters                                                                                                                 ***/
    /**************************************************************************************************************************************/

    /**
     *  @dev   Activates the Vault manager.
     *  @param delegate The address of the Vault manager to activate.
     */
    function activateAssurageManager(address delegate) external;

    /**
     *  @dev   Sets the address of the migration admin.
     *  @param migrationAdmin The address of the migration admin.
     */
    function setMigrationAdmin(address migrationAdmin) external;

    /**
     *  @dev   Sets the virtualized first mint that acts as as offset to `totalAssets` and `totalSupply`
     *         to prevent an MEV-exploit vector against the first Vault depositor.
     *  @param asset         The address of the Vault asset.
     *  @param bootstrapMint The amount of shares that will offset `totalAssets` and `totalSupply`.
     */
    function setBootstrapMint(address asset, uint256 bootstrapMint) external;

    /**************************************************************************************************************************************/
    /*** Allowlist Setters                                                                                                              ***/
    /**************************************************************************************************************************************/

    /**
     *  @dev   Sets the validity of the miner.
     *  @param miner The address of the miner to set the validity for.
     *  @param isValid  A boolean indicating the validity of the miner.
     */
    function setValidMiner(address miner, bool isValid) external;

    /**
     *  @dev   Sets the validity of the factory.
     *  @param factoryKey The key of the factory to set the validity for.
     *  @param factory    The address of the factory to set the validity for.
     *  @param isValid    Boolean indicating the validity of the factory.
     */
    function setValidFactory(bytes32 factoryKey, address factory, bool isValid) external;

    /**
     *  @dev   Sets the validity of the Vault asset.
     *  @param VaultAsset The address of the Vault asset to set the validity for.
     *  @param isValid   A boolean indicating the validity of the Vault asset.
     */
    function setValidVaultAsset(address VaultAsset, bool isValid) external;

    /**
     *  @dev   Sets the validity of the Vault delegate.
     *  @param VaultDelegate The address of the Vault delegate to set the validity for.
     *  @param isValid      A boolean indicating the validity of the Vault delegate.
     */
    function setValidAssurageDelegate(address AssurageDelegate, bool isValid) external;

    /**
     *  @dev   Sets the validity of the Vault deployer.
     *  @param VaultDeployer The address of the Vault deployer to set the validity for.
     *  @param isValid      A boolean indicating the validity of the Vault deployer.
     */
    function setValidVaultDeployer(address VaultDeployer, bool isValid) external;

    /**************************************************************************************************************************************/
    /*** Fee Setters                                                                                                                    ***/
    /**************************************************************************************************************************************/

    /**
     *  @dev   Sets the platform management fee rate for the given Vault manager.
     *  @param delegate               The address of the Vault manager to set the fee for.
     *  @param platformManagementFeeRate The platform management fee rate.
     */
    function setPlatformManagementFeeRate(address delegate, uint256 platformManagementFeeRate) external;


}