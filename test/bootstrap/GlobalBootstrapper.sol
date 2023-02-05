// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import {Address, TestUtils} from "../utils/test.sol";
import {MockGlobal} from "../mocks/Mocks.sol";

/**
 *  @dev Used to setup the MockGlobal contract for test contracts.
 */
contract GlobalBootstrapper is TestUtils {
    address internal GOVERNOR = address(new Address());

    address internal global;

    function _deployAndBootstrapGlobal(
        address liquidityAsset_,
        address assurgaeDelegate_
    ) internal {
        _deployGlobal();
        _bootstrapGlobal(liquidityAsset_, assurgaeDelegate_);
    }

    function _deployGlobal() internal {
        global = address(new MockGlobal(GOVERNOR));
    }

    function _bootstrapGlobal(
        address liquidityAsset_,
        address assurgaeDelegate_
    ) internal {
        vm.startPrank(GOVERNOR);
        MockGlobal(global).setValidVaultAsset(liquidityAsset_, true);
        MockGlobal(global).setValidAssurageDelegate(assurgaeDelegate_, true);
        vm.stopPrank();
    }
}
