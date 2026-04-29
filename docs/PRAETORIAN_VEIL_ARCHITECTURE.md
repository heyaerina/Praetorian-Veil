# Praetorian Veil - Adaptive DeFi Security Layer for Ethereum (Solidity)

## Whitepaper-style Overview

Praetorian Veil is an adaptive security middleware for Ethereum mainnet and rollups that treats DeFi protocols as living systems rather than static contracts. Instead of relying on a single governor multisig, one-time audits, or binary pause switches, it introduces a layered immune model: a UUPS-upgradeable core, a neuromorphic-inspired sentinel swarm, deterministic invariant enforcement through Codex Romanum, and morphogenic response modules that can delay, shadow-route, quarantine, or freeze only the riskiest parts of a protocol. The design goal is not just exploit detection after the fact, but pre-emption during the critical 30-60 second window in which bridge spoofing, oracle manipulation, collateral fraud, or compromised admin actions typically fan out.

The core innovation is composability between deterministic and predictive security. Praetorian Veil does not pretend Solidity can host a real spiking neural network or run arbitrary zkML cheaply on-chain. Instead, it uses the parts Ethereum is good at: bounded state machines, fixed-point scoring, upgrade-safe storage, selector-level controls, delayed settlement queues, and succinct proof verification. The result is a realistic Solidity-first architecture that can be integrated into existing lending, vault, and bridge-facing protocols on mainnet, Arbitrum, Base, and Optimism with minimal migration, while still leaving room for zkVM-backed threat inference, federated learning, and formal verification.

## Technical Assumptions

- Compiler target: Solidity `^0.8.35`, treated here as the latest stable 0.8.x line in April 2026.
- Upgradeability: OpenZeppelin UUPS proxy using ERC-1967 storage discipline.
- Morphogenesis implementation: modular libraries plus selector/module registries rather than a fully generic diamond proxy at MVP stage.
- Neuromorphic behavior: approximated with a bounded leaky-integrate-and-fire scoring engine, not a literal biological neuron model.
- Prediction horizon: 30-60 second pre-exploit detection requires off-chain mempool or sequencer observers whose outputs are submitted as zk-attested risk journals.
- Formal rollback: Ethereum cannot natively rewind already-finalized state; "partial rollback" is implemented as delayed finalization, queue cancellation, shadow routing, and reversible internal intents.

## Detailed Architecture Breakdown

### 1. Deployment & Initialization

#### Objective

Deploy a protected, upgradeable control plane that can wrap or gate sensitive protocol paths while keeping migration overhead low.

#### Contracts

- `PraetorianCore`: central coordinator behind a UUPS proxy.
- `CodexRomanum`: invariant and route policy registry.
- `InvariantChecker`: deterministic rule evaluator.
- `LegionSwarm`: bounded neuromorphic consensus engine.
- `SentinelInterceptor`: pre/post execution hook.
- `MorphingMechanism`: selector freezing, queueing, and shadow-vault routing.

#### Storage Layout

`PraetorianCore` uses a namespaced storage library:

- `address interceptor`
- `address swarm`
- `address morph`
- `address checker`
- `address codex`
- `uint32 reviewInterval`
- `uint64 lastReviewAt`
- `SecurityMode mode`
- `bool emergencyPause`
- `mapping(address => bool) protectedExecutor`
- `mapping(bytes32 => ThreatScore) threatByAction`
- `mapping(bytes32 => bool) actionConsumed`

`CodexRomanum` stores:

- `mapping(bytes32 => Invariant) invariants`
- `mapping(bytes32 => bool) knownInvariant`
- `bytes32[] invariantIds`
- `mapping(address => RouteConfig) routes`

#### Key Function Signatures

```solidity
function initialize(InitConfig calldata cfg) external initializer;
function setComponents(address interceptor, address swarm, address morph, address checker, address codex) external;
function setProtectedExecutor(address executor, bool allowed) external;
function beforeExecute(ActionContext calldata ctx, ProofEnvelope calldata proof, StateVector calldata preState)
    external
    returns (Verdict verdict, uint64 delayUntil);
function afterExecute(ActionContext calldata ctx, StateVector calldata postState) external;
```

#### Internal Logic

```solidity
beforeExecute(ctx, proof, preState):
    require(msg.sender is protectedExecutor)
    require(actionId unused)
    score = interceptor.preCheck(ctx, proof, preState)
    store score by actionId
    delayUntil = morph.applyVerdict(ctx, score)
    if score.verdict == Pause:
        pause core
        set mode = Quarantined
        revert
    emit ActionScreened
    return (score.verdict, delayUntil)
```

#### Gas Optimization

