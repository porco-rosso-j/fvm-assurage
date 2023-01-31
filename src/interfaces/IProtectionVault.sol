// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.17;

//import {IERC4626} from "../interfaces/IERC4626.sol";

interface IProtectionVault {
    function sendClaimedFIL(address _miner, uint256 _compensation)
        external
        payable;

    function setAssurageManager(address _assurageManager) external;

    function depositWithPermit(
        uint256 assets,
        address receiver,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 shares);

    function mintWithPermit(
        uint256 shares,
        address receiver,
        uint256 maxAssets,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 assets);
}
