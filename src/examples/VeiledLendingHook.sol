// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {PraetorianTypes} from "../libraries/PraetorianTypes.sol";
import {IPraetorianCore} from "../interfaces/IPraetorianComponents.sol";

interface IPoolLike {
    function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;
    function withdraw(address asset, uint256 amount, address to) external returns (uint256);
    function borrow(address asset, uint256 amount, uint256 rateMode, uint16 referralCode, address onBehalfOf) external;
}

contract VeiledLendingHook is ReentrancyGuard {
    error ProtectedActionBlocked(PraetorianTypes.Verdict verdict);
    error IntentNotExecutable(bytes32 actionId);

    struct PendingBorrow {
        address asset;
        address onBehalfOf;
        uint256 amount;
        uint16 referralCode;
        uint64 executeAfter;
        bool executed;
    }

    IPraetorianCore public immutable veil;
    IPoolLike public immutable pool;
    mapping(bytes32 => PendingBorrow) public pendingBorrows;

    event BorrowQueued(bytes32 indexed actionId, address indexed asset, address indexed onBehalfOf, uint64 executeAfter);
    event BorrowExecuted(bytes32 indexed actionId, address indexed asset, uint256 amount);

    constructor(address veil_, address pool_) {
        veil = IPraetorianCore(veil_);
        pool = IPoolLike(pool_);
    }

    function veiledSupply(
        address asset,
        uint256 amount,
        address onBehalfOf,
        uint16 referralCode,
        PraetorianTypes.ProofEnvelope calldata proof,
        PraetorianTypes.StateVector calldata preState,
        PraetorianTypes.StateVector calldata postState
    ) external nonReentrant {
        PraetorianTypes.ActionContext memory ctx = _context(
            asset, onBehalfOf, amount, PraetorianTypes.ActionType.Deposit
        );

        (PraetorianTypes.Verdict verdict,) = veil.beforeExecute(ctx, proof, preState);
        if (verdict != PraetorianTypes.Verdict.Allow) revert ProtectedActionBlocked(verdict);

        pool.supply(asset, amount, onBehalfOf, referralCode);
        veil.afterExecute(ctx, postState);
    }

    function veiledBorrow(
        address asset,
        uint256 amount,
        address onBehalfOf,
        uint16 referralCode,
        PraetorianTypes.ProofEnvelope calldata proof,
        PraetorianTypes.StateVector calldata preState,
        PraetorianTypes.StateVector calldata postState
    ) external nonReentrant {
        PraetorianTypes.ActionContext memory ctx = _context(
            asset, onBehalfOf, amount, PraetorianTypes.ActionType.Borrow
        );

        (PraetorianTypes.Verdict verdict, uint64 delayUntil) = veil.beforeExecute(ctx, proof, preState);

        if (verdict == PraetorianTypes.Verdict.Allow) {
            pool.borrow(asset, amount, 2, referralCode, onBehalfOf);
            veil.afterExecute(ctx, postState);
            emit BorrowExecuted(ctx.actionId, asset, amount);
            return;
        }

        if (verdict == PraetorianTypes.Verdict.Shadow || verdict == PraetorianTypes.Verdict.Delay) {
            pendingBorrows[ctx.actionId] = PendingBorrow({
                asset: asset,
                onBehalfOf: onBehalfOf,
                amount: amount,
                referralCode: referralCode,
                executeAfter: delayUntil,
                executed: false
            });
            emit BorrowQueued(ctx.actionId, asset, onBehalfOf, delayUntil);
            return;
        }

        revert ProtectedActionBlocked(verdict);
    }

    function executeQueuedBorrow(bytes32 actionId, PraetorianTypes.StateVector calldata postState) external nonReentrant {
        PendingBorrow storage pending = pendingBorrows[actionId];
        if (pending.executed || pending.executeAfter == 0 || block.timestamp < pending.executeAfter) {
            revert IntentNotExecutable(actionId);
        }

        pending.executed = true;

        PraetorianTypes.ActionContext memory ctx = PraetorianTypes.ActionContext({
            actionId: actionId,
            caller: msg.sender,
            target: address(this),
            receiver: pending.onBehalfOf,
            asset: pending.asset,
            amount: uint96(pending.amount),
            srcChainId: uint32(block.chainid),
            dstChainId: uint32(block.chainid),
            nonce: uint64(block.number),
            timestamp: uint64(block.timestamp),
            actionType: PraetorianTypes.ActionType.Borrow,
            metadataHash: keccak256("QUEUED_BORROW")
        });

        pool.borrow(pending.asset, pending.amount, 2, pending.referralCode, pending.onBehalfOf);
        veil.afterExecute(ctx, postState);
        emit BorrowExecuted(actionId, pending.asset, pending.amount);
    }

    function _context(
        address asset,
        address receiver,
        uint256 amount,
        PraetorianTypes.ActionType actionType
    ) internal view returns (PraetorianTypes.ActionContext memory ctx) {
        ctx = PraetorianTypes.ActionContext({
            actionId: keccak256(
                abi.encodePacked(msg.sender, address(this), asset, receiver, amount, actionType, block.number)
            ),
            caller: msg.sender,
            target: address(this),
            receiver: receiver,
            asset: asset,
            amount: uint96(amount),
            srcChainId: uint32(block.chainid),
            dstChainId: uint32(block.chainid),
            nonce: uint64(block.number),
            timestamp: uint64(block.timestamp),
            actionType: actionType,
            metadataHash: keccak256(abi.encodePacked(asset, receiver, amount, actionType))
        });
    }
}
