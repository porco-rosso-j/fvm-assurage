// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.17;

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
    function delegateManagementFeeRate()
        external
        view
        returns (uint256 delegateManagementFeeRate);

    /**
     *  @dev    Gets the address of the vault.
     *  @return vault The address of the vault.
     */
    function vault() external view returns (address vault);

    /**
     *  @dev    Gets the address of the vault delegate.
     *  @return assurageDelegate The address of the vault delegate.
     */
    function assurageDelegate()
        external
        view
        returns (address assurageDelegate);

    //function premiumFactor() external view returns (uint256 premiumFactor);

    function minProtection() external view returns (uint256 minProtection);

    function minPeriod() external view returns (uint256 minPeriod);

    function beneficiaryBytesAddr()
        external
        view
        returns (bytes memory beneficiaryBytesAddr);

    function assessor() external view returns (address assessor);

    struct Policy {
        address miner;
        uint256 amount;
        uint256 premium;
        uint256 period;
        uint256 expiry;
        uint8 score;
        bool isApproved;
        bool isActive;
        Claim claim;
    }

    struct Claim {
        uint256 claimable;
        bool isConfirmed;
        bool isPaid;
    }

    function policies(address _miner, uint256 _id)
        external
        view
        returns (
            address miner,
            uint256 amount,
            uint256 premium,
            uint256 period,
            uint256 expiry,
            uint8 score,
            bool isApproved,
            bool isActive,
            Claim memory claim
        );

    // function claims(address _miner, uint256 _id)
    //     external
    //     view
    //     returns (
    //         address miner,
    //         uint256 claimable,
    //         bool isConfirmed,
    //         bool isPaid
    //     );

    function isAssessor(address _assessor)
        external
        view
        returns (bool isAssessor);

    function strategyList(uint256 _index)
        external
        view
        returns (address strategy);
}

// function getPolicy(address _miner, uint256 _id)
//     external
//     view
//     returns (Policy memory);

// function getClaim(address _miner, uint256 _id)
//     external
//     view
//     returns (Claim memory);

// function getPolicy(address _miner, uint256 _id)
//     external
//     view
//     returns (
//         address miner,
//         uint256 amount,
//         uint256 premium,
//         uint256 period,
//         uint256 expiry,
//         uint8 score,
//         bool isApproved,
//         bool isActive
//     );

// function getClaim(address _miner, uint256 _id)
//     external
//     view
//     returns (
//         address miner,
//         uint256 claimable,
//         bool isConfirmed,
//         bool isPaid
//     );
