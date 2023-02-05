// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import {Address} from "../utils/test.sol";
import {ProxiedInternals} from "src/proxy/1967Proxy/ProxiedInternals.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";

import {IProtectionVault} from "src/interfaces/IProtectionVault.sol";

import {ProtectionVault} from "src/vault/ProtectionVault.sol";
import {AssurageManager} from "src/vault/AssurageManager.sol";
import {AssurageManagerStorage} from "src/proxy/AssurageManagerStorage.sol";

interface IWFIL {
    function withdraw(uint256) external;

    function deposit() external payable;
}

contract MockWFIL is ERC20, IWFIL {
    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_
    ) ERC20(name_, symbol_, decimals_) {}

    function mint(address recipient_, uint256 amount_) external {
        _mint(recipient_, amount_);
    }

    function burn(address owner_, uint256 amount_) external {
        _burn(owner_, amount_);
    }

    function deposit() public payable {
        balanceOf[msg.sender] += msg.value;
    }

    function withdraw(uint256 wad) public {
        require(balanceOf[msg.sender] >= wad);
        balanceOf[msg.sender] -= wad;
        (bool success, ) = payable(msg.sender).call{value: wad}("");
        require(success, "WETH: ETH transfer failed");
    }

    receive() external payable {
        deposit();
    }
}

contract MockProxied is ProxiedInternals {
    function factory() external view returns (address factory_) {
        return _factory();
    }

    function implementation() external view returns (address implementation_) {
        return _implementation();
    }

    function migrate(address migrator_, bytes calldata arguments_) external {}
}

contract MockERC20Vault is ProtectionVault {
    constructor(
        address assurageManager_,
        address payable asset_,
        string memory name_,
        string memory symbol_
    )
        ProtectionVault(
            assurageManager_,
            asset_,
            address(0),
            0,
            0,
            name_,
            symbol_,
            18
        )
    {
        MockWFIL(asset_).approve(assurageManager_, type(uint256).max);
    }

    function mint(address recipient_, uint256 amount_) external {
        _mint(recipient_, amount_);
    }

    function burn(address owner_, uint256 amount_) external {
        _burn(owner_, amount_);
    }
}

contract MockGlobal {
    uint256 public constant HUNDRED_PERCENT = 1e6;

    bool internal _factorySet;
    mapping(bytes32 => mapping(address => bool)) public _validFactory;

    address public governor;
    address public migrationAdmin;

    mapping(address => bool) public isVaultAsset;
    mapping(address => bool) public isAssurageDelegate;
    mapping(address => bool) public isVaultDeployer;

    mapping(address => uint256) public platformManagementFeeRate;
    mapping(address => address) public assurageManager;

    uint256 internal _bootstrapMint;

    constructor(address governor_) {
        governor = governor_;
    }

    function __setAssurageManager(address owner_, address assurageManager_)
        external
    {
        assurageManager[owner_] = assurageManager_;
    }

    function __setBootstrapMint(uint256 bootstrapMint_) external {
        _bootstrapMint = bootstrapMint_;
    }

    function bootstrapMint(address asset_)
        external
        view
        returns (uint256 bootstrapMint_)
    {
        asset_;
        bootstrapMint_ = _bootstrapMint;
    }

    function isFactory(bytes32 factoryId_, address factory_)
        external
        view
        returns (bool isValid_)
    {
        isValid_ = true;
        if (_factorySet) {
            isValid_ = _validFactory[factoryId_][factory_];
        }
    }

    function setGovernor(address governor_) external {
        governor = governor_;
    }

    function setMigrationAdmin(address migrationAdmin_) external {
        migrationAdmin = migrationAdmin_;
    }

    function setPlatformManagementFeeRate(
        address assurageManager_,
        uint256 platformManagementFeeRate_
    ) external {
        platformManagementFeeRate[
            assurageManager_
        ] = platformManagementFeeRate_;
    }

    function setValidFactory(
        bytes32 factoryId_,
        address factory_,
        bool isValid_
    ) external {
        _factorySet = true;
        _validFactory[factoryId_][factory_] = isValid_;
    }

    function setValidVaultDeployer(address vaultDeployer_, bool isValid_)
        external
    {
        isVaultDeployer[vaultDeployer_] = isValid_;
    }

    function setValidVaultAsset(address vaultAsset_, bool isValid_) external {
        isVaultAsset[vaultAsset_] = isValid_;
    }

    function setValidAssurageDelegate(address assurageDelegate_, bool isValid_)
        external
    {
        isAssurageDelegate[assurageDelegate_] = isValid_;
    }
}

contract MockProtectionVault {
    address public asset;
    address public assurageManager;

    function __setAsset(address asset_) external {
        asset = asset_;
    }

    function __setManager(address assurageManager_) external {
        assurageManager = assurageManager_;
    }

    function redeem(
        uint256,
        address,
        address
    ) external pure returns (uint256) {}
}

contract MockAssurageManager is AssurageManagerStorage, MockProxied {
    address public global;

    uint256 public totalAssets;
    uint256 public unrealizedLosses;

    function configure(
        uint256 minProtection_,
        uint256 liquidityCap_,
        uint256 managementFee_
    ) external {
        // Do nothing.
    }

    function setDelegateManagementFeeRate(uint256 delegateManagementFeeRate_)
        external
    {
        delegateManagementFeeRate = delegateManagementFeeRate_;
    }

    function __setGlobal(address global_) external {
        global = global_;
    }

    function __setVault(address vault_) external {
        vault = vault_;
    }

    function __setAssurageDelegate(address assurageDelegate_) external {
        assurageDelegate = assurageDelegate_;
    }
}

contract MockAssurageManagerMigrator is AssurageManagerStorage {
    fallback() external {
        assurageDelegate = abi.decode(msg.data, (address));
    }
}

contract MockMigrator {
    fallback() external {
        // Do nothing.
    }
}

contract MockAssurageManagerInitializer is MockMigrator {
    function encodeArguments(
        address,
        address,
        uint256,
        string memory,
        string memory
    ) external pure returns (bytes memory encodedArguments_) {
        encodedArguments_ = new bytes(0);
    }

    function decodeArguments(bytes calldata encodedArguments_)
        external
        pure
        returns (
            address global_,
            address owner_,
            address asset_,
            uint256 initialSupply_,
            string memory name_,
            string memory symbol_
        )
    {
        // Do nothing.
    }
}

contract MockFactory {
    mapping(address => bool) public isInstance;

    function createInstance(bytes calldata, bytes32)
        external
        returns (address instance_)
    {
        instance_ = address(new MockAssurageManager());
    }

    function __setIsInstance(address instance, bool status) external {
        isInstance[instance] = status;
    }
}
