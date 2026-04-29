// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {PraetorianTypes} from "./libraries/PraetorianTypes.sol";
import {IMorphingMechanism} from "./interfaces/IPraetorianComponents.sol";

contract ShadowVault is Initializable, AccessControlUpgradeable {
    using SafeERC20 for IERC20;

    bytes32 public constant MORPH_ROLE = keccak256("MORPH_ROLE");
    bytes32 public constant RECOVERY_ROLE = keccak256("RECOVERY_ROLE");

    event Quarantined(address indexed asset, address indexed from, uint256 amount);
    event Released(address indexed asset, address indexed to, uint256 amount);

    function initialize(address admin, address morph, address recovery) external initializer {
        __AccessControl_init();
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(MORPH_ROLE, morph);
        _grantRole(RECOVERY_ROLE, recovery);
    }

    function depositFrom(address asset, address from, uint256 amount) external onlyRole(MORPH_ROLE) {
        IERC20(asset).safeTransferFrom(from, address(this), amount);
        emit Quarantined(asset, from, amount);
    }

    function release(address asset, address to, uint256 amount) external onlyRole(RECOVERY_ROLE) {
        IERC20(asset).safeTransfer(to, amount);
        emit Released(asset, to, amount);
    }
}

contract MorphingMechanism is Initializable, AccessControlUpgradeable, IMorphingMechanism {
    bytes32 public constant SENATE_ROLE = keccak256("SENATE_ROLE");
    bytes32 public constant CORE_ROLE = keccak256("CORE_ROLE");

    error SelectorFrozen(bytes4 selector);
    error IntentUnavailable(bytes32 actionId);
    error IntentStillLocked(bytes32 actionId);

    mapping(bytes4 => PraetorianTypes.ModuleConfig) public moduleBySelector;
    mapping(address => address) public override shadowVaultOf;
    mapping(bytes32 => PraetorianTypes.QueueIntent) public intents;
    mapping(uint8 => bytes4) public selectorForAction;
    mapping(bytes4 => bool) public frozenSelector;

    event ModuleConfigured(bytes4 indexed selector, address indexed implementation, address indexed shadowVault);
    event ShadowVaultSet(address indexed asset, address indexed shadowVault);
    event SelectorStatusChanged(bytes4 indexed selector, bool frozen);
    event IntentQueued(bytes32 indexed actionId, address indexed asset, address indexed beneficiary, uint64 executableAt);
    event IntentReleased(bytes32 indexed actionId);

    function initialize(address admin, address senate, address core_) external initializer {
        __AccessControl_init();
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(SENATE_ROLE, senate);
        _grantRole(CORE_ROLE, core_);
    }

    function setModule(bytes4 selector, PraetorianTypes.ModuleConfig calldata config) external onlyRole(SENATE_ROLE) {
        moduleBySelector[selector] = config;
        emit ModuleConfigured(selector, config.implementation, config.shadowVault);
    }

    function setShadowVault(address asset, address shadowVault) external onlyRole(SENATE_ROLE) {
        shadowVaultOf[asset] = shadowVault;
        emit ShadowVaultSet(asset, shadowVault);
    }

    function mapActionToSelector(uint8 actionType, bytes4 selector) external onlyRole(SENATE_ROLE) {
        selectorForAction[actionType] = selector;
    }

    function isFrozen(bytes4 selector) external view returns (bool) {
        return frozenSelector[selector];
    }

    function applyVerdict(
        PraetorianTypes.ActionContext calldata ctx,
        PraetorianTypes.ThreatScore calldata score
    ) external onlyRole(CORE_ROLE) returns (uint64 delayUntil) {
        bytes4 selector = selectorForAction[uint8(ctx.actionType)];

        if (score.verdict == PraetorianTypes.Verdict.Allow) {
            return 0;
        }

        if (score.verdict == PraetorianTypes.Verdict.Shadow) {
            delayUntil = uint64(block.timestamp + 45);
            intents[ctx.actionId] = PraetorianTypes.QueueIntent({
                asset: ctx.asset,
                beneficiary: ctx.receiver,
                amount: ctx.amount,
                executableAt: delayUntil,
                released: false
            });
            emit IntentQueued(ctx.actionId, ctx.asset, ctx.receiver, delayUntil);
            return delayUntil;
        }

        if (score.verdict == PraetorianTypes.Verdict.Delay) {
            delayUntil = uint64(block.timestamp + 300);
            intents[ctx.actionId] = PraetorianTypes.QueueIntent({
                asset: ctx.asset,
                beneficiary: ctx.receiver,
                amount: ctx.amount,
                executableAt: delayUntil,
                released: false
            });
            emit IntentQueued(ctx.actionId, ctx.asset, ctx.receiver, delayUntil);
            return delayUntil;
        }

        if (selector != bytes4(0)) {
            frozenSelector[selector] = true;
            emit SelectorStatusChanged(selector, true);
        }
    }

    function releaseIntent(bytes32 actionId) external {
        PraetorianTypes.QueueIntent storage intent = intents[actionId];
        if (intent.executableAt == 0 || intent.released) revert IntentUnavailable(actionId);
        if (block.timestamp < intent.executableAt) revert IntentStillLocked(actionId);

        intent.released = true;
        emit IntentReleased(actionId);
    }
}
