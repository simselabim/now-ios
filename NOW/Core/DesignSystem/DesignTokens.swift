import SwiftUI

enum NOWColor {
    static let paper = Color(red: 0.97, green: 0.98, blue: 0.96)
    static let ink = Color(red: 0.09, green: 0.13, blue: 0.13)
    static let inkSoft = Color(red: 0.36, green: 0.41, blue: 0.40)
    static let teal = Color(red: 0.03, green: 0.66, blue: 0.61)
    static let tealPale = Color(red: 0.85, green: 0.95, blue: 0.94)
    static let coral = Color(red: 1.0, green: 0.45, blue: 0.35)
    static let line = Color(red: 0.86, green: 0.89, blue: 0.87)
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .foregroundStyle(.white)
            .background(NOWColor.teal.opacity(configuration.isPressed ? 0.82 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .foregroundStyle(NOWColor.teal)
            .background(NOWColor.tealPale.opacity(configuration.isPressed ? 0.72 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct DangerButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .foregroundStyle(NOWColor.coral)
            .background(NOWColor.coral.opacity(0.14))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
