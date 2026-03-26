# Volt RC Demo (SwiftUI iOS Crypto Trading Simulator)

Volt is an iOS SwiftUI crypto trading **demo simulator** built for architecture demos, product walkthroughs, and engineering exercises. It is **not** a real brokerage client, does not connect to broker accounts, and never places live market orders. The app targets modern iOS (project currently configured for iOS 26.2 in Xcode project settings) and uses SwiftUI, Combine, async/await, and Swift Charts. Market quotes/candles can be seeded from Twelve Data, while order execution and portfolio state transitions are simulated locally on-device.

---

## 1) Product overview

### Purpose
Volt demonstrates a complete trading-product surface area (watchlist → detail chart → trade ticket → portfolio/history/analytics/settings) with deterministic behavior suitable for demos and tests.

### Why Twelve Data is used
Twelve Data is used only for:
- initial quote seeding (`/quote`) at startup/refresh
- historical candle seeding (`/time_series`) for detail charts

Execution logic (fills, positions, P&L, cash changes) remains local in `DefaultTradingSimulationService` + `InMemoryPortfolioRepository`.

### Seeded simulation model (high level)
1. App starts and requests seeded quotes for configured symbols.
2. A local simulation engine begins 1-second tick updates from those seed prices.
3. Portfolio valuation listens to the shared quote stream.
4. Trades are validated and filled locally (with configurable slippage).
5. Portfolio/history/analytics update from the same local state.

### What users can do
- Browse a crypto watchlist and refresh quotes
- Open asset detail and view 1-minute candle charts
- Submit buy/sell simulated market orders
- Track open positions, unrealized and realized P&L
- Review order/activity history with filtering and CSV export
- Review analytics charts and summary metrics
- Use onboarding, runtime profiles, simulator controls, and deterministic demo scenarios

### Who this repo is for
- iOS engineers onboarding into a feature-rich SwiftUI app
- architecture reviewers evaluating data flow and boundaries
- internal demo users/stakeholders validating scope and UX
- contributors extending simulation, analytics, and runtime controls safely

---

## 2) Core features

- **Watchlist**
  - Quote list for configured symbols
  - Pull-to-refresh / manual refresh
  - Data mode banner: live seeded vs offline cached vs offline deterministic

- **Asset detail + Swift Charts**
  - Quote header + live status
  - 1-minute candlestick chart (`CandlestickChartView`)
  - Candle fetch fallback to local cache

- **Trade ticket**
  - Buy/sell market order form
  - Estimated fill price including slippage preset
  - Risk warning thresholds and confirmation-mode messaging
  - Local trade recap text after fills

- **Simulated order execution**
  - Symbol validation, quantity validation, cash/position checks
  - Local slippage application
  - Fills mutate in-memory portfolio + persisted state

- **Portfolio + unrealized P&L**
  - Shared quote-driven mark-to-market valuation
  - Open positions and equity summary
  - Optional local “AI-style” insight cards

- **History / orders / realized P&L**
  - Orders and activity segments
  - Time/symbol/event filters
  - Symbol drill-down to position history

- **Analytics + export**
  - Equity curve, daily realized buckets, realized distribution
  - Summary metrics (win rate, PF, net return, etc.)
  - CSV export presets: order history, realized ledger, summary, full activity

- **Runtime profiles + simulator controls**
  - Conservative / Balanced / Aggressive runtime profiles
  - Environment switching (`mock` vs `twelveDataSeededSimulation`)
  - Slippage, volatility, warnings, default order sizing controls

- **Onboarding + settings**
  - Multi-step onboarding with profile + insights preferences
  - Settings for experience controls and deterministic scenarios

- **Offline fallback + deterministic scenarios**
  - Fallback to cached quotes when seeding fails
  - Deterministic quote fallback if cache is unavailable
  - Deterministic scenario bootstrap for demos and tests

---

## 3) Architecture overview

Volt follows a feature-oriented SwiftUI app architecture with explicit domain protocols and concrete data-layer implementations.

### High-level structure

```text
Volt/
  App/                    # RootTab, lifecycle orchestration, navigation routes
  Core/
    DI/                   # AppContainer dependency wiring
    Environment/          # runtime config, environment, supported assets
    Preferences/          # UserDefaults-backed app preferences
    Logging/ Utilities/
  Domain/
    Models/               # entities, enums, persisted state, analytics models
    Protocols/            # repositories/services contracts
  Data/
    Providers/
      TwelveData/         # quote + candle seed providers
      Mock/               # mock seed/historical providers
    Repositories/         # market/portfolio/trading/analytics/checkpoint services
    Persistence/          # file-backed state/cache/checkpoint/export stores
    Insights/             # local insight generation
    DTOs/ Mappers/
  Features/
    Watchlist/ AssetDetail/ TradeTicket/ ClosePosition/
    Portfolio/ Orders/ PositionHistory/ Analytics/
    Onboarding/ Settings/ Shared/ DesignSystem/
VoltTests/
VoltUITests/
```

