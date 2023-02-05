// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "forge-std/Script.sol";
// import "forge-std/Vm.sol";
// import "forge-std/console.sol";

import "src/core/AssurageGlobal.sol";
import "src/core/NonTransparentProxy.sol";

contract DGlobal is Script {
    address deployerAddress = vm.envAddress("ADDRESS");
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

    function run() external {
        vm.startBroadcast(deployerPrivateKey);

        AssurageGlobal global = new AssurageGlobal();

        NonTransparentProxy proxy = new NonTransparentProxy(
            deployerAddress,
            address(global)
        );

        proxy; // silence warning

        vm.stopBroadcast();
    }
}
