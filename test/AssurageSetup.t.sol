// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.17;

import {DSTest} from "ds-test/test.sol";
import {Vm} from "forge-std/Vm.sol";

contract Address {
    receive() external payable {}
}

import {AssurageManager} from "./mocks/AssurageManagerMock.sol";
import {AssurageManagerFactory} from "src/proxy/AssurageManagerFactory.sol";
import {AssurageManagerInitializer} from "src/proxy/AssurageManagerInitializer.sol";

import {MockERC20Vault, MockWFIL, MockFactory, MockGlobal, MockAssurageManagerMigrator} from "./mocks/Mocks.sol";

import {GlobalBootstrapper} from "./bootstrap/GlobalBootstrapper.sol";

import {console} from "forge-std/console.sol";

contract AssurageManagerBase is DSTest, GlobalBootstrapper {
    address internal ASSURAGE_DELEGATE = address(new Address());

    MockWFIL internal asset;
    MockERC20Vault internal vault;

    AssurageManager internal assurageManager;
    AssurageManagerFactory internal factory;

    address internal implementation;
    address internal initializer;

    function setUp() public virtual {
        asset = new MockWFIL("Wrapped FIL", "WFIL", 18);

        _deployAndBootstrapGlobal(address(asset), ASSURAGE_DELEGATE);

        factory = new AssurageManagerFactory(address(global));

        implementation = address(new AssurageManager());
        initializer = address(new AssurageManagerInitializer());

        vm.startPrank(GOVERNOR);
        factory.registerImplementation(1, implementation, initializer);
        factory.setDefaultVersion(1);
        vm.stopPrank();

        string memory vaultName_ = "Vault";
        string memory vaultSymbol_ = "VAULT1";

        MockGlobal(global).setValidVaultDeployer(address(this), true);

        bytes memory arguments = AssurageManagerInitializer(initializer)
            .encodeArguments(
                ASSURAGE_DELEGATE,
                address(asset),
                0,
                vaultName_,
                vaultSymbol_
            );

        assurageManager = AssurageManager(
            payable(
                factory.createInstance(
                    arguments,
                    keccak256(abi.encode(ASSURAGE_DELEGATE))
                )
            )
        );

        MockERC20Vault mockVault = new MockERC20Vault(
            address(assurageManager),
            payable(asset),
            vaultName_,
            vaultSymbol_
        );

        address vaultAddress = assurageManager.vault();

        vm.etch(vaultAddress, address(mockVault).code);

        // Mint 1M WFIL to vault
        asset.mint(vaultAddress, 1_000e18);

        vault = MockERC20Vault(vaultAddress);

        // Get past zero supply check
        vault.mint(address(1), 1);

        vm.prank(global);
        assurageManager.setActive(true);
    }
}

