// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.17;

import {BigInt} from "filecoin-solidity/cbor/BigIntCbor.sol";
import {MinerTypes} from "filecoin-solidity/types/MinerTypes.sol";
import {CommonTypes} from "filecoin-solidity/types/CommonTypes.sol";
import {MinerAPI} from "filecoin-solidity//MinerAPI.sol";
import {BytesHelper} from "./BytesHelper.sol";

library AssurageMinerAPI {
    using BytesHelper for bytes;

    function getOwner(bytes memory _miner) internal returns (bytes memory) {
        MinerTypes.GetOwnerReturn memory ownerReturn = MinerAPI.getOwner(
            _miner
        );
        return ownerReturn.owner;
    }

    function getAvailableBalance(bytes memory _miner)
        internal
        returns (uint256)
    {
        MinerTypes.GetAvailableBalanceReturn memory availableBalance = MinerAPI
            .getAvailableBalance(_miner);
        BigInt memory balanceBigInt = availableBalance.available_balance;
        bytes memory balanceBytes = balanceBigInt.val;

        return BytesHelper.bytesToUint(balanceBytes);
    }

    function getBeneficiary(bytes memory _miner)
        internal
        returns (bytes memory)
    {
        MinerTypes.GetBeneficiaryReturn memory beneficiary = MinerAPI
            .getBeneficiary(_miner);
        CommonTypes.ActiveBeneficiary memory activeBeneficiary = beneficiary
            .active;
        return activeBeneficiary.beneficiary;
    }

    function getBeneficiaryInfo(bytes memory _miner)
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

        CommonTypes.BeneficiaryTerm memory term = activeBeneficiary.term;
        BigInt memory _quota = term.quota;
        BigInt memory _used_quota = term.used_quota;
        uint64 _expiration = term.expiration;

        uint256 quota = BytesHelper.bytesToUint(_quota.val);
        uint256 used_quota = BytesHelper.bytesToUint(_used_quota.val);
        uint256 expiration = uint256(_expiration);

        return (
            activeBeneficiary.beneficiary,
            (quota - used_quota),
            expiration
        );
    }

    function WithdrawBalance(bytes memory _miner, uint256 _amount)
        internal
        returns (uint256)
    {
        MinerTypes.WithdrawBalanceParams memory param;
        param.amount_requested = BytesHelper.toBytes(_amount);
        MinerTypes.WithdrawBalanceReturn memory result = MinerAPI
            .withdrawBalance(_miner, param);
        return BytesHelper.bytesToUint(result.amount_withdrawn);
    }
}
