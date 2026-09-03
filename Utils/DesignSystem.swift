import AppKit
import SwiftUI

enum AppTheme {
    static let accent = Color(
        light: "3B73B1",
        dark: "78B4EE",
        highContrastLight: "2A5F99",
        highContrastDark: "9BCBFA"
    )
    static let accentStrong = Color(
        light: "24588F",
        dark: "A8D2FA",
        highContrastLight: "174872",
        highContrastDark: "C2DFFF"
    )
    static let accentSoft = Color(
        light: "E8F1FA",
        dark: "26394D",
        highContrastLight: "DCEAF7",
        highContrastDark: "1F3346"
    )

    static let background = Color(light: "F4F5F7", dark: "1C1D1F")
    static let surface = Color(light: "FCFCFD", dark: "282A2D")
    static let surfaceRaised = Color(light: "FFFFFF", dark: "303236")
    static let textPrimary = Color(light: "24262A", dark: "F2F3F5")
    static let textSecondary = Color(light: "686D75", dark: "A7ABB2")
    static let divider = Color(light: "DEE1E6", dark: "41444A")

    static let success = Color(light: "437A59", dark: "71B889")
    static let warning = Color(light: "B7792A", dark: "E4A954")
    static let danger = Color(light: "B94A48", dark: "E77A76")

    enum Spacing {
        static let xs: CGFloat = 4
        static let small: CGFloat = 8
        static let medium: CGFloat = 16
        static let large: CGFloat = 24
        static let xLarge: CGFloat = 32
    }

    enum Radius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
    }

    enum FontStyle {
        static let display = Font.system(size: 30, weight: .bold, design: .serif)
        static let heading = Font.system(size: 20, weight: .semibold)
        static let subheading = Font.system(size: 15, weight: .semibold)
        static let body = Font.system(size: 14)
        static let caption = Font.system(size: 12)
    }
}

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)

        let red: UInt64
        let green: UInt64
        let blue: UInt64
        let alpha: UInt64

        switch cleaned.count {
        case 3:
            red = (value >> 8) * 17
            green = (value >> 4 & 0xF) * 17
            blue = (value & 0xF) * 17
            alpha = 255
        case 8:
            alpha = value >> 24
            red = value >> 16 & 0xFF
            green = value >> 8 & 0xFF
            blue = value & 0xFF
        default:
            red = value >> 16
            green = value >> 8 & 0xFF
            blue = value & 0xFF
            alpha = 255
        }

        self.init(
            .sRGB,
            red: Double(red) / 255,
            green: Double(green) / 255,
            blue: Double(blue) / 255,
            opacity: Double(alpha) / 255
        )
    }

    init(light lightHex: String, dark darkHex: String) {
        self.init(
            light: lightHex,
            dark: darkHex,
            highContrastLight: lightHex,
            highContrastDark: darkHex
        )
    }

    init(
        light lightHex: String,
        dark darkHex: String,
        highContrastLight highContrastLightHex: String,
        highContrastDark highContrastDarkHex: String
    ) {
        self.init(
            nsColor: NSColor(name: nil) { appearance in
                switch appearance.bestMatch(from: [
                    .accessibilityHighContrastDarkAqua,
                    .accessibilityHighContrastAqua,
                    .darkAqua,
                    .aqua,
                ]) {
                case .accessibilityHighContrastDarkAqua:
                    return NSColor(Color(hex: highContrastDarkHex))
                case .accessibilityHighContrastAqua:
                    return NSColor(Color(hex: highContrastLightHex))
                case .darkAqua:
                    return NSColor(Color(hex: darkHex))
                default:
                    return NSColor(Color(hex: lightHex))
                }
            }
        )
    }
}

struct AppCardModifier: ViewModifier {
    var padding: CGFloat = AppTheme.Spacing.medium

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.Radius.medium, style: .continuous)
                    .stroke(AppTheme.divider.opacity(0.8), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.035), radius: 10, y: 3)
    }
}

extension View {
    func appCard(padding: CGFloat = AppTheme.Spacing.medium) -> some View {
        modifier(AppCardModifier(padding: padding))
    }
}