- Use namespaced storage to keep upgrade-safe layouts without copying structs between modules.
- Use packed scalar fields (`uint16`, `uint32`, `uint64`, `uint96`, `uint128`) where practical.
- Persist only action hashes and scores on-chain, not raw feature vectors.
- Keep `beforeExecute` bounded and avoid iterating over large dynamic sets.

#### Interactions

- Existing protocol adapters call `PraetorianCore.beforeExecute`.
- Core delegates scoring to `SentinelInterceptor`.
- Core delegates state shaping to `MorphingMechanism`.

#### Trade-offs

- Minimal migration comes from explicit hook integration, but that means non-integrated contracts receive no protection.
- UUPS keeps deployment lightweight, but governance around upgrades becomes highly sensitive and must itself be protected by Veil rules.

### 2. Real-Time Monitoring

#### Objective

Inspect each protected action in real time using deterministic state digests plus neuromorphic-style swarm scoring.

#### Storage Layout

`SentinelInterceptor` stores:

- `address core`
- `address checker`
- `address swarm`
- `address codex`
- `uint16 shadowThreshold`
- `uint16 pauseThreshold`

`LegionSwarm` stores:

- `address interceptor`
- `uint32 nodeCount`
- `uint16 leakBps`
- `uint16 maxConsensusBps`
- `bytes32 activeModelHash`
- `mapping(uint256 => NodeState) nodes`
- `mapping(bytes32 => uint16) lastConsensus`
- `mapping(bytes32 => uint16) predictedScoreByAction`
- `mapping(bytes32 => bytes32) predictedReasonByAction`
- `mapping(bytes32 => uint64) predictionValidUntil`

#### Key Function Signatures

```solidity
function preCheck(ActionContext calldata ctx, ProofEnvelope calldata proof, StateVector calldata preState)
    external
    returns (ThreatScore memory score);

function observe(ActionContext calldata ctx, bytes32 featureHash)
    external
    returns (uint16 consensusScore);

function submitPredictiveProof(bytes32 actionId, uint16 predictedScore, bytes32 threatClass, ProofEnvelope calldata proof)
    external;
```

#### Internal Logic

`SentinelInterceptor`:

1. Pull deterministic invariant risk from `InvariantChecker`.
2. Hash a compact feature vector from caller, target, asset, amount, liquidity, debt, and metadata.
3. Ask `LegionSwarm` to process the feature hash through bounded node updates.
4. Read any fresh predictive proof already submitted for the action.
5. Add route-specific risk from `CodexRomanum`.
6. Return a `ThreatScore` with verdict: `Allow`, `Shadow`, `Delay`, `Freeze`, or `Pause`.

`LegionSwarm.observe` uses a gas-bounded leaky-integrate-and-fire approximation:

```solidity
for each node in bounded nodeCount:
    if node.enabled and not refractory:
        stimulus = hash(featureHash, nodeId, classId) mod 10000
        membrane = membrane - leak + stimulus
        if membrane >= threshold:
            consensus += weight
            membrane = 0
            refractoryUntil = now + 12 seconds
            emit NodeSpiked
        else:
            store membrane
consensus = min(consensus, 10000)
store consensus by actionId
```

#### Neuromorphic / zk Approximation

- On-chain "neurons" are simple integer state machines with decay, threshold, and refractory windows.
- Off-chain nodes listen to swarm events, retrain models privately, and submit zk-attested predictions.
- Events act as the swarm's communication bus for off-chain agents, while on-chain communication remains storage-based because contracts cannot read logs.

#### Gas Optimization

- Node count is intentionally capped; on mainnet MVP target should be 8-16 nodes, while L2 can tolerate 16-32.
- Feature vectors are hashed once, then reused across nodes.
- Node state uses tightly packed fields.
- Fixed-point math uses basis points and integer decay to avoid expensive divisions.

#### Trade-offs

- Mainnet gets stronger guarantees from scarcity and conservative bounds, but cannot afford large on-chain swarms.
- L2s support richer node counts and more frequent senate reviews, but depend on sequencer behavior and faster finality assumptions.

### 3. Detection & Prediction

#### Objective

Predict exploit trajectories before irreversible asset release.

#### Mechanism

- `Predictive Weave` is implemented as zk-attested off-chain inference over:
  - recent protected actions
  - bridge message patterns
  - admin key activity
  - abnormal liquidity deltas
  - oracle freshness drift
- `LegionSwarm.submitPredictiveProof` stores:
  - `predictedScore`
  - `threatClass`
  - `validUntil`
  - a proof envelope referencing the zkVM image and journal hash

#### Practical zk Flow

