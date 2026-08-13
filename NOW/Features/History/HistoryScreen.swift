import SwiftUI

struct HistoryScreen: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("History")
                            .font(.largeTitle.weight(.black))
                        Text("Meetings that actually happened.")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(NOWColor.inkSoft)
                    }
                    Spacer()
                    NOWLogo(compact: true)
                }

                if appState.history.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(NOWColor.laOrange)
                        Text("No meetings here yet")
                            .font(.headline.weight(.black))
                        Text("Completed meetings and their result will appear here.")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(NOWColor.inkSoft)
                            .multilineTextAlignment(.center)
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity)
                    .background(NOWColor.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                }

                ForEach(appState.history) { item in
                    HStack(spacing: 12) {
                        UserPhoto(url: item.otherMainPhotoURL)
                            .frame(width: 54, height: 54)
                            .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 6) {
                            Text(item.otherDisplayName ?? "Previous match")
                                .font(.headline)
                            Text(item.title)
                                .foregroundStyle(NOWColor.inkSoft)
                            HStack(spacing: 8) {
                                Text(resultLabel(item.result))
                                if let occurredAt = item.occurredAt {
                                    Text(occurredAt.formatted(date: .abbreviated, time: .shortened))
                                }
                            }
                            .font(.caption.weight(.bold))
                            .foregroundStyle(NOWColor.laOrange)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(NOWColor.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
            .padding(20)
        }
        .background(NOWColor.laCream.ignoresSafeArea())
    }

    private func resultLabel(_ result: String) -> String {
        switch result {
        case "we_met": "Met"
        case "cancelled": "Cancelled"
        case "expired": "Expired"
        case "blocked": "Blocked"
        default: result.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }
}
