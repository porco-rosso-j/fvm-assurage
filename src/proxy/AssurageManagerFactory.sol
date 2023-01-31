// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.17;

import {IAssurageProxyFactory, AssurageProxyFactory} from "./AssurageProxyFactory.sol";
import {IAssurageGlobal} from "../interfaces/IAssurageGlobal.sol";

contract AssurageManagerFactory is IAssurageProxyFactory, AssurageProxyFactory {
    constructor(address globals) AssurageProxyFactory(globals) {}

    function createInstance(bytes calldata arguments, bytes32 salt)
        public
        override(IAssurageProxyFactory, AssurageProxyFactory)
        returns (address instance)
    {
        require(
            IAssurageGlobal(assurageGlobal).isVaultDeployer(msg.sender),
            "PMF:CI:NOTDEPLOYER"
        );

        instance = super.createInstance(arguments, salt);
    }
}
