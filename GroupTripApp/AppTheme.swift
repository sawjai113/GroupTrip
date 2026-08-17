import SwiftUI

enum AppTheme {
    static let primary = Color(red: 0.10, green: 0.46, blue: 0.82)
    static let success = Color(red: 0.30, green: 0.69, blue: 0.31)
    static let error = Color(red: 0.96, green: 0.26, blue: 0.21)
    static let warning = Color(red: 1.00, green: 0.60, blue: 0.00)
    static let purple = Color(red: 0.61, green: 0.15, blue: 0.69)
    static let lightBlue = Color(red: 0.13, green: 0.59, blue: 0.95)
    static let background = Color(.systemGroupedBackground)
    static let paper = Color(.systemBackground)
    static let card = Color(.secondarySystemGroupedBackground)

    enum Spacing {
        static let xSmall: CGFloat = 4
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let xLarge: CGFloat = 24
    }

    enum Radius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 14
        static let large: CGFloat = 16
        static let xLarge: CGFloat = 18
    }

    enum IconSize {
        static let small: CGFloat = 32
        static let medium: CGFloat = 44
        static let large: CGFloat = 48
        static let xLarge: CGFloat = 62
    }

    enum FeatureColor {
        static let trip = AppTheme.primary
        static let people = AppTheme.purple
        static let itinerary = AppTheme.warning
        static let places = AppTheme.error
        static let expenses = AppTheme.primary
        static let chat = AppTheme.lightBlue
        static let map = AppTheme.success
    }

    // MARK: - Calm Editorial palette

    /// Builds a dynamic color from the Calm Editorial light/dark hex values
    /// (design variants `001c` light / `001d` dark).
    private static func editorialColor(
        light: (Double, Double, Double),
        dark: (Double, Double, Double)
    ) -> Color {
        Color(uiColor: UIColor { traitCollection in
            let components = traitCollection.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: components.0, green: components.1, blue: components.2, alpha: 1)
        })
    }

    /// Semantic tokens for the Calm Editorial dashboard direction.
    /// Warm paper tones in light mode; warm near-black/brown surfaces and
    /// cream/ink typography in dark mode, with a forest-green accent.
    enum Editorial {
        /// Page background (warm paper / warm near-black).
        static let background = AppTheme.editorialColor(
            light: (0.969, 0.949, 0.910), // #F7F2E8
            dark: (0.071, 0.063, 0.055)   // #12100E
        )

        /// Standard card surface.
        static let card = AppTheme.editorialColor(
            light: (1.000, 0.992, 0.973), // #FFFDF8
            dark: (0.137, 0.118, 0.094)   // #231E18
        )

        /// Card surface one step above `card` (highlighted/expanded surfaces).
        static let raisedCard = AppTheme.editorialColor(
            light: (1.000, 1.000, 1.000), // #FFFFFF
            dark: (0.165, 0.137, 0.110)   // #2A231C
        )

        /// Hairline borders between surfaces.
        static let border = AppTheme.editorialColor(
            light: (0.902, 0.851, 0.776), // #E6D9C6
            dark: (0.271, 0.224, 0.176)   // #45392D
        )

        /// Primary text (warm ink / cream).
        static let primaryText = AppTheme.editorialColor(
            light: (0.149, 0.122, 0.090), // #261F17
            dark: (0.965, 0.933, 0.882)   // #F6EEE1
        )

        /// Secondary text.
        static let secondaryText = AppTheme.editorialColor(
            light: (0.475, 0.431, 0.376), // #796E60
            dark: (0.722, 0.663, 0.569)   // #B8A991
        )

        /// Forest-green accent color.
        static let forest = AppTheme.editorialColor(
            light: (0.184, 0.408, 0.306), // #2F684E
            dark: (0.514, 0.773, 0.608)   // #83C59B
        )

        /// Deep forest green for emphasis/buttons on top of `forest`.
        static let forestDeep = AppTheme.editorialColor(
            light: (0.122, 0.310, 0.224), // #1F4F39
            dark: (0.741, 0.925, 0.796)   // #BDECCB
        )

        /// Warm amber accent (demo mode, highlights).
        static let sand = AppTheme.editorialColor(
            light: (0.773, 0.553, 0.325), // #C58D53
            dark: (0.851, 0.655, 0.404)   // #D9A767
        )

        /// "Owed to you" terracotta.
        static let owed = AppTheme.editorialColor(
            light: (0.655, 0.373, 0.231), // #A75F3B
            dark: (0.886, 0.545, 0.404)   // #E28B67
        )

        /// "You owe" forest green.
        static let due = AppTheme.editorialColor(
            light: (0.184, 0.408, 0.306), // #2F684E
            dark: (0.514, 0.773, 0.608)   // #83C59B
        )
    }
}

struct CoverImage: Identifiable, Hashable {
    let id = UUID()
    var url: String
    var title: String

    static let defaultOptions = [
        CoverImage(url: "https://images.unsplash.com/photo-1506869640319-fe1a24fd76dc?w=800", title: "Mountain adventure"),
        CoverImage(url: "https://images.unsplash.com/photo-1529156069898-49953e39b3ac?w=800", title: "Friends traveling"),
        CoverImage(url: "https://images.unsplash.com/photo-1539635278303-d4002c07eae3?w=800", title: "Group celebration"),
        CoverImage(url: "https://images.unsplash.com/photo-1488646953014-85cb44e25828?w=800", title: "City skyline"),
        CoverImage(url: "https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=800", title: "Beach paradise"),
        CoverImage(url: "https://images.unsplash.com/photo-1476514525535-07fb3b4ae5f1?w=800", title: "Lake view")
    ]
}
