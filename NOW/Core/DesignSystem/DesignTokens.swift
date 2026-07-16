import SwiftUI
import UIKit

enum NOWColor {
    static let lime = Color(red: 1.0, green: 0.73, blue: 0.25)
    static let limeSoft = Color(red: 1.0, green: 0.86, blue: 0.45)
    static let paper = Color(red: 1.0, green: 0.96, blue: 0.88)
    static let surface = Color(red: 1.0, green: 0.98, blue: 0.94)
    static let ink = Color(red: 0.19, green: 0.11, blue: 0.18)
    static let slate = Color(red: 0.38, green: 0.25, blue: 0.19)
    static let inkSoft = Color(red: 0.54, green: 0.42, blue: 0.33)
    static let mapMist = Color(red: 0.94, green: 0.77, blue: 0.62)
    static let mapLine = Color.white.opacity(0.42)
    static let coral = Color(red: 0.94, green: 0.32, blue: 0.43)
    static let line = Color(red: 0.85, green: 0.76, blue: 0.65)

    static let laCream = Color(red: 1.0, green: 0.95, blue: 0.85)
    static let laMapBase = Color(red: 0.93, green: 0.75, blue: 0.62)
    static let laMauve = Color(red: 0.49, green: 0.41, blue: 0.46)
    static let laBrown = Color(red: 0.34, green: 0.19, blue: 0.09)
    static let laBrownSoft = Color(red: 0.46, green: 0.34, blue: 0.31)
    static let laEspresso = Color(red: 0.19, green: 0.11, blue: 0.18)
    static let laCoral = Color(red: 0.94, green: 0.32, blue: 0.43)
    static let laOrange = Color(red: 1.0, green: 0.61, blue: 0.31)
    static let laGold = Color(red: 1.0, green: 0.82, blue: 0.42)
    static let laBlush = Color(red: 1.0, green: 0.47, blue: 0.50)
    static let laGreen = Color(red: 0.42, green: 0.78, blue: 0.56)

    static let teal = lime
    static let tealPale = lime.opacity(0.22)
}

enum LAGradient {
    static let sunset = LinearGradient(
        colors: [NOWColor.laGold, NOWColor.laOrange, NOWColor.laCoral],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let match = LinearGradient(
        colors: [
            NOWColor.laOrange,
            NOWColor.laBlush,
            NOWColor.laCoral,
            NOWColor.laEspresso
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    static let mapWash = LinearGradient(
        colors: [
            NOWColor.laMapBase.opacity(0.52),
            NOWColor.laCoral.opacity(0.18),
            NOWColor.laEspresso.opacity(0.34)
        ],
        startPoint: .top,
        endPoint: .bottom
    )
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
        HStack(spacing: compact ? 5 : 8) {
            Text("NOW")
            Circle()
                .fill(NOWColor.laOrange)
                .frame(width: compact ? 7 : 11, height: compact ? 7 : 11)
        }
        .font(.system(size: compact ? 15 : 44, weight: .heavy, design: .rounded))
        .tracking(compact ? 1.2 : 0)
        .foregroundStyle(compact ? NOWColor.surface : NOWColor.ink)
        .padding(.horizontal, compact ? 12 : 0)
        .padding(.vertical, compact ? 8 : 0)
        .background(compact ? NOWColor.laBrownSoft.opacity(0.92) : .clear)
        .clipShape(Capsule())
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
            .foregroundStyle(active ? NOWColor.surface : NOWColor.laBrown)
            .background(active ? NOWColor.laCoral : NOWColor.surface)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(active ? Color.clear : NOWColor.laBrown.opacity(0.62), lineWidth: 1.2))
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
            .foregroundStyle(NOWColor.surface)
            .background(LAGradient.sunset.opacity(configuration.isPressed ? 0.78 : 1))
            .clipShape(Capsule())
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.bold))
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .foregroundStyle(NOWColor.laBrown)
            .background(NOWColor.surface.opacity(configuration.isPressed ? 0.72 : 1))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(NOWColor.laBrown.opacity(0.35), lineWidth: 1))
    }
}

struct DangerButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.bold))
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .foregroundStyle(.white)
            .background(NOWColor.laBrown.opacity(configuration.isPressed ? 0.82 : 1))
            .clipShape(Capsule())
    }
}

struct LATopStripe: View {
    var body: some View {
        HStack(spacing: 0) {
            NOWColor.laCoral
            NOWColor.laOrange
            NOWColor.laGold
            NOWColor.laGreen
        }
        .frame(height: 5)
        .ignoresSafeArea(edges: .top)
    }
}

struct LAPill: View {
    let text: String
    var icon: String?
    var tint: Color = NOWColor.laBrownSoft
    var foreground: Color = NOWColor.surface

    var body: some View {
        HStack(spacing: 6) {
            if let icon {
                Circle()
                    .fill(tint)
                    .frame(width: 9, height: 9)
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 5, weight: .black))
                            .foregroundStyle(foreground)
                    )
            }
            Text(text)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .font(.caption2.weight(.heavy))
        .foregroundStyle(foreground)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(NOWColor.laBrownSoft.opacity(0.92))
        .clipShape(Capsule())
    }
}
