// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import { 
    IVaultFactory,
    IAssurageProxyFactory,
    IAssurageGlobal
     } from "./interfaces/Interfaces.sol";

contract VaultFactory is IVaultFactory {

    address public override global;

    constructor(address _global) {
        require((global = _global) != address(0), "ZERO_ADDRESS");
    }

    function deployVault(
        address _assurageManagerFactory,
        address _asset,
        string memory _name,
        string memory _symbol
    ) external override returns(address assurageManager) {
        address delegate = msg.sender;

        IAssurageGlobal global = IAssurageGlobal(global);

        require(delegate.isAssurageDelegate(delegate), "Invalid Delegate");

        require(global.isAssurageFactory(_assurageManagerFactory), "Invalid Factory");
        IAssurageProxyFactory afactory = IAssurageProxyFactory(_assurageManagerFactory);

        bytes32 salt = keccak256(abi.encode(delegate));

        bytes memory arguments = IAssurageManagerInitializer(
            initializers_[0]).encodeArguments(delegate, asset, configParams_[5], name_, symbol_
        );

        assurageManager  = IAssurageProxyFactory(factories_[0]).createInstance(arguments, salt);
        address vault = IAssurageManager(vaultManager).pool();

        initialize(delegate, asset, _initialSupply, );

    }

    function _initialize(
        address poolDelegate_,
        address asset_,
        uint256 initialSupply_,
        string memory name_,
        string memory symbol_
    ) internal {
        address globals_ = IMapleProxyFactoryLike(msg.sender).mapleGlobals();

        require((poolDelegate = poolDelegate_) != address(0), "PMI:I:ZERO_PD");
        require((asset = asset_)               != address(0), "PMI:I:ZERO_ASSET");

        require(IMapleGlobalsLike(globals_).isPoolDelegate(poolDelegate_),                 "PMI:I:NOT_PD");
        require(IMapleGlobalsLike(globals_).ownedPoolManager(poolDelegate_) == address(0), "PMI:I:POOL_OWNER");
        require(IMapleGlobalsLike(globals_).isPoolAsset(asset_),                           "PMI:I:ASSET_NOT_ALLOWED");

        address migrationAdmin_ = IMapleGlobalsLike(globals_).migrationAdmin();

        require(initialSupply_ == 0 || migrationAdmin_ != address(0), "PMI:I:INVALID_POOL_PARAMS");

        pool = address(
            new Pool(
                address(this),
                asset_,
                migrationAdmin_,
                IMapleGlobalsLike(globals_).bootstrapMint(asset_),
                initialSupply_,
                name_,
                symbol_
            )
        );

        poolDelegateCover = address(new PoolDelegateCover(address(this), asset));

        emit Initialized(poolDelegate_, asset_, address(pool));
    }





}