### Separation of concerns
- **Domain**: models + protocols only (no UI details).
- **Data**: implementations for providers, repositories, simulation, persistence.
- **Features**: SwiftUI views and view models per screen.
- **Core/DI**: single bootstrap point (`AppContainer.bootstrap()`).

### Shared quote-driven valuation model
`InMemoryPortfolioRepository` subscribes to shared `quotesPublisher` and recalculates all open positions and portfolio summary whenever quotes change. This centralizes unrealized P&L logic and prevents each feature from inventing its own valuation.

### Twelve Data vs local execution engine
- Twelve Data providers seed input market data only.
- Local simulation engine (`DefaultMarketSimulationEngine`) drives ongoing ticks.
- Trading service (`DefaultTradingSimulationService`) validates and fills orders locally.

### Repository/service/view model interaction
1. View models subscribe to repository/service publishers.
2. User actions call view model intents.
3. View models delegate mutations to domain services.
4. Services update repositories.
5. Repositories publish updated state to all subscribers.

### Persistence location
Primary persisted artifacts are JSON files in app support under `.../Application Support/Volt/`:
- `portfolio_state.json`
- `market_cache.json`
- `account_snapshot_checkpoints.json`

Preferences and UI restoration use `UserDefaults` keys.

### Runtime profiles + deterministic scenarios
- Runtime profiles map to environment + simulator defaults.
- Scenario bootstrap swaps portfolio state to deterministic snapshots and marks scenario ID in preferences.

---

## 4) How data moves through the app

1. **Initial seed flow**
   - `VoltApp` launches → `AppLifecycleCoordinator.onLaunch()` → `marketDataRepository.start()`.
   - Seed provider fetches quotes (Twelve Data or mock provider via switchable provider).

2. **Simulation flow**
   - Seed quotes start/reseed `DefaultMarketSimulationEngine`.
   - Engine emits periodic simulated ticks.

3. **Quote update flow**
   - Repository merges ticks into quote stream.
   - Watchlist/detail screens receive updates via publishers.

4. **Portfolio valuation flow**
   - Portfolio repository recalculates current prices and unrealized P&L from shared quote stream.

5. **History + analytics flow**
   - Filled orders append order records, activity events, realized entries.
   - Analytics service recomputes derived summaries/buckets and publishes filtered outputs.

6. **Persistence + reload flow**
   - Portfolio updates persist to file-backed store.
   - Checkpoint snapshots persist asynchronously.
   - Relaunch restores persisted portfolio/checkpoints/preferences.

7. **Offline fallback path**
   - Seeding failure → cached quotes if present (`offlineCached`)
   - else deterministic quote defaults (`offlineDeterministic`)
   - chart fetch failures fall back to cached candles when available

---

## 5) Getting started

### Prerequisites
- Xcode with iOS SDK compatible with this project (project setting currently uses iOS deployment target `26.2`)
- macOS capable of running iOS Simulator
- Optional Twelve Data API key for live seeding

### Clone and open
```bash
git clone <repo-url>
cd Volt
open Volt.xcodeproj
```

### Run from Xcode
1. Select `Volt` scheme.
2. Choose an iOS Simulator device.
3. Run (`⌘R`).

### Configure market-data seeding
Set environment variables in your scheme (`Product > Scheme > Edit Scheme... > Run > Environment Variables`):

- `TWELVE_DATA_API_KEY` = your API key (optional but required for Twelve Data requests)
- `TWELVE_DATA_BASE_URL` = defaults to `https://api.twelvedata.com`
- `VOLT_ENV` = `mock` or `twelveDataSeededSimulation`
- `VOLT_SYMBOLS` = comma-separated symbols (e.g., `BTC/USD,ETH/USD,SOL/USD`)

If no API key is set while using Twelve Data mode, app startup falls back to cached/deterministic data.

### Mock vs seeded simulation
- **Mock mode**: set `VOLT_ENV=mock` or choose Conservative profile.
- **Twelve Data seeded simulation**: set `VOLT_ENV=twelveDataSeededSimulation` and provide API key.

### Deterministic demo scenarios
From **Settings > Deterministic Demo Scenario**, select:
- Empty New User
- Balanced Starter
- Analytics Rich

This replaces portfolio state with deterministic snapshots and refreshes market data.

