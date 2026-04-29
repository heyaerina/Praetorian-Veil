// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

import {PraetorianTypes} from "./libraries/PraetorianTypes.sol";
import {VeilStorage} from "./libraries/VeilStorage.sol";

contract LegionSwarm is Initializable, AccessControlUpgradeable {
    bytes32 public constant SENATE_ROLE = keccak256("SENATE_ROLE");
    bytes32 public constant PROVER_ROLE = keccak256("PROVER_ROLE");

    error NotInterceptor();
    error InvalidProofWindow();

    event NodeSeeded(uint256 indexed nodeId, uint64 threshold, uint16 weightBps, uint8 classId);
    event NodeSpiked(uint256 indexed nodeId, bytes32 indexed actionId, uint64 membrane, uint16 stimulus);
    event ConsensusComputed(bytes32 indexed actionId, uint16 consensusScore);
    event PredictiveProofAccepted(bytes32 indexed actionId, uint16 predictedScore, bytes32 indexed threatClass);
    event SenateReviewApplied(uint32 indexed nodeCount, uint16 leakBps, bytes32 indexed newModelHash);

    function initialize(
        address admin,
        address senate,
        address interceptor_,
        uint32 nodeCount_,
        uint16 leakBps_
    ) external initializer {
        __AccessControl_init();
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(SENATE_ROLE, senate);

        VeilStorage.SwarmLayout storage s = VeilStorage.swarm();
        s.interceptor = interceptor_;
        s.nodeCount = nodeCount_;
        s.leakBps = leakBps_;
        s.maxConsensusBps = 10_000;
        s.activeModelHash = keccak256("PRAETORIAN_MODEL_V1");

        for (uint256 i; i < nodeCount_; ) {
            PraetorianTypes.NodeState storage node = s.nodes[i];
            node.enabled = true;
            node.threshold = uint64(4_000 + (i * 125));
            node.weightBps = uint16(500 + (i * 50));
            node.classId = uint8(i % 4);
            emit NodeSeeded(i, node.threshold, node.weightBps, node.classId);

            unchecked {
                ++i;
            }
        }
    }

    function setInterceptor(address interceptor_) external onlyRole(SENATE_ROLE) {
        VeilStorage.swarm().interceptor = interceptor_;
    }

    function observe(
        PraetorianTypes.ActionContext calldata ctx,
        bytes32 featureHash
    ) external returns (uint16 consensusScore) {
        VeilStorage.SwarmLayout storage s = VeilStorage.swarm();
        if (msg.sender != s.interceptor) revert NotInterceptor();

        uint32 nodeCount_ = s.nodeCount;
        uint256 aggregate;

        for (uint256 i; i < nodeCount_; ) {
            PraetorianTypes.NodeState storage node = s.nodes[i];
            if (node.enabled && block.timestamp >= node.refractoryUntil) {
                uint16 stimulus = uint16(uint256(keccak256(abi.encode(featureHash, i, node.classId))) % 10_000);
                uint64 leak = uint64((uint256(node.membrane) * s.leakBps) / 10_000);
                uint64 membrane = node.membrane > leak ? node.membrane - leak : 0;
                membrane += stimulus;
                node.lastStimulus = stimulus;

                if (membrane >= node.threshold) {
                    aggregate += node.weightBps;
                    node.membrane = 0;
                    node.refractoryUntil = uint32(block.timestamp) + 12;
                    emit NodeSpiked(i, ctx.actionId, membrane, stimulus);
                } else {
                    node.membrane = membrane;
                }
            }

            unchecked {
                ++i;
            }
        }

        if (aggregate > s.maxConsensusBps) {
            aggregate = s.maxConsensusBps;
        }

        consensusScore = uint16(aggregate);
        s.lastConsensus[ctx.actionId] = consensusScore;
        emit ConsensusComputed(ctx.actionId, consensusScore);
    }

    function submitPredictiveProof(
        bytes32 actionId,
        uint16 predictedScore,
        bytes32 threatClass,
        PraetorianTypes.ProofEnvelope calldata proof
    ) external onlyRole(PROVER_ROLE) {
        if (proof.validUntil < block.timestamp) revert InvalidProofWindow();

        VeilStorage.SwarmLayout storage s = VeilStorage.swarm();

        // The zkVM verifier hook is intentionally abstracted here. In production,
        // this path should call the selected RISC Zero/SP1 verifier and compare
        // the journal against keccak256(actionId, predictedScore, threatClass, modelHash).
        s.predictedScoreByAction[actionId] = predictedScore;
        s.predictedReasonByAction[actionId] = threatClass;
        s.predictionValidUntil[actionId] = proof.validUntil;

        emit PredictiveProofAccepted(actionId, predictedScore, threatClass);
    }

    function latestPrediction(bytes32 actionId) external view returns (uint16 predictedScore, bytes32 reason) {
        VeilStorage.SwarmLayout storage s = VeilStorage.swarm();
        if (s.predictionValidUntil[actionId] >= block.timestamp) {
            predictedScore = s.predictedScoreByAction[actionId];
            reason = s.predictedReasonByAction[actionId];
        }
    }

    function senateReview(uint32 maxNodes, uint16 leakBps_, bytes32 newModelHash) external onlyRole(SENATE_ROLE) {
        VeilStorage.SwarmLayout storage s = VeilStorage.swarm();
        uint32 nodeCount_ = s.nodeCount < maxNodes ? s.nodeCount : maxNodes;

        for (uint256 i; i < nodeCount_; ) {
            PraetorianTypes.NodeState storage node = s.nodes[i];
            if (node.enabled && node.lastStimulus < 1_000 && node.threshold > 2_000) {
                node.threshold -= 50;
            }

            unchecked {
                ++i;
            }
        }

        s.leakBps = leakBps_;
        s.activeModelHash = newModelHash;
        emit SenateReviewApplied(nodeCount_, leakBps_, newModelHash);
    }
}
