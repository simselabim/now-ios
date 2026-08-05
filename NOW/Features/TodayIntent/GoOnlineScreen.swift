import SwiftUI

struct GoOnlineScreen: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedPlan: Plan?
    @State private var selectedIntent: Intent?
    @State private var selectedTimeWindow: TimeWindow?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 13) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        NOWLogo(compact: true)
                        Text("Nearby for today")
                            .font(.caption.weight(.black))
                            .foregroundStyle(NOWColor.inkSoft)
                    }
                    Spacer()
                    NOWChip(text: "Today", active: true)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text("What feels right now?")
                        .font(.system(size: 29, weight: .black, design: .rounded))
                        .foregroundStyle(NOWColor.ink)
                    Text("Choose all three to go online and meet nearby today.")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(NOWColor.inkSoft)
                }

                CompactIntentPicker(title: "Plan", selection: $selectedPlan, values: Plan.allCases)
                CompactIntentPicker(title: "Connection", selection: $selectedIntent, values: Intent.allCases)
                CompactIntentPicker(title: "When today", selection: $selectedTimeWindow, values: TimeWindow.allCases)

                if let error = appState.errorMessage {
                    Text(error)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(NOWColor.coral)
                        .padding(11)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(NOWColor.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                Button(appState.isLoading ? "Going online..." : "Go online") {
                    goOnline()
                }
                .disabled(!isReady || appState.isLoading)
                .buttonStyle(PrimaryButtonStyle())
                .opacity(isReady ? 1 : 0.45)
                .overlay {
                    if appState.isLoading {
                        ProgressView()
                            .tint(NOWColor.surface)
                            .offset(x: -120)
                    }
                }

                Text("One active match at a time. Tonight everything resets.")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(NOWColor.inkSoft)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 12)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(NOWColor.laCream.ignoresSafeArea())
        .overlay(alignment: .top) { LATopStripe() }
    }

    private var isReady: Bool {
        selectedPlan != nil && selectedIntent != nil && selectedTimeWindow != nil
    }

    private func goOnline() {
        guard let selectedPlan, let selectedIntent, let selectedTimeWindow else { return }
        appState.todayIntent = TodayIntent(
            plan: selectedPlan,
            intent: selectedIntent,
            timeWindow: selectedTimeWindow
        )
        appState.goOnline()
    }
}

private struct CompactIntentPicker<T: RawRepresentable & Identifiable & Hashable>: View where T.RawValue == String {
    let title: String
    @Binding var selection: T?
    let values: [T]

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title.uppercased())
                .font(.caption.weight(.bold))
                .foregroundStyle(NOWColor.inkSoft)

            CompactFlowLayout(values: values, selection: $selection)
        }
        .padding(12)
        .background(NOWColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(NOWColor.line.opacity(0.8), lineWidth: 1)
        )
    }
}

private struct CompactFlowLayout<T: RawRepresentable & Identifiable & Hashable>: View where T.RawValue == String {
    let values: [T]
    @Binding var selection: T?

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 82), spacing: 7)], spacing: 7) {
            ForEach(values) { value in
                Button(value.rawValue) {
                    selection = value
                }
                .font(.caption.weight(.bold))
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .foregroundStyle(selection == value ? NOWColor.surface : NOWColor.inkSoft)
                .background(selection == value ? NOWColor.laCoral : NOWColor.paper)
                .clipShape(Capsule())
            }
        }
    }
}
