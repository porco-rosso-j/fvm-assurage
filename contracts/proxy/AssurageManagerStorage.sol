// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { IAssurageManagerStorage } from "../interfaces/IAssurageManagerStorage.sol";

abstract contract AssurageManagerStorage is IAssurageManagerStorage {

    uint256 internal _locked;  // Used when checking for reentrancy.

    address public override assurageDelegate;
    address public override asset;
    address public override vault;

    bool public override active;
    bool public override configured;

    uint256 public override liquidityCap;
    uint256 public override delegateManagementFeeRate;

    uint public override premiumFactor; // e.g 0.00007% 7e13
    uint public override minProtection; // e.g 10 FIL 1e19
    uint public override minPeriod; // e.g a week 604800

    uint constant public override DECIMAL_PRECISION = 1e18;
    uint constant public override MAX_DELEGATE_FEE_RATE = 5e17; // 50%
    bytes public beneficiaryBytesAddr;

    uint public totalCovered;
    uint public bufferRate; // e.g 9e17 90%;

    struct Policy {
        address miner;
        address pvault;
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

    mapping (address => mapping(uint => Policy)) public policies; // miner => policyId =>　Policy
    mapping (address => uint) public policyId;

    mapping (address => mapping(uint => Claim)) public claims; // miner => claimId => Claim
    mapping (address => uint) public claimId;

    mapping(address => bool) public override isAssessor;

}