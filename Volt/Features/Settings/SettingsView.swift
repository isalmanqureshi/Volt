import SwiftUI

struct SettingsView: View {
    @StateObject var viewModel: SettingsViewModel

    var body: some View {
        List {
            Section("Data & Environment") {
                LabeledContent("Mode", value: viewModel.preferences.selectedEnvironment.displayName)
                Text("Market seeding can use Twelve Data. Trade execution is always local simulation.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Simulator") {
                Picker("Default size mode", selection: Binding(
                    get: { viewModel.preferences.simulatorRisk.orderSizeMode },
                    set: viewModel.setOrderSizeMode
                )) {
                    ForEach(OrderSizeMode.allCases, id: \.self) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                Toggle("Risk warnings", isOn: Binding(
                    get: { viewModel.preferences.simulatorRisk.riskWarningsEnabled },
                    set: viewModel.setRiskWarningsEnabled
                ))
                Toggle("Confirm large trades", isOn: Binding(
                    get: { viewModel.preferences.simulatorRisk.requiresLargeOrderConfirmation },
                    set: viewModel.setLargeOrderConfirmation
                ))
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

            Section("Supported Symbols") {
                ForEach(SupportedAssets.demoAssets) { asset in
                    Text(asset.symbol)
                }
            }
        }
        .navigationTitle("Settings")
    }
}
