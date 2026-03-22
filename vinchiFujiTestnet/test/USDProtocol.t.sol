// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {USDm} from "../src/USDm.sol";
import {USDmY} from "../src/USDmY.sol";
import {USDv} from "../src/USDv.sol";
import {USDManager} from "../src/USDManager.sol";

contract USDProtocolTest is Test {
    USDm public usdm;
    USDmY public vault;
    USDManager public manager;
    USDv public usdv;

    address alice = address(0x1);
    address bob = address(0x2);

    function setUp() public {
        usdm = new USDm();
        vault = new USDmY(usdm);
        manager = new USDManager(address(usdm), address(vault));
        usdv = manager.usdv();

        // Give alice some initial USDm
        usdm.mint(alice, 1000 ether);

        // Give bob some USDm to inject yield later
        usdm.mint(bob, 500 ether);
    }

    function test_DepositAndMintReceipt() public {
        vm.startPrank(alice);
        usdm.approve(address(manager), 100 ether);
        // Deposit 100 at 3%
        manager.depositUSDm(100 ether);
        vm.stopPrank();

        // Manager should hold Vault Shares (USDmY) equal to the principal (100)
        assertEq(vault.balanceOf(address(manager)), 100 ether);

        // Alice should hold Receipt Tokens (USDv) equal to the FUTURE limit (103)
        assertEq(usdv.balanceOf(alice), 103 ether);

        // Vault should hold the actual underlying stablecoin (USDm) equal to principal (100)
        assertEq(usdm.balanceOf(address(vault)), 100 ether);
    }

    function test_YieldInjectionAndClaim() public {
        // 1. ALICE DEPOSITS 100 at 3%
        vm.startPrank(alice);
        usdm.approve(address(manager), 100 ether);
        manager.depositUSDm(100 ether); // She gets 103 USDv
        vm.stopPrank();

        // ALICE TRANSFERS TO BOB (They trade it)
        vm.prank(alice);
        usdv.transfer(bob, 103 ether);

        assertEq(usdv.balanceOf(alice), 0);
        assertEq(usdv.balanceOf(bob), 103 ether);

        // 2. YIELD IS GENERATED
        // Admin or whoever injects yield to the vault. Say, 10 USDm profit at the end of the month
        vm.startPrank(bob);
        usdm.approve(address(vault), 10 ether);
        vault.injectYield(10 ether);
        vm.stopPrank();

        // 3. BOB CLAIMS HIS YIELD
        vm.startPrank(bob);
        uint256 balanceBefore = usdm.balanceOf(bob);
        // Bob claims all his 103 USDv, reversing the math using the same rate (300 bps)
        manager.claimYield(103 ether);
        uint256 balanceAfter = usdm.balanceOf(bob);
        vm.stopPrank();

        // Bob's resulting balance increase should be the principal (100) + the proportional yield it generated (10)
        // Given ERC4626 math and percentage divisions, we allow a tiny few wei of truncation difference.
        uint256 expectedReturn = 110 ether;
        uint256 actualReturn = balanceAfter - balanceBefore;

        console.log("Balance difference: ", actualReturn);

        // Assert it's extremely close to 110 ether (within 10 wei of precision loss)
        assertGe(actualReturn, expectedReturn - 10);
        assertLe(actualReturn, expectedReturn + 10);
    }
}
