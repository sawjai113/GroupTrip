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
    var time: Date?
    var isDone: Bool
    var tag: String
    var participantIDs: [UUID]

    init(id: UUID = UUID(), title: String, note: String = "", date: Date? = nil, time: Date? = nil, isDone: Bool = false, tag: String = "", participantIDs: [UUID] = []) {
        self.id = id
        self.title = title
        self.note = note
        self.date = date
        self.time = date == nil ? nil : time
        self.isDone = isDone
        self.tag = tag
        self.participantIDs = participantIDs
    }
}

struct PlanningDaySection: Equatable {
    var date: Date
    var items: [TripPlanningItem]
}

enum PlanningTimeline {
    static func sections(from items: [TripPlanningItem], calendar: Calendar = .current) -> (dated: [PlanningDaySection], undated: [TripPlanningItem]) {
        let indexedItems = items.enumerated().map { index, item in
            IndexedPlanningItem(index: index, item: item)
        }
        let datedItems = indexedItems.compactMap { indexed -> (date: Date, indexed: IndexedPlanningItem)? in
            guard let date = indexed.item.date else { return nil }
            return (calendar.startOfDay(for: date), indexed)
        }
        let dates = Array(Set(datedItems.map(\.date))).sorted()
        let sections = dates.map { date in
            let dayItems = datedItems
                .filter { $0.date == date }
                .map(\.indexed)
                .sorted { lhs, rhs in
                    switch (lhs.item.time, rhs.item.time) {
                    case let (lhsTime?, rhsTime?):
                        let lhsComponents = calendar.dateComponents([.hour, .minute], from: lhsTime)
                        let rhsComponents = calendar.dateComponents([.hour, .minute], from: rhsTime)
                        if lhsComponents.hour != rhsComponents.hour {
                            return (lhsComponents.hour ?? 0) < (rhsComponents.hour ?? 0)
                        }
                        if lhsComponents.minute != rhsComponents.minute {
                            return (lhsComponents.minute ?? 0) < (rhsComponents.minute ?? 0)
                        }
                        return lhs.index < rhs.index
                    case (_?, nil):
                        return true
                    case (nil, _?):
                        return false
                    case (nil, nil):
                        return lhs.index < rhs.index
                    }
                }
                .map(\.item)
            return PlanningDaySection(date: date, items: dayItems)
        }
        let undated = indexedItems.filter { $0.item.date == nil }.map(\.item)
        return (sections, undated)
    }

    private struct IndexedPlanningItem {
        var index: Int
        var item: TripPlanningItem
    }
}

enum PlanningDateTimeInput {
    static func resolvedDate(hasDate: Bool, date: Date) -> Date? {
        hasDate ? date : nil
    }

    static func resolvedTime(hasDate: Bool, hasTime: Bool, time: Date) -> Date? {
        hasDate && hasTime ? time : nil
    }
}

struct PeopleHall: Equatable {
    var organizers: [Participant]
    var travelers: [Participant]

    static func grouped(_ participants: [Participant]) -> PeopleHall {
        PeopleHall(
            organizers: participants.filter(\.isOrganizer).sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending },
            travelers: participants.filter { !$0.isOrganizer }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        )
    }

    static func grouped(_ participants: Participant...) -> PeopleHall {
        grouped(participants)
    }
}

/// Trip-relative money status. Foundation-only — the view layer maps the phrase
/// to a tint (TripStatus.tint precedent).
enum PersonBalancePhrase: Equatable {
    case getsBack(Decimal)
    case owes(Decimal)
    case settled

    init(net: Decimal) {
        if net > 0 {
            self = .getsBack(net)
        } else if net < 0 {
            self = .owes(-net)
        } else {
            self = .settled
        }
    }

    var text: String {
        switch self {
        case let .getsBack(amount):
            "Gets back \(amount.wholeCurrencyText)"
        case let .owes(amount):
            "Owes \(amount.wholeCurrencyText)"
        case .settled:
            "Settled"
        }
    }
}

enum PersonBalance {
    static func phrase(net: Decimal) -> PersonBalancePhrase {
        PersonBalancePhrase(net: net)
    }
}

