// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { IProxied } from "../proxy/1967Proxy/interfaces/IProxied.sol";
import { IAssurageManagerStorage } from "./IAssurageManagerStorage.sol";

interface IAssurageManager is IProxied, IAssurageManagerStorage {

    /**************************************************************************************************************************************/
    /*** Events                                                                                                                         ***/
    /**************************************************************************************************************************************/

    /**
     *  @dev   Emitted when a new management fee rate is set.
     *  @param managementFeeRate The amount of management fee rate.
     */
    event DelegateManagementFeeRateSet(uint256 managementFeeRate);

    /**
     *  @dev   Emitted when a new liquidity cap is set.
     *  @param liquidityCap The value of liquidity cap.
     */
    event LiquidityCapSet(uint256 liquidityCap);

    /**
     *  @dev   Emitted when the vault is configured the pool.
     *  @param liquidityCap              The new liquidity cap.
     *  @param delegateManagementFeeRate The management fee rate.
     */
    event VaultConfigured(uint256 liquidityCap, uint256 delegateManagementFeeRate);

    /**
     *  @dev   Emitted when a pool is sets to be active or inactive.
     *  @param active Whether the pool is active.
     */
    event SetAsActive(bool active);

    /**************************************************************************************************************************************/
    /*** Administrative Functions                                                                                                       ***/
    /**************************************************************************************************************************************/

    /**
     *  @dev   Configures the pool.
     *  @param assessor   The assessor address
     *  @param minProtection  The minimum protection amount
     *  @param liquidityCap      The new liquidity cap.
     *  @param managementFee     The management fee rate.
     */
    function configure(address assessor, address minProtection, uint256 liquidityCap, uint256 managementFee) external;

    /**
     *  @dev   Sets a the pool to be active or inactive.
     *  @param active Whether the pool is active.
     */
    function setActive(bool active) external;

    /**
     *  @dev   Sets the value for liquidity cap.
     *  @param liquidityCap The value for liquidity cap.
     */
    function setLiquidityCap(uint256 liquidityCap) external;

    /**
     *  @dev   Sets the value for the delegate management fee rate.
     *  @param delegateManagementFeeRate The value for the delegate management fee rate.
     */
    function setDelegateManagementFeeRate(uint256 delegateManagementFeeRate) external;


    /**************************************************************************************************************************************/
    /*** LP Token View Functions                                                                                                        ***/
    /**************************************************************************************************************************************/

    /**
     *  @dev    Returns the amount of exit shares for the input amount.
     *  @param  amount  Address of the account.
     *  @return shares  Amount of shares able to be exited.
     */
    function convertToExitShares(uint256 amount) external view returns (uint256 shares);

    /**
     *  @dev   Gets the amount of assets that can be deposited.
     *  @param receiver  The address to check the deposit for.
     *  @param maxAssets The maximum amount assets to deposit.
     */
    function maxDeposit(address receiver) external view returns (uint256 maxAssets);

    /**
     *  @dev   Gets the amount of shares that can be minted.
     *  @param receiver  The address to check the mint for.
     *  @param maxShares The maximum amount shares to mint.
     */
    function maxMint(address receiver) external view returns (uint256 maxShares);

    /**
     *  @dev   Gets the amount of shares that can be redeemed.
     *  @param owner     The address to check the redemption for.
     *  @param maxShares The maximum amount shares to redeem.
     */
    function maxRedeem(address owner) external view returns (uint256 maxShares);

    /**
     *  @dev   Gets the amount of assets that can be withdrawn.
     *  @param owner     The address to check the withdraw for.
     *  @param maxAssets The maximum amount assets to withdraw.
     */
    function maxWithdraw(address owner) external view returns (uint256 maxAssets);

    /**
     *  @dev    Gets the amount of shares that can be redeemed.
     *  @param  owner   The address to check the redemption for.
     *  @param  shares  The amount of requested shares to redeem.
     *  @return assets  The amount of assets that will be returned for `shares`.
     */
    function previewRedeem(address owner, uint256 shares) external view returns (uint256 assets);

    /**
     *  @dev    Gets the amount of assets that can be redeemed.
     *  @param  owner   The address to check the redemption for.
     *  @param  assets  The amount of requested shares to redeem.
     *  @return shares  The amount of assets that will be returned for `assets`.
     */
    function previewWithdraw(address owner, uint256 assets) external view returns (uint256 shares);

    /**************************************************************************************************************************************/
    /*** View Functions                                                                                                                 ***/
    /**************************************************************************************************************************************/

    /**
     *  @dev    Gets the address of the globals.
     *  @return globals The address of the globals.
     */
    function globals() external view returns (address globals);

    /**
     *  @dev    Gets the address of the governor.
     *  @return governor The address of the governor.
     */
    function governor() external view returns (address governor);

    /**
     *  @dev    Returns if pool has sufficient cover.
     *  @return hasSufficientCover True if pool has sufficient cover.
     */
    function hasSufficientCover() external view returns (bool hasSufficientCover);

    /**
     *  @dev    Returns the amount of total assets.
     *  @return totalAssets Amount of of total assets.
     */
    function totalAssets() external view returns (uint256 totalAssets);

    /**
     *  @dev    Returns the amount unrealized losses.
     *  @return unrealizedLosses Amount of unrealized losses.
     */
    function unrealizedLosses() external view returns (uint256 unrealizedLosses);

}