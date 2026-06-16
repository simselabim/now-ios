import SwiftUI
import UIKit

enum NOWColor {
    static let lime = Color(red: 0.87, green: 1.0, blue: 0.09)
    static let limeSoft = Color(red: 0.94, green: 1.0, blue: 0.62)
    static let paper = Color(red: 0.95, green: 0.95, blue: 0.93)
    static let surface = Color.white
    static let ink = Color(red: 0.15, green: 0.21, blue: 0.24)
    static let slate = Color(red: 0.26, green: 0.34, blue: 0.38)
    static let inkSoft = Color(red: 0.46, green: 0.49, blue: 0.50)
    static let mapMist = Color(red: 0.84, green: 0.87, blue: 0.86)
    static let mapLine = Color.white.opacity(0.58)
    static let coral = Color(red: 0.78, green: 0.25, blue: 0.22)
    static let line = Color(red: 0.86, green: 0.87, blue: 0.84)

    static let teal = lime
    static let tealPale = lime.opacity(0.22)
}

enum NOWPhoto {
    static let person = "human-city-person-woman"
    static let cafeMeet = "human-city-cafe-meet"
    static let streetCoffee = "human-city-street-coffee"
    static let parkWalkBlur = "human-city-park-walk-blur"
    static let cafeTableBlur = "human-city-cafe-table-blur"
}

struct NOWLogo: View {
    var compact = false

    var body: some View {
        HStack(spacing: compact ? 1 : 2) {
            Text("N")
            ZStack {
                Text("O")
                Circle()
                    .stroke(NOWColor.ink, lineWidth: compact ? 1.6 : 2.4)
                    .frame(width: compact ? 13 : 22, height: compact ? 13 : 22)
                Circle()
                    .fill(NOWColor.lime)
                    .frame(width: compact ? 6 : 10, height: compact ? 6 : 10)
            }
            Text("W")
        }
        .font(.system(size: compact ? 22 : 48, weight: .black, design: .rounded))
        .foregroundStyle(NOWColor.ink)
        .accessibilityLabel("NOW")
    }
}

struct PhotoSurface: View {
    let name: String
    var height: CGFloat
    var blur: CGFloat = 0
    var cornerRadius: CGFloat = 22
    var overlay: LinearGradient = LinearGradient(
        colors: [.clear, Color.black.opacity(0.58)],
        startPoint: .center,
        endPoint: .bottom
    )

    var body: some View {
        BundlePhoto(name: name)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .blur(radius: blur)
            .overlay(overlay)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

struct BundlePhoto: View {
    let name: String

    var body: some View {
        if let url = Bundle.main.url(forResource: name, withExtension: "png"),
           let image = UIImage(contentsOfFile: url.path) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                NOWColor.paper
                Image(systemName: "photo")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(NOWColor.inkSoft)
            }
        }
    }
}

struct NOWBackButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.headline.weight(.black))
                .foregroundStyle(NOWColor.ink)
                .frame(width: 42, height: 42)
                .background(NOWColor.surface.opacity(0.96))
                .clipShape(Circle())
                .overlay(Circle().stroke(NOWColor.line.opacity(0.85), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Back")
    }
}

struct NOWChip: View {
    let text: String
    var active = false

    var body: some View {
        Text(text)
            .font(.caption.weight(.black))
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .foregroundStyle(active ? NOWColor.ink : NOWColor.slate)
            .background(active ? NOWColor.lime : NOWColor.paper)
            .clipShape(Capsule())
    }
}

struct NOWInfoCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
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

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.black))
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .foregroundStyle(NOWColor.ink)
            .background(NOWColor.lime.opacity(configuration.isPressed ? 0.76 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.bold))
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .foregroundStyle(NOWColor.ink)
            .background(NOWColor.paper.opacity(configuration.isPressed ? 0.72 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct DangerButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.bold))
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .foregroundStyle(.white)
            .background(NOWColor.ink.opacity(configuration.isPressed ? 0.82 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
