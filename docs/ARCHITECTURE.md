# Volt Architecture (iOS 17+ SwiftUI)

## 1) Purpose and audience

This document is the engineering deep-dive for Volt’s architecture. It is intended for contributors who need to understand runtime behavior, data ownership, and cross-feature flow before changing implementation code.

Use this alongside the root `README.md`:
- `README.md` is the concise entry point.
- This document explains architectural internals and invariants.

---

## 2) System overview

Volt is a SwiftUI crypto trading **simulation** app:

- Market data is seeded from Twelve Data (`quote`) when enabled.
- Asset detail candles come from Twelve Data `time_series` when enabled.
- Order execution is always local via `DefaultTradingSimulationService` + `InMemoryPortfolioRepository`.
- A single shared quote stream drives watchlist, asset detail, and portfolio valuation.
- Local persistence stores portfolio state, market cache, checkpoints, and preferences.
- Analytics and “AI-style” insights are generated from local persisted/runtime state.
- Deterministic demo scenarios can replace state for reproducible demos.
- Offline fallback exists for both quote seeding and candles.

This app is not a broker client and does not submit real orders.

---

## 3) Architectural principles

The implementation enforces these rules:

1. **Single quote-driven valuation path**
   - `DefaultMarketDataRepository` is the canonical quote publisher.
   - `InMemoryPortfolioRepository` subscribes to that stream and recomputes valuation centrally.

2. **Provider data is seed/input, not execution**
   - Twelve Data provides initial quotes and historical candles.
   - Trade fills are local and deterministic relative to current quote + slippage config.

3. **No business logic in SwiftUI views**
   - Views render state and invoke view-model actions.
   - Validation/execution/filtering/calculation live in view models/services/repositories.

4. **Repository/service owns state transitions**
   - Portfolio/order/activity mutations happen in repository/service layer.
   - Analytics are derived from repository and checkpoint streams.

5. **Deterministic, testable behavior is preferred**
   - Runtime profiles map to explicit environment + risk defaults.
   - Demo scenarios inject fixed persisted portfolio snapshots.

6. **Runtime switches should not duplicate pipelines**
   - Market startup/reseed pipelines are serialized via actor state.
   - Simulation engine guards against duplicate tick loop tasks.

7. **Persistence and migration are explicit**
   - Preferences schema + legacy decode path are explicit.
   - Portfolio persistence supports envelope + legacy payload decode fallback.

8. **Analytics/insights must be local-state grounded**
   - Analytics derive from orders/activity/realized/checkpoints.
   - Insight service is rule/template-based, no remote LLM dependency.

---

## 4) Module and folder structure

### Repository structure (top-level)

```text
.
├─ Volt/                    # App source
│  ├─ App/                  # lifecycle + root tab/navigation
│  ├─ Core/                 # DI, env/config, preferences, logging, utilities
│  ├─ Domain/               # models + protocols
│  ├─ Data/                 # providers, repositories, persistence, insights
│  ├─ Features/             # SwiftUI screens + view models
│  └─ Assets.xcassets/
├─ VoltTests/               # unit/integration-style tests
├─ VoltUITests/             # UI tests
├─ docs/                    # architecture and longer docs
├─ README.md
└─ Volt.xcodeproj/
```

### Responsibility map

