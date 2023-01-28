// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import { IAssurageProxyFactory } from "../interfaces/IAssurageProxyFactory.sol";
import { IProxied } from "../proxy/1967Proxy/interfaces/IProxied.sol";
import { ProxiedInternals } from "../proxy/1967Proxy/ProxiedInternals.sol";

import { AssurageManagerStorage } from "../proxy/AssurageManagerStorage.sol";

import { IERC20 } from "../interfaces/IERC4626.sol";
import { IAssurageGlobal } from "../interfaces/IAssurageGlobal.sol";
import { IProtectionVault } from "../interfaces/IProtectionVault.sol";

import { IAssurageManager } from "../interfaces/IAssurageManager.sol";
import { MinerActor } from "../FilecoinSolidityAPI/MinerActor.sol";


contract AssurageManager is IAssurageManager, ProxiedInternals, AssurageManagerStorage {

    modifier onlyDelegate() {
        require(
            msg.sender == assurageDelegate,
            "Only callable by Owner"
        );
    
        _;
    }

    modifier nonReentrant() {
        require(_locked == 1, "PM:LOCKED");

        _locked = 2;

        _;

        _locked = 1;
    }

    // constructor(address _assessor) {
    //     owner = msg.sender;
    //     assessor = _assessor;
    // }

    function migrate(address migrator_, bytes calldata arguments_) external override {
        require(msg.sender == _factory(),        "PM:M:NOT_FACTORY");
        require(_migrate(migrator_, arguments_), "PM:M:FAILED");
    }

    function setImplementation(address implementation_) external override {
        require(msg.sender == _factory(), "PM:SI:NOT_FACTORY");
        _setImplementation(implementation_);
    }

    function upgrade(uint256 _version, bytes calldata _arguments) external override {
        require(msg.sender == assurageDelegate || msg.sender == governor(), "PM:U:NOT_AUTHORIZED");
        IAssurageProxyFactory(_factory()).upgradeInstance(_version, _arguments);
    }

    function configure(
        address _assessor,
        uint _minProtection,
        uint256 _liquidityCap,
        uint256 _delegateManagementFeeRate
    )
        external override
    {
        require(!configured, "PM:CO:ALREADY_CONFIGURED");
        require(IAssurageGlobal(global()).isVaultDeployer(msg.sender), "PM:CO:NOT_DEPLOYER");
        require(_delegateManagementFeeRate <= HUNDRED_PERCENT, "PM:CO:OOB");
        require(minProtection != 0, "");

        configured = true;
        assessor = _assessor;
        minProtection = _minProtection;
        liquidityCap = _liquidityCap;
        delegateManagementFeeRate = _delegateManagementFeeRate;

        emit VaultConfigured(_liquidityCap, _delegateManagementFeeRate);
    }

    // ---------------------------------- //
    // Protection Vault Operations
    // ---------------------------------- //

    function setActive(bool _active) external override {
        require(msg.sender == global(), "PM:SA:NOT_GLOBALS");
        emit SetAsActive(active = _active);
    }

    function setDelegateManagementFeeRate(uint256 _delegateManagementFeeRate) external override onlyDelegate {
        require(_delegateManagementFeeRate <= MAX_DELEGATE_FEE_RATE, "PM:SDMFR:OOB");
        emit DelegateManagementFeeRateSet(delegateManagementFeeRate = _delegateManagementFeeRate);
    }

    function setLiquidityCap(uint256 _liquidityCap) external override onlyDelegate {
        emit LiquidityCapSet(liquidityCap = _liquidityCap);
    }

    function setMinProtection(uint _minProtection) public onlyOwner {
        require(_minProtection > 0, "Invalid Amount");
        emit MinProtectionSet(minProtection = _minProtection);
    }

    function setAssessor(address _assessor) public onlyOwner {
        require(_assessor != address(0), "Invalid Address");
        isAssessor[_assessor] = true;
        emit AssessorAddrSet(assessor = _assessor);
    } 

    function setBeneficiaryBytesAddr(bytes memory _beneficiaryBytesAddr) public onlyOwner {
        emit BeneficiaryBytesAddrSet(beneficiaryBytesAddr = _beneficiaryBytesAddr);
    }

    // ---------------------------------- //
    // Miner API methods
    // ---------------------------------- //

    function getOwner(address _miner) internal view returns(bytes memory) { 
        MinerActor minerInstance = MinerActor(_miner);
        return minerInstance.getOwner().owner;    
    }

    function getBeneficiary(address _miner) internal view returns(bytes memory) {
        MinerActor minerInstance = MinerActor(_miner);
        return minerInstance.mockGetBeneficiary().activeBeneficiary;
    }

    function _verifyBeneficiaryBytesAddr(address _miner) internal view returns(bool) {
        address minerBeneficiary = getBeneficiary(_miner);
        return beneficiaryBytesAddr == minerBeneficiary;
    }

    function _getAvailableBalance(address _miner) internal view returns(uint) {
        MinerActor minerInstance = MinerActor(_miner);
        return minerInstance.getAbailableBalance(_miner);
    }

    // ---------------------------------- //
    // Miner Operations for Application/Policy
    // ---------------------------------- //

    function applyForProtection(address _miner, address _pvault, uint _amount, uint _period) public returns(Policy memory, uint) {
        require(_miner == msg.sender, "Invalid caller");
        require(_validateApplication(_miner, _pvault, _amount, _period), "Invalid Application");

        uint newId = policyId[_miner] == 0 ? 1 : (policyId[_miner] + 1);

        Policy storage policy = policies[_miner][newId];
        policy.miner = _miner;
        policy.pvault = _pvault;
        policy.amount = _amount;
        policy.period = _period;

        policyId[_miner]++;

        emit newApplicationMade(_miner, _pvault, _amount, _period, newId);
        return (policies[_miner][newId], newId);
    }

    function _validateApplication(address _miner, address _pvault, uint _amount, uint _period) internal view returns(bool) {

        require(_pvault == vault, "Invalid Vault");
        require(_verifyBeneficiaryBytesAddr(_miner), "Invalid Beneficiary");

        require(_amount >= minProtection, "Invalid Amount");
        require(_period >= minPeriod, "Invalid Period");

        uint totalAsset = totalAssets();
        uint protectionCapacity = totalAsset * bufferRate / DECIMAL_PRECISION; 
        require(totalAsset + _amount <= protectionCapacity, "Insufficient Capacity");

        return true;
    }

    function activatePolicy(address _miner, uint _id) external returns(Policy memory) {
        require( _miner == msg.sender, "Invalid caller");
        require(_validatePolicyActivation(_miner, _id), "Invalid Activation");

        Policy memory policy = policies[_miner][_id];

        uint premium = _quotePremium(policy.amount, policy.period, policy.score);
        policy.premium = premium;

        policy.expiry = block.timestamp + policy.period;
        policy.isActive = true;

        IProtectionVault(policy.pvault).payPremium(_miner, premium);

        policies[_miner][_id] = policy;
        return policies[_miner][_id];
    }

    function _validatePolicyActivation(address _miner, uint _id) internal view returns(bool) {
         Policy memory policy = policies[_miner][_id];

        require(_miner == policy.miner, "Invalid miner");
        require(policy.isApproved, "Not Approved yet");
        require(!policy.isActive, "Already activated");

        uint balance = _getAvailableBalance(_miner);
        require(balance >= premium, "Insufficient Balance");

        return true;
    }

    function _quotePremium(uint _amount, uint _peirod, uint8 _score) public view returns(uint) {
        uint basePremium = (_amount * _peirod) * ( premiumFactor / DECIMAL_PRECISION );
        return basePremium * DECIMAL_PRECISION / ( _score * DECIMAL_PRECISION );
    }

    // ---------------------------------- //
    // Miner Operations for Claiming
    // ---------------------------------- //
    function fileClaim(address _miner, uint _id, uint _claimable) public {
       require( _miner == msg.sender, "Invalid caller");
       require( policies[_miner][_id].amount >= _claimable, "claim amount is too large");

       uint newId = claimId[_miner] == 0 ? 1 : (claimId[_miner] + 1);

       _updateClaim(_miner, _claimable, false, false, newId);

       claimId[_miner]++;
    }

    function payCompensation(address _miner, uint _id) public returns(uint){
        require( _miner == msg.sender, "Invalid caller");
        require(_miner == policy.miner, "Invalid miner");

        Claim memory claim = claims[_miner][_id];
        require(claim.isComfirmed, "Claim hasn't been confirmed yet");
        require(claim.isPaid, "Already Paid");

        uint totalAsset = IProtectionVault(vault).totalAssets();
        require(totalAsset >= claim.claimable, "Insufficient Vault Liquidity");

        IProtectionVault(policies[_miner][_id].pvault).sendClaimETH(_miner, claim.claimable);
        _updateClaim(_miner, claim.claimable, claim.isComfirmed, true, _id);

        return claim.claimable;
    }

    function _updateClaim(address _miner, uint _claimable, bool _isComfirmed, bool _isPaid, uint _id) internal {
        Claim storage claim = claims[_miner][_id];

        claim.miner = _miner;
        claim.claimable = _claimable;
        claim.isComfirmed = _isComfirmed;
        claim.isPaid = _isPaid;
    }

    function renewPolocy(address _miner, uint _id) public returns(Policy memory)  {
        require( _miner == msg.sender, "Invalid caller");

        Policy memory policy = policies[_miner][_id];
        require(policy.expiry >= block.timestamp, "Policy has expired");

        uint premium = _quotePremium(policy.amount, policy.period, policy.score);
        policy.premium = premium;

        policy.expiry = policy.expiry + policy.period;
        IProtectionVault(policy.pvault).payPremium(_miner, premium);

        return policies[_miner][_id];
    }

    // should be here applyForPolicyRenewal()

    // ---------------------------------- //
    // Assessor Operation
    // ---------------------------------- //

    function approvePolicy(address _miner, uint _id, uint8 _score) public {
        require(isAssessor(msg.sender), "Invalid Assossor");

        Policy storage policy = policies[_miner][_id];
        require(policy.isApproved == false, "Already aaproved");

        policy.isApproved = true;
        policy.score = _score;
    }

    function approveClaim(address _miner, uint _id, uint _claimable) public {
        require(isAssessor(msg.sender), "Invalid Assossor");

        Claim storage claim = claims[_miner][_id];
        require(claim.miner != address(0) && claim.claimable != 0, "Invalid Claim");

        claim.claimable = _claimable;
        claim.isComfirmed = true;
    }

    function rejectClaim(address _miner, uint _id) public {
        require(isAssessor(msg.sender), "Invalid Assossor");

        Claim storage claim = claims[_miner][_id];
        require(claim.miner != address(0), "Invalid Miner");

        claim.isComfirmed = false;
    }

    function modifyScore(address _miner, uint _id, uint8 _score) public {
        require(isAssessor(msg.sender), "Invalid Assossor");
        policies[_miner][_id].score = _score;
    }

    // ---------------------------------- //
    // View Functions
    // ---------------------------------- //
    function factory() external view override returns (address factory) {
        factory = _factory();
    }

    function global() public view override returns (address global) {
        global = IAssurageProxyFactory(_factory()).assurageGlobal();
    }

    function governor() public view override returns (address governor) {
        governor = IAssurageGlobal(global()).governor();
    }

    function implementation() external view override returns (address implementation) {
        implementation = _implementation();
    }

    function totalAssets() public view override returns (uint256 totalAssets) {
        totalAssets = IERC20(asset).balanceOf(vault);

        // for (uint256 i_ = 0; i_ < length_;) {
        //     totalAssets_ += IStrategy(strategyList[i_]).assetsUnderManagement();
        //     unchecked { ++i_; }
        // }
    }
}