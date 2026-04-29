# Praetorian Veil Certora Targets

## Priority Invariants

1. If `PraetorianCore` is paused, `beforeExecute` must not return `Allow`.
2. Only addresses in `protectedExecutor` may call `beforeExecute` and `afterExecute`.
3. A queued intent in `MorphingMechanism` cannot be released before `executableAt`.
4. Once a selector is frozen, integrations must not treat that path as executable.
5. `actionConsumed[actionId]` must prevent duplicate approval of the same action.
6. `guardianPause` must always move the system into a non-normal security mode.
7. `submitPredictiveProof` must reject stale proofs.

## Suggested Rule Families

- Authorization rules for `SENATE_ROLE`, `GUARDIAN_ROLE`, `UPGRADER_ROLE`, and `CORE_ROLE`
- Safety rules around queue release windows
- Consistency rules for `currentMode`, `paused()`, and verdict transitions
- No-bypass rules ensuring protected adapters cannot skip the Veil hook

## Suggested Verification Order

1. `PraetorianCore` authorization and pause behavior
2. `MorphingMechanism` queue and freeze semantics
3. `LegionSwarm` proof freshness and bounded consensus behavior
4. adapter-specific rules for protected borrow, withdraw, and bridge flows
