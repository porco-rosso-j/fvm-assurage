// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.4.25 <=0.8.17;

import {BigNumbers, BigNumber} from "@zondax/solidity-bignumber/src/BigNumbers.sol";
import "@zondax/filecoin-solidity/contracts/v0.8/types/MinerTypes.sol";
import { MinerActor } from "../../FilecoinSolidityAPI/MinerActor.sol";

/// @title This contract is a proxy to a built-in Miner actor. Calling one of its methods will result in a cross-actor call being performed. However, in this mock library, no actual call is performed.
/// @author Zondax AG
/// @dev Methods prefixed with mock_ will not be available in the real library. These methods are merely used to set mock state. Note that this interface will likely break in the future as we align it
//       with that of the real library!
abstract contract MinerAPIMock is MinerActor {

    MockActiveBeneficiary public mockActiveBeneficiary;

   struct MockBeneficiaryTerm {
        BigInt new_quota;
        BigInt bigint;
        uint64 new_expiration;
    }

    struct MockActiveBeneficiary {
        bytes mockActiveBeneficiary;
        MockBeneficiaryTerm term;
    }

    function mockSetBeneficiary(bytes memory _beneficiary, uint _new_quota, uint64 _new_expiration) public override {
        require(_beneficiary.length == 0);

        BigNumber memory zero = BigNumbers.zero();
        MockBeneficiaryTerm memory term = MockBeneficiaryTerm(
            BigInt(abi.encodePacked(_new_quota), true),
            BigInt(zero.val, zero.neg),
            _new_expiration
        );

        mockActiveBeneficiary = MockActiveBeneficiary(_beneficiary, term);
        isBeneficiarySet = true;
    }

    function mockGetBeneficiary() public view returns (MockActiveBeneficiary memory) {
        require(isBeneficiarySet);
        return mockActiveBeneficiary;
    }

    function mockGetAvailableBalance() public view returns(uint) {
        return address(this).balance;
    }
 
    function mockWithdrawBalance(
        address _target,
        uint _amount
    ) public returns (uint) { //MinerTypes.WithdrawBalanceReturn memory
        require(isBeneficiarySet);
        require(_target == msg.sender, "Invalid Caller");

        (bool sent, ) = _target.call{value: _amount}("");
        require(sent, "Failed to send Ether");

        return _amount;
    }
    
}