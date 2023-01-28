// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.7;

import { ProxyFactory } from "./1967proxy/ProxyFactory.sol";
import { IAssurageGlobal }  from "./interfaces/IAssurageGlobal.sol";
import { IAssurageProxied }      from "./interfaces/IAssurageProxied.sol";
import { IAssurageProxyFactory } from "../interfaces/IAssurageProxyFactory.sol";

/// @title A Assurage factory for Proxy contracts that proxy AssurageProxied implementations.
contract AssurageProxyFactory is IAssurageProxyFactory, ProxyFactory {

    address public override AssurageGlobal;
    uint256 public override defaultVersion;

    mapping(address => bool) public override isInstance;
    mapping(uint256 => mapping(uint256 => bool)) public override upgradeEnabledForPath;

    constructor(address AssurageGlobal) {
        require(IAssurageGlobal(AssurageGlobal = AssurageGlobal).governor() != address(0), "MPF:C:INVALIDGLOBALS");
    }

    modifier onlyGovernor() {
        require(msg.sender == IAssurageGlobal(AssurageGlobal).governor(), "MPF:NOTGOVERNOR");
        _;
    }

    /**************************************************************************************************************************************/
    /*** Admin Functions                                                                                                                ***/
    /**************************************************************************************************************************************/

    function disableUpgradePath(uint256 fromVersion, uint256 toVersion) public override virtual onlyGovernor {
        require(fromVersion != toVersion,                              "MPF:DUP:OVERWRITINGINITIALIZER");
        require(registerMigrator(fromVersion, toVersion, address(0)), "MPF:DUP:FAILED");

        emit UpgradePathDisabled(fromVersion, toVersion);

        upgradeEnabledForPath[fromVersion][toVersion] = false;
    }

    function enableUpgradePath(uint256 fromVersion, uint256 toVersion, address migrator) public override virtual onlyGovernor {
        require(fromVersion != toVersion,                             "MPF:EUP:OVERWRITINGINITIALIZER");
        require(registerMigrator(fromVersion, toVersion, migrator), "MPF:EUP:FAILED");

        emit UpgradePathEnabled(fromVersion, toVersion, migrator);

        upgradeEnabledForPath[fromVersion][toVersion] = true;
    }

    function registerImplementation(uint256 version, address implementationAddress, address initializer)
        public override virtual onlyGovernor
    {
        // Version 0 reserved as "no version" since default `defaultVersion` is 0.
        require(version != uint256(0), "MPF:RI:INVALIDVERSION");

        emit ImplementationRegistered(version, implementationAddress, initializer);

        require(registerImplementation(version, implementationAddress), "MPF:RI:FAILFORIMPLEMENTATION");

        // Set migrator for initialization, which understood as fromVersion == toVersion.
        require(registerMigrator(version, version, initializer), "MPF:RI:FAILFORMIGRATOR");
    }

    function setDefaultVersion(uint256 version) public override virtual onlyGovernor {
        // Version must be 0 (to disable creating new instances) or be registered.
        require(version == 0 || implementationOf[version] != address(0), "MPF:SDV:INVALIDVERSION");

        emit DefaultVersionSet(defaultVersion = version);
    }

    function setGlobal(address AssurageGlobal) public override virtual onlyGovernor {
        require(IAssurageGlobal(AssurageGlobal).governor() != address(0), "MPF:SG:INVALIDGLOBALS");
        emit AssurageGlobalSet(AssurageGlobal = AssurageGlobal);
    }

    /**************************************************************************************************************************************/
    /*** Instance Functions                                                                                                             ***/
    /**************************************************************************************************************************************/

    function createInstance(bytes calldata arguments, bytes32 salt)
        public override virtual  returns (address instance)
    {
        bool success;
        ( success, instance ) = newInstance(arguments, keccak256(abi.encodePacked(arguments, salt)));
        require(success, "MPF:CI:FAILED");

        isInstance[instance] = true;

        emit InstanceDeployed(defaultVersion, instance, arguments);
    }

    // NOTE: The implementation proxied by the instance defines the access control logic for its own upgrade.
    function upgradeInstance(uint256 toVersion, bytes calldata arguments) public override virtual  {
        uint256 fromVersion = versionOf[IAssurageProxied(msg.sender).implementation()];

        require(upgradeEnabledForPath[fromVersion][toVersion], "MPF:UI:NOTALLOWED");

        emit InstanceUpgraded(msg.sender, fromVersion, toVersion, arguments);

        require(upgradeInstance(msg.sender, toVersion, arguments), "MPF:UI:FAILED");
    }

    /**************************************************************************************************************************************/
    /*** View Functions                                                                                                                 ***/
    /**************************************************************************************************************************************/

    function getInstanceAddress(bytes calldata arguments, bytes32 salt) public view override virtual returns (address instanceAddress) {
        return getDeterministicProxyAddress(keccak256(abi.encodePacked(arguments, salt)));
    }

    function implementationOf(uint256 version) public view override virtual returns (address implementation) {
        return implementationOf[version];
    }

    function defaultImplementation() external view override returns (address defaultImplementation) {
        return implementationOf[defaultVersion];
    }

    function migratorForPath(uint256 oldVersion, uint256 newVersion) public view override virtual returns (address migrator) {
        return migratorForPath[oldVersion][newVersion];
    }

    function versionOf(address implementation) public view override virtual returns (uint256 version) {
        return versionOf[implementation];
    }

}