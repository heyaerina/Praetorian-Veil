// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {PraetorianTypes} from "../libraries/PraetorianTypes.sol";

interface IPraetorianCore {
    function beforeExecute(
        PraetorianTypes.ActionContext calldata ctx,
        PraetorianTypes.ProofEnvelope calldata proof,
        PraetorianTypes.StateVector calldata preState
    ) external returns (PraetorianTypes.Verdict verdict, uint64 delayUntil);

    function afterExecute(
        PraetorianTypes.ActionContext calldata ctx,
        PraetorianTypes.StateVector calldata postState
    ) external;
}

interface ISentinelInterceptor {
    function preCheck(
        PraetorianTypes.ActionContext calldata ctx,
        PraetorianTypes.ProofEnvelope calldata proof,
        PraetorianTypes.StateVector calldata preState
    ) external returns (PraetorianTypes.ThreatScore memory score);

    function postCheck(
        PraetorianTypes.ActionContext calldata ctx,
        PraetorianTypes.StateVector calldata postState
    ) external view returns (bool healthy, bytes32 reason);
}

interface ILegionSwarm {
    function observe(
        PraetorianTypes.ActionContext calldata ctx,
        bytes32 featureHash
    ) external returns (uint16 consensusScore);

    function latestPrediction(bytes32 actionId) external view returns (uint16 predictedScore, bytes32 reason);
}

interface IMorphingMechanism {
    function applyVerdict(
        PraetorianTypes.ActionContext calldata ctx,
        PraetorianTypes.ThreatScore calldata score
    ) external returns (uint64 delayUntil);

    function releaseIntent(bytes32 actionId) external;

    function shadowVaultOf(address asset) external view returns (address);
}

interface IInvariantChecker {
    function evaluate(
        PraetorianTypes.ActionContext calldata ctx,
        PraetorianTypes.StateVector calldata state
    ) external view returns (uint16 score, bytes32 reason);
}

interface ICodexRomanum {
    function routeConfig(address adapter) external view returns (PraetorianTypes.RouteConfig memory);

    function invariantCount() external view returns (uint256);

    function invariantAt(
        uint256 index
    ) external view returns (bytes32 id, PraetorianTypes.Invariant memory invariant_);
}
