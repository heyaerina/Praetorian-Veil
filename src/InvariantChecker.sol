// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

import {PraetorianTypes} from "./libraries/PraetorianTypes.sol";
import {ICodexRomanum, IInvariantChecker} from "./interfaces/IPraetorianComponents.sol";

contract InvariantChecker is Initializable, AccessControlUpgradeable, IInvariantChecker {
    bytes32 public constant SENATE_ROLE = keccak256("SENATE_ROLE");

    address public codex;
    uint8 public maxScan;

    event CodexUpdated(address indexed codex);
    event MaxScanUpdated(uint8 indexed maxScan);

    function initialize(address admin, address senate, address codex_) external initializer {
        __AccessControl_init();
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(SENATE_ROLE, senate);
        codex = codex_;
        maxScan = 12;
    }

    function setCodex(address codex_) external onlyRole(SENATE_ROLE) {
        codex = codex_;
        emit CodexUpdated(codex_);
    }

    function setMaxScan(uint8 maxScan_) external onlyRole(SENATE_ROLE) {
        maxScan = maxScan_;
        emit MaxScanUpdated(maxScan_);
    }

    function evaluate(
        PraetorianTypes.ActionContext calldata ctx,
        PraetorianTypes.StateVector calldata state
    ) external view returns (uint16 score, bytes32 reason) {
        ICodexRomanum codex_ = ICodexRomanum(codex);
        uint256 count = codex_.invariantCount();
        uint256 upper = count < maxScan ? count : maxScan;

        for (uint256 i; i < upper; ) {
            (bytes32 invariantId, PraetorianTypes.Invariant memory invariant_) = codex_.invariantAt(i);

            if (invariant_.enabled && _appliesTo(invariant_, ctx)) {
                (bool violated, uint16 penalty) = _checkInvariant(invariant_, ctx, state);
                if (violated) {
                    score += penalty;
                    if (reason == bytes32(0)) {
                        reason = invariantId;
                    }
                }
            }

            unchecked {
                ++i;
            }
        }
    }

    function _appliesTo(
        PraetorianTypes.Invariant memory invariant_,
        PraetorianTypes.ActionContext calldata ctx
    ) internal pure returns (bool) {
        return invariant_.subject == address(0) || invariant_.subject == ctx.asset || invariant_.subject == ctx.target;
    }

    function _checkInvariant(
        PraetorianTypes.Invariant memory invariant_,
        PraetorianTypes.ActionContext calldata ctx,
        PraetorianTypes.StateVector calldata state
    ) internal view returns (bool violated, uint16 penalty) {
        penalty = invariant_.maxDeltaBps == 0 ? uint16(1500) : invariant_.maxDeltaBps;

        if (invariant_.invariantType == 0) {
            violated = state.assetReserves < invariant_.minValue;
        } else if (invariant_.invariantType == 1) {
            violated = uint256(block.timestamp) > uint256(state.lastOracleUpdate) + uint256(invariant_.maxValue);
        } else if (invariant_.invariantType == 2) {
            uint256 lhs = uint256(state.protocolLiquidity) * 10_000;
            uint256 rhs = uint256(state.protocolDebt) * uint256(10_000 + invariant_.maxDeltaBps);
            violated = lhs < rhs;
        } else if (invariant_.invariantType == 3) {
            violated = uint256(ctx.amount) > uint256(invariant_.maxValue);
        } else if (invariant_.invariantType == 4) {
            violated = ctx.actionType == PraetorianTypes.ActionType.AdminCall
                && uint256(state.adminNonce) > uint256(invariant_.maxValue);
        } else {
            penalty = 0;
            violated = false;
        }
    }
}
