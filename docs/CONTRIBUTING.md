# Contributing to Volt

## 1. Purpose

This guide is for engineers contributing to Volt’s iOS 17+ SwiftUI codebase.

It exists to protect architectural invariants that make the simulator reliable: one quote-driven valuation path, local deterministic execution, migration-safe persistence, and reproducible runtime behavior.

In this repository, a good contribution is one that:

- preserves existing invariants and data-flow boundaries
- keeps behavior deterministic and testable
- avoids duplicate pipelines and hidden state
- ships with targeted tests and no regressions in lifecycle/concurrency behavior

Read this together with `README.md` and `docs/ARCHITECTURE.md`.

---

## 2. Before you start

Complete this checklist before changing code:

- Read `README.md` end-to-end.
- Read `docs/ARCHITECTURE.md` end-to-end.
- Run the app in Simulator and verify the core flows (watchlist, trade ticket, portfolio, settings).
- Run unit tests and UI tests.
- Understand runtime profiles (`conservative` / `balanced` / `aggressive`) and deterministic demo scenarios (`scenario.empty`, `scenario.balanced`, `scenario.analytics`).

---

## 3. Core architectural rules (NON-NEGOTIABLE)

### 3.1 Single source of truth for pricing

- `DefaultMarketDataRepository` is the canonical quote publisher.
- `InMemoryPortfolioRepository` must remain the canonical valuation owner.
- Do not duplicate valuation logic in feature modules.
- Watchlist, asset detail, portfolio, history, and analytics must continue to derive from the same quote-driven state.

### 3.2 No business logic in SwiftUI views

- `View` structs render state and forward user actions.
- ViewModels orchestrate flows and bind streams.
- Repositories/services own validation, mutation, and calculations.

### 3.3 No duplicate data pipelines

- No per-screen timers for market updates.
- No per-screen network calls for the same quote data.
- No parallel simulation engines or ad-hoc quote streams.

### 3.4 Determinism is mandatory

- Demo scenarios must remain reproducible.
- Given the same quote sequence + orders + slippage settings, results must match.
- Tests must not rely on timing races, real network timing, or non-deterministic random behavior.

### 3.5 Execution stays local

- Trading execution remains local simulation only.
- Provider layer (Twelve Data / mock) is data input only.
- Do not add broker APIs or “real trade” pathways.

### 3.6 Persistence must remain migration-safe

- Never break decode for existing persisted payloads.
- If structure changes, increment versioning and add migration/decode fallback.
- Keep corruption/failure fallback behavior explicit and safe.

### 3.7 Environment/runtime isolation

- Do not mix data across runtime environments or profiles.
- Checkpoint and analytics filtering by environment must continue to work.
- Deterministic scenario application must keep environment behavior isolated and explicit.

---

## 4. Concurrency and lifecycle rules

- Do not allow duplicate `start()` / `manualRefresh()` / seeding pipelines.
- Guard startup and reseed with in-flight serialization (existing `StartupState` pattern).
- Cancel owned tasks/subscriptions on:
  - runtime profile switch
  - deterministic scenario switch
  - screen disappear / lifecycle boundaries where applicable
- Prefer structured concurrency; avoid unowned detached tasks.
- Never block the main thread for network, persistence, analytics compute, or large transforms.
- Avoid unnecessary nested `MainActor` hops.
- Combine pipelines must be single-owned and cancellable; no duplicate subscriptions with the same effect.

Required correctness constraints:

- Preserve the previously fixed seed-race class of bug: concurrent launch/refresh calls must not create parallel seed pipelines or duplicate simulation starts.
- Preserve checkpoint ordering correctness: order-execution checkpoints must reflect post-mutation repository state, not stale pre-mutation values.

---

## 5. State and data flow guidelines

Think in layers:

- **Repositories/services:** authoritative state + mutation
- **ViewModels:** mapping, orchestration, user-intent handling
- **Views:** rendering and event forwarding only

Rules:

