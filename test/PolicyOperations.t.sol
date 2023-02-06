// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.17;

import {StdCheats} from "forge-std/StdCheats.sol";
import {AssurageManagerBase, Address, DSTest, Vm, console} from "./AssurageSetup.t.sol";

// TEST COMMAND:  forge test --match-path test/PolicyOperations.t.sol -vvvvv

contract PolicyOperationsBase is AssurageManagerBase {
    address internal SP = address(new Address());
    address internal NonSP = address(new Address());
    address internal LP = address(new Address());
    uint256 internal A_MONTH = 2628000 * 6;
    uint256 internal TEN_FIL = 1000e18;
    uint8 internal SCORE = 99;
    uint256 internal CLAIMABLE = 500e18;
    uint256 internal LP_DEPOSIT = 10000e18;

    function _activationSetup() internal returns (uint256) {
        assurageManager.configure(10e18, 2628000, 1_000_000e18, 0.1e6);

        vm.prank(SP);
        uint256 id = assurageManager.applyForProtection(SP, TEN_FIL, A_MONTH);

        vm.prank(ASSURAGE_DELEGATE);
        assurageManager.approvePolicy(SP, id, 99);

        return id;
    }

    function _claimSetup() internal returns (uint256) {
        uint256 id = _activationSetup();

        vm.deal(address(SP), 1000e18);
        vm.prank(SP);
        assurageManager.activatePolicy(SP, id);
        return id;
    }

    function _claimSetup2() internal returns (uint256) {
        uint256 id = _claimSetup();

        vm.prank(SP);
        assurageManager.fileClaim(SP, id, CLAIMABLE);

        vm.prank(ASSURAGE_DELEGATE);
        assurageManager.approveClaim(SP, id, CLAIMABLE);

        vm.deal(address(LP), LP_DEPOSIT);
        vm.prank(address(LP));
        asset.deposit{value: LP_DEPOSIT}();

        return id;
    }
}

// TEST COMMAND: forge test --match-contract Application -vvvvv

contract Application is PolicyOperationsBase {
    function test_applyForProtection_invalidCaller() external {
        address NonSP = address(new Address());
        vm.prank(NonSP);

        vm.expectRevert("INVALID_CALLER");
        assurageManager.applyForProtection(SP, TEN_FIL, A_MONTH);
    }

    // function test_applyForProtection_invalidBeneficiary() external {
    //     vm.prank(SP);
    //     vm.expectRevert("INVALID_BENEFICIARY");
    //     assurageManager.applyForProtection(SP, TEN_FIL, A_MONTH);
    // }

    function test_applyForProtection_invalidAMOUNT() external {
        vm.prank(ASSURAGE_DELEGATE);
        assurageManager.setMinProtection(TEN_FIL);

        uint256 NINE_FIL = 900e17;
        vm.prank(SP);
        vm.expectRevert("INVALID_AMOUNT");
        assurageManager.applyForProtection(SP, NINE_FIL, A_MONTH);
    }

    function test_applyForProtection_invalidPeriod() external {
        vm.prank(ASSURAGE_DELEGATE);
        assurageManager.setMinPeriod(A_MONTH);

        uint256 A_DAY = 86400;
        vm.prank(SP);
        vm.expectRevert("INVALID_PEIROD");
        assurageManager.applyForProtection(SP, A_DAY, A_DAY);
    }

    // forge test --match-contract Application --match-test test_application_success --fork-url https://api.hyperspace.node.glif.io/rpc/v1 -vvv
    function test_application_success() public {
        (
            address miner,
            uint256 amount,
            ,
            uint256 period,
            ,
            ,
            ,
            ,

        ) = assurageManager.policies(SP, 1);

        assertEq(miner, address(0));
        assertEq(amount, uint256(0));
        assertEq(period, uint256(0));

        consoleBefore(miner, amount, period);

        vm.prank(SP);
        uint256 id = assurageManager.applyForProtection(SP, TEN_FIL, A_MONTH);

        (miner, amount, , period, , , , , ) = assurageManager.policies(SP, id);

        assertEq(miner, SP);
        assertEq(amount, TEN_FIL);
        assertEq(period, A_MONTH);

        consoleAfter(miner, amount, period);
    }

    // consoles
    function consoleBefore(
        address miner,
        uint256 amount,
        uint256 period
    ) internal view {
        console.log("");
        console.log("[Before] Policy Application:");
        console.log("miner", miner);
        console.log("amount", amount);
        console.log("period", period);
        console.log("");
    }

    function consoleAfter(
        address miner,
        uint256 amount,
        uint256 period
    ) internal view {
        console.log("");
        console.log("[After] Policy Application:");
        console.log("miner", miner);
        console.log("amount", amount);
        console.log("period", period);
        console.log("");
    }
}

