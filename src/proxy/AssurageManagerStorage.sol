// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.7;

import { IAssurageManagerStorage } from "../interfaces/IAssurageManagerStorage.sol";

abstract contract AssurageManagerStorage is IAssurageManagerStorage {

    uint256 internal _locked;  // Used when checking for reentrancy.

    address public override assurageDelegate;
    address public override assessor;
    address public override asset;
    address public override vault;

    bool public override active;
    bool public override configured;

    uint256 public override liquidityCap;
    uint256 public override delegateManagementFeeRate;

    uint public override premiumFactor; // e.g 0.00007% 7e13
    uint public override minProtection; // e.g 10 FIL 1e19
    uint public override minPeriod; // e.g a week 604800

    uint constant public DECIMAL_PRECISION = 1e18;
    uint constant public MAX_DELEGATE_FEE_RATE = 5e17; // 50%
    bytes public override beneficiaryBytesAddr; // Manager's FIL ID (Address bytes)

    mapping (address => mapping(uint => Policy)) public override policies; // miner => policyId =>　Policy
    mapping (address => uint) public policyId;

    mapping (address => mapping(uint => Claim)) public override claims; // miner => claimId => Claim
    mapping (address => uint) public claimId;

    mapping(address => bool) public override isAssessor;
    address[] public override strategyList;

}