// forge test --match-contract ConfigureTests -vvv --fork-url http://localhost:8545
contract ConfigureTests is AssurageManagerBase {
    uint256 internal minProtection = 10e18; // 10 FIL
    uint256 internal minPeriod = 2628000; // A Month
    uint256 internal liquidityCap = 1_000_000e18; // 1M FIL
    uint256 internal managementFeeRate = 0.1e6;

    function test_configure_notDeployer() public {
        vm.prank(ASSURAGE_DELEGATE);
        vm.expectRevert("PM:CO:NOT_DEPLOYER");
        assurageManager.configure(
            minProtection,
            minPeriod,
            liquidityCap,
            managementFeeRate
        );

        assurageManager.configure(
            minProtection,
            minPeriod,
            liquidityCap,
            managementFeeRate
        );
    }

    function test_configure_minProtection() public {
        vm.expectRevert("INVALID_AMOUNT");
        assurageManager.configure(
            0,
            minPeriod,
            liquidityCap,
            managementFeeRate
        );

        assurageManager.configure(
            1e18,
            minPeriod,
            liquidityCap,
            managementFeeRate
        );
    }

    function test_configure_minPeriod() public {
        vm.expectRevert("INVALID_AMOUNT");
        assurageManager.configure(
            minProtection,
            0,
            liquidityCap,
            managementFeeRate
        );

        assurageManager.configure(
            minProtection,
            1e18,
            liquidityCap,
            managementFeeRate
        );
    }

    function test_configure_delegateManagementFeeOOB() public {
        vm.expectRevert("PM:CO:OOB");
        assurageManager.configure(
            minProtection,
            minPeriod,
            liquidityCap,
            100_0001
        );

        assurageManager.configure(
            minProtection,
            minPeriod,
            liquidityCap,
            100_0000
        );
    }

    function test_configure_alreadyConfigured() public {
        assurageManager.configure(
            minProtection,
            minPeriod,
            liquidityCap,
            managementFeeRate
        );

        vm.expectRevert("PM:CO:ALREADY_CONFIGURED");
        assurageManager.configure(
            minProtection,
            minPeriod,
            liquidityCap,
            managementFeeRate
        );
    }

    function test_configure_success() public {
        assertTrue(!assurageManager.configured());

        assertEq(assurageManager.minProtection(), uint256(0));
        assertEq(assurageManager.minPeriod(), uint256(0));
        assertEq(assurageManager.liquidityCap(), uint256(0));
        assertEq(assurageManager.delegateManagementFeeRate(), uint256(0));
        assertEq(assurageManager.assessor(), address(0));
        assertEq(assurageManager.beneficiaryBytesAddr().length, 0);

        assurageManager.configure(
            minProtection,
            minPeriod,
            liquidityCap,
            managementFeeRate
        );

        assertTrue(assurageManager.configured());

        assertEq(assurageManager.minProtection(), minProtection);
        assertEq(assurageManager.minPeriod(), minPeriod);
        assertEq(assurageManager.liquidityCap(), liquidityCap);
        assertEq(
            assurageManager.delegateManagementFeeRate(),
            managementFeeRate
        );
        assertEq(assurageManager.assessor(), address(ASSURAGE_DELEGATE));
        assertTrue(assurageManager.isAssessor(address(ASSURAGE_DELEGATE)));

        assertEq(assurageManager.beneficiaryBytesAddr().length, 4);
    }
}

contract MigrateTests is AssurageManagerBase {
    address internal migrator = address(new MockAssurageManagerMigrator());

    function test_migrate_notFactory() external {
        vm.expectRevert("PM:M:NOT_FACTORY");
        assurageManager.migrate(migrator, "");
    }

    function test_migrate_internalFailure() external {
        vm.prank(assurageManager.factory());
        vm.expectRevert("PM:M:FAILED");
        assurageManager.migrate(migrator, "");
    }

    function test_migrate_success() external {
        assertEq(assurageManager.assurageDelegate(), ASSURAGE_DELEGATE);

        vm.prank(assurageManager.factory());
        assurageManager.migrate(migrator, abi.encode(address(0)));

        assertEq(assurageManager.assurageDelegate(), address(0));
    }
}

contract SetImplementationTests is AssurageManagerBase {
    address internal newImplementation = address(new AssurageManager());

    function test_setImplementation_notFactory() external {
        vm.expectRevert("PM:SI:NOT_FACTORY");
        assurageManager.setImplementation(newImplementation);
    }

    function test_setImplementation_success() external {
        assertEq(assurageManager.implementation(), implementation);

        vm.prank(assurageManager.factory());
        assurageManager.setImplementation(newImplementation);

        assertEq(assurageManager.implementation(), newImplementation);
    }
}

contract SetActive_SetterTests is AssurageManagerBase {
    function setUp() public override {
        super.setUp();
        vm.prank(global);
        assurageManager.setActive(false);
    }

    function test_setActive_notGlobal() external {
        assertTrue(!assurageManager.active());

        vm.expectRevert("PM:SA:NOT_GLOBALS");
        assurageManager.setActive(true);
    }

    function test_setActive_success() external {
        assertTrue(!assurageManager.active());

        vm.prank(address(global));
        assurageManager.setActive(true);

        assertTrue(assurageManager.active());

        vm.prank(address(global));
        assurageManager.setActive(false);

        assertTrue(!assurageManager.active());
    }
}

contract SetLiquidityCap_SetterTests is AssurageManagerBase {
    address internal NOT_ASSURAGE_DELEGATE = address(new Address());

    function test_setLiquidityCap_notAssurageDelegate() external {
        vm.prank(NOT_ASSURAGE_DELEGATE);
        vm.expectRevert("NOT_DELEGATE");
        assurageManager.setLiquidityCap(1000);
    }

    function test_setLiquidityCap_success() external {
        assertEq(assurageManager.liquidityCap(), 0);

        vm.prank(ASSURAGE_DELEGATE);
        assurageManager.setLiquidityCap(1000);

        assertEq(assurageManager.liquidityCap(), 1000);
    }
}

