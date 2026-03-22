// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {USDm} from "../src/USDm.sol";
import {USDmY} from "../src/USDmY.sol";
import {USDv} from "../src/USDv.sol";
import {USDManager} from "../src/USDManager.sol";

contract DebugScript is Script {
    function run() external {
        USDm usdm = new USDm();
        USDmY vault = new USDmY(usdm);
        USDManager manager = new USDManager(address(usdm), address(vault));
        USDv usdv = manager.usdv();

        address alice = address(0x1);
        usdm.mint(alice, 1000 ether);

        vm.startPrank(alice);
        usdm.approve(address(manager), 100 ether);
        console.log("Calling deposit...");
        manager.depositUSDm(100 ether); // She gets 103 USDv
        console.log("Deposit done!");
        vm.stopPrank();

        address bob = address(0x2);
        vm.prank(alice);
        usdv.transfer(bob, 104 ether);

        usdm.mint(bob, 500 ether);
        vm.startPrank(bob);
        usdm.approve(address(vault), 10 ether);
        vault.injectYield(10 ether);
        vm.stopPrank();

        vm.startPrank(bob);
        console.log("Calling claimYield");
        manager.claimYield(103 ether);
        console.log("Claim done");
        vm.stopPrank();
    }
}
