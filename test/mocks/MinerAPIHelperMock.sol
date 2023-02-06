// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.17;

// Non Mock Implementaion, MinerAPIHelper.sol is located in src/filecoin-api/..

// A contract that handles fetching and validating return values via MinerAPI
contract MinerAPIHepler {
    uint256 Silencer;

    function getOwner(bytes memory _miner) internal returns (bytes memory) {
        _miner;
        Silencer = 0;
        return bytes("TEST");
        // MinerTypes.GetOwnerReturn memory ownerReturn = MinerAPI.getOwner(
        //     _miner
        // );
        // return ownerReturn.owner;
    }

    function _getIdFromETHAddr(address _add) internal returns (bytes memory) {
        _add;
        Silencer = 0;
        return bytes("TEST");
        // bytes memory bytesAddr = abi.encodePacked(_add);
        // uint64 addressUint = PrecompilesAPI.resolveEthAddress(bytesAddr);
        // return BytesHelper.toBytes(addressUint);
    }

    function _validateAvailableBalance(address _add, uint256 _premium)
        internal
        returns (bool)
    {
        _add;
        _premium;
        Silencer = 0;
        // bytes memory _miner = getIdFromETHAddr(_add);
        // MinerTypes.GetAvailableBalanceReturn memory availableBalance = MinerAPI
        //     .getAvailableBalance(_miner);
        // BigInt memory balanceBigInt = availableBalance.available_balance;
        // bytes memory balanceBytes = balanceBigInt.val;

        // require(
        //     BytesHelper.bytesToUint(balanceBytes) >= _premium,
        //     "Insufficient Balance"
        // );

        return true;
    }

    function _validateBeneficiary(
        address _add,
        bytes memory _beneficiaryBytesAddr
    ) internal returns (bool) {
        _add;
        _beneficiaryBytesAddr;
        Silencer = 0;
        // bytes memory _miner = getIdFromETHAddr(_add);

        // MinerTypes.GetBeneficiaryReturn memory beneficiary = MinerAPI
        //     .getBeneficiary(_miner);
        // CommonTypes.ActiveBeneficiary memory activeBeneficiary = beneficiary
        //     .active;

        // require(
        //     keccak256(_beneficiaryBytesAddr) ==
        //         keccak256(activeBeneficiary.beneficiary),
        //     "INVALID_BENEFICIARY"
        // );

        return true;
    }

    function _validateBeneficiaryInfo(
        address _add,
        bytes memory _beneficiaryBytesAddr,
        uint256 _premium
    ) internal returns (bool) {
        _add;
        _beneficiaryBytesAddr;
        _premium;
        Silencer = 0;
        // bytes memory _miner = getIdFromETHAddr(_add);

        // MinerTypes.GetBeneficiaryReturn memory beneficiary = MinerAPI
        //     .getBeneficiary(_miner);
        // CommonTypes.ActiveBeneficiary memory activeBeneficiary = beneficiary
        //     .active;

        // require(
        //     keccak256(_beneficiaryBytesAddr) ==
        //         keccak256(activeBeneficiary.beneficiary),
        //     "Invalid Beneficiary"
        // );

        // CommonTypes.BeneficiaryTerm memory term = activeBeneficiary.term;
        // BigInt memory _quota = term.quota;
        // BigInt memory _used_quota = term.used_quota;
        // uint64 _expiration = term.expiration;

        // uint256 quota = BytesHelper.bytesToUint(_quota.val);
        // uint256 used_quota = BytesHelper.bytesToUint(_used_quota.val);
        // uint256 expiration = uint256(_expiration);

        // require(quota - used_quota >= _premium, "Insufficient allowance");
        // require(expiration > block.timestamp, "Invalid expiration");

        return true;
    }

    function _sendClaimedFILToMiner(address _add, uint256 _amount) internal {
        // bytes memory _miner = getIdFromETHAddr(_add);
        // SendAPI.send(_miner, _compensation);

        // bool success;
        // assembly {
        //     success := call(gas(), _add, _amount, 0, 0, 0, 0)
        // }
        // require(success, "ETH_TRANSFER_FAILED");
        payable(_add).transfer(_amount);
    }

    function _withdrawBalance(address _miner, uint256 _amount)
        public
        payable
        returns (bool)
    {
        Silencer = 0;
        // bytes memory _miner = getIdFromETHAddr(_add);

        // MinerTypes.WithdrawBalanceParams memory param;
        // param.amount_requested = BytesHelper.toBytes(_amount);
        // MinerTypes.WithdrawBalanceReturn memory result = MinerAPI
        //     .withdrawBalance(_miner, param);

        // require(
        //     BytesHelper.bytesToUint(result.amount_withdrawn) == _amount,
        //     "Invalid return value"
        // );

        // mock withdrawal
        bytes memory _data = abi.encode(address(this), _amount);

        (bool success, bytes memory data) = _miner.call(_data);
        require(success, "FAILED");

        return true;
    }
}

/*
        (bool success, bytes memory data) = _miner.call(
            abi.encodeWithSignature(
                "sendFIL(address, uint256)",
                payable(address(this)),
                _amount
            )
        );
        require(success, "FAILED");
*/