// TEST COMMAND: forge test --match-contract Activation -vvvvv

contract Activation is PolicyOperationsBase {
    function test_activatePolicy_invalidCaller() external {
        uint256 id = _activationSetup();

        vm.prank(NonSP);
        vm.expectRevert("INVALID_CALLER");
        assurageManager.activatePolicy(SP, id);

        beforeActivation();
        assurageManager.activatePolicy(SP, id);
    }

    function test_activatePolicy_notApproved() external {
        assurageManager.configure(10e18, 2628000, 1_000_000e18, 0.1e6);

        vm.startPrank(SP);
        uint256 id = assurageManager.applyForProtection(SP, TEN_FIL, A_MONTH);

        vm.expectRevert("NOT_APPROVED");
        assurageManager.activatePolicy(SP, id);
        vm.stopPrank();

        vm.prank(ASSURAGE_DELEGATE);
        assurageManager.approvePolicy(SP, id, SCORE);

        beforeActivation();
        assurageManager.activatePolicy(SP, id);
    }

    function test_activatePolicy_alreadyActivated() external {
        uint256 id = _activationSetup();

        beforeActivationStart();
        assurageManager.activatePolicy(SP, id);

        vm.expectRevert("ALREADY_ACTIVATED");
        assurageManager.activatePolicy(SP, id);
    }

    /*

    function test_activatePolicy_insufficientBalance() external {
        uint256 id = _activationSetup();

        beforeActivationStart();

        // available balance < amount

        vm.expectRevert("INSUFFICIENT_BALANCE");
        assurageManager.activatePolicy(SP, id);
    }

    function test_activatePolicy_inValidBeneficiaryInfo() external {
        uint256 id = _activationSetup();

        beforeActivationStart();

        // set BeneficiaryInfo

        vm.expectRevert("INVALID_BENEFICIARY_INFO");
        assurageManager.activatePolicy(SP, id);
    }

    function test_activatePolicy_withdrawalFailed() external {
        uint256 id = _activationSetup();

        beforeActivationStart();

        // balance < amount

        vm.expectRevert("WITHDRAWAL_FAILED");
        assurageManager.activatePolicy(SP, id);
    }

    */

    function test_activation_success() public {
        uint256 id = _activationSetup();
        uint256 PREMIUM = assurageManager._quotePremium(
            TEN_FIL,
            A_MONTH,
            SCORE
        );
        uint256 EXPIRY = A_MONTH + block.timestamp;

        (
            address miner,
            uint256 amount,
            uint256 premium,
            uint256 period,
            uint256 expiry,
            uint8 score,
            bool isApproved,
            bool isActive,

        ) = assurageManager.policies(SP, id);

        assertEq(miner, SP);
        assertEq(amount, TEN_FIL);
        assertEq(period, A_MONTH);

        vm.deal(address(SP), 20e18);

        consoleBefore(
            miner,
            amount,
            premium,
            period,
            expiry,
            score,
            isApproved,
            isActive
        );

        vm.prank(SP);
        assurageManager.activatePolicy(SP, id);

        (
            miner,
            amount,
            premium,
            period,
            expiry,
            score,
            isApproved,
            isActive,

        ) = assurageManager.policies(SP, id);

        assertEq(miner, SP);
        assertEq(amount, TEN_FIL);
        assertEq(premium, PREMIUM);
        assertEq(period, A_MONTH);
        assertEq(expiry, EXPIRY);
        assertEq(score, SCORE);
        assertTrue(isApproved);
        assertTrue(isActive);

        consoleAfter(
            miner,
            amount,
            premium,
            period,
            expiry,
            score,
            isApproved,
            isActive
        );
    }

    // consoles

    function consoleBefore(
        address miner,
        uint256 amount,
        uint256 premium,
        uint256 period,
        uint256 expiry,
        uint8 score,
        bool isApproved,
        bool isActive
    ) internal view {
        console.log("");
        console.log(
            "/////////////////// --- POLICY ACTIVATION ---- ////////////////////////"
        );
        console.log("");
        console.log("");
        console.log("---- Before -----");
        console.log("- SP Address     :", miner);
        console.log("- Cover Amount   :", amount / 1e18, "FIL");
        console.log("- Premium Amount :", premium / 1e18, "FIL");
        console.log("- Duration       :", period / 60 / 60 / 24, "DAYS");
        console.log("- Expiry         :", expiry, "(TIMESTAMP)");
        console.log("- SP Score       :", score, "Pts");
        console.log("- Approval?      :", isApproved);
        console.log("- Active?        :", isActive);
        console.log("- SP FIL Balance :", address(SP).balance / 1e18, "FIL");
        console.log("");
    }

    function consoleAfter(
        address miner,
        uint256 amount,
        uint256 premium,
        uint256 period,
        uint256 expiry,
        uint8 score,
        bool isApproved,
        bool isActive
    ) internal view {
        console.log("         .");
        console.log("         .");
        console.log("   activatePolicy()");
        console.log("         .");
        console.log("         .");
        console.log("");
        console.log("---- After -----");
        console.log("- SP Address     :", miner);
        console.log("- Cover Amount   :", amount / 1e18, "FIL");
        console.log("- Premium Amount :", premium / 1e18, "FIL");
        console.log("- Duration       :", period / 60 / 60 / 24, "DAYS");
        console.log("- Expiry         :", expiry, "(TIMESTAMP)");
        console.log("- SP Score       :", score, "Pts");
        console.log("- Approval?      :", isApproved);
        console.log("- Active?        :", isActive);
        console.log("- SP FIL Balance :", address(SP).balance / 1e18, "FIL");
        console.log("");
        console.log("");
        console.log(
            "//////////////////////////////////////////////////////////////////"
        );
        console.log("");
    }

    // Activation Helpers

    function queryPremium() internal view returns (uint256) {
        return assurageManager._quotePremium(TEN_FIL, A_MONTH, SCORE);
    }

    function beforeActivation() internal {
        uint256 PREMIUM = queryPremium();
        vm.deal(address(SP), PREMIUM);
        vm.prank(SP);
    }

    function beforeActivationStart() internal {
        uint256 PREMIUM = queryPremium();
        vm.deal(address(SP), PREMIUM);
        vm.startPrank(SP);
    }
}

