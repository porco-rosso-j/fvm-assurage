// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.17;

import {IWFIL} from "../interfaces/IWFIL.sol";
import {IAssurageProxyFactory} from "../interfaces/IAssurageProxyFactory.sol";
import {IAssurageGlobal} from "../interfaces/IAssurageGlobal.sol";
import {IStrategy} from "../interfaces/IStrategy.sol";
import {IProtectionVault} from "../interfaces/IProtectionVault.sol";

import {IAssurageManager} from "../interfaces/IAssurageManager.sol";
import {ProxiedInternals} from "../proxy/1967Proxy/ProxiedInternals.sol";
import {AssurageManagerStorage} from "../proxy/AssurageManagerStorage.sol";

import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {MinerAPIHepler} from "../filecoin-api/MinerAPIHepler.sol";

contract AssurageManager is
    IAssurageManager,
    ProxiedInternals,
    AssurageManagerStorage,
    MinerAPIHepler
{
    uint256 public constant HUNDRED_PERCENT = 100_0000;

    modifier onlyDelegate() {
        require(msg.sender == assurageDelegate, "Only callable by Owner");

        _;
    }

    modifier nonReentrant() {
        require(_locked == 1, "PM:LOCKED");

        _locked = 2;

        _;

        _locked = 1;
    }

    function migrate(address migrator_, bytes calldata arguments_)
        external
        override
    {
        require(msg.sender == _factory(), "PM:M:NOT_FACTORY");
        require(_migrate(migrator_, arguments_), "PM:M:FAILED");
    }

    function setImplementation(address implementation_) external override {
        require(msg.sender == _factory(), "PM:SI:NOT_FACTORY");
        _setImplementation(implementation_);
    }

    function upgrade(uint256 _version, bytes calldata _arguments)
        external
        override
    {
        require(
            msg.sender == assurageDelegate || msg.sender == governor(),
            "PM:U:NOT_AUTHORIZED"
        );
        IAssurageProxyFactory(_factory()).upgradeInstance(_version, _arguments);
    }

    function configure(
        uint256 _minProtection,
        uint256 _liquidityCap,
        uint256 _delegateManagementFeeRate
    ) external override {
        require(!configured, "PM:CO:ALREADY_CONFIGURED");
        require(
            IAssurageGlobal(global()).isVaultDeployer(msg.sender),
            "PM:CO:NOT_DEPLOYER"
        );
        require(_delegateManagementFeeRate <= HUNDRED_PERCENT, "PM:CO:OOB");
        require(_minProtection != 0, "");

        configured = true;
        minProtection = _minProtection;
        liquidityCap = _liquidityCap;
        delegateManagementFeeRate = _delegateManagementFeeRate;

        emit VaultConfigured(
            _minProtection,
            _liquidityCap,
            _delegateManagementFeeRate
        );
    }

    // ---------------------------------- //
    // Config Operations
    // ---------------------------------- //

    function setActive(bool _active) external override {
        require(msg.sender == global(), "PM:SA:NOT_GLOBALS");
        emit SetAsActive(active = _active);
    }

    function setDelegateManagementFeeRate(uint256 _delegateManagementFeeRate)
        external
        override
        onlyDelegate
    {
        require(
            _delegateManagementFeeRate <= MAX_DELEGATE_FEE_RATE,
            "PM:SDMFR:OOB"
        );
        emit DelegateManagementFeeRateSet(
            delegateManagementFeeRate = _delegateManagementFeeRate
        );
    }

    function setLiquidityCap(uint256 _liquidityCap)
        external
        override
        onlyDelegate
    {
        emit LiquidityCapSet(liquidityCap = _liquidityCap);
    }

    function setMinProtection(uint256 _minProtection)
        public
        override
        onlyDelegate
    {
        require(_minProtection > 0, "Invalid Amount");
        emit MinProtectionSet(minProtection = _minProtection);
    }

    function setAssessor(address _assessor) public override onlyDelegate {
        require(_assessor != address(0), "Invalid Address");
        isAssessor[_assessor] = true;
        emit AssessorAddrSet(assessor = _assessor);
    }

    function setBeneficiaryBytesAddr(bytes memory _beneficiaryBytesAddr)
        public
        override
        onlyDelegate
    {
        emit BeneficiaryBytesAddrSet(
            beneficiaryBytesAddr = _beneficiaryBytesAddr
        );
    }

    // ---------------------------------- //
    // Miner Operations for Application/Policy
    // ---------------------------------- //

    function applyForProtection(
        address _miner,
        bytes memory _minerId,
        uint256 _amount,
        uint256 _period
    ) public override returns (Policy memory, uint256) {
        require(_miner == msg.sender, "Invalid caller");
        require(
            _validateApplication(_miner, _minerId, _amount, _period),
            "Invalid Application"
        );

        uint256 newId = policyId[_miner] == 0 ? 1 : (policyId[_miner] + 1);

        Policy storage policy = policies[_miner][newId];
        policy.miner = _miner;
        policy.minerId = _minerId;
        policy.amount = _amount;
        policy.period = _period;

        policyId[_miner]++;

        emit newApplicationMade(_miner, _amount, _period, newId);
        return (policies[_miner][newId], newId);
    }

    function _validateApplication(
        address _miner,
        bytes memory _minerId,
        uint256 _amount,
        uint256 _period
    ) internal view returns (bool) {
        require(_minerId.length != 0, "Invalid MinerID");
        require(
            _validateBeneficiary(_miner, beneficiaryBytesAddr),
            "Invalid Beneficiary"
        );
        require(_amount >= minProtection, "Invalid Amount");
        require(_period >= minPeriod, "Invalid Period");

        return true;
    }

    function activatePolicy(address _miner, uint256 _id)
        public
        override
        returns (Policy memory)
    {
        require(
            _miner == msg.sender && _miner == policy.miner,
            "Invalid Miner"
        );
        require(policy.isApproved, "Not Approved yet");
        require(!policy.isActive, "Already activated");

        Policy memory policy = policies[_miner][_id];

        uint256 premium = _quotePremium(
            policy.amount,
            policy.period,
            policy.score
        );
        policy.premium = premium;

        policy.expiry = block.timestamp + policy.period;
        policy.isActive = true;

        _withdrawAndPayPremium(_miner, policy.minerId, premium);

        policies[_miner][_id] = policy;
        emit newPolicyActivated(policy, _id);
        return policies[_miner][_id];
    }

    function _quotePremium(
        uint256 _amount,
        uint256 _peirod,
        uint8 _score
    ) public view returns (uint256) {
        uint256 basePremium = (_amount * _peirod) *
            (premiumFactor / DECIMAL_PRECISION);
        return (basePremium * DECIMAL_PRECISION) / (_score * DECIMAL_PRECISION);
    }

    function _withdrawAndPayPremium(
        address _miner,
        bytes memory _minerId,
        uint256 _premium
    ) internal {
        require(
            _validateAvailableBalance(_minerId, _miner),
            "Insufficient Balance"
        );

        require(
            _validateBeneficiaryInfo(_miner, beneficiaryBytesAddr, _premium),
            "Invalid Beneficiary"
        );

        require(_withdrawBalance(_minerId, _premium), "Withdrawal Failed");

        IWFIL(asset).deposit{value: _premium}();

        SafeTransferLib.safeTransfer(ERC20(asset), vault, _premium);
    }

    // ---------------------------------- //
    // Miner Operations for Claiming
    // ---------------------------------- //
    function fileClaim(
        address _miner,
        uint256 _id,
        uint256 _claimable,
        bytes memory _minerId
    ) public override {
        require(_miner == msg.sender, "Invalid caller");
        require(
            policies[_miner][_id].amount >= _claimable,
            "claim amount is too large"
        );

        uint256 newId = claimId[_miner] == 0 ? 1 : (claimId[_miner] + 1);

        Claim memory claim = _updateClaim(
            _miner,
            _minerId,
            _claimable,
            false,
            false,
            newId
        );

        claimId[_miner]++;

        emit newClaimFiled(claim, _id);
    }

    function payCompensation(address _miner, uint256 _id)
        public
        override
        returns (uint256)
    {
        require(_miner == msg.sender, "Invalid caller");

        Claim memory claim = claims[_miner][_id];
        require(_miner == claim.miner, "Invalid miner");
        require(claim.isComfirmed, "Claim hasn't been confirmed yet");
        require(claim.isPaid, "Already Paid");
        require(
            totalAssets() >= claim.claimable,
            "Insufficient Vault Liquidity"
        );

        IProtectionVault(vault).sendClaimedFIL(claim.minerId, claim.claimable);
        _updateClaim(
            _miner,
            claim.minerId,
            claim.claimable,
            claim.isComfirmed,
            true,
            _id
        );

        emit newCompensationPaid(claim, _id);
        return claim.claimable;
    }

    function _updateClaim(
        address _miner,
        bytes memory _minerId,
        uint256 _claimable,
        bool _isComfirmed,
        bool _isPaid,
        uint256 _id
    ) internal returns (Claim memory) {
        Claim storage claim = claims[_miner][_id];

        claim.miner = _miner;
        claim.minerId = _minerId;
        claim.claimable = _claimable;
        claim.isComfirmed = _isComfirmed;
        claim.isPaid = _isPaid;

        return claim;
    }

    // function renewPolocy(address _miner, uint256 _id)
    //     public
    //     override
    //     returns (Policy memory)
    // {
    //     require(_miner == msg.sender, "Invalid caller");

    //     Policy storage policy = policies[_miner][_id];
    //     require(policy.expiry >= block.timestamp, "Policy has expired");

    //     uint256 premium = _quotePremium(
    //         policy.amount,
    //         policy.period,
    //         policy.score
    //     );
    //     policy.premium = premium;

    //     policy.expiry = policy.expiry + policy.period;

    //     return policies[_miner][_id];
    // }

    // should be here applyForPolicyRenewal()

    // ---------------------------------- //
    // Assessor Operation
    // ---------------------------------- //

    function approvePolicy(
        address _miner,
        uint256 _id,
        uint8 _score
    ) public override {
        require(isAssessor[msg.sender], "Invalid Assossor");

        Policy storage policy = policies[_miner][_id];
        require(policy.isApproved == false, "Already aaproved");

        policy.isApproved = true;
        policy.score = _score;
    }

    function approveClaim(
        address _miner,
        uint256 _id,
        uint256 _claimable
    ) public override {
        require(isAssessor[msg.sender], "Invalid Assossor");

        Claim storage claim = claims[_miner][_id];
        require(
            claim.miner != address(0) && claim.claimable != 0,
            "Invalid Claim"
        );

        claim.claimable = _claimable;
        claim.isComfirmed = true;
    }

    function rejectClaim(address _miner, uint256 _id) public override {
        require(isAssessor[msg.sender], "Invalid Assossor");

        Claim storage claim = claims[_miner][_id];
        require(claim.miner != address(0), "Invalid Miner");

        claim.isComfirmed = false;
    }

    function modifyScore(
        address _miner,
        uint256 _id,
        uint8 _score
    ) public override {
        require(isAssessor[msg.sender], "Invalid Assossor");
        policies[_miner][_id].score = _score;
    }

    // ---------------------------------- //
    // Storategy Operations
    // ---------------------------------- //

    function addStrategy(address _strategy) public override onlyDelegate {
        require(
            IAssurageGlobal(global()).isStrategy(_strategy),
            "Unregistered Strategy"
        );
        strategyList.push(_strategy);
        IStrategy(_strategy).approveManager();
    }

    function investInStrategy(uint256 _index, uint256 _amount)
        public
        override
        onlyDelegate
    {
        require(_index < strategyList.length, "Invalid Index");

        address strategy = strategyList[_index];

        // transfer wFIL from vault ot strategy
        SafeTransferLib.safeTransferFrom(
            ERC20(asset),
            vault,
            strategy,
            _amount
        );
        // have strategy proceed deposit
        IStrategy(strategy).deposit(_amount);
    }

    function withdrawFromStrategy(uint256 _index, uint256 _amount)
        public
        override
        onlyDelegate
    {
        require(_index < strategyList.length, "Invalid Index");
        require(
            IWFIL(asset).balanceOf(vault) > _amount,
            "Insufficient Balance"
        );

        address strategy = strategyList[_index];
        require(IStrategy(strategy).getBalance(_amount) != 0, "No Balance");

        // send share token to Strategy contract
        SafeTransferLib.safeTransfer(
            ERC20(IStrategy(strategy).share()),
            strategy,
            _amount
        );

        // have Strategy contract proceed withdrawal
        uint256 withdrawn_amount = IStrategy(strategy).withdraw(_amount);

        // send wFIL back to vault
        SafeTransferLib.safeTransferFrom(
            ERC20(wFIL),
            strategy,
            vault,
            withdrawn_amount
        );
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
        uint256 totalAsset = IWFIL(asset).balanceOf(vault);

        uint256 length = strategyList.length;
        uint256 balance;
        for (uint256 i = 0; i < length; ) {
            balance = IWFIL(IStrategy(strategyList[i]).share()).balanceOf(
                address(this)
            );
            totalAsset += IStrategy(strategyList[i]).getBalance(balance);
            unchecked {
                ++i;
            }
        }

        return totalAsset;
    }
}
