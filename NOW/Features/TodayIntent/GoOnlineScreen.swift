import SwiftUI

struct GoOnlineScreen: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("One person at a time.")
                    .font(.largeTitle.weight(.bold))

                Text("Go online when you are actually open to meet today. If you match, discovery pauses.")
                    .foregroundStyle(NOWColor.inkSoft)

                IntentPicker(title: "Plan", selection: $appState.todayIntent.plan, values: Plan.allCases)
                IntentPicker(title: "Connection", selection: $appState.todayIntent.intent, values: Intent.allCases)
                IntentPicker(title: "When today", selection: $appState.todayIntent.timeWindow, values: TimeWindow.allCases)

                Text("One active match only. Meet, cancel, or let today end before starting another.")
                    .font(.footnote)
                    .foregroundStyle(NOWColor.inkSoft)
                    .padding()
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                Button("Go Online for today") {
                    appState.goOnline()
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding(20)
        }
    }
}

private struct IntentPicker<T: RawRepresentable & CaseIterable & Identifiable & Hashable>: View where T.RawValue == String {
    let title: String
    @Binding var selection: T
    let values: [T]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.caption.weight(.bold))
                .foregroundStyle(NOWColor.inkSoft)

            FlowLayout(values: values, selection: $selection)
        }
        .padding()
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct FlowLayout<T: RawRepresentable & Identifiable & Hashable>: View where T.RawValue == String {
    let values: [T]
    @Binding var selection: T

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 8)], spacing: 8) {
            ForEach(values) { value in
                Button(value.rawValue) {
                    selection = value
                }
                .font(.subheadline.weight(.semibold))
                .padding(.vertical, 9)
                .frame(maxWidth: .infinity)
                .foregroundStyle(selection == value ? NOWColor.teal : NOWColor.inkSoft)
                .background(selection == value ? NOWColor.tealPale : NOWColor.paper)
                .clipShape(Capsule())
            }
        }
    }
}
