import SwiftUI

struct SettingsView: View {
    @StateObject var viewModel: SettingsViewModel

    var body: some View {
        List {
            Section("Runtime Profile") {
                Picker("Profile", selection: Binding(
                    get: { viewModel.preferences.activeRuntimeProfileID },
                    set: viewModel.setRuntimeProfile
                )) {
                    ForEach(viewModel.runtimeProfiles) { profile in
                        Text(profile.name).tag(profile.id)
                    }
                }
                .accessibilityIdentifier("settings_profile_picker")

                LabeledContent("Environment", value: viewModel.preferences.selectedEnvironment.displayName)
                Text(viewModel.preferences.activeRuntimeProfile.subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Simulator Controls") {
                Picker("Slippage", selection: Binding(
                    get: { viewModel.preferences.simulatorRisk.slippagePreset },
                    set: viewModel.setSlippage
                )) {
                    ForEach(SlippagePreset.allCases, id: \.self) { preset in
                        Text(preset.title).tag(preset)
                    }
                }

                Picker("Volatility", selection: Binding(
                    get: { viewModel.preferences.simulatorRisk.volatilityPreset },
                    set: viewModel.setVolatility
                )) {
                    ForEach(SimulatorVolatilityPreset.allCases, id: \.self) { preset in
                        Text(preset.title).tag(preset)
                    }
                }

                Picker("Confirmation", selection: Binding(
                    get: { viewModel.preferences.simulatorRisk.tradeConfirmationMode },
                    set: viewModel.setTradeConfirmationMode
                )) {
                    ForEach(TradeConfirmationMode.allCases, id: \.self) { mode in
                        Text(mode.title).tag(mode)
                    }
                }

                Toggle("Risk warnings", isOn: Binding(
                    get: { viewModel.preferences.simulatorRisk.riskWarningsEnabled },
                    set: viewModel.setRiskWarningsEnabled
                ))

                Stepper(value: Binding(get: { NSDecimalNumber(decimal: viewModel.preferences.simulatorRisk.warningThresholdPercent).doubleValue }, set: { viewModel.setWarningThresholdPercent(Decimal($0)) }), in: 5...90, step: 5) {
                    Text("Warning threshold: \(viewModel.preferences.simulatorRisk.warningThresholdPercent.formatted())%")
                }

                Button("Reset simulator controls") {
                    viewModel.resetSimulatorControls()
                }
            }

            Section("Experience") {
                Toggle("AI summaries", isOn: Binding(
                    get: { viewModel.preferences.aiSummariesEnabled },
                    set: viewModel.setAISummaries
                ))
                Button("Restart Onboarding") {
                    viewModel.resetOnboarding()
                }
            }

            if viewModel.scenarios.isEmpty == false {
                Section("Deterministic Demo Scenario") {
                    Picker("Scenario", selection: Binding(
                        get: { viewModel.preferences.activeDemoScenarioID ?? "" },
                        set: viewModel.setScenario
                    )) {
                        Text("Off").tag("")
                        ForEach(viewModel.scenarios) { scenario in
                            Text(scenario.name).tag(scenario.id)
                        }
                    }
                    .accessibilityIdentifier("settings_scenario_picker")

                    if let active = viewModel.scenarios.first(where: { $0.id == viewModel.preferences.activeDemoScenarioID }) {
                        Text(active.detail)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("About / Demo Info") {
                Text("Volt RC Demo is a simulated crypto trading app. It never places real broker orders.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text("Portfolio, trade history, and analytics stay on this device. Market quote seeding may use Twelve Data when available.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text("Offline fallback may use cached or deterministic demo data.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Settings")
    }
}
