import SwiftUI

struct SettingsView: View {
    let environmentName: String

    var body: some View {
        List {
            Section("Environment") {
                LabeledContent("Mode", value: environmentName)
                Text("Milestone 0/1: simulation only, no broker connectivity.")
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
