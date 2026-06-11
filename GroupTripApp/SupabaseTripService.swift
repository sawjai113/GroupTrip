import Foundation
import Supabase

struct SupabaseTripService {
    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseConfig.client) {
        self.client = client
    }

    func loadTrips() async throws -> [TripPlan] {
        let rows: [SupabaseTripDTO] = try await client
            .from("trips")
            .select()
            .order("start_date", ascending: true)
            .execute()
            .value

        return rows.map { $0.tripPlan() }
    }

    func createTrip(name: String, destination: String, emoji: String, imageURL: String, startDate: Date, endDate: Date) async throws -> TripPlan {
        let session = try await client.auth.session
        let tripID = UUID()
        let remoteTrip = SupabaseTripDTO(
            id: tripID,
            name: name,
            destination: destination,
            emoji: emoji,
            imageURL: imageURL,
            startDate: SupabaseDateFormatter.string(from: startDate),
            endDate: SupabaseDateFormatter.string(from: endDate)
        )

        try await client
            .from("trips")
            .insert(remoteTrip)
            .execute()

        let membership = SupabaseTripMemberDTO(
            id: UUID(),
            tripID: tripID,
            userID: session.user.id,
            guestMemberID: nil,
            displayName: nil,
            role: "owner",
            memberKind: "account"
        )

        try await client
            .from("trip_members")
            .insert(membership)
            .execute()

        return remoteTrip.tripPlan()
    }
}

enum SupabaseDateFormatter {
    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static func date(from string: String?) -> Date? {
        guard let string else { return nil }
        return formatter.date(from: string)
    }

    static func string(from date: Date) -> String {
        formatter.string(from: date)
    }
}

struct SupabaseTripDTO: Codable, Hashable {
    var id: UUID
    var name: String
    var destination: String?
    var emoji: String?
    var imageURL: String?
    var startDate: String
    var endDate: String

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case destination
        case emoji
        case imageURL = "image_url"
        case startDate = "start_date"
        case endDate = "end_date"
    }

    func tripPlan(
        participants: [SupabaseTripParticipantDTO] = [],
        places: [SupabaseTripPlaceDTO] = [],
        planningItems: [SupabaseTripPlanningItemDTO] = [],
        expenses: [SupabaseTripExpenseDTO] = [],
        splits: [SupabaseTripExpenseSplitDTO] = [],
        directPayments: [SupabaseTripDirectPaymentDTO] = []
    ) -> TripPlan {
        let expenseParticipants = participants.map(\.participant)
        let expenseSplits = Dictionary(grouping: splits, by: \.expenseID)
        let expenseItems = expenses.map { expense in
            ExpenseItem(
                id: expense.id,
                title: expense.title,
                paidBy: expense.paidByParticipantID,
                amount: expense.amount,
                participants: Set(expenseSplits[expense.id, default: []].map(\.participantID))
            )
        }
        let payments = directPayments.map(\.directPayment)

        return TripPlan(
            id: id,
            destination: destination ?? "New destination",
            emoji: emoji ?? "✈️",
            imageURL: imageURL ?? CoverImage.defaultOptions[0].url,
            startDate: SupabaseDateFormatter.date(from: startDate) ?? Date(),
            endDate: SupabaseDateFormatter.date(from: endDate) ?? Date(),
            viewModel: TripCalculatorViewModel(
                tripName: name,
                calculator: TripExpenseCalculator(
                    participants: expenseParticipants,
                    expenses: expenseItems,
                    payments: payments
                )
            ),
            places: places.map(\.tripPlace),
            planningItems: planningItems.map(\.tripPlanningItem)
        )
    }
}

struct SupabaseTripMemberDTO: Codable, Hashable {
    var id: UUID
    var tripID: UUID
    var userID: UUID?
    var guestMemberID: UUID?
    var displayName: String?
    var role: String
    var memberKind: String

