// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import {PraetorianTypes} from "./libraries/PraetorianTypes.sol";
import {VeilStorage} from "./libraries/VeilStorage.sol";
import {
    IMorphingMechanism,
    ISentinelInterceptor,
    IPraetorianCore
} from "./interfaces/IPraetorianComponents.sol";

contract PraetorianCore is
    Initializable,
    UUPSUpgradeable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    IPraetorianCore
{
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant SENATE_ROLE = keccak256("SENATE_ROLE");
    bytes32 public constant GUARDIAN_ROLE = keccak256("GUARDIAN_ROLE");

    error NotProtectedExecutor();
    error DuplicateAction(bytes32 actionId);
    error BlockedVerdict(PraetorianTypes.Verdict verdict);
    error ComponentsNotConfigured();

    struct InitConfig {
        address admin;
        address upgrader;
        address senate;
        address guardian;
        address interceptor;
        address swarm;
        address morph;
        address checker;
        address codex;
        uint32 reviewInterval;
    }

    event ComponentsUpdated(
        address indexed interceptor,
        address indexed swarm,
        address indexed morph,
        address checker,
        address codex
    );
    event ProtectedExecutorSet(address indexed executor, bool allowed);
    event ActionScreened(
        bytes32 indexed actionId,
        address indexed executor,
        PraetorianTypes.Verdict verdict,
        uint16 totalScore,
        uint64 delayUntil
    );
    event ActionFinalized(bytes32 indexed actionId, bool healthy, bytes32 reason);
    event EmergencyModeChanged(PraetorianTypes.SecurityMode indexed mode, bytes32 indexed reason);
    event SenateReviewTriggered(uint64 indexed timestamp);

    modifier onlyProtectedExecutor() {
        if (!VeilStorage.core().protectedExecutor[msg.sender]) revert NotProtectedExecutor();
        _;
    }

    function initialize(InitConfig calldata cfg) external initializer {
        __AccessControl_init();
        __Pausable_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, cfg.admin);
        _grantRole(UPGRADER_ROLE, cfg.upgrader);
        _grantRole(SENATE_ROLE, cfg.senate);
        _grantRole(GUARDIAN_ROLE, cfg.guardian);

        VeilStorage.CoreLayout storage s = VeilStorage.core();
        s.interceptor = cfg.interceptor;
        s.swarm = cfg.swarm;
        s.morph = cfg.morph;
        s.checker = cfg.checker;
        s.codex = cfg.codex;
        s.reviewInterval = cfg.reviewInterval;
        s.mode = PraetorianTypes.SecurityMode.Normal;

        emit ComponentsUpdated(cfg.interceptor, cfg.swarm, cfg.morph, cfg.checker, cfg.codex);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}

    function setComponents(
        address interceptor,
        address swarm,
        address morph,
        address checker,
        address codex
    ) external onlyRole(SENATE_ROLE) {
        VeilStorage.CoreLayout storage s = VeilStorage.core();
        s.interceptor = interceptor;
        s.swarm = swarm;
        s.morph = morph;
        s.checker = checker;
        s.codex = codex;
        emit ComponentsUpdated(interceptor, swarm, morph, checker, codex);
    }

    function setProtectedExecutor(address executor, bool allowed) external onlyRole(SENATE_ROLE) {
        VeilStorage.core().protectedExecutor[executor] = allowed;
        emit ProtectedExecutorSet(executor, allowed);
    }

    function currentMode() external view returns (PraetorianTypes.SecurityMode) {
        return VeilStorage.core().mode;
    }

    function componentAddresses() external view returns (address, address, address, address, address) {
        VeilStorage.CoreLayout storage s = VeilStorage.core();
        return (s.interceptor, s.swarm, s.morph, s.checker, s.codex);
    }

    function beforeExecute(
        PraetorianTypes.ActionContext calldata ctx,
        PraetorianTypes.ProofEnvelope calldata proof,
        PraetorianTypes.StateVector calldata preState
    )
        external
        whenNotPaused
        nonReentrant
        onlyProtectedExecutor
        returns (PraetorianTypes.Verdict verdict, uint64 delayUntil)
    {
        VeilStorage.CoreLayout storage s = VeilStorage.core();
        if (s.actionConsumed[ctx.actionId]) revert DuplicateAction(ctx.actionId);
        if (s.interceptor == address(0) || s.morph == address(0)) revert ComponentsNotConfigured();

        s.actionConsumed[ctx.actionId] = true;

        PraetorianTypes.ThreatScore memory score =
            ISentinelInterceptor(s.interceptor).preCheck(ctx, proof, preState);
        s.threatByAction[ctx.actionId] = score;
        delayUntil = IMorphingMechanism(s.morph).applyVerdict(ctx, score);

        if (score.verdict == PraetorianTypes.Verdict.Pause) {
            _pause();
            s.mode = PraetorianTypes.SecurityMode.Quarantined;
            emit EmergencyModeChanged(s.mode, score.reason);
            revert BlockedVerdict(score.verdict);
        }

        verdict = score.verdict;
        emit ActionScreened(ctx.actionId, msg.sender, verdict, score.total, delayUntil);
    }

    function afterExecute(
        PraetorianTypes.ActionContext calldata ctx,
        PraetorianTypes.StateVector calldata postState
    ) external whenNotPaused onlyProtectedExecutor {
        VeilStorage.CoreLayout storage s = VeilStorage.core();
        (bool healthy, bytes32 reason) = ISentinelInterceptor(s.interceptor).postCheck(ctx, postState);
        emit ActionFinalized(ctx.actionId, healthy, reason);

        if (!healthy) {
            _pause();
            s.mode = PraetorianTypes.SecurityMode.Recovery;
            emit EmergencyModeChanged(s.mode, reason);
        }
    }

    function guardianPause(bytes32 reason) external onlyRole(GUARDIAN_ROLE) {
        VeilStorage.CoreLayout storage s = VeilStorage.core();
        _pause();
        s.mode = PraetorianTypes.SecurityMode.Quarantined;
        emit EmergencyModeChanged(s.mode, reason);
    }

    function guardianUnpause() external onlyRole(GUARDIAN_ROLE) {
        VeilStorage.CoreLayout storage s = VeilStorage.core();
        _unpause();
        s.mode = PraetorianTypes.SecurityMode.Elevated;
        emit EmergencyModeChanged(s.mode, keccak256("GUARDIAN_UNPAUSE"));
    }

    function triggerSenateReview() external onlyRole(SENATE_ROLE) {
        VeilStorage.CoreLayout storage s = VeilStorage.core();
        s.lastReviewAt = uint64(block.timestamp);
        emit SenateReviewTriggered(s.lastReviewAt);
    }
}