### Reset local state for testing
- UI tests use launch arg `UITEST_RESET` to clear key `UserDefaults` entries.
- Manual reset options:
  - Settings: restart onboarding / scenario off
  - Delete app from simulator/device to clear app support + defaults entirely

---

## 6) Configuration

### Runtime environments and profiles
- `TradingEnvironment`: `mock`, `twelveDataSeededSimulation`
- Profiles: Conservative, Balanced, Aggressive
- Profile switch updates environment + simulator defaults, then orchestrates reseed/refresh

### Simulator controls
Configurable in Settings:
- slippage preset
- volatility preset
- confirmation mode
- risk warnings and threshold
- order-size defaults + reset to profile defaults

### Seeded simulation behavior
- Startup seed once; guarded against duplicate concurrent startup pipelines.
- Manual refresh and stale-resume paths can force reseed.

### Settings/preferences that affect behavior
Persisted preferences include:
- onboarding completion
- local AI summary enabled/disabled
- selected environment/profile
- simulator risk preferences
- active deterministic scenario ID

### Where config lives
- Runtime env + symbols + API keys: `AppConfiguration.current()`
- User-tunable runtime prefs: `UserDefaultsAppPreferencesStore`

---

## 7) Testing

### Test targets
- `VoltTests`: domain/data/viewmodel/repository coverage
- `VoltUITests`: onboarding/tab/settings/scenario flows

### What is covered
- DTO decoding and mapping (Twelve Data)
- market repository seeding/fallback behavior
- portfolio persistence and migration compatibility
- analytics recompute/filter behavior
- runtime profile and onboarding preference flows
- deterministic scenario catalog stability
- UI flow checks including large text navigation path

### Running tests
In Xcode: Product > Test (`⌘U`)

or CLI:
```bash
xcodebuild test -project Volt.xcodeproj -scheme Volt -destination 'platform=iOS Simulator,name=iPhone 16'
```

### Pre-merge verification priorities
- quote-seeding + fallback mode behavior
- trade execution correctness (cash/qty checks, slippage application)
- shared quote-driven valuation consistency
- persistence compatibility and migration safety
- deterministic scenario behavior

---

## 8) Performance and concurrency notes

- **Shared repositories** reduce duplicated work: one market stream and one portfolio valuation source feed all tabs.
- **Startup deduping**: `DefaultMarketDataRepository.StartupState` prevents duplicate seed pipelines.
- **Simulation deduping**: `DefaultMarketSimulationEngine` guards tick loop creation (`tickTask == nil`) and cancels on stop/deinit.
- **Checkpoint throttling**: checkpoint service throttles periodic/resume checkpoints with a minimum interval and max retained count.
- **Analytics compute queue**: heavy analytics recompute happens on a dedicated utility queue.

When debugging lag/races:
1. Check startup/refresh sequencing in `DefaultMarketDataRepository` and `AppLifecycleCoordinator`.
2. Check simulation task lifecycle in `DefaultMarketSimulationEngine`.
3. Check analytics structural recompute logging and filter updates in `DefaultPortfolioAnalyticsService`.
4. Check checkpoint write pressure in `DefaultAccountSnapshotCheckpointService`.

---

## 9) Persistence and migration

### Persisted locally
- Portfolio state: open positions, order history, realized P&L history, activity timeline, cash balance
- Market cache: latest quotes + candle cache per symbol
- Snapshot checkpoints: equity/cash/P&L timeline + trigger metadata
- User preferences + UI restoration ranges/tab

### Storage mechanisms
- File-backed JSON stores in app support (`Volt/` subdirectory)
- UserDefaults for preferences/UI state keys

### Migration/versioning present
- Portfolio store supports legacy raw payload decode and wrapped envelope (versioned envelope currently `version: 2`).
- Preferences store supports legacy v1 decode and maps into current schema (`AppPreferences.schemaVersion = 2`).

### Clearing state during development
- Delete app from simulator/device
- Or clear specific defaults keys:
  - `volt.app_preferences`
  - `volt.ui_restoration`

---

## 10) Offline and fallback behavior

If Twelve Data requests fail (including missing API key):
1. Use cached quotes if available (`offlineCached`)
2. Else synthesize deterministic symbol fallback quotes (`offlineDeterministic`)
3. Continue simulation from fallback seed so app remains interactive

For candles:
- failed network fetch falls back to cached candles when present

### Limitations in offline mode
- quote freshness may be stale (cached)
- deterministic fallback prices are synthetic
- analytics reflect local simulated/history state, not external account truth

---

## 11) Analytics and insight engine

