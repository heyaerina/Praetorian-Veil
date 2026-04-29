// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {PraetorianTypes} from "./PraetorianTypes.sol";

library VeilStorage {
    bytes32 internal constant CORE_SLOT = keccak256("praetorian.veil.core.storage.v1");
    bytes32 internal constant CODEX_SLOT = keccak256("praetorian.veil.codex.storage.v1");
    bytes32 internal constant SWARM_SLOT = keccak256("praetorian.veil.swarm.storage.v1");

    struct CoreLayout {
        address interceptor;
        address swarm;
        address morph;
        address checker;
        address codex;
        uint32 reviewInterval;
        uint64 lastReviewAt;
        PraetorianTypes.SecurityMode mode;
        bool emergencyPause;
        mapping(address => bool) protectedExecutor;
        mapping(bytes32 => PraetorianTypes.ThreatScore) threatByAction;
        mapping(bytes32 => bool) actionConsumed;
    }

    struct CodexLayout {
        mapping(bytes32 => PraetorianTypes.Invariant) invariants;
        mapping(bytes32 => bool) knownInvariant;
        bytes32[] invariantIds;
        mapping(address => PraetorianTypes.RouteConfig) routes;
    }

    struct SwarmLayout {
        address interceptor;
        uint32 nodeCount;
        uint16 leakBps;
        uint16 maxConsensusBps;
        bytes32 activeModelHash;
        mapping(uint256 => PraetorianTypes.NodeState) nodes;
        mapping(bytes32 => uint16) lastConsensus;
        mapping(bytes32 => uint16) predictedScoreByAction;
        mapping(bytes32 => bytes32) predictedReasonByAction;
        mapping(bytes32 => uint64) predictionValidUntil;
    }

    function core() internal pure returns (CoreLayout storage layout_) {
        bytes32 slot = CORE_SLOT;
        assembly {
            layout_.slot := slot
        }
    }

    function codex() internal pure returns (CodexLayout storage layout_) {
        bytes32 slot = CODEX_SLOT;
        assembly {
            layout_.slot := slot
        }
    }

    function swarm() internal pure returns (SwarmLayout storage layout_) {
        bytes32 slot = SWARM_SLOT;
        assembly {
            layout_.slot := slot
        }
    }
}
