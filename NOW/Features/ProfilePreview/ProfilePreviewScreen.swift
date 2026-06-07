import SwiftUI

struct ProfilePreviewScreen: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        if let point = appState.selectedPoint {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Button("Back to map") {
                        appState.closeProfilePreview()
                    }
                    .font(.subheadline.weight(.semibold))

                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .center, spacing: 14) {
                            Circle()
                                .fill(NOWColor.coral)
                                .frame(width: 84, height: 84)
                                .overlay(Text(String(point.profile.name.prefix(1))).font(.title.bold()).foregroundStyle(.white))

                            VStack(alignment: .leading, spacing: 6) {
                                Text("\(point.profile.name), \(point.profile.age)")
                                    .font(.title.weight(.bold))
                                Text("\(point.profile.distance) away")
                                    .foregroundStyle(NOWColor.inkSoft)
                                HStack {
                                    Tag(point.profile.plan.rawValue, active: true)
                                    Tag(point.profile.intent.rawValue, active: false)
                                }
                            }
                        }

                        Text(point.profile.prompt)
                            .font(.body)

                        Text("You share \(point.profile.sharedInterests.count) interests")
                            .font(.headline)
                        Text(point.profile.sharedInterests.joined(separator: " · "))
                            .foregroundStyle(NOWColor.inkSoft)

                        Text("Contact details stay off profiles. Meet through NOW first.")
                            .font(.footnote)
                            .foregroundStyle(NOWColor.inkSoft)
                    }
                    .padding()
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    Button("Interested today") {
                        appState.markInterested(point)
                    }
                    .buttonStyle(PrimaryButtonStyle())

                    Button("Not Now") {
                        appState.notNow(point)
                    }
                    .buttonStyle(SecondaryButtonStyle())

                    Button("Block") {
                        appState.block(point)
                    }
                    .buttonStyle(DangerButtonStyle())
                }
                .padding(20)
            }
        }
    }
}

private struct Tag: View {
    let text: String
    let active: Bool

    init(_ text: String, active: Bool) {
        self.text = text
        self.active = active
    }

    var body: some View {
        Text(text)
            .font(.caption.weight(.bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .foregroundStyle(active ? NOWColor.teal : NOWColor.inkSoft)
            .background(active ? NOWColor.tealPale : NOWColor.paper)
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