1. Off-chain watchers ingest mempool, sequencer feed, and recent logs.
2. A federated training node computes a risk journal locally.
3. A zkVM guest (RISC Zero or SP1) proves:
   - model hash
   - features hash
   - risk class
   - predicted score
4. The proof is submitted before or alongside the protected action.
5. `SentinelInterceptor` combines deterministic and predictive risk.

#### Solidity Limitations and Realistic Approximation

- Solidity cannot train a model or verify large ML traces economically.
- Prediction therefore means proof verification plus bounded risk ingestion, not raw model execution on-chain.
- The 30-60 second window is realistic for queued bridge mints, admin actions, high-value withdrawals, and governance operations, but not for every retail transfer.

#### Trade-offs

- Prediction improves pre-emption but introduces latency, prover availability assumptions, and proof-verifier costs.
- On L2, short proof windows are more usable because fees are low and cadence is faster.

### 4. Adaptation & Morphogenesis

#### Objective

Reconfigure the protected protocol in response to threat severity without requiring blanket shutdown.

#### Storage Layout

`MorphingMechanism` stores:

- `mapping(bytes4 => ModuleConfig) moduleBySelector`
- `mapping(address => address) shadowVaultOf`
- `mapping(bytes32 => QueueIntent) intents`
- `mapping(uint8 => bytes4) selectorForAction`
- `mapping(bytes4 => bool) frozenSelector`

#### Key Function Signatures

```solidity
function applyVerdict(ActionContext calldata ctx, ThreatScore calldata score)
    external
    returns (uint64 delayUntil);
function setModule(bytes4 selector, ModuleConfig calldata config) external;
function setShadowVault(address asset, address shadowVault) external;
function releaseIntent(bytes32 actionId) external;
```

#### Internal Logic

- `Allow`: execute immediately.
- `Shadow`: queue the intent for about 45 seconds and optionally reroute asset flows to a shadow vault.
- `Delay`: queue for a longer window such as 5 minutes.
- `Freeze`: freeze the selector mapped to the action type.
- `Pause`: let core enter global quarantine mode.

The morphogenic model is selector-centric instead of monolithic. That is crucial because most DeFi exploits target one path, not every function at once. Freezing `bridgeMint()` or `setOracle()` is far safer than pausing deposits, repayments, and liquidations protocol-wide.

#### Formal Proof Angle

Morphing operations should be gated by invariants that can be expressed in Certora:

- frozen selectors must remain non-executable
- shadow intents cannot be released before `executableAt`
- pause mode must imply no new `beforeExecute` approvals
- protected executors cannot bypass the hook

#### Gas Optimization

- Queue only hashes and compact metadata on-chain.
- Avoid full function router rewrites; use selector freeze maps and adapter routing.
- Use shadow vaults only for high-value or bridge-related assets.

#### Trade-offs

- Selector-level control is safer and cheaper than generic module hot-swapping.
- Full dynamic execution re-routing is possible but increases complexity and audit surface.

### 5. Response & Recovery

#### Objective

Contain damage, preserve evidence, and recover gracefully.

#### Circuit Imperator

`PraetorianCore.guardianPause(bytes32 reason)` and verdict-triggered pause create a layered halt mechanism:

- local freeze for a risky function
- quarantine mode for a subsystem
- recovery mode when post-state invariants fail

#### Partial Rollback Reality

Praetorian Veil cannot reverse finalized L1 state. Instead it implements:

- delayed execution queues
- queue cancellation before release
- quarantined assets in `ShadowVault`
- staged settlement for high-risk actions

That gives rollback-like behavior where it matters most: before funds become unrecoverable.

### 6. Continuous Evolution

#### Objective

Periodically update node sensitivity and defense posture through internal "Senate Review".

#### Mechanism

- `PraetorianCore.triggerSenateReview()` timestamps a review epoch.
- `LegionSwarm.senateReview()` nudges thresholds and updates `activeModelHash`.
- Off-chain training nodes publish new zkVM images for later proofs.

#### Review Policy

- Mainnet: every 6-12 hours for highly exposed bridge and admin routes.
- L2: every 1-4 hours due to lower proof and calibration costs.

#### Trade-offs

- Faster review means better adaptation but more governance and model churn.
- Slower review reduces operational burden but risks stale defenses.

## High-Level Solidity Skeleton Code

The repository includes realistic skeleton contracts here:

