import SwiftUI

struct SettingsView: View {
    @StateObject var viewModel: SettingsViewModel
    @State private var showResetConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader("Settings")

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    SectionLabel("Runtime Profile")
                        .padding(.bottom, Spacing.xs + 2)
                    profileSegments
                    Text(viewModel.preferences.activeRuntimeProfile.subtitle)
                        .font(Typography.secondary)
                        .foregroundStyle(Color.voltTextTertiary)
                        .padding(.top, Spacing.sm)

                    SectionLabel("Data & Execution")
                        .padding(.top, Spacing.gutter)
                        .padding(.bottom, Spacing.xs + 2)
                    dataExecutionCard

                    SectionLabel("Simulation")
                        .padding(.top, Spacing.gutter)
                        .padding(.bottom, Spacing.xs + 2)
                    simulationCard

                    SectionLabel("Advanced")
                        .padding(.top, Spacing.gutter)
                        .padding(.bottom, Spacing.xs + 2)
                    advancedCard

                    resetButton
                        .padding(.top, Spacing.gutter + Spacing.sm)

                    aboutFootnotes
                        .padding(.top, Spacing.gutter)
                }
                .padding(.horizontal, Spacing.gutter)
                .padding(.bottom, Spacing.gutter)
            }
        }
        .voltScreen()
        .toolbar(.hidden, for: .navigationBar)
        .confirmationDialog(
            "Reset portfolio?",
            isPresented: $showResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Reset to fresh $50,000 account", role: .destructive) {
                viewModel.setScenario("")
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Clears positions, history and analytics. This cannot be undone.")
        }
    }

    // MARK: Runtime profile

    private var profileSegments: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(viewModel.runtimeProfiles) { profile in
                let isActive = viewModel.preferences.activeRuntimeProfileID == profile.id
                Button {
                    viewModel.setRuntimeProfile(profile.id)
                } label: {
                    Text(profile.name)
                        .font(Typography.bodySecondary)
                        .foregroundStyle(isActive ? Color.voltAccent : Color.white.opacity(0.55))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.sm)
                        .background(
                            isActive ? Color.voltAccent.opacity(0.14) : .clear,
                            in: RoundedRectangle(cornerRadius: Radius.button - 2, style: .continuous)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(Spacing.xs)
        .voltSurfaceStyle(cornerRadius: Radius.button)
        .accessibilityIdentifier("settings_profile_picker")
    }

    // MARK: Data & execution

    private var dataExecutionCard: some View {
        settingsCard {
            settingsRow(label: "Data Source") {
                HStack(spacing: 3) {
                    dataSourcePill("Mock", isActive: viewModel.preferences.selectedEnvironment == .mock)
                    dataSourcePill("Live", isActive: viewModel.preferences.selectedEnvironment != .mock)
                }
                .padding(3)
                .background(Color.voltBackground, in: RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
            }
            RowDivider()
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Slippage")
                    .font(Typography.emphasis)
                    .foregroundStyle(Color.voltTextPrimary)
                HStack(spacing: Spacing.sm) {
                    ForEach(SlippagePreset.allCases, id: \.self) { preset in
                        FilterPill(
                            title: slippageLabel(preset),
                            isSelected: viewModel.preferences.simulatorRisk.slippagePreset == preset,
                            isMono: true,
                            expands: true
                        ) {
                            viewModel.setSlippage(preset)
                        }
                    }
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md + 2)
        }
    }

    private func dataSourcePill(_ title: String, isActive: Bool) -> some View {
        Text(title)
            .font(Typography.monoSecondary)
            .foregroundStyle(isActive ? Color.voltAccent : Color.white.opacity(0.5))
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.xs + 1)
            .background(
                isActive ? Color.voltAccent.opacity(0.14) : .clear,
                in: RoundedRectangle(cornerRadius: Radius.button - 2, style: .continuous)
            )
    }

    private func slippageLabel(_ preset: SlippagePreset) -> String {
        guard preset != .off else { return "Off" }
        let percent = preset.basisPoints / 100
        return "\(percent.formatted(.number.precision(.fractionLength(0...2))))%"
    }

    // MARK: Simulation

    private var simulationCard: some View {
        settingsCard {
            settingsRow(label: "Demo Scenario") {
                Menu {
                    Button("Off") { viewModel.setScenario("") }
                    ForEach(viewModel.scenarios) { scenario in
                        Button(scenario.name) { viewModel.setScenario(scenario.id) }
                    }
                } label: {
                    HStack(spacing: Spacing.xs + 2) {
                        Text(activeScenarioName)
                            .font(Typography.body)
                            .foregroundStyle(Color.white.opacity(0.5))
                        Image(systemName: "chevron.right")
                            .font(Typography.caption)
                            .foregroundStyle(Color.white.opacity(0.3))
                    }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("settings_scenario_picker")
            }
            RowDivider()
            settingsRow(label: "Risk Warnings") {
                Toggle("", isOn: Binding(
                    get: { viewModel.preferences.simulatorRisk.riskWarningsEnabled },
                    set: viewModel.setRiskWarningsEnabled
                ))
                .labelsHidden()
                .tint(Color.voltAccent)
            }
        }
    }

    private var activeScenarioName: String {
        viewModel.scenarios.first(where: { $0.id == viewModel.preferences.activeDemoScenarioID })?.name ?? "Off"
    }

    // MARK: Advanced

    private var advancedCard: some View {
        settingsCard {
            settingsRow(label: "Volatility") {
                menuValue(
                    title: viewModel.preferences.simulatorRisk.volatilityPreset.title,
                    options: SimulatorVolatilityPreset.allCases.map { preset in
                        (preset.title, { viewModel.setVolatility(preset) })
                    }
                )
            }
            RowDivider()
            settingsRow(label: "Confirmation") {
                menuValue(
                    title: viewModel.preferences.simulatorRisk.tradeConfirmationMode.title,
                    options: TradeConfirmationMode.allCases.map { mode in
                        (mode.title, { viewModel.setTradeConfirmationMode(mode) })
                    }
                )
            }
            RowDivider()
            settingsRow(label: "Warning threshold") {
                HStack(spacing: Spacing.sm) {
                    Text("\(viewModel.preferences.simulatorRisk.warningThresholdPercent.voltPriceString(precision: 0))%")
                        .font(Typography.monoBody)
                        .foregroundStyle(Color.voltTextPrimary)
                    Stepper(
                        "",
                        value: Binding(
                            get: { NSDecimalNumber(decimal: viewModel.preferences.simulatorRisk.warningThresholdPercent).doubleValue },
                            set: { viewModel.setWarningThresholdPercent(Decimal($0)) }
                        ),
                        in: 5...90,
                        step: 5
                    )
                    .labelsHidden()
                }
            }
            RowDivider()
            settingsRow(label: "AI summaries") {
                Toggle("", isOn: Binding(
                    get: { viewModel.preferences.aiSummariesEnabled },
                    set: viewModel.setAISummaries
                ))
                .labelsHidden()
                .tint(Color.voltAccent)
            }
            RowDivider()
            Button {
                viewModel.resetSimulatorControls()
            } label: {
                settingsRow(label: "Reset simulator controls") {
                    Image(systemName: "arrow.counterclockwise")
                        .font(Typography.bodySecondary)
                        .foregroundStyle(Color.voltTextSecondary)
                }
            }
            .buttonStyle(.plain)
            RowDivider()
            Button {
                viewModel.resetOnboarding()
            } label: {
                settingsRow(label: "Restart onboarding") {
                    Image(systemName: "chevron.right")
                        .font(Typography.caption)
                        .foregroundStyle(Color.white.opacity(0.3))
                }
            }
            .buttonStyle(.plain)
        }
    }

    private func menuValue(title: String, options: [(String, () -> Void)]) -> some View {
        Menu {
            ForEach(options, id: \.0) { option in
                Button(option.0, action: option.1)
            }
        } label: {
            HStack(spacing: Spacing.xs + 2) {
                Text(title)
                    .font(Typography.body)
                    .foregroundStyle(Color.white.opacity(0.5))
                Image(systemName: "chevron.right")
                    .font(Typography.caption)
                    .foregroundStyle(Color.white.opacity(0.3))
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: Reset + about

    private var resetButton: some View {
        Button {
            showResetConfirmation = true
        } label: {
            Text("Reset Portfolio")
                .font(Typography.emphasis.weight(.semibold))
                .foregroundStyle(Color.voltDanger)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                        .strokeBorder(Color.voltDanger.opacity(0.4), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private var aboutFootnotes: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Volt is a simulated crypto trading app. It never places real broker orders.")
            Text("Portfolio, trade history, and analytics stay on this device. Market quote seeding may use Twelve Data when available.")
            Text("Offline fallback may use cached or deterministic demo data.")
        }
        .font(Typography.secondary)
        .foregroundStyle(Color.voltTextTertiary)
    }

    // MARK: Card scaffolding

    private func settingsCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .voltSurfaceStyle()
    }

    private func settingsRow<Accessory: View>(label: String, @ViewBuilder accessory: () -> Accessory) -> some View {
        HStack {
            Text(label)
                .font(Typography.emphasis)
                .foregroundStyle(Color.voltTextPrimary)
            Spacer()
            accessory()
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md + 2)
        .contentShape(Rectangle())
    }
}

#Preview {
    NavigationStack {
        SettingsView(viewModel: SettingsViewModel(preferencesStore: UserDefaultsAppPreferencesStore()))
    }
}
