// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

import {PraetorianTypes} from "./libraries/PraetorianTypes.sol";
import {
    ICodexRomanum,
    IInvariantChecker,
    ILegionSwarm,
    ISentinelInterceptor
} from "./interfaces/IPraetorianComponents.sol";

contract SentinelInterceptor is Initializable, AccessControlUpgradeable, ISentinelInterceptor {
    bytes32 public constant SENATE_ROLE = keccak256("SENATE_ROLE");

    error NotCore();

    address public core;
    address public checker;
    address public swarm;
    address public codex;
    uint16 public shadowThreshold;
    uint16 public pauseThreshold;

    event CoreUpdated(address indexed core);
    event ThresholdsUpdated(uint16 shadowThreshold, uint16 pauseThreshold);
    event ThreatScored(bytes32 indexed actionId, uint16 totalScore, PraetorianTypes.Verdict verdict, bytes32 reason);

    modifier onlyCore() {
        if (msg.sender != core) revert NotCore();
        _;
    }

    function initialize(
        address admin,
        address senate,
        address core_,
        address checker_,
        address swarm_,
        address codex_,
        uint16 shadowThreshold_,
        uint16 pauseThreshold_
    ) external initializer {
        __AccessControl_init();
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(SENATE_ROLE, senate);

        core = core_;
        checker = checker_;
        swarm = swarm_;
        codex = codex_;
        shadowThreshold = shadowThreshold_;
        pauseThreshold = pauseThreshold_;
    }

    function setCore(address core_) external onlyRole(SENATE_ROLE) {
        core = core_;
        emit CoreUpdated(core_);
    }

    function setThresholds(uint16 shadowThreshold_, uint16 pauseThreshold_) external onlyRole(SENATE_ROLE) {
        shadowThreshold = shadowThreshold_;
        pauseThreshold = pauseThreshold_;
        emit ThresholdsUpdated(shadowThreshold_, pauseThreshold_);
    }

    function preCheck(
        PraetorianTypes.ActionContext calldata ctx,
        PraetorianTypes.ProofEnvelope calldata proof,
        PraetorianTypes.StateVector calldata preState
    ) external onlyCore returns (PraetorianTypes.ThreatScore memory score) {
        (score.ruleScore, score.reason) = IInvariantChecker(checker).evaluate(ctx, preState);

        bytes32 featureHash = keccak256(
            abi.encodePacked(
                ctx.caller,
                ctx.target,
                ctx.asset,
                ctx.amount,
                ctx.actionType,
                preState.protocolLiquidity,
                preState.protocolDebt,
                preState.extraHash
            )
        );

        score.swarmScore = ILegionSwarm(swarm).observe(ctx, featureHash);
        (score.predictedScore, bytes32 predictedReason) = ILegionSwarm(swarm).latestPrediction(ctx.actionId);

        PraetorianTypes.RouteConfig memory route = ICodexRomanum(codex).routeConfig(ctx.target);
        if (route.requireProof && proof.validUntil < block.timestamp) {
            score.predictedScore += 1_000;
            if (score.reason == bytes32(0)) {
                score.reason = keccak256("STALE_PROOF_WINDOW");
            }
        }

        score.total = _saturatingAdd4(score.ruleScore, score.swarmScore, score.predictedScore, route.baseRiskBps);

        if (score.reason == bytes32(0)) {
            score.reason = predictedReason;
        }

        score.verdict = _deriveVerdict(ctx, score.total, route.shadowOnAlert);
        emit ThreatScored(ctx.actionId, score.total, score.verdict, score.reason);
    }

    function postCheck(
        PraetorianTypes.ActionContext calldata ctx,
        PraetorianTypes.StateVector calldata postState
    ) external view onlyCore returns (bool healthy, bytes32 reason) {
        (uint16 ruleScore, bytes32 firstReason) = IInvariantChecker(checker).evaluate(ctx, postState);
        healthy = ruleScore < pauseThreshold;
        reason = firstReason;
    }

    function _deriveVerdict(
        PraetorianTypes.ActionContext calldata ctx,
        uint16 totalScore,
        bool shadowOnAlert
    ) internal view returns (PraetorianTypes.Verdict verdict) {
        if (totalScore >= pauseThreshold) {
            if (
                ctx.actionType == PraetorianTypes.ActionType.AdminCall ||
                ctx.actionType == PraetorianTypes.ActionType.BridgeMint ||
                ctx.actionType == PraetorianTypes.ActionType.Governance
            ) {
                return PraetorianTypes.Verdict.Pause;
            }

            return PraetorianTypes.Verdict.Freeze;
        }

        if (totalScore >= shadowThreshold) {
            return shadowOnAlert ? PraetorianTypes.Verdict.Shadow : PraetorianTypes.Verdict.Delay;
        }

        return PraetorianTypes.Verdict.Allow;
    }

    function _saturatingAdd4(uint16 a, uint16 b, uint16 c, uint16 d) internal pure returns (uint16) {
        uint256 total = uint256(a) + b + c + d;
        return total > 10_000 ? 10_000 : uint16(total);
    }
}
