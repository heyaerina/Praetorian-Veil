// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";

import {PraetorianCore} from "../src/PraetorianCore.sol";

contract PraetorianCoreTest is Test {
    PraetorianCore internal core;

    function setUp() external {
        core = new PraetorianCore();

        PraetorianCore.InitConfig memory cfg = PraetorianCore.InitConfig({
            admin: address(this),
            upgrader: address(this),
            senate: address(this),
            guardian: address(this),
            interceptor: address(0x1001),
            swarm: address(0x1002),
            morph: address(0x1003),
            checker: address(0x1004),
            codex: address(0x1005),
            reviewInterval: 6 hours
        });

        core.initialize(cfg);
    }

    function testInitialModeIsNormal() external view {
        assertEq(uint256(core.currentMode()), 0);
    }

    function testComponentAddressesAreStored() external view {
        (address interceptor, address swarm, address morph, address checker, address codex) = core.componentAddresses();

        assertEq(interceptor, address(0x1001));
        assertEq(swarm, address(0x1002));
        assertEq(morph, address(0x1003));
        assertEq(checker, address(0x1004));
        assertEq(codex, address(0x1005));
    }
}
