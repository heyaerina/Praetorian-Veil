# Praetorian Veil

Adaptive DeFi security middleware for Ethereum mainnet and L2s, designed around a UUPS-upgradeable core, a neuromorphic-inspired sentinel swarm, deterministic invariant enforcement, and morphing response modules.

## What is in this workspace

- [`docs/PRAETORIAN_VEIL_ARCHITECTURE.md`](docs/PRAETORIAN_VEIL_ARCHITECTURE.md) contains the whitepaper-style architecture, threat model, roadmap, and solo developer setup.
- `src/` contains Solidity skeletons for the core contracts and an example lending integration hook.
- `foundry.toml` provides a minimal Foundry profile for building the MVP.

## Suggested next command sequence

```powershell
forge install OpenZeppelin/openzeppelin-contracts-upgradeable
forge install OpenZeppelin/openzeppelin-contracts
forge build
forge test
```

## Design assumptions

- Compiler target: Solidity `^0.8.35`.
- Upgrade pattern: OpenZeppelin UUPS with ERC-1967 storage slots.
- True spiking neural networks and 30-60 second prediction are approximated via bounded leaky-integrate-and-fire style scoring on-chain plus zk-attested off-chain inference.
- Existing protocols integrate through explicit hook calls or adapter wrappers; Ethereum does not offer a universal native pre-execution hook for arbitrary contracts.
