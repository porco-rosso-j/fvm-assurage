// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

interface IAssurageManagerStorage {

    /**
     *  @dev    Returns whether or not a pool is active.
     *  @return active True if the pool is active.
     */
    function active() external view returns (bool active);

    /**
     *  @dev    Gets the address of the funds asset.
     *  @return asset The address of the funds asset.
     */
    function asset() external view returns (address asset);

    /**
     *  @dev    Returns whether or not a pool is configured.
     *  @return configured True if the pool is configured.
     */
    function configured() external view returns (bool configured);

    /**
     *  @dev    Gets the liquidity cap for the pool.
     *  @return liquidityCap The liquidity cap for the pool.
     */
    function liquidityCap() external view returns (uint256 liquidityCap);

    /**
     *  @dev    Gets the delegate management fee rate.
     *  @return delegateManagementFeeRate The value for the delegate management fee rate.
     */
    function delegateManagementFeeRate() external view returns (uint256 delegateManagementFeeRate);

    /**
     *  @dev    Gets the address of the pool.
     *  @return pool The address of the pool.
     */
    function vault() external view returns (address pool);

    /**
     *  @dev    Gets the address of the pool delegate.
     *  @return assurageDelegate The address of the pool delegate.
     */
    function assurageDelegate() external view returns (address assurageDelegate);

    function premiumFactor() external view returns (uint premiumFactor);

    function minProtection() external view returns (uint minProtection);
    
    function minPeriod() external view returns (uint minPeriod);
    
    function policies(address miner, uint id) external view returns (Policy memory policies[miner][id]);
    
    function claims(address miner, uint id) external view returns (Claim memory claims[miner][id]);

}