contract SetMinProtection_SetterTests is AssurageManagerBase {
    address internal NOT_ASSURAGE_DELEGATE = address(new Address());

    function test_setMinProtection_notAssurageDelegate() external {
        vm.prank(NOT_ASSURAGE_DELEGATE);
        vm.expectRevert("NOT_DELEGATE");
        assurageManager.setMinProtection(1e18);
    }

    function test_setMinProtection_invalidAmount() external {
        vm.prank(ASSURAGE_DELEGATE);
        vm.expectRevert("INVALID_AMOUNT");
        assurageManager.setMinProtection(0);
    }

    function test_setMinProtection_success() external {
        assertEq(assurageManager.minProtection(), 0);

        vm.prank(ASSURAGE_DELEGATE);
        assurageManager.setMinProtection(1e18);

        assertEq(assurageManager.minProtection(), 1e18);
    }
}

contract SetMinPeriod_SetterTests is AssurageManagerBase {
    address internal NOT_ASSURAGE_DELEGATE = address(new Address());

    function test_setMinPeriod_notAssurageDelegate() external {
        vm.prank(NOT_ASSURAGE_DELEGATE);
        vm.expectRevert("NOT_DELEGATE");
        assurageManager.setMinPeriod(1e18);
    }

    function test_setMinPeriod_invalidAmount() external {
        vm.prank(ASSURAGE_DELEGATE);
        vm.expectRevert("INVALID_AMOUNT");
        assurageManager.setMinPeriod(0);
    }

    function test_setMinPeriod_success() external {
        assertEq(assurageManager.minPeriod(), 0);

        vm.prank(ASSURAGE_DELEGATE);
        assurageManager.setMinPeriod(1e18);

        assertEq(assurageManager.minPeriod(), 1e18);
    }
}

contract SetDelegateManagementFeeRate_SetterTests is AssurageManagerBase {
    address internal NOT_ASSURAGE_DELEGATE = address(new Address());

    uint256 internal newManagementFeeRate = 10_0000;

    function test_setDelegateManagementFeeRate_notAssurageDelegate() external {
        vm.prank(NOT_ASSURAGE_DELEGATE);
        vm.expectRevert("NOT_DELEGATE");
        assurageManager.setDelegateManagementFeeRate(newManagementFeeRate);
    }

    function test_setDelegateManagementFeeRate_oob() external {
        vm.startPrank(ASSURAGE_DELEGATE);
        vm.expectRevert("PM:SDMFR:OOB");
        assurageManager.setDelegateManagementFeeRate(100_0001);

        assurageManager.setDelegateManagementFeeRate(100_0000);
    }

    function test_setDelegateManagementFeeRate_success() external {
        assertEq(assurageManager.delegateManagementFeeRate(), uint256(0));

        vm.prank(ASSURAGE_DELEGATE);
        assurageManager.setDelegateManagementFeeRate(newManagementFeeRate);

        assertEq(
            assurageManager.delegateManagementFeeRate(),
            newManagementFeeRate
        );
    }
}

contract SetAssessor_SetterTests is AssurageManagerBase {
    address internal NOT_ASSURAGE_DELEGATE = address(new Address());
    address internal NEW_ASSESSOR = address(new Address());

    function test_setAssessor_notAssurageDelegate() external {
        vm.prank(NOT_ASSURAGE_DELEGATE);
        vm.expectRevert("NOT_DELEGATE");
        assurageManager.setAssessor(NEW_ASSESSOR);
    }

    function test_setAssessor_invalidAddress() external {
        vm.prank(ASSURAGE_DELEGATE);
        vm.expectRevert("INVALID_ADDRESS");
        assurageManager.setAssessor(address(0));
    }

    function test_setAssessor_success() external {
        assertEq(assurageManager.assessor(), address(0));

        vm.prank(ASSURAGE_DELEGATE);
        assurageManager.setAssessor(NEW_ASSESSOR);

        assertEq(assurageManager.assessor(), NEW_ASSESSOR);
        assertTrue(assurageManager.isAssessor(NEW_ASSESSOR));
    }
}
