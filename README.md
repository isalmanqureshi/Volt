<div align="center">
  <img src="Volt/Assets.xcassets/AppIcon.appiconset/Volt_Rev.png" alt="Volt app icon" width="140" />

  # Volt RC — iOS Crypto Trading Simulator

  **A premium-feel, on-device crypto trading simulator for demos, architecture reviews, and engineering workflows.**

  ![Platform](https://img.shields.io/badge/Platform-iOS-0A84FF?style=flat-square)
  ![Language](https://img.shields.io/badge/Language-Swift-F05138?style=flat-square)
  ![UI](https://img.shields.io/badge/UI-SwiftUI-0A84FF?style=flat-square)
  ![Charts](https://img.shields.io/badge/Charts-Swift%20Charts-8E8E93?style=flat-square)
  ![License](https://img.shields.io/badge/License-Apache--2.0-111111?style=flat-square)
</div>

---

## Preview

<p align="center">
  <img src="docs/media/volt-preview.gif" alt="Volt app demo" width="320" />
</p>

> If the GIF does not render, add your screen recording at `docs/media/volt-preview.gif`.

---

## What is Volt?

Volt is a full-featured crypto trading simulator built with SwiftUI. It's designed for architecture demos, product walkthroughs, and engineering exercises — **not** real trading. No broker accounts, no live orders, no financial risk. Just a clean, realistic simulation you can run entirely on-device.

> **Quick disclaimer:** Volt is a demo app. It doesn't execute real trades and isn't financial advice.

This makes it great for:
- iOS engineers getting up to speed on a real SwiftUI codebase
- Architecture reviewers who want to trace data flow end-to-end
- Internal stakeholders doing product walkthroughs or demos
- Contributors looking for a well-structured base to extend

---

## Features

- **Watchlist** — Browse live or seeded quotes for your configured symbols, pull-to-refresh, and see a clear banner showing whether you're in live, cached, or offline mode.
- **Asset detail + charts** — Tap any asset to see a quote header and a 1-minute candlestick chart (Swift Charts). Falls back to cached candles gracefully if the network is unavailable.
- **Trade ticket** — Submit buy or sell market orders with estimated fill prices (including slippage), risk warnings, and a post-fill recap.
- **Portfolio** — See your open positions with real-time unrealized P&L, all driven from the same shared quote stream.
- **History** — Review filled orders and activity, filter by symbol or event type, and export to CSV.
- **Analytics** — Equity curve, daily P&L buckets, win rate, profit factor, and more.
- **Settings** — Switch between runtime profiles (Conservative / Balanced / Aggressive), adjust slippage and volatility, enable deterministic demo scenarios, and more.

---

## Tech Stack

- **Language:** Swift
- **UI:** SwiftUI + Swift Charts
- **Architecture:** Feature-oriented modular structure with clear domain boundaries
- **Persistence:** JSON state in Application Support + UserDefaults preferences
- **Market data source:** Twelve Data (seed only)
- **Execution model:** Fully local simulation engine (on-device order execution)

---

## Screenshots

> Add screenshots under `docs/media/` and reference them here to showcase additional screens (Portfolio, Analytics, History, Trade Ticket).

---

## Architecture

For a deeper technical walkthrough of runtime/data-flow/concurrency/persistence design, see [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

### Project structure

```text
Volt/
  App/           # Root tab, lifecycle, navigation
  Core/          # DI, runtime config, preferences, logging
  Domain/        # Models + protocols (no UI, no data layer details)
  Data/          # Providers, repositories, simulation, persistence
  Features/      # SwiftUI views + view models, one folder per screen
```

### Data flow (high level)

1. App launches → market data repository seeds quotes from Twelve Data (or mock/cache).
2. A local simulation engine picks up those seed prices and emits 1-second ticks.
3. The shared quote stream drives watchlist, detail, and portfolio valuation simultaneously.
4. When you place a trade, the local trading service validates and fills it, mutating the in-memory portfolio.
5. Everything persists to JSON files in app support so state survives relaunches.

A few things worth calling out:
- **One quote stream, one valuation source.** `InMemoryPortfolioRepository` subscribes to the shared quote publisher and recomputes unrealized P&L centrally. No screen invents its own valuation logic.
- **Twelve Data is seeding only.** It provides input prices at startup. All execution logic is local.
- **Startup is deduplicated.** The market repository guards against duplicate concurrent seed pipelines, and the simulation engine prevents duplicate tick loops.

---

## Installation

### Prerequisites

- Xcode with an iOS SDK compatible with this project (configured for iOS 26.2 deployment target)
- macOS capable of running iOS Simulator
- (Optional) A Twelve Data API key for live seeding

### Clone and run

```bash
git clone <repo-url>
cd Volt
open Volt.xcodeproj
```

Select the `Volt` scheme, pick a simulator, and hit `⌘R`.

### Environment variables

Set under `Product > Scheme > Edit Scheme > Run > Environment Variables`:

| Variable | Purpose |
|---|---|
| `TWELVE_DATA_API_KEY` | Your Twelve Data key (optional; omitting it triggers offline fallback) |
| `TWELVE_DATA_BASE_URL` | Defaults to `https://api.twelvedata.com` |
| `VOLT_ENV` | `mock` or `twelveDataSeededSimulation` |
| `VOLT_SYMBOLS` | Comma-separated symbols, e.g. `BTC/USD,ETH/USD,SOL/USD` |

If you just want to poke around without an API key, set `VOLT_ENV=mock` (or pick the Conservative profile in Settings) and everything runs from local mock data.

---

## Demo scenarios

Volt has three built-in deterministic scenarios you can load from **Settings > Deterministic Demo Scenario**:

- **Empty New User** — clean slate, no history
- **Balanced Starter** — some positions, a bit of history
- **Analytics Rich** — lots of trades and history for showcasing the analytics screen

Each scenario replaces the local portfolio state with a fixed snapshot, so demos are reproducible. Set it back to "Off" in Settings to return to a normal empty-user state.

---

## Configuration and runtime profiles

Profiles are the highest-level knob. Switching profiles updates the environment and simulator defaults in one shot:

| Profile | Environment | Use case |
|---|---|---|
| Conservative | Mock | Fully offline, great for demos without network |
| Balanced | Twelve Data seeded | Normal usage with live-seeded prices |
| Aggressive | Twelve Data seeded | Higher volatility + slippage presets |

Beyond profiles, you can tune slippage, volatility, confirmation mode, risk warning thresholds, and default order sizing directly in Settings.

---

## Persistence

Volt stores three things locally (under `.../Application Support/Volt/`):

- `portfolio_state.json` — positions, order history, realized P&L, cash balance
- `market_cache.json` — latest quotes + candle cache per symbol
- `account_snapshot_checkpoints.json` — equity/cash/P&L timeline snapshots

Preferences and UI state live in `UserDefaults`. The portfolio store supports schema migration (currently on version 2), so state from older builds survives upgrades.

To reset during development: delete the app from the simulator, or clear `volt.app_preferences` and `volt.ui_restoration` from UserDefaults manually.

---

## Offline behavior

If Twelve Data seeding fails (network down, missing API key, rate limit), Volt degrades gracefully:

1. Uses cached quotes if any are available → shows `offlineCached` banner
2. Falls back to deterministic synthetic prices if no cache → shows `offlineDeterministic` banner
3. Simulation continues from the fallback seed so the app stays fully interactive

Candle fetches fall back to cached candles the same way. The app never just sits broken.

---

## Testing

```bash
# In Xcode
⌘U
```

### What's covered

- DTO decoding and mapping (Twelve Data)
- Market repository seeding and fallback behavior
- Portfolio persistence and migration compatibility
- Analytics recompute and filtering
- Runtime profile and onboarding preference flows
- Deterministic scenario catalog stability
- UI flows including large Dynamic Type navigation paths

UI tests use the `UITEST_RESET` launch argument to clear UserDefaults before each run.

### Key things to protect when contributing

- Quote seeding + fallback mode correctness
- Trade execution math (cash checks, qty validation, slippage)
- Shared quote-driven valuation consistency
- Persistence compatibility across schema versions
- Deterministic scenario reproducibility

---

## Analytics and insights

The analytics screen surfaces: equity curve, daily realized P&L buckets, realized-outcome distribution, win rate, profit factor, net return, and closed trade count.

The "AI-style" insight cards throughout the app are generated by `LocalInsightSummaryService` — rule and template based, running fully on-device with no remote LLM calls. Quality improves with more local trade history.

---

## Troubleshooting

**Watchlist shows fallback mode / seeding failed**  
→ Set `TWELVE_DATA_API_KEY` in your scheme, or switch to `VOLT_ENV=mock`.

**Symbols not loading**  
→ Check that `VOLT_SYMBOLS` uses the right format (`BTC/USD,ETH/USD,...`) and that your Twelve Data plan covers those symbols.

**Stale portfolio state from a previous session**  
→ Delete the app from the simulator to clear everything, or disable the active deterministic scenario in Settings.

**Tests failing unexpectedly**  
→ Confirm the simulator destination matches and that `UITEST_RESET` is set in the UI test scheme.

---

## Performance notes

- Heavy analytics recompute runs on a dedicated background queue.
- Checkpoint writes are throttled with a minimum interval and max retained count.
- The simulation engine and market repository both guard against duplicate task creation.

If you're debugging lag or race conditions, the most useful starting points are: `DefaultMarketDataRepository`, `DefaultMarketSimulationEngine`, `DefaultPortfolioAnalyticsService`, and `DefaultAccountSnapshotCheckpointService`.

---

## Contributing

A few things to keep in mind:

- **Respect the architecture boundaries.** Domain protocols stay pure (no UI, no I/O). Data layer implements them. Feature view models consume them.
- **Don't introduce a second source of market or portfolio truth.** The shared quote stream and `InMemoryPortfolioRepository` are the canonical sources.
- **Keep business logic out of SwiftUI view structs.** If it's testable logic, it belongs in a view model or service.
- **Write tests for behavior changes** and update this README when runtime behavior or persistence contracts change.

---

## Quick file reference

| What | Where |
|---|---|
| App bootstrap | `Volt/VoltApp.swift`, `Volt/Core/DI/AppContainer.swift` |
| Runtime config | `Volt/Core/Environment/AppConfiguration.swift` |
| Market seeding + fallback | `Volt/Data/Repositories/DefaultMarketDataRepository.swift` |
| Simulation engine | `Volt/Data/Repositories/DefaultMarketSimulationEngine.swift` |
| Trade execution | `Volt/Data/Repositories/DefaultTradingSimulationService.swift` |
| Portfolio valuation | `Volt/Data/Repositories/InMemoryPortfolioRepository.swift` |
| Analytics | `Volt/Data/Repositories/DefaultPortfolioAnalyticsService.swift` |
| Runtime profiles | `Volt/Domain/Models/RuntimeProfile.swift` |
| Demo scenarios | `Volt/Domain/Models/DemoScenario.swift`, `Volt/Data/Repositories/DefaultDemoScenarioBootstrapService.swift` |

---

## Author

Maintained by the Volt RC contributors.

---

## License

This project is licensed under the Apache License 2.0 (`Apache-2.0`). See [`LICENSE`](LICENSE).

Apache-2.0 includes an express patent license from contributors (see Section 3 of `LICENSE`).
