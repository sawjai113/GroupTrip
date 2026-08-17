import SwiftUI

/// Persisted app-level appearance preference.
///
/// Stored as a plain raw-string `@AppStorage` value under the key
/// `wanderaid.appearance`. This is a local, non-secret UI preference and is
/// intentionally independent of auth/session state.
enum AppAppearance: String, CaseIterable, Identifiable {
    case auto
    case light
    case dark

    var id: String { rawValue }

    /// User-facing label shown in menus and pickers.
    var displayName: String {
        switch self {
        case .auto:
            return "Auto"
        case .light:
            return "Light"
        case .dark:
            return "Dark"
        }
    }

    /// SF Symbol shown next to each option in the appearance picker.
    var systemImage: String {
        switch self {
        case .auto:
            return "circle.lefthalf.filled"
        case .light:
            return "sun.max"
        case .dark:
            return "moon"
        }
    }

    /// Color scheme override for `.preferredColorScheme(...)`.
    /// `nil` follows the system appearance.
    var preferredColorScheme: ColorScheme? {
        switch self {
        case .auto:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }

    /// Safe parser: unknown or missing stored values fall back to `.auto`.
    static func parse(_ rawValue: String?) -> AppAppearance {
        rawValue.flatMap(AppAppearance.init(rawValue:)) ?? .auto
    }
}
