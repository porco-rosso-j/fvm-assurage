// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.17;

import {IAssurageProxied} from "../interfaces/IAssurageProxied.sol";
import {IAssurageManagerStorage} from "./IAssurageManagerStorage.sol";

interface IAssurageManager is IAssurageProxied, IAssurageManagerStorage {
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
     *  @param minProtection              The minimum protection.
     *  @param liquidityCap              The new liquidity cap.
     *  @param delegateManagementFeeRate The management fee rate.
     */
    event VaultConfigured(
        uint256 minProtection,
        uint256 minAmount,
        uint256 liquidityCap,
        uint256 delegateManagementFeeRate
    );

    /**
     *  @dev   Emitted when a pool is sets to be active or inactive.
     *  @param active Whether the pool is active.
     */
    event SetAsActive(bool active);

    event AssessorAddrSet(address assessor);

    event MinProtectionSet(uint256 minProtection);

    event MinPeriodSet(uint256 minPeriod);

    // event BeneficiaryBytesAddrSet(bytes beneficiaryBytesAddr);

    event newApplicationMade(
        address miner,
        uint256 amount,
        uint256 period,
        uint256 id
    );

    event newPolicyActivated(Policy policy, uint256 id);

    event newClaimFiled(Claim claim, uint256 id);

    event newCompensationPaid(Claim claim, uint256 id);

    //event newApplicationMade(address miner, address pvault, uint amount, uint period, uint id);

    //event newApplicationMade(address miner, address pvault, uint amount, uint period, uint id);

    /**************************************************************************************************************************************/
    /*** Administrative Functions                                                                                                       ***/
    /**************************************************************************************************************************************/

    /**
     *  @dev   Configures the pool.
     *  @param minProtection  The minimum protection amount
     *  @param liquidityCap      The new liquidity cap.
     *  @param managementFee     The management fee rate.
     */
    function configure(
        uint256 minProtection,
        uint256 minAmount,
        uint256 liquidityCap,
        uint256 managementFee
    ) external;

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
    function setDelegateManagementFeeRate(uint256 delegateManagementFeeRate)
        external;

    function setMinProtection(uint256 _minProtection) external;

    function setMinPeriod(uint256 _minPeriod) external;

    function setAssessor(address _assessor) external;

    // function setBeneficiaryBytesAddr(bytes memory _beneficiaryBytesAddr)
    //     external;

    function applyForProtection(
        address _miner,
        uint256 _amount,
        uint256 _period
    ) external returns (uint256);

    function activatePolicy(address _miner, uint256 _id) external;

    function fileClaim(
        address _miner,
        uint256 _id,
        uint256 _claimable
    ) external;

    function claimCompensation(address _miner, uint256 _id)
        external
        payable
        returns (uint256);

    // function renewPolocy(address _miner, uint256 _id)
    //     external
    //     returns (Policy memory);

    function approvePolicy(
        address _miner,
        uint256 _id,
        uint8 _score
    ) external;

    function approveClaim(
        address _miner,
        uint256 _id,
        uint256 _claimable
    ) external;

    function modifyScore(
        address _miner,
        uint256 _id,
        uint8 _score
    ) external;

    function addStrategy(address _strategy) external;

    function investInStrategy(uint256 _index, uint256 _amount) external;

    function withdrawFromStrategy(uint256 _index, uint256 _amount) external;

    /**************************************************************************************************************************************/
    /*** View Functions                                                                                                                 ***/
    /**************************************************************************************************************************************/

    /**
     *  @dev    Gets the address of the globals.
     *  @return global The address of the globals.
     */
    function global() external view returns (address global);

    /**
     *  @dev    Gets the address of the governor.
     *  @return governor The address of the governor.
     */
    function governor() external view returns (address governor);

    /**
     *  @dev    Returns the amount of total assets.
     *  @return totalAssets Amount of of total assets.
     */
    function totalAssets() external view returns (uint256 totalAssets);
}
