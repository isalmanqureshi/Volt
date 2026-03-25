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

            Section("About / Demo Info") {
                Text("Volt is a demo trading simulator. It does not connect to brokerage accounts or place real orders.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Settings")
    }
}