- **App/**
  - Bootstraps lifecycle (`VoltApp`), tab shell (`RootTabView`), and scene-phase handling (`AppLifecycleCoordinator`).

- **Core/**
  - Dependency graph (`AppContainer`).
  - Process-env runtime config (`AppConfiguration`).
  - Environment abstraction (`EnvironmentProviding`).
  - Preferences storage (`UserDefaultsAppPreferencesStore`).

- **Domain/**
  - Protocols for repository/services.
  - Data models for orders, positions, quotes, checkpoints, analytics, runtime profiles.

- **Data/**
  - Provider adapters (Twelve Data + mock + switchable facade).
  - Simulation engine and market repository.
  - Portfolio/trading/analytics/checkpoint services.
  - Persistence stores and CSV export.
  - Local insight generator.

- **Features/**
  - Feature-oriented view + view-model pairs:
    watchlist, asset detail, trade ticket, portfolio, orders/history, analytics, onboarding, settings, close position.

- **VoltTests/**
  - DTO/mapper tests, repository behavior tests, lifecycle/profile tests, persistence migration tests, feature VM tests.

- **VoltUITests/**
  - Onboarding, settings/profile, deterministic scenario selection, large Dynamic Type navigation.

- **docs/**
  - Engineering documentation (this file).

---

## 5) Core runtime model

### Runtime concepts

- **Environment (`TradingEnvironment`)**
  - `.mock`
  - `.twelveDataSeededSimulation`

- **Runtime profile (`RuntimeProfile`)**
  - `conservative`, `balanced`, `aggressive`
  - Encodes environment + simulator defaults (slippage/volatility/etc.).

- **Simulator controls (`SimulatorRiskPreferences`)**
  - Order sizing mode/default size, risk-warning threshold, slippage preset, volatility preset, confirmation mode.

- **Market seeding mode (`MarketDataMode`)**
  - Live seeded, offline cached fallback, offline deterministic fallback.

- **Deterministic scenarios (`DemoScenario`)**
  - Fixed `PersistedPortfolioState` snapshots (empty, balanced, analytics-rich).

### Ownership and interaction

- `AppContainer.bootstrap()` wires all dependencies and restores preferences.
- `AppLifecycleCoordinator.onLaunch()` starts market seeding + first checkpoint.
- Preferences changes drive environment/profile updates; profile switch triggers refresh/reseed orchestration.
- Scenario apply/reset mutates portfolio persistence-backed state and triggers market refresh.

---

## 6) End-to-end data flow

### A) App launch / restore

```text
VoltApp.task
  -> AppLifecycleCoordinator.onLaunch()
    -> MarketDataRepository.start()
      -> seed pipeline (provider -> quotes)
      -> simulation start/reseed
    -> checkpoint(appLaunch)
```

Additionally on launch:
- `AppContainer` restores preferences/environment.
- `InMemoryPortfolioRepository` restores persisted portfolio state if present.
- `DefaultAccountSnapshotCheckpointService` restores checkpoint history if present.
- `RootTabView` restores selected tab and analytics/history filters from UI state store.

### B) Initial seed and simulation start

1. `DefaultMarketDataRepository.runSeedPipeline(...)` serializes seed operations via `StartupState` actor.
2. Seed provider selected by current preferences environment.
3. On success:
   - quotes published to `quotesSubject`
   - cache written (`market_cache.json`)
   - simulation engine `start` or `reseed`
   - data mode = live seeded
4. On failure:
   - fallback to cached quotes if available, else deterministic synthetic quotes
   - fallback quotes cached
   - simulation still starts/reseeds
   - data mode = offline cached or offline deterministic

### C) Quote propagation

- Simulation tick updates flow through `ticksPublisher`.
- Market repo merges ticks into current quotes and republishes full quote list.
- Consumers:
  - Watchlist rows
  - Asset detail latest quote
  - Portfolio repository valuation recompute

### D) Watchlist updates

- `WatchlistViewModel` maps quote stream to row state and exposes connection/seeding/data mode badges.
- Pull-to-refresh triggers `manualRefresh()` -> forced reseed pipeline.

### E) Asset detail / chart loading

- On first `onAppear`, `AssetDetailViewModel` subscribes to symbol quote stream and position stream.
- Candle task requests recent candles from repository.
- Repository uses historical provider; on failure, returns cached candles if available.
- On disappear, cancellables/tasks are cancelled to avoid duplicate subscriptions.

### F) Order execution / position mutation

1. Trade ticket validates quantity/cash/quote context.
2. `DefaultTradingSimulationService.placeOrder` validates symbol/quantity/position.
3. Execution price = quote ± slippage preset basis points.
4. Repository applies buy/sell mutation:
   - updates positions
   - appends order history + activity events
   - appends realized P&L entries for sell reductions/closes
   - persists full state snapshot
5. Trading service triggers checkpoint(`orderExecution`).

### G) Portfolio revaluation

- Every quote update triggers repository recalculation:
  - per-position mark price + unrealized P&L
  - aggregate market value/equity/realized/unrealized
- `PortfolioViewModel` and analytics service consume summary updates.

### H) History / analytics / checkpoints

- Analytics service subscribes to order/activity/realized/summary publishers.
- Structural recomputes happen on compute queue when history streams change.
- Summary-driven updates happen when only live summary changes.
- Performance points prefer checkpoint history (filtered by active environment) and fallback to realized activity timeline when checkpoints absent.

### I) Persistence writes

- Portfolio state persisted atomically on each trade mutation/replacement.
- Checkpoints persisted asynchronously on dedicated queue.
- Market quotes/candles cached in app support.
- Preferences/UI restoration persisted in `UserDefaults`.

### J) Offline fallback path

- Seed failure -> use cached quotes or deterministic fallback quotes.
- Candle fetch failure -> return cached candles when available.
- Simulation remains active to keep UI responsive.

### K) Runtime profile switch flow

```text
Settings -> preferencesStore.selectRuntimeProfile
  -> preferencesPublisher update
    -> AppContainer.bindRuntimeProfileChanges
      -> environmentProvider.updateEnvironment
      -> lifecycleCoordinator.applyRuntimeProfileSwitch
        -> marketDataRepository.manualRefresh()
        -> checkpoint(manualRefresh)
```

### L) Deterministic scenario application flow

```text
Settings scenario picker
  -> DefaultDemoScenarioBootstrapService.applyScenario
    -> portfolioRepository.replaceState(scenario.state)
    -> preferences.selectedEnvironment = .mock
    -> preferences.activeDemoScenarioID = scenario.id
    -> marketDataRepository.manualRefresh()
```

---

## 7) Market data architecture

### Twelve Data role

- `TwelveDataMarketSeedProvider`: fetches per-symbol quotes for startup/reseed.
- `TwelveDataHistoricalDataProvider`: fetches 1-minute candles for asset detail.
- `TwelveDataMapper` maps DTOs into domain `Quote`/`Candle`.

### Why seeded simulation exists

The app needs realistic initial prices without depending on a continuous streaming broker feed. Seeding provides plausible market anchors; simulation provides continuous local updates and deterministic demo behavior.

### Shared live quote state

- Canonical quote state lives in `DefaultMarketDataRepository` (`CurrentValueSubject<[Quote], Never>`).
- Tick stream from `DefaultMarketSimulationEngine` updates canonical quote array.
- No feature owns independent quote truth.

### Offline/cached fallback

- Quote fallback order: cached quotes -> deterministic per-symbol defaults.
- Candle fallback: cached candles if network/provider fails.
- Market cache caps per-symbol candle retention (`maxCandlesPerSymbol`).

---

## 8) Trading simulation architecture

### Ticket to fill

- `TradeTicketViewModel` computes estimated fill using active slippage preset.
- Service validates quantity, symbol support, required position for sell, quote presence.
- Fill is applied immediately through portfolio repository.

### Position lifecycle

- **Buy**: open new position or increase existing with weighted average cost.
- **Sell**: partial reduce or full close existing position.
- Updates generate:
  - `OrderRecord`
  - `ActivityEvent` (`buy`, `partialClose`, `fullClose`)
  - `RealizedPnLEntry` on close/reduce.

### P&L model

- **Unrealized P&L** recomputed from current quote mark and average entry.
- **Realized P&L** produced when quantity is closed.
- Portfolio summary tracks cash + market value + realized + unrealized + equity.

### Determinism

- Execution is local only; no external matching/broker latency.
- Given the same quote sequence, slippage preset, and order sequence, results are reproducible.

---

## 9) Portfolio, analytics, and insight architecture

### Portfolio summary derivation

- `InMemoryPortfolioRepository` is the source of truth for:
  - open positions
  - order history
  - activity timeline
  - realized history
  - summary/equity

### Analytics service

- `DefaultPortfolioAnalyticsService` derives:
  - summary metrics (win rate, PF, net return, etc.)
  - performance points
  - daily buckets
  - realized distribution
  - filtered orders/activity
- Work is done on dedicated `DispatchQueue` (`com.volt.analytics.compute`).

### Checkpoints/snapshots

- `DefaultAccountSnapshotCheckpointService` writes environment-tagged equity snapshots.
- Triggers include launch/background/resume/manual refresh/order execution.
- Minimum interval throttles periodic/resume checkpointing.

### History drill-down

- `positionHistory(symbol:)` reconstructs symbol-focused order/activity + realized aggregates.

### Insight generation

- `LocalInsightSummaryService` creates textual cards/recaps from local state and runtime context.
- No remote model calls.

### Export

- `DefaultCSVExportService` exports history and analytics summary CSVs to temp output directory.

### Profile/environment isolation

- Performance series uses checkpoint filtering by active environment when environment provider is available.

---

## 10) Persistence and migration architecture

### What is stored

- Portfolio: positions, orders, activity, realized history, cash.
- Market cache: quotes + candles map.
- Checkpoints: account snapshots over time with trigger/env.
- Preferences: onboarding, profile, environment, simulator controls, scenario selection.
- UI restoration: selected tab + selected analytics/history ranges.

### Storage location

- File-backed stores: `Application Support/Volt/*.json`.
- Preferences + UI restoration: `UserDefaults` keys (`volt.app_preferences`, `volt.ui_restoration`).

### Repository/store interactions

- Portfolio repository reads once at init and writes atomically on mutation.
- Market repository reads cache at init and updates cache on seed/candle success/fallback.
- Checkpoint service reads at init and writes asynchronously on checkpoint.

### Migration/versioning

- Preferences schema has explicit version (`AppPreferences.schemaVersion = 2`) and legacy decode path.
- Portfolio persistence supports legacy non-envelope decode and envelope with `version` field.

### Corruption/failure behavior

- Preferences decode failure clears stored payload and falls back to defaults.
- Portfolio decode failure throws; repository catches and recovers with default empty state.
- Checkpoint decode failure logs and continues with empty checkpoint set.

---

## 11) Concurrency model and lifecycle

### Serialization and deduplication

- Startup/reseed serialization: `DefaultMarketDataRepository.StartupState` actor.
- Duplicate seed requests await active pipeline rather than starting another.
- Tick loop dedupe: `DefaultMarketSimulationEngine` keeps a single `tickTask` guarded by lock.

### Actor/MainActor boundaries

- `AppContainer`, `AppLifecycleCoordinator`, and most feature view models are `@MainActor`.
- Market repo uses actor + Combine subjects (not `@MainActor`).
- Analytics heavy recompute runs off-main on utility queue.

### Combine + async/await

- Async/await used for seeding, candle fetch, lifecycle tasks.
- Combine used for long-lived quote/summary/history streams and view-model bindings.

### Cancellation/lifetime

- Asset detail cancels quote/position subscriptions + candle task on disappear.
- Simulation tick task cancels on `stop` and deinit.
- View models rely on cancellable sets tied to object lifetime.

### Scene phase and screen re-entry

- `VoltApp` forwards scene-phase changes to lifecycle coordinator.
- Foreground resume may trigger reseed only after stale interval.
- Asset detail guards duplicate setup with `hasStarted`.
- Root tab creates shared tab dependencies once per appearance cycle to avoid repeated VM instantiation.

---

## 12) Performance and memory model

### Hot paths

- Quote propagation: tick burst -> quote array update -> downstream UI/repo consumers.
- Portfolio recompute: O(openPositions) per quote update.
- Analytics structural recompute: grouping/sorting of orders/activity/realized on history mutation.

### Chart and history operations

- Candle fetch sorted and cached; chart uses bounded candle series.
- History filters apply in-memory predicate checks by time range/symbol/event kind.

### Insight generation

- Local string-template logic; negligible overhead relative to analytics recompute.

### Ownership/lifetime

- `AppContainer` owns singleton-like repositories/services for app session.
- Feature VMs subscribe to shared services; no duplicate repositories created per screen.
- Market cache and checkpoints are file-backed; memory state retains latest in-process arrays.

### Cache bounds and trade-offs

- Candle cache is bounded per symbol (`maxCandlesPerSymbol`).
- Checkpoints capped (`maxCheckpointCount`, default 2,000).
- Acceptable trade-off: several analytics operations are full-array recomputes, suitable for demo-scale datasets.

---

## 13) UI architecture

- **Watchlist**
  - Reads canonical quote list and market mode/state badges.
  - Pull-to-refresh triggers reseed.

- **Asset detail**
  - Subscribes to a single symbol quote stream + open position stream.
  - Fetches recent candles once per appear cycle with explicit loading/error states.

- **Trade ticket**
  - Validates quantity/quote/cash and previews slippage-adjusted fill.
  - Executes through trading simulation service only.

- **Portfolio**
  - Renders summary + positions from repository publishers.
  - Uses local insight cards when enabled in preferences.

- **History (Orders/Activity)**
  - Uses analytics filters + export service for CSV output.

- **Analytics**
  - Binds to derived publishers (performance/buckets/distribution/summary).

- **Onboarding**
  - Preference-gated full-screen flow from root tab.

- **Settings**
  - Controls runtime profile, simulator controls, onboarding reset, deterministic scenario selection.

---

## 14) Testing strategy

### Unit/integration focus

- Data DTO decode + mapping tests (Twelve Data).
- Market repository behavior: seeding, fallback, lifecycle behavior.
- Portfolio/persistence/migration compatibility tests.
- Analytics recompute and filtering tests.
- Runtime profile and preference migration tests.
- View model behavior tests (trade ticket, asset detail, close position, runtime profile flows).

### UI tests

- Onboarding completion/reset flows.
- Settings/profile/tab navigation.
- Deterministic scenario selection and watchlist data-mode visibility.
- Large Dynamic Type navigability check.

### Critical pre-merge coverage priorities

1. Quote seeding + fallback correctness.
2. Trade validation/fill/position/P&L math.
3. Persistence compatibility across schema evolution.
4. Runtime profile switch orchestration.
5. Deterministic scenario reproducibility.

---

## 15) Extension points / future work

Grounded in current abstractions:

- Add a true streaming provider implementing `MarketSeedProvider`/stream extension without changing feature layer contracts.
- Expand analytics with richer factor/risk metrics while reusing checkpoint + repository streams.
- Introduce optional remote insight provider behind current insight protocols.
- Expand export/reporting presets and destinations beyond temp CSV files.
- App Store hardening: stricter telemetry, privacy disclosures, and production-grade error/reporting surfaces.

---

## 16) Known limitations

- Simulated execution only; no broker integration.
- Seed provider is request/response bootstrap, not live exchange feed.
- Candle quality/coverage depends on provider availability and plan constraints.
- Local JSON persistence is demo-friendly, not transactional database-grade.
- Analytics quality depends on local retained history and checkpoints.
- Deterministic scenarios intentionally replace local state and force mock environment.

---

## 17) Contributor guidance (rules to preserve)

When modifying architecture, preserve these invariants:

1. Keep one shared quote-driven valuation model (`DefaultMarketDataRepository` -> `InMemoryPortfolioRepository`).
2. Do not introduce parallel/competing portfolio or quote sources.
3. Keep business logic out of SwiftUI `View` structs.
4. Do not create ad hoc per-screen background timers/market loops.
5. Keep runtime switching and demo scenarios deterministic and serialized.
6. Update tests + docs whenever behavior, persistence schema, or runtime contracts change.