struct PersonFootprint: Equatable {
    var paidExpenses: [ExpenseItem]
    var sharedExpenses: [ExpenseItem]
    var places: [TripPlace]
    var plans: [TripPlanningItem]

    static func aggregate(
        participantID: Participant.ID,
        tripID _: TripPlan.ID,
        expenses: [ExpenseItem],
        places: [TripPlace],
        planningItems: [TripPlanningItem]
    ) -> PersonFootprint {
        PersonFootprint(
            paidExpenses: expenses
                .filter { $0.paidBy == participantID }
                .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending },
            sharedExpenses: expenses
                .filter { $0.paidBy != participantID && $0.participants.contains(participantID) }
                .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending },
            places: places
                .filter { $0.participantIDs.contains(participantID) }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending },
            plans: planningItems
                .filter { $0.participantIDs.contains(participantID) }
                .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        )
    }
}

struct ParticipantSelection: Equatable {
    private var ordered: [UUID]
    private var membership: Set<UUID>

    init(participantIDs: [UUID] = []) {
        ordered = []
        membership = []
        for id in participantIDs where !membership.contains(id) {
            ordered.append(id)
            membership.insert(id)
        }
    }

    var orderedIDs: [UUID] { ordered }

    func contains(_ participantID: UUID) -> Bool {
        membership.contains(participantID)
    }

    mutating func toggle(_ participantID: UUID) {
        if membership.contains(participantID) {
            membership.remove(participantID)
            ordered.removeAll { $0 == participantID }
        } else {
            membership.insert(participantID)
            ordered.append(participantID)
        }
    }

    mutating func set(_ participantID: UUID, isSelected: Bool) {
        if isSelected != membership.contains(participantID) {
            toggle(participantID)
        }
    }
}

enum TripShareTextBuilder {
    static func text(tripName: String, inviteCode: String?) -> String? {
        let trimmedCode = (inviteCode ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        guard !trimmedCode.isEmpty else { return nil }
        let trimmedTripName = tripName.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName = trimmedTripName.isEmpty ? "this trip" : trimmedTripName
        return "Join \(displayName) on Wanderaid — invite code \(trimmedCode)"
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
            [.food, .hotel, .show, .museum]
        case .planningItem:
            [.flight, .hotel, .show, .museum, .custom]
        }
    }
}

struct PlaceTagInput: Equatable {
    var selectedTag: TripTag?
    var customText: String

    init(selectedTag: TripTag? = nil, customText: String = "") {
        self.selectedTag = selectedTag
        self.customText = customText
    }

    init(prefilling tag: String) {
        let trimmed = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            self.selectedTag = nil
            self.customText = ""
        } else if let canonical = TripTag.subset(for: .place).first(where: { $0.rawValue == trimmed }) {
            self.selectedTag = canonical
            self.customText = ""
        } else {
            self.selectedTag = .custom
            self.customText = trimmed
        }
    }

    var resolvedTag: String {
        let custom = customText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !custom.isEmpty { return custom }
        return selectedTag?.rawValue == TripTag.custom.rawValue ? "" : selectedTag?.rawValue ?? ""
    }
}

extension Array where Element == TripPlace {
    func filtered(by tag: TripTag?) -> [TripPlace] {
        guard let tag else { return self }
        let normalized = tag.rawValue.lowercased()
        return filter {
            $0.tag.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalized
        }
    }
}

struct PlaceMapsLink: Equatable {
    let appURL: URL
    let webURL: URL

    init?(name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return nil }

        var appComponents = URLComponents()
        appComponents.scheme = "comgooglemaps"
        appComponents.host = ""
        appComponents.queryItems = [URLQueryItem(name: "q", value: trimmedName)]

        var webComponents = URLComponents()
        webComponents.scheme = "https"
        webComponents.host = "www.google.com"
        webComponents.path = "/maps/search/"
        webComponents.queryItems = [
            URLQueryItem(name: "api", value: "1"),
            URLQueryItem(name: "query", value: trimmedName)
        ]

        guard let appURL = appComponents.url, let webURL = webComponents.url else { return nil }
        self.appURL = appURL
        self.webURL = webURL
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
