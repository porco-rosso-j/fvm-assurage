// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.7;

import {IWFIL, IERC20} from "../interfaces/IWFIL.sol";
import {ILidoStrategy} from "../interfaces/IStrategy.sol";

interface IWstFIL {
    function getStFILByWstFIL(uint _wstFILAmount) external view returns (uint256);
    function unwrap(uint256 _wstFILAmount) external returns (uint256);
}

interface IStFIL {
    function getPooledFILByShares(uint256 _sharesAmount) external view returns (uint256);
    function unstake(uint _sharesAmount) external returns (uint256);
}

contract LidoStorategy is ILidoStrategy {

    modifier onlyManager() {
        require(
        msg.sender == assurageManager,
            "Only callable by onlyManager"
        );
    
        _;
    }

    address public override wstFIL;
    address public override stFIL;
    address public override wFIL;

    address public assurageManager;
    address public vault;

    constructor(address _assurageManager, address _wstFIL, address _stFIL, address _wFIL) {
        wstFIL = _wstFIL;
        stFIL = _stFIL;
        wFIL = _wFIL;
        assurageManager = _assurageManager;
    }

    // function setManager(address _assurageManager) public override onlyManager {
    //     require(_assurageManager != address(0), "Invalid Address");
    //     assurageManager = _assurageManager;
    // }

    // WFIL transferred from vault beforehand
    // convert WFIL into FIL
    // deposit FIL into Lido fork to get wstFIL
    function deposit(uint _amount) external override onlyManager {

        IERC20(wFIL).approve(wFIL, _amount);
        IWFIL(wFIL).withdraw(_amount);

        address _wstFIL = wstFIL;

        assembly {
            if iszero(call(gas(), _wstFIL, _amount, 0, 0, 0, 0)) {
                mstore(0x00, 0xb12d13eb)
                revert(0x1c, 0x04)
            }
        }
    }

    // suppose stFIL is redeemable to FIL unlike stFIL to FIL
    // approve wstFIL contract and convert wstFIL into stFIL
    // approve stFIL contract and rdeem stFIL for FIK
    // send FIL to vault
    function withdraw(uint _amount) external override onlyManager returns(uint FILAmount) {

        IERC20(wstFIL).approve(wstFIL, _amount);
        uint stFILAmount = IWstFIL(wstFIL).unwrap(_amount);

        IERC20(stFIL).approve(stFIL, stFILAmount);
        FILAmount = IStFIL(stFIL).unstake(stFILAmount);

        address _wFIL = wFIL;

        assembly {
            if iszero(call(gas(), _wFIL, FILAmount, 0, 0, 0, 0)) {
                mstore(0x00, 0xb12d13eb)
                revert(0x1c, 0x04)
            }
        }

        IERC20(wFIL).transfer(vault, FILAmount);
    }

    // get AUM ( Assets Under Management )
    function getAUM() external override view returns(uint) {
        uint stFILAmount = IWstFIL(wstFIL).getStFILByWstFIL(IERC20(wstFIL).balanceOf(address(this)));
        return IStFIL(stFIL).getPooledFILByShares(stFILAmount);
    }

}