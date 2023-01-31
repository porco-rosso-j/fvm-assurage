// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.17;

import {IAssurageManagerStorage} from "../interfaces/IAssurageManagerStorage.sol";

abstract contract AssurageManagerStorage is IAssurageManagerStorage {
    uint256 internal _locked; // Used when checking for reentrancy.

    address public override assurageDelegate;
    address public override assessor;
    address public override asset;
    address public override vault;

    bool public override active;
    bool public override configured;

    uint256 public override liquidityCap;
    uint256 public override delegateManagementFeeRate;

    uint256 public override premiumFactor; // e.g 0.00007% 7e13
    uint256 public override minProtection; // e.g 10 FIL 1e19
    uint256 public override minPeriod; // e.g a week 604800

    uint256 public constant DECIMAL_PRECISION = 1e18;
    uint256 public constant MAX_DELEGATE_FEE_RATE = 5e17; // 50%
    bytes public override beneficiaryBytesAddr; // Manager's FIL ID (Address bytes)

    mapping(address => mapping(uint256 => Policy)) public override policies; // miner => policyId =>　Policy
    mapping(address => uint256) public policyId;

    mapping(address => mapping(uint256 => Claim)) public override claims; // miner => claimId => Claim
    mapping(address => uint256) public claimId;

    mapping(address => bool) public override isAssessor;
    address[] public override strategyList;
}
