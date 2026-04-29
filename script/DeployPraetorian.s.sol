// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Script} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {PraetorianCore} from "../src/PraetorianCore.sol";
import {CodexRomanum} from "../src/CodexRomanum.sol";
import {InvariantChecker} from "../src/InvariantChecker.sol";
import {LegionSwarm} from "../src/LegionSwarm.sol";
import {SentinelInterceptor} from "../src/SentinelInterceptor.sol";
import {MorphingMechanism} from "../src/MorphingMechanism.sol";

contract DeployPraetorian is Script {
    function run() external {
        uint256 deployerPk = vm.envUint("PRIVATE_KEY");
        address admin = vm.addr(deployerPk);
        address senate = vm.envOr("SENATE_ADDRESS", admin);
        address guardian = vm.envOr("GUARDIAN_ADDRESS", admin);
        address upgrader = vm.envOr("UPGRADER_ADDRESS", admin);

        vm.startBroadcast(deployerPk);

        CodexRomanum codexImpl = new CodexRomanum();
        codexImpl.initialize(admin, senate);

        InvariantChecker checkerImpl = new InvariantChecker();
        checkerImpl.initialize(admin, senate, address(codexImpl));

        MorphingMechanism morphImpl = new MorphingMechanism();

        PraetorianCore coreImpl = new PraetorianCore();
        PraetorianCore.InitConfig memory cfg = PraetorianCore.InitConfig({
            admin: admin,
            upgrader: upgrader,
            senate: senate,
            guardian: guardian,
            interceptor: address(0),
            swarm: address(0),
            morph: address(0),
            checker: address(checkerImpl),
            codex: address(codexImpl),
            reviewInterval: 6 hours
        });

        ERC1967Proxy coreProxy = new ERC1967Proxy(address(coreImpl), abi.encodeCall(PraetorianCore.initialize, (cfg)));
        PraetorianCore core = PraetorianCore(address(coreProxy));

        morphImpl.initialize(admin, senate, address(core));

        LegionSwarm swarmImpl = new LegionSwarm();
        swarmImpl.initialize(admin, senate, address(0), 8, 1_250);

        SentinelInterceptor interceptorImpl = new SentinelInterceptor();
        interceptorImpl.initialize(
            admin,
            senate,
            address(core),
            address(checkerImpl),
            address(swarmImpl),
            address(codexImpl),
            3_500,
            7_000
        );

        swarmImpl.setInterceptor(address(interceptorImpl));

        core.setComponents(
            address(interceptorImpl),
            address(swarmImpl),
            address(morphImpl),
            address(checkerImpl),
            address(codexImpl)
        );

        vm.stopBroadcast();
    }
}
