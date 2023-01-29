// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.7;

interface IAssurageManagerStorage {

    /**
     *  @dev    Returns whether or not a vault is active.
     *  @return active True if the vault is active.
     */
    function active() external view returns (bool active);

    /**
     *  @dev    Gets the address of the funds asset.
     *  @return asset The address of the funds asset.
     */
    function asset() external view returns (address asset);

    /**
     *  @dev    Returns whether or not a vault is configured.
     *  @return configured True if the vault is configured.
     */
    function configured() external view returns (bool configured);

    /**
     *  @dev    Gets the liquidity cap for the vault.
     *  @return liquidityCap The liquidity cap for the vault.
     */
    function liquidityCap() external view returns (uint256 liquidityCap);

    /**
     *  @dev    Gets the delegate management fee rate.
     *  @return delegateManagementFeeRate The value for the delegate management fee rate.
     */
    function delegateManagementFeeRate() external view returns (uint256 delegateManagementFeeRate);

    /**
     *  @dev    Gets the address of the vault.
     *  @return vault The address of the vault.
     */
    function vault() external view returns (address vault);

    /**
     *  @dev    Gets the address of the vault delegate.
     *  @return assurageDelegate The address of the vault delegate.
     */
    function assurageDelegate() external view returns (address assurageDelegate);

    function premiumFactor() external view returns (uint premiumFactor);

    function minProtection() external view returns (uint minProtection);
    
    function minPeriod() external view returns (uint minPeriod);

    function beneficiaryBytesAddr() external view returns (bytes memory beneficiaryBytesAddr);

    function assessor() external view returns (address assessor);

    struct Policy {
        address miner;
        uint amount;
        uint premium;
        uint period;
        uint expiry;
        uint8 score;
        bool isApproved;
        bool isActive;
    }

    struct Claim {
        address miner;
        uint claimable;
        bool isComfirmed; 
        bool isPaid;    
    }

    function policies(address _miner, uint _id) external view returns (
        address miner, 
        uint amount,
        uint premium,
        uint period,
        uint expiry,
        uint8 score,
        bool isApproved,
        bool isActive
        );
    
    function claims(address _miner, uint _id) external view returns (
        address miner,
        uint claimable,
        bool isComfirmed,
        bool isPaid
    );


    function isAssessor(address _assessor) external view returns (bool isAssessor);

    function strategyList(uint _index) external view returns (address strategy);
}

    // function policies(address _miner, uint _id) external view returns(Policy memory);

    // function claims(address _miner, uint _id) external view returns (Claim memory);

