// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.17;

import {IWFIL, IERC20} from "../interfaces/IWFIL.sol";
import {ILidoStrategy} from "../interfaces/IStrategy.sol";
import {IAssurageGlobal} from "../interfaces/IAssurageGlobal.sol";
import {SafeTransferLib, ERC20} from "solmate/utils/SafeTransferLib.sol";

interface IWstFIL {
    function stFIL() external view returns (IStFIL);

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

contract LidoStorategy is ILidoStrategy {
    address public global;

    address public override wstFIL;
    address public override wFIL;

    mapping(address => bool) public isValidManager;

    constructor(
        address _global,
        address _wstFIL,
        address _wFIL
    ) {
        global = _global;
        wstFIL = _wstFIL;
        wFIL = _wFIL;
    }

    // set by Delegate
    function setValidManager(address _assurageManager) public override {
        (address assurageManager, bool IsAssurageGlobal) = IAssurageGlobal(
            global
        ).assurageDelegates(msg.sender);

        require(assurageManager == _assurageManager, "Invalid Address");
        require(IsAssurageGlobal, "Invalid Manager");
        isValidManager[_assurageManager] = true;
    }

    function approveManager() public override {
        require(isValidManager[msg.sender], "Invalid Sender");
        SafeTransferLib.safeApprove(ERC20(wFIL), msg.sender, type(uint256).max);
    }

    // called by AssurageManager
    function deposit(uint256 _amount) external override {
        require(isValidManager[msg.sender], "Invalid Sender");

        // convert wFIL to FIL
        IWFIL(wFIL).withdraw(_amount);

        // send FIL to wstFIL contract
        SafeTransferLib.safeTransferETH(wstFIL, _amount);

        // Transfer received share token, wstFIL to Manager
        SafeTransferLib.safeTransfer(
            ERC20(wstFIL),
            msg.sender,
            IERC20(wstFIL).balanceOf(address(this))
        );
    }

    // suppose stFIL is redeemable to FIL unlike stFIL to FIL
    // approve wstFIL contract and convert wstFIL into stFIL
    // approve stFIL contract and rdeem stFIL for FIK
    // send FIL to vault
    function withdraw(uint256 _amount)
        external
        override
        returns (uint256 filAmount)
    {
        require(isValidManager[msg.sender], "Invalid Sender");

        SafeTransferLib.safeApprove(ERC20(wstFIL), wstFIL, _amount);
        uint256 stFILAmount = IWstFIL(wstFIL).unwrap(_amount);

        address stFIL = address(IWstFIL(wstFIL).stFIL());

        SafeTransferLib.safeApprove(ERC20(stFIL), stFIL, stFILAmount);
        filAmount = IStFIL(stFIL).unstake(stFILAmount);

        // Wrap FIL for wFIL
        IWFIL(wFIL).deposit{value: filAmount}();
    }

    function getBalance(uint256 _amount)
        external
        view
        override
        returns (uint256)
    {
        uint256 stFILAmount = IWstFIL(wstFIL).getStFILByWstFIL(_amount);
        address stFIL = address(IWstFIL(wstFIL).stFIL());
        return IStFIL(stFIL).getPooledFILByShares(stFILAmount);
    }

    function share() public view override returns (address) {
        return wstFIL;
    }
}
