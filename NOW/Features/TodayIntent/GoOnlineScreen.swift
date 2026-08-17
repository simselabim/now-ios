import SwiftUI

struct GoOnlineScreen: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedPlans: Set<Plan> = []
    @State private var selectedIntents: Set<Intent> = []
    @State private var selectedTimeWindows: Set<TimeWindow> = []

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
                    Text("Choose any that feel right, or skip for now.")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(NOWColor.inkSoft)
                }

                CompactIntentPicker(title: "Plan", selection: $selectedPlans, values: Plan.goOnlineOptions) { $0.goOnlineLabel }
                CompactIntentPicker(title: "Connection", selection: $selectedIntents, values: Intent.goOnlineOptions) { $0.rawValue }
                CompactIntentPicker(title: "When today", selection: $selectedTimeWindows, values: TimeWindow.goOnlineOptions) { $0.rawValue }

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
                .disabled(appState.isLoading)
                .buttonStyle(PrimaryButtonStyle())
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
        .onAppear {
            selectedPlans = appState.todayIntent.plans
            selectedIntents = appState.todayIntent.intents
            selectedTimeWindows = appState.todayIntent.timeWindows
        }
    }

    private func goOnline() {
        appState.todayIntent = TodayIntent(
            plans: selectedPlans,
            intents: selectedIntents,
            timeWindows: selectedTimeWindows
        )
        appState.goOnline()
    }
}

private struct CompactIntentPicker<T: RawRepresentable & Identifiable & Hashable>: View where T.RawValue == String {
    let title: String
    @Binding var selection: Set<T>
    let values: [T]
    let label: (T) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title.uppercased())
                .font(.caption.weight(.bold))
                .foregroundStyle(NOWColor.inkSoft)

            CompactFlowLayout(values: values, selection: $selection, label: label)
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
    @Binding var selection: Set<T>
    let label: (T) -> String

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 7), count: 3), spacing: 7) {
            ForEach(values) { value in
                Button(label(value)) {
                    if selection.contains(value) {
                        selection.remove(value)
                    } else {
                        selection.insert(value)
                    }
                }
                .font(.caption.weight(.bold))
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .foregroundStyle(selection.contains(value) ? NOWColor.surface : NOWColor.inkSoft)
                .background(selection.contains(value) ? NOWColor.laCoral : NOWColor.paper)
                .clipShape(Capsule())
                .accessibilityLabel(label(value))
                .accessibilityValue(selection.contains(value) ? "Selected" : "Not selected")
                .accessibilityAddTraits(selection.contains(value) ? .isSelected : [])
            }
        }
    }
}
