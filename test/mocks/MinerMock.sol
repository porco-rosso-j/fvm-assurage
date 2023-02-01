// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.17;

import "filecoin-solidity/contracts/v0.8/types/MinerTypes.sol";
import {IMinerActor} from "src/interfaces/IMinerActor.sol";

// import {IAssurageManager} from "../../interfaces/IAssurageManager.sol";

contract MinerActorMock is IMinerActor {
    bytes owner;
    bool isBeneficiarySet = false;

    ActiveBeneficiary public activeBeneficiary;
    mapping(CommonTypes.SectorSize => uint64) sectorSizesBytes;

    struct BeneficiaryTerm {
        BigInt new_quota;
        BigInt bigint;
        uint64 new_expiration;
    }

    struct ActiveBeneficiary {
        bytes activeBeneficiary;
        BeneficiaryTerm term;
    }

    constructor(bytes memory _owner) {
        owner = _owner;

        sectorSizesBytes[CommonTypes.SectorSize._2KiB] = 2 << 10;
        sectorSizesBytes[CommonTypes.SectorSize._8MiB] = 8 << 20;
        sectorSizesBytes[CommonTypes.SectorSize._512MiB] = 512 << 20;
        sectorSizesBytes[CommonTypes.SectorSize._32GiB] = 32 << 30;
        sectorSizesBytes[CommonTypes.SectorSize._64GiB] = 2 * (32 << 30);
    }

    function setBeneficiary(
        bytes memory _beneficiary,
        uint256 _new_quota,
        uint64 _new_expiration
    ) public {
        require(_beneficiary.length == 0);

        BeneficiaryTerm memory term = BeneficiaryTerm(
            BigInt(abi.encodePacked(_new_quota), true),
            BigInt(abi.encodePacked(uint256(0)), false),
            _new_expiration
        );

        activeBeneficiary = ActiveBeneficiary(_beneficiary, term);
        isBeneficiarySet = true;
    }

    function getBeneficiary() public view override returns (bytes memory) {
        require(isBeneficiarySet);
        return activeBeneficiary.activeBeneficiary;
    }

    function getAvailableBalance() public view override returns (uint256) {
        return address(this).balance;
    }

    function withdrawBalance(address _target, uint256 _amount) public override {
        //MinerTypes.WithdrawBalanceReturn memory
        require(isBeneficiarySet);
        require(_target == msg.sender, "Invalid Caller");

        (bool sent, ) = _target.call{value: _amount}("");
        require(sent, "Failed to send Ether");
    }

    /*




    */
}
