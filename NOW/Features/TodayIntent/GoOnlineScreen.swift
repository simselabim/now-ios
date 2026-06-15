import SwiftUI

struct GoOnlineScreen: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        NOWLogo(compact: true)
                        Text("Nearby for today")
                            .font(.caption.weight(.black))
                            .foregroundStyle(NOWColor.inkSoft)
                    }
                    Spacer()
                    NOWChip(text: "Today", active: true)
                }

                ZStack(alignment: .bottomLeading) {
                    PhotoSurface(name: NOWPhoto.streetCoffee, height: 230, blur: 0.8)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("What feels right now?")
                            .font(.system(size: 32, weight: .black))
                            .foregroundStyle(.white)
                        Text("Pick the plan you would actually say yes to today.")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    .padding(18)
                }

                IntentPicker(title: "Plan", selection: $appState.todayIntent.plan, values: Plan.allCases)
                IntentPicker(title: "Connection", selection: $appState.todayIntent.intent, values: Intent.allCases)
                IntentPicker(title: "When today", selection: $appState.todayIntent.timeWindow, values: TimeWindow.allCases)

                Text("One active match only. Stay with this one for now. Tonight everything resets.")
                    .font(.footnote)
                    .foregroundStyle(NOWColor.inkSoft)
                    .padding(14)
                    .background(NOWColor.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                Button("Go online") {
                    appState.goOnline()
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding(22)
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
        .padding(16)
        .background(NOWColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(NOWColor.line.opacity(0.8), lineWidth: 1)
        )
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
                .foregroundStyle(selection == value ? NOWColor.ink : NOWColor.inkSoft)
                .background(selection == value ? NOWColor.lime : NOWColor.paper)
                .clipShape(Capsule())
            }
        }
    }
}