- No direct provider calls from UI or ViewModels when a repository abstraction exists.
- Do not shadow repository state with long-lived local copies unless there is an explicit invalidation contract.
- No ad-hoc caches without ownership, bounds, and invalidation rules.
- Avoid recomputing full datasets on each tick when incremental or derived updates are possible.

---

## 6. Performance guidelines

- No heavy work in SwiftUI `body`.
- No unguarded heavy work in `onAppear`.
- Avoid repeated sorting/filtering/grouping inside hot update paths.
- Do not recompute full analytics/history datasets on every quote tick.
- Use cached derived state or memoization where appropriate.
- Prepare chart data outside views; pass precomputed view-ready structures.
- File I/O and persistence writes must remain off the main thread.

---

## 7. Memory management rules

- Prevent retain cycles in closures and publishers.
- Use `[weak self]` where lifecycle ownership is not guaranteed.
- Ensure timers/tasks/subscriptions are released on lifecycle transitions.
- Do not allow unbounded in-memory growth of quote/history/checkpoint/candle collections.
- Do not duplicate large arrays across layers without reason.
- After profile/scenario switches, ensure stale pipelines are not still publishing into active state.

---

## 8. Adding a new feature

1. Define the feature contract first (inputs, outputs, invariants, failure modes).
2. Identify required changes by layer:
   - domain models/protocols
   - repository/service behavior
   - ViewModel/UI surface
3. Extend existing repositories/services when possible.
4. Do not create a parallel system that overlaps existing data flow.
5. Add tests:
   - unit tests for domain/repository/viewmodel behavior
   - UI tests when navigation or settings/onboarding behavior changes
6. Validate before PR:
   - deterministic behavior maintained
   - no duplicate pipelines
   - lifecycle cancellation verified
   - acceptable performance impact

---

## 9. Modifying existing features

When changing existing code, verify you do not break:

- shared quote-driven valuation
- persistence compatibility
- analytics derivation correctness

If you change data structures:

- add migration/version updates and tests

If you change execution logic:

- verify fill math, position transitions, and realized/unrealized P&L

If you change quote flow:

- verify watchlist, detail, portfolio, and analytics stay synchronized

---

## 10. Testing expectations

- Every non-trivial change must include unit tests.
- UI tests are required for navigation-flow and onboarding/settings behavior changes.
- Prefer deterministic scenario/profile-driven tests for reproducibility.
- Avoid flaky timing-based assertions; synchronize on explicit state transitions/events.
- Treat fallback-mode, migration, and lifecycle tests as regression-critical.

---

## 11. Code style and structure

- Keep files focused and cohesive.
- Use explicit, domain-accurate naming.
- Apply strong access control (`private`, `fileprivate`, `internal`) intentionally.
- No force unwraps in production paths.
- Avoid oversized ViewModels that accumulate unrelated responsibilities.
- Avoid “god” services; split by domain responsibility when growth demands it.

---

## 12. What NOT to do

Do not:

- add a second data source for canonical quotes/valuation
- duplicate simulation logic in another service or feature
- put business logic in SwiftUI views
- bypass repositories to mutate core state
- add async background work without lifecycle ownership/cancellation
- introduce global mutable state for core runtime flows
- weaken deterministic behavior or demo scenario reproducibility
- ignore measurable performance regressions in hot paths

---

## 13. Pull request checklist

- [ ] Follows architecture rules in this document and `docs/ARCHITECTURE.md`
- [ ] No duplicate pipelines introduced
- [ ] Deterministic behavior preserved
- [ ] No main-thread blocking work added
- [ ] Tests added/updated for behavior changes
- [ ] Existing tests pass locally
- [ ] No persistence or migration breakage introduced
- [ ] Performance impact reviewed (especially hot quote/update paths)

---

## 14. Issues and discussions

- Open a GitHub issue for bugs, regressions, and concrete improvement proposals.
- For architectural changes (new pipeline, storage contract change, execution model change), discuss design before implementation.
- For large changes, post a short design proposal first: problem, constraints, alternatives, chosen approach, migration/testing plan.
- If you are unsure whether a change affects invariants, treat it as an architecture discussion first.