- [`src/PraetorianCore.sol`](../src/PraetorianCore.sol)
- [`src/SentinelInterceptor.sol`](../src/SentinelInterceptor.sol)
- [`src/LegionSwarm.sol`](../src/LegionSwarm.sol)
- [`src/MorphingMechanism.sol`](../src/MorphingMechanism.sol)
- [`src/InvariantChecker.sol`](../src/InvariantChecker.sol)
- [`src/CodexRomanum.sol`](../src/CodexRomanum.sol)
- [`src/examples/VeiledLendingHook.sol`](../src/examples/VeiledLendingHook.sol)

### Architecture Notes About the Skeleton

- The code is intentionally integration-first. Existing protocols call a hook before sensitive actions rather than being rewritten into a completely new proxy stack.
- The swarm is cheap enough to be credible on-chain because it stores only tiny bounded node states.
- zk verification is stubbed as an explicit extension point. Production deployments should wire RISC Zero or SP1 verifier contracts into `submitPredictiveProof`.
- Storage is modular and upgrade-safe, so future releases can swap implementations without breaking layout.

## Implementation Roadmap

### Phase 0: Week 1-2

#### Goal

Convert the concept into a buildable solo-developer repository.

#### Deliverables

- Foundry workspace
- UUPS `PraetorianCore`
- `CodexRomanum` and `InvariantChecker`
- one protected adapter such as `VeiledLendingHook`
- Slither baseline

#### Estimated Gas

- `beforeExecute` with rule-only scoring: `25k-55k`
- `afterExecute`: `12k-28k`
- queueing intent: additional `20k-35k`

### Phase 1: Month 1-2

#### Goal

Ship MVP with rule-based sentinel in pure Solidity.

#### Deliverables

- production-grade access control
- timelocked governance
- action queues
- selector freeze map
- shadow vault for 1-2 assets
- Foundry fuzz tests
- Certora invariants for pause, queue, and authorization

#### Tooling

- Foundry
- OpenZeppelin Contracts v5.x
- Slither
- Tenderly
- Certora

#### Estimated Gas

- `beforeExecute`: `45k-90k`
- `Delay` or `Shadow` path: `70k-130k`

### Phase 2: Month 3-6

#### Goal

Introduce bounded on-chain swarm behavior and prediction ingestion.

#### Deliverables

- `LegionSwarm.observe`
- event schema for off-chain risk agents
- low-node-count consensus on L1
- higher-node-count deployment on Arbitrum/Base/Optimism
- replay simulation against historical exploit traces

#### Estimated Gas

- rule + swarm on L1 with 8 nodes: `80k-160k`
- rule + swarm on L2 with 16 nodes: `90k-180k`

### Phase 3: Month 6-12

#### Goal

Wire in zkVM-based predictive proofs and federated learning journals.

#### Deliverables

- Rust guest program for RISC Zero or SP1
- proof-verifier contract
- proof relayer
- model hash rotation policy
- zk-attested action score injection

#### Estimated Gas

- proof submission: highly verifier-dependent, target `250k-700k`
- normal protected action with pre-submitted proof: `90k-180k`

### Phase 4: Month 12-24

#### Goal

Expand into a cross-L2 immune mesh with richer morphogenesis.

#### Deliverables

- standardized bridge route registry
- per-L2 security profiles
- oracle-specific adapters
- decentralized insurance trigger integration
- protocol family templates for lending, vaults, bridges, and restaking

## Threat Model & Simulation

### Case A: Kelp DAO-style Bridge Spoofing

#### Attack Shape

An attacker forges or replays a cross-chain message that appears to authorize asset release or synthetic minting on Ethereum.

#### Example Flow

1. Attacker calls a bridge-facing adapter with a forged message payload.
2. Adapter constructs `ActionContext` with `actionType = BridgeMint`.
3. `beforeExecute` triggers:
   - `CodexRomanum` route policy checks canonical sender and proof freshness.
   - `InvariantChecker` sees message freshness or notional limits violated.
   - `LegionSwarm` spikes because the feature hash resembles historical bridge spoof classes.
   - `Predictive Weave` may already have submitted a high-risk proof from mempool observation.
4. `SentinelInterceptor` returns `Pause` or `Freeze`.
5. `MorphingMechanism` freezes the bridge selector or queues the mint into shadow mode.
6. No assets are released to the attacker; if funds were staged, they remain in a shadow vault.

#### Why This Helps

- Canonical route policy blocks trust in arbitrary relayers.
- Proof freshness windows make delayed or replayed messages suspicious.
- Selector-level isolation avoids shutting down the whole protocol.

### Case B: Drift-style Social Engineering / Admin Key Compromise

#### Attack Shape

An attacker compromises an operator or admin key and submits a validly signed but malicious privileged call.

#### Example Flow

