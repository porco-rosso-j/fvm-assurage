// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.17;

import {BigInt} from "filecoin-solidity/contracts/v0.8/cbor/BigIntCbor.sol";
import {MinerTypes} from "filecoin-solidity/contracts/v0.8/types/MinerTypes.sol";
import {CommonTypes} from "filecoin-solidity/contracts/v0.8/types/CommonTypes.sol";
import {MinerAPI} from "filecoin-solidity/contracts/v0.8//MinerAPI.sol";
import {PrecompilesAPI} from "filecoin-solidity/contracts/v0.8//PrecompilesAPI.sol";
import {SendAPI} from "filecoin-solidity/contracts/v0.8/SendAPI.sol";
import {BytesHelper} from "./BytesHelper.sol";

// A contract that handles fetching and validating return values via MinerAPI
contract MinerAPIHepler {
    using BytesHelper for bytes;
    uint256 Silencer;

    function getOwner(bytes memory _miner) internal returns (bytes memory) {
        MinerTypes.GetOwnerReturn memory ownerReturn = MinerAPI.getOwner(
            _miner
        );
        return ownerReturn.owner;
    }

    // Still Unusable func
    function _getIdFromETHAddr(address _add)
        internal
        view
        returns (bytes memory)
    {
        bytes memory bytesAddr = abi.encodePacked(_add);
        uint64 addressUint = PrecompilesAPI.resolveEthAddress(bytesAddr);
        return BytesHelper.toBytes(uint256(addressUint));
    }

    function _validateAvailableBalance(address _add, uint256 _premium)
        internal
        returns (bool)
    {
        bytes memory _miner = _getIdFromETHAddr(_add);
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
        address _add,
        bytes memory _beneficiaryBytesAddr
    ) internal returns (bool) {
        bytes memory _miner = _getIdFromETHAddr(_add);

        MinerTypes.GetBeneficiaryReturn memory beneficiary = MinerAPI
            .getBeneficiary(_miner);
        CommonTypes.ActiveBeneficiary memory activeBeneficiary = beneficiary
            .active;

        require(
            keccak256(_beneficiaryBytesAddr) ==
                keccak256(activeBeneficiary.beneficiary),
            "INVALID_BENEFICIARY"
        );

        return true;
    }

    function _validateBeneficiaryInfo(
        address _add,
        bytes memory _beneficiaryBytesAddr,
        uint256 _premium
    ) internal returns (bool) {
        bytes memory _miner = _getIdFromETHAddr(_add);

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

    function _sendClaimedFILToMiner(address _add, uint256 _compensation)
        internal
    {
        bytes memory _miner = _getIdFromETHAddr(_add);
        SendAPI.send(_miner, _compensation);
    }

    function _withdrawBalance(address _miner, uint256 _amount)
        internal
        returns (bool)
    {
        bytes memory miner = _getIdFromETHAddr(_miner);

        MinerTypes.WithdrawBalanceParams memory param;
        param.amount_requested = BytesHelper.toBytes(_amount);
        MinerTypes.WithdrawBalanceReturn memory result = MinerAPI
            .withdrawBalance(miner, param);

        require(
            BytesHelper.bytesToUint(result.amount_withdrawn) == _amount,
            "Invalid return value"
        );

        return true;
    }
}
