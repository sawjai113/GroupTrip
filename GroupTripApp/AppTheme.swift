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
