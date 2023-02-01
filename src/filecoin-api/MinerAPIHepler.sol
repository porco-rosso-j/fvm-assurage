// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.17;

import {BigInt} from "filecoin-solidity/contracts/v0.8/cbor/BigIntCbor.sol";
import {MinerTypes} from "filecoin-solidity/contracts/v0.8/types/MinerTypes.sol";
import {CommonTypes} from "filecoin-solidity/contracts/v0.8/types/CommonTypes.sol";
import {MinerAPI} from "filecoin-solidity/contracts/v0.8//MinerAPI.sol";
import {PrecompilesAPI} from "filecoin-solidity/contracts/v0.8//PrecompilesAPI.sol";
import {BytesHelper} from "./BytesHelper.sol";

// A contract that handles fetching and validating return values via MinerAPI
contract MinerAPIHepler {
    using BytesHelper for bytes;

    function getOwner(bytes memory _miner) internal returns (bytes memory) {
        MinerTypes.GetOwnerReturn memory ownerReturn = MinerAPI.getOwner(
            _miner
        );
        return ownerReturn.owner;
    }

    function _validateAvailableBalance(bytes memory _miner, uint256 _premium)
        internal
        returns (bool)
    {
        MinerTypes.GetAvailableBalanceReturn memory availableBalance = MinerAPI
            .getAvailableBalance(_miner);
        BigInt memory balanceBigInt = availableBalance.available_balance;
        bytes memory balanceBytes = balanceBigInt.val;

        require(
            BytesHelper.bytesToUint(balanceBytes) >= _premium,
            "Insufficient Balance"
        );

        return true;
    }

    function _validateBeneficiary(
        bytes memory _miner,
        bytes memory _beneficiaryBytesAddr
    ) internal returns (bool) {
        MinerTypes.GetBeneficiaryReturn memory beneficiary = MinerAPI
            .getBeneficiary(_miner);
        CommonTypes.ActiveBeneficiary memory activeBeneficiary = beneficiary
            .active;

        require(
            keccak256(_beneficiaryBytesAddr) ==
                keccak256(activeBeneficiary.beneficiary),
            "Invalid Beneficiary"
        );

        return true;
    }

    function _validateBeneficiaryInfo(
        bytes memory _miner,
        bytes memory _beneficiaryBytesAddr,
        uint256 _premium
    )
        internal
        returns (
            bytes memory,
            uint256,
            uint256
        )
    {
        MinerTypes.GetBeneficiaryReturn memory beneficiary = MinerAPI
            .getBeneficiary(_miner);
        CommonTypes.ActiveBeneficiary memory activeBeneficiary = beneficiary
            .active;

        require(
            keccak256(_beneficiaryBytesAddr) ==
                keccak256(activeBeneficiary.beneficiary),
            "Invalid Beneficiary"
        );

        CommonTypes.BeneficiaryTerm memory term = activeBeneficiary.term;
        BigInt memory _quota = term.quota;
        BigInt memory _used_quota = term.used_quota;
        uint64 _expiration = term.expiration;

        uint256 quota = BytesHelper.bytesToUint(_quota.val);
        uint256 used_quota = BytesHelper.bytesToUint(_used_quota.val);
        uint256 expiration = uint256(_expiration);

        require(quota - used_quota >= _premium, "Insufficient allowance");
        require(expiration > block.timestamp, "Invalid expiration");

        return true;
    }

    function _withdrawBalance(bytes memory _miner, uint256 _amount)
        internal
        returns (bool)
    {
        MinerTypes.WithdrawBalanceParams memory param;
        param.amount_requested = BytesHelper.toBytes(_amount);
        MinerTypes.WithdrawBalanceReturn memory result = MinerAPI
            .withdrawBalance(_miner, param);

        require(
            BytesHelper.bytesToUint(result.amount_withdrawn) == _amount,
            "Invalid return value"
        );

        return true;
    }
}
