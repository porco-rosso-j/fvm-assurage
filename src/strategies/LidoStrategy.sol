// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.17;

/*
Still under development, better to also be 4626 based strategy vault.
*/

import {ERC4626, ERC20} from "solmate/mixins/ERC4626.sol";
import {IWFIL, IERC20} from "../interfaces/IWFIL.sol";
import {ILidoStrategy} from "../interfaces/IStrategy.sol";
import {IAssurageManager} from "../interfaces/IAssurageManager.sol";

interface IWstFIL {
    function getStFILByWstFIL(uint256 _wstFILAmount)
        external
        view
        returns (uint256);

    function unwrap(uint256 _wstFILAmount) external returns (uint256);
}

interface IStFIL {
    function getPooledFILByShares(uint256 _sharesAmount)
        external
        view
        returns (uint256);

    function unstake(uint256 _sharesAmount) external returns (uint256);
}

contract LidoStorategy is ILidoStrategy, ERC4626 {
    address public global;
    address public override wstFIL;
    address public override stFIL;
    address public override wFIL;

    mapping(address => bool) public approvedManagers;
    address public vault;

    constructor(
        address _global,
        address _wstFIL,
        address _stFIL,
        address _wFIL
    ) ERC4626(ERC20(_asset), _name, _symbol) {
        wstFIL = _wstFIL;
        stFIL = _stFIL;
        wFIL = _wFIL;
        global = _gloabl;
    }

    function setManager(address _assurageManager) public override {
        require(_assurageManager != address(0), "Invalid Address");
        require(
            IAssurageGlobal(global)
                .assurageDelegates[msg.sender]
                .isAssurageDelegate,
            "Invalid Sender"
        );
        approvedManagers[
            IAssurageGlobal(global)
                .assurageDelegates[msg.sender]
                .assurageManager
        ] = true;
    }

    // WFIL transferred from vault beforehand
    // convert WFIL into FIL
    // deposit FIL into Lido fork to get wstFIL
    function deposit(uint256 _amount) external override onlyManager {
        require(approvedManagers[msg.sender], "Invalid Sender");

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
    function withdraw(uint256 _amount)
        external
        override
        onlyManager
        returns (uint256 FILAmount)
    {
        IERC20(wstFIL).approve(wstFIL, _amount);
        uint256 stFILAmount = IWstFIL(wstFIL).unwrap(_amount);

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
    function getAUM() external view override returns (uint256) {
        uint256 stFILAmount = IWstFIL(wstFIL).getStFILByWstFIL(
            IERC20(wstFIL).balanceOf(address(this))
        );
        return IStFIL(stFIL).getPooledFILByShares(stFILAmount);
    }
}
