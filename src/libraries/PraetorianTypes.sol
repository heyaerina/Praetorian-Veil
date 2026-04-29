// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

library PraetorianTypes {
    enum SecurityMode {
        Normal,
        Elevated,
        Quarantined,
        Recovery
    }

    enum ActionType {
        Deposit,
        Withdraw,
        Borrow,
        Repay,
        Liquidate,
        BridgeMint,
        BridgeRelease,
        Governance,
        OracleUpdate,
        AdminCall
    }

    enum Verdict {
        Allow,
        Shadow,
        Delay,
        Freeze,
        Pause
    }

    struct ProofEnvelope {
        bytes32 imageId;
        bytes32 journalHash;
        bytes seal;
        uint64 validUntil;
    }

    struct ActionContext {
        bytes32 actionId;
        address caller;
        address target;
        address receiver;
        address asset;
        uint96 amount;
        uint32 srcChainId;
        uint32 dstChainId;
        uint64 nonce;
        uint64 timestamp;
        ActionType actionType;
        bytes32 metadataHash;
    }

    struct StateVector {
        uint128 protocolLiquidity;
        uint128 protocolDebt;
        uint128 assetReserves;
        uint128 oraclePriceE18;
        uint64 lastOracleUpdate;
        uint64 adminNonce;
        bytes32 extraHash;
    }

    struct ThreatScore {
        uint16 ruleScore;
        uint16 swarmScore;
        uint16 predictedScore;
        uint16 total;
        Verdict verdict;
        bytes32 reason;
    }

    struct Invariant {
        bool enabled;
        uint8 invariantType;
        uint16 maxDeltaBps;
        address subject;
        uint128 minValue;
        uint128 maxValue;
        bytes32 lhsKey;
        bytes32 rhsKey;
    }

    struct RouteConfig {
        bool enabled;
        bool shadowOnAlert;
        bool requireProof;
        uint16 baseRiskBps;
        uint16 maxNotionalBps;
        uint32 freshnessWindow;
        address canonicalSender;
        address verifier;
    }

    struct ModuleConfig {
        address implementation;
        address shadowVault;
        uint48 activatedAt;
        uint48 cooldownEndsAt;
        uint8 flags;
        bool frozen;
    }

    struct NodeState {
        uint64 membrane;
        uint64 threshold;
        uint32 refractoryUntil;
        uint16 weightBps;
        uint16 lastStimulus;
        uint8 classId;
        bool enabled;
    }

    struct QueueIntent {
        address asset;
        address beneficiary;
        uint128 amount;
        uint64 executableAt;
        bool released;
    }
}
