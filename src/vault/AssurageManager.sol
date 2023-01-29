// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.7;

import {IWFIL, IERC20} from "../interfaces/IWFIL.sol";
import { IAssurageProxyFactory } from "../interfaces/IAssurageProxyFactory.sol";
import { IAssurageGlobal } from "../interfaces/IAssurageGlobal.sol";
import {IStrategy} from "../interfaces/IStrategy.sol";
import { IProtectionVault } from "../interfaces/IProtectionVault.sol";

import { IAssurageManager } from "../interfaces/IAssurageManager.sol";
import { ProxiedInternals } from "../proxy/1967Proxy/ProxiedInternals.sol";
import { AssurageManagerStorage } from "../proxy/AssurageManagerStorage.sol";

import { IMinerActor } from "../interfaces/IMinerActor.sol";

contract AssurageManager is IAssurageManager, ProxiedInternals, AssurageManagerStorage {

    uint256 public constant HUNDRED_PERCENT = 100_0000;

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

    function migrate(address migrator_, bytes calldata arguments_) external override {
        require(msg.sender == _factory(), "PM:M:NOT_FACTORY");
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
        uint256 _minProtection,
        uint256 _liquidityCap,
        uint256 _delegateManagementFeeRate
    )
        external override
    {
        require(!configured, "PM:CO:ALREADY_CONFIGURED");
        require(IAssurageGlobal(global()).isVaultDeployer(msg.sender), "PM:CO:NOT_DEPLOYER");
        require(_delegateManagementFeeRate <= HUNDRED_PERCENT, "PM:CO:OOB");
        require(_minProtection != 0, "");

        configured = true;
        minProtection = _minProtection;
        liquidityCap = _liquidityCap;
        delegateManagementFeeRate = _delegateManagementFeeRate;

        emit VaultConfigured(_minProtection, _liquidityCap, _delegateManagementFeeRate);
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

    function setMinProtection(uint _minProtection) public override onlyDelegate {
        require(_minProtection > 0, "Invalid Amount");
        emit MinProtectionSet(minProtection = _minProtection);
    }

    function setAssessor(address _assessor) public override onlyDelegate {
        require(_assessor != address(0), "Invalid Address");
        isAssessor[_assessor] = true;
        emit AssessorAddrSet(assessor = _assessor);
    } 

    function setBeneficiaryBytesAddr(bytes memory _beneficiaryBytesAddr) public override onlyDelegate {
        emit BeneficiaryBytesAddrSet(beneficiaryBytesAddr = _beneficiaryBytesAddr);
    }

    // ---------------------------------- //
    // Miner API methods
    // ---------------------------------- //

    function _verifyBeneficiaryBytesAddr(address _miner) internal view returns(bool) {
        bytes memory minerBeneficiary = IMinerActor(_miner).getBeneficiary();
        return keccak256(beneficiaryBytesAddr) == keccak256(minerBeneficiary);
    }

    function _getAvailableBalance(address _miner) internal view returns(uint) {
        return IMinerActor(_miner).getAvailableBalance();
    }

    function _withdrawBalance(address _miner, uint _premium) internal {
        IMinerActor(_miner).withdrawBalance(address(this), _premium);
    }

    // ---------------------------------- //
    // Miner Operations for Application/Policy
    // ---------------------------------- //

    function applyForProtection(address _miner, uint _amount, uint _period) public override returns(Policy memory, uint) {
        require(_miner == msg.sender, "Invalid caller");
        require(_validateApplication(_miner, _amount, _period), "Invalid Application");

        uint newId = policyId[_miner] == 0 ? 1 : (policyId[_miner] + 1);

        Policy storage policy = policies[_miner][newId];
        policy.miner = _miner;
        policy.amount = _amount;
        policy.period = _period;

        policyId[_miner]++;

        emit newApplicationMade(_miner, _amount, _period, newId);
        return (policies[_miner][newId], newId);
    }

    function _validateApplication(address _miner, uint _amount, uint _period) internal view returns(bool) {

        require(_verifyBeneficiaryBytesAddr(_miner), "Invalid Beneficiary");

        require(_amount >= minProtection, "Invalid Amount");
        require(_period >= minPeriod, "Invalid Period");

        // uint totalAsset = totalAssets();
        // uint protectionCapacity = totalAsset * bufferRate / DECIMAL_PRECISION; 
        // require(totalAsset + _amount <= protectionCapacity, "Insufficient Capacity");

        return true;
    }

    function activatePolicy(address _miner, uint _id) public override returns(Policy memory) {
        require( _miner == msg.sender, "Invalid caller");
        require(_validatePolicyActivation(_miner, _id), "Invalid Activation");

        Policy memory policy = policies[_miner][_id];

        uint premium = _quotePremium(policy.amount, policy.period, policy.score);
        policy.premium = premium;

        policy.expiry = block.timestamp + policy.period;
        policy.isActive = true;

        _withdrawAndPayPremium(_miner, premium);

        policies[_miner][_id] = policy;
        emit newPolicyActivated(policy, _id);
        return policies[_miner][_id];
    }

    function _validatePolicyActivation(address _miner, uint _id) internal view returns(bool) {
         Policy memory policy = policies[_miner][_id];

        require(_miner == policy.miner, "Invalid miner");
        require(policy.isApproved, "Not Approved yet");
        require(!policy.isActive, "Already activated");

        return true;
    }

    function _quotePremium(uint _amount, uint _peirod, uint8 _score) public view returns(uint) {
        uint basePremium = (_amount * _peirod) * ( premiumFactor / DECIMAL_PRECISION );
        return basePremium * DECIMAL_PRECISION / ( _score * DECIMAL_PRECISION );
    }

    address constant public WFIL = 0x4B7ee45f30767F36f06F79B32BF1FCa6f726DEda;

    function _withdrawAndPayPremium(address _miner, uint _premium) internal {

        if ( asset == WFIL ) {
           uint minerBalance = _getAvailableBalance(_miner);
           require(minerBalance >= _premium, "Insufficient Balance");

           _withdrawBalance(_miner, _premium);
           IWFIL(asset).deposit{ value:_premium }();

           require(IERC20(asset).transfer(vault, _premium), "Transfer Failed");

        } else {
            uint minerBalance = IERC20(asset).balanceOf(_miner);
            require(minerBalance >= _premium, "Insufficient Balance");

            require(IERC20(asset).transferFrom(_miner, vault, _premium), "Transfer Failed");
        }

    }

    // ---------------------------------- //
    // Miner Operations for Claiming
    // ---------------------------------- //
    function fileClaim(address _miner, uint _id, uint _claimable) public override {
       require( _miner == msg.sender, "Invalid caller");
       require( policies[_miner][_id].amount >= _claimable, "claim amount is too large");

       uint newId = claimId[_miner] == 0 ? 1 : (claimId[_miner] + 1);

       Claim memory claim = _updateClaim(_miner, _claimable, false, false, newId);

       claimId[_miner]++;

       emit newClaimFiled(claim, _id);
    }

    function payCompensation(address _miner, uint _id) public override returns(uint) {
        require( _miner == msg.sender, "Invalid caller");

        Claim memory claim = claims[_miner][_id];
        require(_miner == claim.miner, "Invalid miner");
        require(claim.isComfirmed, "Claim hasn't been confirmed yet");
        require(claim.isPaid, "Already Paid");

        uint totalAsset = totalAssets();
        require(totalAsset >= claim.claimable, "Insufficient Vault Liquidity");

        IProtectionVault(vault).sendClaimedFIL(_miner, claim.claimable);
        _updateClaim(_miner, claim.claimable, claim.isComfirmed, true, _id);

        emit newCompensationPaid(claim, _id);
        return claim.claimable;
    }

    function _updateClaim(address _miner, uint _claimable, bool _isComfirmed, bool _isPaid, uint _id) internal returns(Claim memory) {
        Claim storage claim = claims[_miner][_id];

        claim.miner = _miner;
        claim.claimable = _claimable;
        claim.isComfirmed = _isComfirmed;
        claim.isPaid = _isPaid;

        return claim;
    }

    function renewPolocy(address _miner, uint _id) public override returns(Policy memory)  {
        require( _miner == msg.sender, "Invalid caller");

        Policy storage policy = policies[_miner][_id];
        require(policy.expiry >= block.timestamp, "Policy has expired");

        uint premium = _quotePremium(policy.amount, policy.period, policy.score);
        policy.premium = premium;

        policy.expiry = policy.expiry + policy.period;

        return policies[_miner][_id];
    }

    // should be here applyForPolicyRenewal()

    // ---------------------------------- //
    // Assessor Operation
    // ---------------------------------- //

    function approvePolicy(address _miner, uint _id, uint8 _score) public override {
        require(isAssessor[msg.sender], "Invalid Assossor");

        Policy storage policy = policies[_miner][_id];
        require(policy.isApproved == false, "Already aaproved");

        policy.isApproved = true;
        policy.score = _score;
    }

    function approveClaim(address _miner, uint _id, uint _claimable) public override {
        require(isAssessor[msg.sender], "Invalid Assossor");

        Claim storage claim = claims[_miner][_id];
        require(claim.miner != address(0) && claim.claimable != 0, "Invalid Claim");

        claim.claimable = _claimable;
        claim.isComfirmed = true;
    }

    function rejectClaim(address _miner, uint _id) public override {
        require(isAssessor[msg.sender], "Invalid Assossor");

        Claim storage claim = claims[_miner][_id];
        require(claim.miner != address(0), "Invalid Miner");

        claim.isComfirmed = false;
    }

    function modifyScore(address _miner, uint _id, uint8 _score) public override {
        require(isAssessor[msg.sender], "Invalid Assossor");
        policies[_miner][_id].score = _score;
    }

    // ---------------------------------- //
    // Storategy Operations
    // ---------------------------------- //

    function addStrategy(address _strategy) public override onlyDelegate {
        strategyList.push(_strategy);
    }

    function investInStrategy(uint _index, uint _amount) public override onlyDelegate {
        IStrategy(strategyList[_index]).deposit(_amount);
    }

    function withdrawFromStrategy(uint _index, uint _amount) public override onlyDelegate {
        IStrategy(strategyList[_index]).withdraw(_amount);
    }

    // ---------------------------------- //
    // View Functions
    // ---------------------------------- //
    function factory() external view override returns (address) {
        return _factory();
    }

    function global() public view override returns (address) {
        return IAssurageProxyFactory(_factory()).assurageGlobal();
    }

    function governor() public view override returns (address) {
        return IAssurageGlobal(global()).governor();
    }

    function implementation() external view override returns (address) {
       return _implementation();
    }

    function totalAssets() public view override returns (uint256) {
        uint totalAsset = IERC20(asset).balanceOf(vault);

        uint256 length = strategyList.length;

        for (uint256 i = 0; i < length;) {
            totalAsset += IStrategy(strategyList[i]).getAUM();
            unchecked { ++i; }
        }

        return totalAsset;
    }
}