1. Compromised admin attempts `setOracle`, `upgradeTo`, `sweepFunds`, or collateral-factor mutation.
2. Adapter or governance executor calls `beforeExecute` with `actionType = AdminCall` or `Governance`.
3. `InvariantChecker` observes admin nonce drift, withdrawal bounds, or sudden parameter deltas.
4. `LegionSwarm` spikes because the action is out-of-profile for the current epoch.
5. `Predictive Weave` boosts risk if the compromised key has abnormal timing, target, or routing patterns.
6. Verdict becomes `Pause` for privileged paths.
7. Core enters quarantine mode, guardian reviews, and only a timelocked recovery path can resume operations.

#### Why This Helps

- A valid signature is not enough if behavior violates Codex constraints.
- High-risk admin calls become staged or blocked before state mutation.
- The system degrades safely to human review rather than instant loss.

## Challenges & Mitigation

### Gas Optimization in Solidity

- Keep node count low on L1 and higher on L2.
- Hash compact feature vectors instead of storing raw data.
- Pack storage aggressively and use `unchecked` increments inside bounded loops.
- Prefer basis points and integer decay over high-precision fixed-point libraries.
- Route only high-risk flows through shadow queues; do not wrap every low-value transfer.

### False Positives

- Use tiered responses: `Allow`, `Shadow`, `Delay`, `Freeze`, `Pause`.
- Apply stricter thresholds to bridge and admin flows than to deposits and repayments.
- Let users re-execute delayed intents after a short confidence window.
- Use L2s for richer model calibration before tightening mainnet thresholds.

### Governance

- Use a multisig plus timelock for `SENATE_ROLE`.
- Give `GUARDIAN_ROLE` pause-only power, not arbitrary upgrade power.
- Keep `UPGRADER_ROLE` separate and timelocked.
- Protect governance executors with Praetorian Veil itself.

### Quantum Resistance

- Solidity cannot natively make Ethereum post-quantum, but Veil can prepare for hybrid authorization:
  - require multisig plus a lattice-based signature attestation verified by an external precompile or verifier contract once available
  - use PQ signatures first for off-chain prover attestations and operator workflows
  - keep recovery committees able to rotate keys rapidly

### Avoiding a New Single Point of Failure

- Split roles across core, senate, guardian, and prover.
- Keep morphing decisions selector-scoped whenever possible.
- Let protocols choose fail-open for low-risk actions and fail-closed for privileged routes.
- Make every critical module individually upgradeable and formally specified.

## Next Steps & Improvement Ideas

### MVP in the First 1-2 Months

1. Finalize action taxonomy for one protocol archetype first, ideally lending or vaults.
2. Implement and test pure-Solidity invariant scoring with no zk dependencies.
3. Add queueing plus selector freeze for borrow, withdraw, bridge mint, and admin paths.
4. Build Foundry fuzz tests around invariant preservation and bypass attempts.
5. Simulate historical exploit traces in Tenderly and Anvil forks.

### Advanced Extensions

- Hardware neuromorphic co-processors can eventually generate risk journals for zk attestation, but the chain-facing contract should still consume only proofs and compact scores.
- Auto-claim decentralized insurance can trigger when a recovery event is finalized and proofs of incident scope are published.
- Cross-L2 support can standardize risk journals so Arbitrum, Base, and Optimism deployments share threat intelligence without sharing raw user data.
- Oracle-specific morphing can temporarily widen heartbeat requirements, switch to median-of-medians feeds, or quarantine only one asset market.

## Solo Developer Build Kit

### Hardware & Environment

- 16 GB RAM minimum, 32 GB preferred for proving, fuzzing, and large builds
- Git and GitHub account
- hardware wallet before any real deployment

### Core Tools

- Foundry as the primary framework
- Node.js 20+
- Hardhat only if you want JS orchestration scripts
- VS Code with Solidity, Foundry, and Error Lens extensions

### Libraries and Security Stack

- OpenZeppelin Contracts and Contracts Upgradeable
- Slither
- Certora
- Tenderly
- RISC Zero or SP1

### Knowledge Priorities

1. ERC-1967 and UUPS storage discipline
2. selector-based protocol adapters
3. EIP-2535 concepts, even if the MVP stays library-modular
4. zkVM guest programming in Rust
5. threat replay from real bridge and admin incidents

## Recommended Immediate Build Sequence

1. Install Foundry and OpenZeppelin dependencies.
2. Turn the current skeleton into a compiling Foundry repo.
3. Add one full happy-path integration and one blocked-path integration test.
4. Write Certora invariants for queue release, selector freeze, and protected executor gating.
5. Fork Ethereum or Base in Anvil and replay a simplified bridge-spoof scenario.
