import SwiftUI
import UIKit

// MARK: - Colors

enum AppColor {
    // Primary — neon violet
    static let accent = Color(light: .init(hex: "A855F7"), dark: .init(hex: "8B5CF6"))
    static let accentGradient = LinearGradient(
        colors: [Color(hex: "A855F7"), Color(hex: "7E22CE")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // Chat Bubbles
    static let userBubble = Color(light: .init(hex: "A855F7"), dark: .init(hex: "8B5CF6"))
    static let userBubbleGradient = LinearGradient(
        colors: [Color(hex: "A855F7"), Color(hex: "7E22CE")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let assistantBubble = Color(light: .init(hex: "2D1B44"), dark: .init(hex: "2D1B44"))

    // Difficulty
    static let difficultyEasy = Color(light: .init(hex: "22C55E"), dark: .init(hex: "22C55E")) // Bright green
    static let difficultyMedium = Color(light: .init(hex: "F59E0B"), dark: .init(hex: "F59E0B")) // Amber
    static let difficultyHard = Color(light: .init(hex: "EF4444"), dark: .init(hex: "EF4444")) // Red

    // Surfaces
    static let cardBackground = Color(light: .init(hex: "2D1B44"), dark: .init(hex: "2D1B44"))
    static let surfaceElevated = Color(light: .init(hex: "2D1B44"), dark: .init(hex: "2D1B44"))
    static let surfacePrimary = Color(light: .init(hex: "150B24"), dark: .init(hex: "150B24"))
    static let pageBackground = Color(light: .init(hex: "150B24"), dark: .init(hex: "150B24"))

    // Gamification
    static let streakFlame = Color(light: .init(hex: "F97316"), dark: .init(hex: "F97316"))
    static let xpGold = Color(light: .init(hex: "FBBF24"), dark: .init(hex: "FBBF24"))

    // Gamification gradients
    static let streakGradient = LinearGradient(
        colors: [Color(hex: "F97316"), Color(hex: "DC2626")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let xpGradient = LinearGradient(
        colors: [Color(hex: "FBBF24"), Color(hex: "F59E0B")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let levelGradientColors: [Color] = [
        Color(hex: "8B5CF6"), Color(hex: "6D28D9"),
        Color(hex: "A855F7"), Color(hex: "7C3AED")
    ]
    static let progressRingGradient = AngularGradient(
        colors: [Color(hex: "8B5CF6"), Color(hex: "A855F7"), Color(hex: "C084FC"), Color(hex: "8B5CF6")],
        center: .center,
        startAngle: .degrees(-90),
        endAngle: .degrees(270)
    )
    static let cardBorder = Color.white.opacity(0.06)

    // Semantic
    static let success = Color(light: .init(hex: "6B8F4E"), dark: .init(hex: "7DA35C"))
    static let warning = Color(light: .init(hex: "D4964E"), dark: .init(hex: "E0A862"))
    static let error = Color(light: .init(hex: "C45B4E"), dark: .init(hex: "D46B5E"))

    // Code
    static let codeBackground = Color(light: .init(hex: "F2EFE9"), dark: .init(hex: "2A2622"))
    static let codeText = Color(light: .init(hex: "3A3A3A"), dark: .init(hex: "D4D4D4"))
    static let codeKeyword = Color(light: .init(hex: "9B59B6"), dark: .init(hex: "C586C0"))
    static let codeString = Color(light: .init(hex: "E67E22"), dark: .init(hex: "CE9178"))
    static let codeComment = Color(light: .init(hex: "7F8C8D"), dark: .init(hex: "7A7A6E"))
    static let codeNumber = Color(light: .init(hex: "27AE60"), dark: .init(hex: "B5CEA8"))
    static let codeType = Color(light: .init(hex: "D35400"), dark: .init(hex: "DCDCAA"))
    static let codeBuiltin = Color(light: .init(hex: "2980B9"), dark: .init(hex: "9CDCFE"))
}

// MARK: - Typography

enum AppFont {
    static let largeTitle: Font = .system(.largeTitle, design: .rounded).weight(.black)
    static let title: Font = .system(.title, design: .rounded).weight(.black)
    static let title2: Font = .system(.title2, design: .rounded).weight(.heavy)
    static let title3: Font = .system(.title3, design: .rounded).weight(.bold)
    static let headline: Font = .system(.headline, design: .rounded).weight(.bold)
    static let body: Font = .system(.body, design: .rounded).weight(.medium)
    static let callout: Font = .system(.callout, design: .rounded).weight(.medium)
    static let subheadline: Font = .system(.subheadline, design: .rounded).weight(.medium)
    static let caption: Font = .system(.caption, design: .rounded).weight(.medium)
    static let caption2: Font = .system(.caption2, design: .default)
    static let codeBlock: Font = .system(size: 14, design: .monospaced)
    static let codeInline: Font = .system(size: 13, design: .monospaced)
}

// MARK: - Spacing

enum AppSpacing {
    static let xxs: CGFloat = 2
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 24
    static let xxxl: CGFloat = 32
}

// MARK: - Corner Radius

enum AppRadius {
    static let small: CGFloat = 16
    static let medium: CGFloat = 20
    static let large: CGFloat = 28
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 40
    static let pill: CGFloat = 100
}

// MARK: - Shadows

struct CardShadow: ViewModifier {
    func body(content: Content) -> some View {
        // Solid bottom lip (no blur) for dark mode
        content.shadow(color: Color.black.opacity(0.4), radius: 0, x: 0, y: 4)
    }
}

struct ElevatedShadow: ViewModifier {
    func body(content: Content) -> some View {
        content.shadow(color: Color.black.opacity(0.5), radius: 0, x: 0, y: 6)
    }
}

struct SoftShadow: ViewModifier {
    func body(content: Content) -> some View {
        content.shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 4)
    }
}

extension View {
    func cardShadow() -> some View { modifier(CardShadow()) }
    func elevatedShadow() -> some View { modifier(ElevatedShadow()) }
    func softShadow() -> some View { modifier(SoftShadow()) }
}

// MARK: - Color Helpers

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    init(light: Color, dark: Color) {
        self.init(uiColor: UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(dark)
                : UIColor(light)
        })
    }
}

// MARK: - Difficulty Color Extension

import Foundation

extension Difficulty {
    var color: Color {
        switch self {
        case .easy: return AppColor.difficultyEasy
        case .medium: return AppColor.difficultyMedium
        case .hard: return AppColor.difficultyHard
        }
    }
}
