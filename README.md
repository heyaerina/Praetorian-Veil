# Praetorian Veil

Praetorian Veil is an adaptive DeFi security layer for Ethereum, built as Solidity-first middleware for mainnet and L2 environments such as Arbitrum, Base, and Optimism. The system is designed to protect high-risk protocol actions before losses cascade, using a combination of deterministic invariant enforcement, neuromorphic-inspired swarm scoring, morphing response controls, and upgradeable security orchestration.

## Case

DeFi in 2026 is no longer failing only because of simple reentrancy or arithmetic bugs. Modern incidents increasingly emerge from cross-chain message spoofing, compromised admin workflows, oracle drift, fake collateral paths, and operational failures that happen outside a single contract's audit boundary. Protocols need a protection layer that can sit between sensitive execution paths and real capital, especially for bridge-facing, governance-facing, and high-value state transitions.

Praetorian Veil is designed for that case. Instead of acting like a static guardrail, it acts like a protocol immune system: inspect, score, isolate, delay, freeze, and recover. The goal is not just to pause everything after damage is visible, but to identify suspicious execution patterns early enough to reduce blast radius in the final seconds before an exploit becomes irreversible.

## Problem

Most DeFi security stacks still rely on some combination of:

- one-time audits and point-in-time assumptions
- privileged multisigs or admin keys as the final line of defense
- manual incident response after anomalous transactions are already in flight
- coarse-grained circuit breakers that freeze an entire protocol instead of isolating one dangerous path
- fragmented tooling across monitoring, formal verification, simulation, and runtime controls

That model breaks down when the exploit path is operational, cross-domain, or socially engineered. A valid signature can still be malicious. A verified bridge packet can still be fraudulent. A healthy-looking protocol can still be one transaction away from a systemic loss event.

## Solution

Praetorian Veil introduces a modular runtime defense architecture with four core ideas:

- `PraetorianCore`: a UUPS-upgradeable control plane that coordinates policy, detection, and response.
- `Codex Romanum`: a storage-backed registry of mathematical and protocol-specific invariants.
- `Legion Swarm`: a gas-bounded, neuromorphic-inspired scoring layer that approximates leaky integrate-and-fire detection behavior on-chain.
- `MorphingMechanism`: selector-level adaptation that can delay, shadow-route, quarantine, freeze, or pause only the paths that become unsafe.

The design intentionally uses realistic Ethereum primitives instead of science-fiction abstractions. True spiking neural networks and full zkML execution are not practical directly inside Solidity, so Praetorian Veil approximates them with bounded state machines on-chain and leaves richer inference to zk-attested off-chain systems. This keeps the architecture credible for real deployment while preserving a path toward more advanced predictive security.

## What's Inside

- [`docs/PRAETORIAN_VEIL_ARCHITECTURE.md`](docs/PRAETORIAN_VEIL_ARCHITECTURE.md)
  Whitepaper-style architecture document covering system vision, detailed component design, threat model, roadmap, and solo-developer build plan.
- `src/`
  Solidity skeleton contracts for the core modules, including upgradeable orchestration, invariants, swarm scoring, and morphing controls.
- `src/examples/`
  Example integration hook showing how an existing lending-style protocol can route actions through Praetorian Veil before execution.
- `script/`
  Deployment skeleton for bootstrapping the initial system layout.
- `test/`
  Minimal Foundry test scaffold for the core contract setup.
- `certora/`
  Starting point for formal verification targets and invariant planning.
- `foundry.toml`
  Minimal Foundry configuration for building the MVP.

## Repository Structure

```text
.
|-- certora/
|-- docs/
|-- script/
|-- src/
|   |-- examples/
|   |-- interfaces/
|   `-- libraries/
|-- test/
|-- .env.example
|-- foundry.toml
`-- README.md
```

## Current Scope

This repository is currently a strong architectural and implementation foundation, not a production-ready deployed system. It includes:

- a detailed concept and threat model
- realistic Solidity skeletons for the main modules
- a UUPS-based upgrade path
- an example adapter pattern for existing protocols
- a formal verification starting point

It does not yet include:

- production-ready dependency installation
- full Foundry test coverage
- live zkVM verifier integration
- audited bridge adapters or oracle adapters
- finalized governance and recovery operations

## Design Assumptions

- Compiler target: Solidity `^0.8.35`
- Upgrade pattern: OpenZeppelin UUPS with ERC-1967 storage slots
- Runtime detection: bounded on-chain scoring, not full neural execution
- Prediction model: zk-attested off-chain inference submitted through proof envelopes
- Integration style: explicit adapter or hook-based protection for sensitive protocol paths

## Vision

Praetorian Veil is meant to evolve into a reusable security substrate for modern DeFi protocols, especially those exposed to bridges, restaking, governance, leverage, and oracle-sensitive capital flows. The long-term direction is a system that behaves less like a static firewall and more like an adaptive immune layer for on-chain finance.
