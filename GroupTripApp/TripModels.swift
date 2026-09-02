import Foundation

struct TripPlace: Identifiable, Hashable {
    let id: UUID
    var name: String
    var note: String
    var tag: String
    var participantIDs: [UUID]

    init(id: UUID = UUID(), name: String, note: String = "", tag: String = "", participantIDs: [UUID] = []) {
        self.id = id
        self.name = name
        self.note = note
        self.tag = tag
        self.participantIDs = participantIDs
    }
}

struct TripPlanningItem: Identifiable, Hashable {
    let id: UUID
    var title: String
    var note: String
    var date: Date?
    var isDone: Bool
    var tag: String
    var participantIDs: [UUID]

    init(id: UUID = UUID(), title: String, note: String = "", date: Date? = nil, isDone: Bool = false, tag: String = "", participantIDs: [UUID] = []) {
        self.id = id
        self.title = title
        self.note = note
        self.date = date
        self.isDone = isDone
        self.tag = tag
        self.participantIDs = participantIDs
    }
}

struct TripTag: RawRepresentable, Hashable, Identifiable {
    enum ItemKind {
        case place
        case planningItem
    }

    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    var id: String { rawValue }

    static let food = TripTag("food")
    static let hotel = TripTag("hotel")
    static let flight = TripTag("flight")
    static let show = TripTag("show")
    static let museum = TripTag("museum")
    static let custom = TripTag("custom")

    static let canonical: [TripTag] = [.food, .hotel, .flight, .show, .museum, .custom]

    static func subset(for itemKind: ItemKind) -> [TripTag] {
        switch itemKind {
        case .place:
            [.food, .hotel, .show, .museum, .custom]
        case .planningItem:
            [.flight, .hotel, .show, .museum, .custom]
        }
    }
}

struct TripPlan: Identifiable {
    let id: UUID
    var destination: String
    var emoji: String
    var imageURL: String
    var startDate: Date
    var endDate: Date
    var viewModel: TripCalculatorViewModel
    var places: [TripPlace]
    var planningItems: [TripPlanningItem]

    init(
        id: UUID = UUID(),
        destination: String = "New destination",
        emoji: String = "✈️",
        imageURL: String = CoverImage.defaultOptions[0].url,
        startDate: Date,
        endDate: Date,
        viewModel: TripCalculatorViewModel,
        places: [TripPlace] = [],
        planningItems: [TripPlanningItem] = []
    ) {
        self.id = id
        self.destination = destination
        self.emoji = emoji
        self.imageURL = imageURL
        self.startDate = startDate
        self.endDate = max(startDate, endDate)
        self.viewModel = viewModel
        self.places = places
        self.planningItems = planningItems
    }

    var status: TripStatus {
        let today = Calendar.current.startOfDay(for: Date())
        let start = Calendar.current.startOfDay(for: startDate)
        let end = Calendar.current.startOfDay(for: endDate)

        if end < today { return .past }
        if start > today { return .future }
        return .current
    }

    var dateRangeText: String {
        if Calendar.current.isDate(startDate, inSameDayAs: endDate) {
            return Self.shortDateFormatter.string(from: startDate)
        }

        return "\(Self.shortDateFormatter.string(from: startDate)) - \(Self.shortDateFormatter.string(from: endDate))"
    }

    var fullDateRangeText: String {
        "\(Self.longDateFormatter.string(from: startDate)) - \(Self.longDateFormatter.string(from: endDate))"
    }

    private static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMM d")
        return formatter
    }()

    private static let longDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMM d yyyy")
        return formatter
    }()
}

enum TripStatus {
    case past
    case current
    case future

    var badgeText: String? {
        switch self {
        case .past: nil
        case .current: "NOW"
        case .future: "UPCOMING"
        }
    }
}

enum TripPlanDate { }

extension Decimal {
    var wholeCurrencyText: String {
        let number = self as NSDecimalNumber
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter.string(from: number) ?? "$0"
    }

    var signedCurrencyText: String {
        if self > 0 {
            return "+\(currencyText)"
        }

        if self < 0 {
            return "-\(abs(self).currencyText)"
        }

        return "$0.00"
    }
}
