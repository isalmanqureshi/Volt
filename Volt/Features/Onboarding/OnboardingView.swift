import SwiftUI

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject var viewModel: OnboardingViewModel

    var body: some View {
        NavigationStack {
            VStack(spacing: DS.Spacing.lg) {
                TabView(selection: $viewModel.step) {
                    page(title: "Welcome to Volt RC Demo", subtitle: "A simulated crypto trading experience.", detail: "This app is not a broker and does not execute real orders.")
                        .tag(0)
                    page(title: "Market data + simulation", subtitle: "Quotes can be seeded from Twelve Data.", detail: "Order execution remains local and deterministic.")
                        .tag(1)
                    VStack(alignment: .leading, spacing: DS.Spacing.md) {
                        page(title: "Portfolio intelligence", subtitle: "History and analytics stay local.", detail: "You can enable deterministic AI-style summaries from local state.")
                        Picker("Starter profile", selection: $viewModel.starterProfileID) {
                            ForEach(RuntimeProfile.all) { profile in
                                Text(profile.name).tag(profile.id)
                            }
                        }
                        Toggle("Enable AI summaries", isOn: $viewModel.enableAISummaries)
                    }
                    .tag(2)
                }
                .tabViewStyle(.page)

                HStack {
                    Button("Skip") {
                        viewModel.skip()
                        dismiss()
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    Button(viewModel.isLastStep ? "Get Started" : "Next") {
                        if viewModel.isLastStep {
                            viewModel.complete()
                            dismiss()
                        } else {
                            viewModel.next()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(DS.Spacing.lg)
            .navigationTitle("Onboarding")
        }
    }

    private func page(title: String, subtitle: String, detail: String) -> some View {
        DSCard(title: nil) {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text(title)
                    .font(.title3.weight(.semibold))
                Text(subtitle)
                    .font(.headline)
                Text(detail)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    OnboardingView(viewModel: OnboardingViewModel(preferences: UserDefaultsAppPreferencesStore(defaults: .standard, key: "preview.onboarding")))
}
