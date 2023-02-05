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

import {SafeTransferLib, ERC20} from "solmate/utils/SafeTransferLib.sol";
import {MinerAPIHepler} from "../filecoin-api/MinerAPIHepler.sol";

import {console} from "forge-std/console.sol";

contract AssurageManager is
    IAssurageManager,
    ProxiedInternals,
    AssurageManagerStorage,
    MinerAPIHepler
{
    uint256 public constant HUNDRED_PERCENT = 100_0000;

    modifier onlyDelegate() {
        require(msg.sender == assurageDelegate, "NOT_DELEGATE");

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
        uint256 _minPeriod,
        uint256 _liquidityCap,
        uint256 _delegateManagementFeeRate
    ) external override {
        require(!configured, "PM:CO:ALREADY_CONFIGURED");
        require(
            IAssurageGlobal(global()).isVaultDeployer(msg.sender),
            "PM:CO:NOT_DEPLOYER"
        );
        require(_delegateManagementFeeRate <= HUNDRED_PERCENT, "PM:CO:OOB");
        require(_minProtection != 0 && _minPeriod != 0, "INVALID_AMOUNT");

        configured = true;

        minPeriod = _minPeriod;
        minProtection = _minProtection;
        liquidityCap = _liquidityCap;
        delegateManagementFeeRate = _delegateManagementFeeRate;

        assessor = assurageDelegate;
        isAssessor[assurageDelegate] = true;
        beneficiaryBytesAddr = _getIdFromETHAddr(address(this));

        emit VaultConfigured(
            _minProtection,
            _minPeriod,
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
        require(_delegateManagementFeeRate <= HUNDRED_PERCENT, "PM:SDMFR:OOB");
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
        require(_minProtection > 0, "INVALID_AMOUNT");
        emit MinProtectionSet(minProtection = _minProtection);
    }

    function setMinPeriod(uint256 _minPeriod) public override onlyDelegate {
        require(_minPeriod > 0, "INVALID_AMOUNT");
        emit MinPeriodSet(minPeriod = _minPeriod);
    }

    function setAssessor(address _assessor) public override onlyDelegate {
        require(_assessor != address(0), "INVALID_ADDRESS");
        assessor = _assessor;
        isAssessor[_assessor] = true;
        emit AssessorAddrSet(assessor = _assessor);
    }

    // ---------------------------------- //
    // Miner Operations for Application/Policy
    // ---------------------------------- //

    function applyForProtection(
        address _miner,
        uint256 _amount,
        uint256 _period
    ) public override returns (uint256) {
        require(_miner == msg.sender, "INVALID_CALLER");
        require(_amount >= minProtection, "INVALID_AMOUNT");
        require(_period >= minPeriod, "INVALID_PEIROD");
        _validateBeneficiary(_miner, beneficiaryBytesAddr);

        uint256 newId = policyId[_miner] == 0 ? 1 : (policyId[_miner] + 1);

        Policy storage policy = policies[_miner][newId];
        policy.miner = _miner;
        policy.amount = _amount;
        policy.period = _period;

        policyId[_miner]++;

        emit newApplicationMade(_miner, _amount, _period, newId);
        return newId;
    }

    function activatePolicy(address _miner, uint256 _id) public override {
        require(_miner == msg.sender, "INVALID_CALLER");

        Policy memory policy = policies[_miner][_id];
        require(policy.isApproved, "NOT_APPROVED");
        require(!policy.isActive, "ALREADY_ACTIVATED");

        uint256 premium = _quotePremium(
            policy.amount,
            policy.period,
            policy.score
        );
        policy.premium = premium;

        policy.expiry = block.timestamp + policy.period;
        policy.isActive = true;

        _withdrawAndPayPremium(_miner, premium);

        policies[_miner][_id] = policy;
        emit newPolicyActivated(policy, _id);
    }

    function _quotePremium(
        uint256 _amount,
        uint256 _peirod,
        uint8 _score
    ) public pure returns (uint256) {
        uint256 PERIOD_DAYS = _peirod / 60 / 60 / 24;
        uint256 BASE_PREMIUM = (_amount * PERIOD_DAYS * premiumFactor) /
            DECIMAL_PRECISION;
        uint256 PREMIUM = (BASE_PREMIUM *
            ((_score * DECIMAL_PRECISION) / 100)) / DECIMAL_PRECISION;
        return PREMIUM;
    }

    function _withdrawAndPayPremium(address _miner, uint256 _premium) internal {
        require(
            _validateAvailableBalance(_miner, _premium),
            "INSUFFICIENT_BALANCE"
        );

        require(
            _validateBeneficiaryInfo(_miner, beneficiaryBytesAddr, _premium),
            "INVALID_BENEFICIARY_INFO"
        );

        require(_withdrawBalance(_miner, _premium), "WITHDRAWAL_FAILED");

        IWFIL(asset).deposit{value: _premium}();

        SafeTransferLib.safeTransfer(ERC20(asset), vault, _premium);
    }

    // ---------------------------------- //
    // Miner Operations for Claiming
    // ---------------------------------- //
    function fileClaim(
        address _miner,
        uint256 _id,
        uint256 _claimable
    ) public override {
        require(_miner == msg.sender, "INVALID_CALLER");
        Policy memory policy = policies[_miner][_id];
        require(policy.isActive, "NOT_ACTIVATED");
        require(
            policy.amount >= _claimable && _claimable != 0,
            "INVALID_AMOUNT"
        );

        Claim memory claim = _updateClaim(
            _miner,
            _id,
            _claimable,
            false,
            false
        );

        emit newClaimFiled(claim, _id);
    }

    function claimCompensation(address _miner, uint256 _id)
        public
        payable
        override
        returns (uint256)
    {
        require(_miner == msg.sender, "INVALID_CALLER");

        Claim memory claim = policies[_miner][_id].claim;
        require(claim.isConfirmed, "NOT_CONFIRMED");
        require(!claim.isPaid, "ALREADY_PAID");
        require(totalAssets() >= claim.claimable, "INSUFFICIENT_LIQUIDITY");

        SafeTransferLib.safeTransferFrom(
            ERC20(asset),
            vault,
            address(this),
            claim.claimable
        );

        IWFIL(address(asset)).withdraw(claim.claimable);
        _sendClaimedFILToMiner(_miner, claim.claimable);

        _updateClaim(_miner, _id, claim.claimable, claim.isConfirmed, true);
        policies[_miner][_id].isActive = false;

        emit newCompensationPaid(claim, _id);
        return claim.claimable;
    }

    function _updateClaim(
        address _miner,
        uint256 _id,
        uint256 _claimable,
        bool _isConfirmed,
        bool _isPaid
    ) internal returns (Claim memory) {
        Claim storage claim = policies[_miner][_id].claim;

        claim.claimable = _claimable;
        claim.isConfirmed = _isConfirmed;
        claim.isPaid = _isPaid;

        return claim;
    }

    // ---------------------------------- //
    // Assessor Operation
    // ---------------------------------- //

    function approvePolicy(
        address _miner,
        uint256 _id,
        uint8 _score
    ) public override {
        require(
            isAssessor[msg.sender] && assessor == msg.sender,
            "INVALID_ASSESSOR"
        );

        Policy storage policy = policies[_miner][_id];
        require(policy.isApproved == false, "ALREADY_APPROVED");

        policy.isApproved = true;
        policy.score = _score;
    }

    function approveClaim(
        address _miner,
        uint256 _id,
        uint256 _claimable
    ) public override {
        require(isAssessor[msg.sender], "Invalid Assossor");

        Claim storage claim = policies[_miner][_id].claim;
        require(claim.claimable != 0, "Invalid Claim");

        claim.claimable = _claimable;
        claim.isConfirmed = true;
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
            ERC20(asset),
            strategy,
            vault,
            withdrawn_amount
        );
    }

    // ---------------------------------- //
    // View Functions
    // ---------------------------------- //
    function getClaim(address _miner, uint256 _id)
        external
        view
        returns (
            uint256,
            bool,
            bool
        )
    {
        Claim memory claim = policies[_miner][_id].claim;
        return (claim.claimable, claim.isConfirmed, claim.isPaid);
    }

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

    receive() external payable {}
}

/*

   function rejectClaim(address _miner, uint256 _id) external;

    function rejectClaim(address _miner, uint256 _id) public override {
        require(isAssessor[msg.sender], "Invalid Assossor");

        Claim storage claim = policies[_miner][_id].claim;
        require(claim.claimable != 0, "Invalid Claim");

        claim.isConfirmed = false;
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
*/