// TEST COMMAND: forge test --match-contract Claim -vvvvv
contract Claim is PolicyOperationsBase {
    function test_fileClaim_invalidCaller() external {
        uint256 id = _claimSetup();

        vm.prank(NonSP);
        vm.expectRevert("INVALID_CALLER");
        assurageManager.fileClaim(SP, id, CLAIMABLE);

        vm.prank(SP);
        assurageManager.fileClaim(SP, id, CLAIMABLE);
    }

    function test_fileClaim_invalidAmount() external {
        uint256 id = _claimSetup();
        uint256 INVAlID_CLAIMABLE = TEN_FIL + 1e18;

        vm.startPrank(SP);
        vm.expectRevert("INVALID_AMOUNT");
        assurageManager.fileClaim(SP, id, INVAlID_CLAIMABLE);

        vm.expectRevert("INVALID_AMOUNT");
        assurageManager.fileClaim(SP, id, 0);

        assurageManager.fileClaim(SP, id, CLAIMABLE);
    }

    function test_fileClaim_success() external {
        uint256 id = _claimSetup();

        (uint256 claimable, bool isConfirmed, bool isPaid) = assurageManager
            .getClaim(SP, id);

        assertEq(claimable, 0);
        assertTrue(!isConfirmed);
        assertTrue(!isPaid);

        vm.prank(SP);
        assurageManager.fileClaim(SP, id, CLAIMABLE);

        (claimable, isConfirmed, isPaid) = assurageManager.getClaim(SP, id);

        assertEq(claimable, CLAIMABLE);
        assertTrue(!isConfirmed);
        assertTrue(!isPaid);
    }

    function test_claimCompensation_invalidCaller() external {
        uint256 id = _claimSetup2();

        vm.prank(NonSP);
        vm.expectRevert("INVALID_CALLER");
        assurageManager.claimCompensation(SP, id);

        vm.prank(SP);
        assurageManager.claimCompensation(SP, id);
    }

    function test_claimCompensation_notConfirmed() external {
        uint256 id = _claimSetup();

        vm.prank(SP);
        assurageManager.fileClaim(SP, id, CLAIMABLE);

        vm.deal(address(LP), LP_DEPOSIT);
        vm.prank(address(LP));
        asset.deposit{value: LP_DEPOSIT}();

        vm.prank(SP);
        vm.expectRevert("NOT_CONFIRMED");
        assurageManager.claimCompensation(SP, id);

        vm.prank(ASSURAGE_DELEGATE);
        assurageManager.approveClaim(SP, id, CLAIMABLE);

        vm.prank(SP);
        assurageManager.claimCompensation(SP, id);
    }

    function test_claimCompensation_alreadyPaid() external {
        uint256 id = _claimSetup2();

        vm.prank(SP);
        assurageManager.claimCompensation(SP, id);

        vm.prank(SP);
        vm.expectRevert("ALREADY_PAID");
        assurageManager.claimCompensation(SP, id);
    }

    function test_claimCompensation_insufficientLiquidity() external {
        uint256 id = _claimSetup2();

        asset.burn(address(vault), 1_000e18);

        vm.prank(SP);
        vm.expectRevert("INSUFFICIENT_LIQUIDITY");
        assurageManager.claimCompensation(SP, id);

        asset.mint(address(vault), 1_000e18);

        vm.prank(SP);
        assurageManager.claimCompensation(SP, id);
    }

    function test_claimCompensation_success() external {
        uint256 id = _claimSetup2();

        (uint256 claimable, bool isConfirmed, bool isPaid) = assurageManager
            .getClaim(SP, id);

        assertEq(claimable, claimable);
        assertTrue(isConfirmed);
        assertTrue(!isPaid);

        consoleBefore(claimable, isConfirmed, isPaid);

        vm.prank(SP);
        assurageManager.claimCompensation(SP, id);

        (claimable, isConfirmed, isPaid) = assurageManager.getClaim(SP, id);

        assertEq(claimable, CLAIMABLE);
        assertTrue(isConfirmed);
        assertTrue(isPaid);

        (, , , , , , , bool isActive, ) = assurageManager.policies(SP, id);

        assertTrue(!isActive);

        consoleAfter(claimable, isConfirmed, isPaid);
    }

    // consoles

    function consoleBefore(
        uint256 claimable,
        bool isConfirmed,
        bool isPaid
    ) internal view {
        console.log("");
        console.log(
            "/////////////////// --- CLAIM PAYMENT ---- ////////////////////////"
        );
        console.log("");
        console.log("");
        console.log("---- Before -----");
        console.log("- Claimable      :", claimable / 1e18, "FIL");
        console.log("- Confirmed?     :", isConfirmed);
        console.log("- Paid?          :", isPaid);
        console.log("- SP FIL Balance :", address(SP).balance / 1e18, "FIL");
        console.log("");
    }

    function consoleAfter(
        uint256 claimable,
        bool isConfirmed,
        bool isPaid
    ) internal view {
        console.log("         .");
        console.log("         .");
        console.log(" claimCompensation()");
        console.log("         .");
        console.log("         .");
        console.log("");
        console.log("---- After -----");
        console.log("- Claimable      :", claimable / 1e18, "FIL");
        console.log("- Confirmed?     :", isConfirmed);
        console.log("- Paid?          :", isPaid);
        console.log("- SP FIL Balance :", address(SP).balance / 1e18, "FIL");
        console.log("");
        console.log("");
        console.log(
            "//////////////////////////////////////////////////////////////////"
        );
        console.log("");
    }
}