    enum CodingKeys: String, CodingKey {
        case id
        case tripID = "trip_id"
        case userID = "user_id"
        case guestMemberID = "guest_member_id"
        case displayName = "display_name"
        case role
        case memberKind = "member_kind"
    }

    var tripMember: TripMember {
        TripMember(
            id: id,
            displayName: displayName ?? "Traveler",
            role: tripMemberRole,
            accountID: userID
        )
    }

    private var tripMemberRole: TripMember.Role {
        switch role {
        case "owner": .owner
        case "member": .member
        default: .guest
        }
    }
}

struct SupabaseTripParticipantDTO: Codable, Hashable {
    var id: UUID
    var tripID: UUID
    var displayName: String
    var linkedMemberID: UUID?
    var linkedUserID: UUID?
    var isOrganizer: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case tripID = "trip_id"
        case displayName = "display_name"
        case linkedMemberID = "linked_member_id"
        case linkedUserID = "linked_user_id"
        case isOrganizer = "is_organizer"
    }

    var participant: Participant {
        Participant(id: id, name: displayName)
    }

    var expenseParticipant: ExpenseParticipant {
        ExpenseParticipant(id: id, displayName: displayName, linkedMemberID: linkedMemberID)
    }
}

struct SupabaseTripPlaceDTO: Codable, Hashable {
    var id: UUID
    var tripID: UUID
    var name: String
    var note: String
    var category: String
    var googlePlaceID: String?
    var latitude: Double?
    var longitude: Double?

    enum CodingKeys: String, CodingKey {
        case id
        case tripID = "trip_id"
        case name
        case note
        case category
        case googlePlaceID = "google_place_id"
        case latitude
        case longitude
    }

    var tripPlace: TripPlace {
        TripPlace(id: id, name: name, note: note, category: category)
    }
}

struct SupabaseTripPlanningItemDTO: Codable, Hashable {
    var id: UUID
    var tripID: UUID
    var title: String
    var note: String
    var scheduledDate: String?
    var isDone: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case tripID = "trip_id"
        case title
        case note
        case scheduledDate = "scheduled_date"
        case isDone = "is_done"
    }

    var tripPlanningItem: TripPlanningItem {
        TripPlanningItem(
            id: id,
            title: title,
            note: note,
            date: SupabaseDateFormatter.date(from: scheduledDate),
            isDone: isDone
        )
    }
}

struct SupabaseTripExpenseDTO: Codable, Hashable {
    var id: UUID
    var tripID: UUID
    var title: String
    var paidByParticipantID: UUID
    var amount: Decimal
    var currencyCode: String
    var incurredOn: String?

    enum CodingKeys: String, CodingKey {
        case id
        case tripID = "trip_id"
        case title
        case paidByParticipantID = "paid_by_participant_id"
        case amount
        case currencyCode = "currency_code"
        case incurredOn = "incurred_on"
    }
}

struct SupabaseTripExpenseSplitDTO: Codable, Hashable {
    var expenseID: UUID
    var participantID: UUID
    var shareAmount: Decimal?

    enum CodingKeys: String, CodingKey {
        case expenseID = "expense_id"
        case participantID = "participant_id"
        case shareAmount = "share_amount"
    }
}

struct SupabaseTripDirectPaymentDTO: Codable, Hashable {
    var id: UUID
    var tripID: UUID
    var title: String
    var fromParticipantID: UUID
    var toParticipantID: UUID
    var amount: Decimal
    var currencyCode: String
    var paidOn: String?

    enum CodingKeys: String, CodingKey {
        case id
        case tripID = "trip_id"
        case title
        case fromParticipantID = "from_participant_id"
        case toParticipantID = "to_participant_id"
        case amount
        case currencyCode = "currency_code"
        case paidOn = "paid_on"
    }

    var directPayment: DirectPayment {
        DirectPayment(
            id: id,
            title: title,
            from: fromParticipantID,
            to: toParticipantID,
            amount: amount
        )
    }
}