### Analytics available
- portfolio summary metrics (realized/unrealized/closed trades/win rate/PF)
- equity curve points
- daily realized P&L buckets
- realized-outcome distribution
- filtered order/activity views

### Insight summaries
“AI-style” summaries are generated by `LocalInsightSummaryService` from local in-memory/persisted data only (no remote LLM calls).

- Portfolio insights: equity recap, concentration, trade pattern, recent activity, attribution
- Analytics insights: runtime context + contribution/quality cards
- History insights: activity breadth cards
- Trade recap: post-fill summary sentence

### Limitations
- Rule/template-based summarization (not model-based reasoning)
- Quality depends on local history volume and scenario state

---

## 12) Accessibility and UX quality notes

Observed UX patterns:
- broad use of `ContentUnavailableView` for empty/loading states
- visible fallback/offline messaging in Watchlist footer
- support for large Dynamic Type flow is explicitly UI-tested (`UICTContentSizeCategoryAccessibilityL` path)
- accessibility identifiers are provided for key UI test selectors (e.g., scenario picker/data mode label)

Release-candidate polish areas to keep protecting:
- explicit state messaging (seeding/fallback/error)
- deterministic startup/reset behavior for demos/tests
- stable navigation around onboarding/profile switching

---

## 13) Limitations and disclaimers

- This app is a **demo simulator**, not a broker integration.
- It does **not** execute real trades and is **not** financial advice.
- Market data can be seeded from Twelve Data, but execution is local only.
- Analytics/history fidelity is bounded by local state, persisted checkpoints, and selected deterministic scenarios.

---

## 14) Roadmap / future work

Potential next steps that align with current architecture:
- Add streaming provider abstraction (WebSocket) while preserving seeded+simulated mode.
- Expand analytics export/report formats beyond CSV presets.
- Add deeper risk and exposure analytics per symbol/profile.
- Harden packaging/release pipeline for distribution (signing, QA matrix, telemetry policy).
- Optional abstraction for remote insight provider while keeping local deterministic fallback.

---

## 15) Contributing guidance

When contributing:
- Keep architecture boundaries intact (Domain protocols, Data implementations, Feature view models).
- Avoid introducing duplicate market/portfolio state sources.
- Keep business logic out of SwiftUI view structs.
- Prefer deterministic, testable logic and add/adjust tests with behavior changes.
- Preserve the shared quote-driven valuation pathway.
- Update docs (including this README) whenever runtime behavior or persistence contracts change.

---

## 16) Troubleshooting

### Missing API key
- Symptom: seeding fails, watchlist shows fallback mode.
- Fix: set `TWELVE_DATA_API_KEY` in scheme or switch to mock environment/profile.

### No market seed data
- Verify `VOLT_SYMBOLS` format (`BTC/USD,ETH/USD,...`) and symbol support list.
- Check network availability and Twelve Data status/limits.

### Offline fallback activated
- Expected when seed provider errors.
- App continues with cached/deterministic data; pull-to-refresh retries.

### Stale local persisted state
- Delete app or clear defaults keys, then relaunch.
- Disable deterministic scenario if you expect a clean account.

### Deterministic scenario confusion
- Scenario selection replaces entire portfolio state.
- Set scenario to “Off” in Settings to return to default empty-new-user state.

### Tests failing due to local state/config
- Ensure UI tests launch with `UITEST_RESET` as configured.
- Confirm simulator destination and environment variables are consistent.

---

## 17) License / repository notes

No license file is currently present in this repository root. Add a `LICENSE` file before external redistribution.

---

## 18) Quick reference (important files)

- App bootstrap: `Volt/VoltApp.swift`, `Volt/Core/DI/AppContainer.swift`
- Runtime config: `Volt/Core/Environment/AppConfiguration.swift`
- Market seeding/fallback: `Volt/Data/Repositories/DefaultMarketDataRepository.swift`
- Simulation engine: `Volt/Data/Repositories/DefaultMarketSimulationEngine.swift`
- Local execution: `Volt/Data/Repositories/DefaultTradingSimulationService.swift`
- Portfolio valuation/persistence: `Volt/Data/Repositories/InMemoryPortfolioRepository.swift`
- Analytics service: `Volt/Data/Repositories/DefaultPortfolioAnalyticsService.swift`
- Preferences/runtime profiles: `Volt/Core/Preferences/UserDefaultsAppPreferencesStore.swift`, `Volt/Domain/Models/RuntimeProfile.swift`
- Deterministic scenarios: `Volt/Domain/Models/DemoScenario.swift`, `Volt/Data/Repositories/DefaultDemoScenarioBootstrapService.swift`

