import Foundation
import Supabase

protocol TripSyncServicing {
    func loadTrips() async throws -> [TripPlan]
    func createTrip(name: String, destination: String, emoji: String, imageURL: String, startDate: Date, endDate: Date) async throws -> TripPlan
    func createPlace(_ place: TripPlace, in tripID: UUID) async throws -> TripPlace
    func deletePlace(_ placeID: UUID, from tripID: UUID) async throws
    func createInvite(for tripID: UUID, role: TripInvite.Role) async throws -> TripInvite
    func lookupInvite(code: String) async throws -> TripInvitePreview?
    func acceptInvite(code: String) async throws
}

struct SupabaseTripService: TripSyncServicing {
    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseConfig.client) {
        self.client = client
    }

    func loadTrips() async throws -> [TripPlan] {
        let tripRows: [SupabaseTripDTO] = try await client
            .from("trips")
            .select()
            .order("start_date", ascending: true)
            .execute()
            .value

        let tripIDs = tripRows.map(\.id)
        guard !tripIDs.isEmpty else { return [] }
        let tripIDFilters = tripIDs.map { $0 as any PostgrestFilterValue }

        let participants: [SupabaseTripParticipantDTO] = try await client
            .from("trip_participants")
            .select()
            .in("trip_id", values: tripIDFilters)
            .execute()
            .value

        let places: [SupabaseTripPlaceDTO] = try await client
            .from("trip_places")
            .select()
            .in("trip_id", values: tripIDFilters)
            .order("created_at", ascending: true)
            .execute()
            .value

        let planningItems: [SupabaseTripPlanningItemDTO] = try await client
            .from("trip_planning_items")
            .select()
            .in("trip_id", values: tripIDFilters)
            .order("scheduled_date", ascending: true)
            .order("created_at", ascending: true)
            .execute()
            .value

        let expenses: [SupabaseTripExpenseDTO] = try await client
            .from("trip_expenses")
            .select()
            .in("trip_id", values: tripIDFilters)
            .order("incurred_on", ascending: true)
            .order("created_at", ascending: true)
            .execute()
            .value

        let expenseIDs = expenses.map(\.id)
        let splits: [SupabaseTripExpenseSplitDTO]
        if expenseIDs.isEmpty {
            splits = []
        } else {
            let expenseIDFilters = expenseIDs.map { $0 as any PostgrestFilterValue }
            splits = try await client
                .from("trip_expense_splits")
                .select()
                .in("expense_id", values: expenseIDFilters)
                .execute()
                .value
        }

        let directPayments: [SupabaseTripDirectPaymentDTO] = try await client
            .from("trip_direct_payments")
            .select()
            .in("trip_id", values: tripIDFilters)
            .order("paid_on", ascending: true)
            .order("created_at", ascending: true)
            .execute()
            .value

        return Self.assembleTrips(
            trips: tripRows,
            participants: participants,
            places: places,
            planningItems: planningItems,
            expenses: expenses,
            splits: splits,
            directPayments: directPayments
        )
    }

    static func assembleTrips(
        trips: [SupabaseTripDTO],
        participants: [SupabaseTripParticipantDTO],
        places: [SupabaseTripPlaceDTO],
        planningItems: [SupabaseTripPlanningItemDTO],
        expenses: [SupabaseTripExpenseDTO],
        splits: [SupabaseTripExpenseSplitDTO],
        directPayments: [SupabaseTripDirectPaymentDTO]
    ) -> [TripPlan] {
        let participantsByTripID = Dictionary(grouping: participants, by: \.tripID)
        let placesByTripID = Dictionary(grouping: places, by: \.tripID)
        let planningItemsByTripID = Dictionary(grouping: planningItems, by: \.tripID)
        let expensesByTripID = Dictionary(grouping: expenses, by: \.tripID)
        let directPaymentsByTripID = Dictionary(grouping: directPayments, by: \.tripID)
        let expenseIDsByTripID = expensesByTripID.mapValues { Set($0.map(\.id)) }

        return trips.map { trip in
            let tripExpenseIDs = expenseIDsByTripID[trip.id, default: []]
            let tripSplits = splits.filter { tripExpenseIDs.contains($0.expenseID) }

            return trip.tripPlan(
                participants: participantsByTripID[trip.id, default: []],
                places: placesByTripID[trip.id, default: []],
                planningItems: planningItemsByTripID[trip.id, default: []],
                expenses: expensesByTripID[trip.id, default: []],
                splits: tripSplits,
                directPayments: directPaymentsByTripID[trip.id, default: []]
            )
        }
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

    func createPlace(_ place: TripPlace, in tripID: UUID) async throws -> TripPlace {
        let trimmedPlace = TripPlace(
            id: place.id,
            name: place.name.trimmingCharacters(in: .whitespacesAndNewlines),
            note: place.note.trimmingCharacters(in: .whitespacesAndNewlines),
            category: place.category.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        guard !trimmedPlace.name.isEmpty else { return trimmedPlace }

        let row = SupabaseTripPlaceDTO(tripID: tripID, place: trimmedPlace)

        try await client
            .from("trip_places")
            .insert(row)
            .execute()

        return trimmedPlace
    }

    func deletePlace(_ placeID: UUID, from tripID: UUID) async throws {
        try await client
            .from("trip_places")
            .delete()
            .eq("id", value: placeID)
            .eq("trip_id", value: tripID)
            .execute()
    }

    func createInvite(for tripID: UUID, role: TripInvite.Role = .guest) async throws -> TripInvite {
        let session = try await client.auth.session
        let invite = SupabaseTripInviteDTO(
            id: UUID(),
            tripID: tripID,
            code: Self.makeInviteCode(),
            createdBy: session.user.id,
            role: role.rawValue,
            maxUses: nil,
            useCount: 0,
            expiresAt: nil,
            isActive: true
        )

        try await client
            .from("trip_invites")
            .insert(invite)
            .execute()

        return invite.tripInvite
    }

    func lookupInvite(code: String) async throws -> TripInvitePreview? {
        let params = SupabaseInviteLookupParams(inviteCode: code)
        let rows: [SupabaseInviteLookupDTO] = try await client
            .rpc("lookup_active_trip_invite", params: params)
            .execute()
            .value

        return rows.first?.invitePreview
    }

    func acceptInvite(code: String) async throws {
        let params = SupabaseInviteLookupParams(inviteCode: code)
        try await client
            .rpc("accept_trip_invite", params: params)
            .execute()
    }

    private static func makeInviteCode() -> String {
        let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        return String((0..<8).map { _ in alphabet.randomElement() ?? "W" })
    }
}

struct TripInvite: Equatable, Identifiable {
    enum Role: String, Codable, Equatable {
        case member
        case guest
    }

    var id = UUID()
    var tripID: UUID
    var code: String
    var role: Role
    var expiresAt: Date?
}

struct TripInvitePreview: Equatable, Identifiable {
    var inviteID: UUID
    var tripID: UUID
    var tripName: String
    var role: TripInvite.Role
    var expiresAt: Date?

    var id: UUID { inviteID }
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

enum SupabaseDateTimeFormatter {
    private static let formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let fallbackFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static func date(from string: String?) -> Date? {
        guard let string else { return nil }
        return formatter.date(from: string) ?? fallbackFormatter.date(from: string)
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

struct SupabaseTripInviteDTO: Codable, Hashable {
    var id: UUID
    var tripID: UUID
    var code: String
    var createdBy: UUID
    var role: String
    var maxUses: Int?
    var useCount: Int
    var expiresAt: String?
    var isActive: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case tripID = "trip_id"
        case code
        case createdBy = "created_by"
        case role
        case maxUses = "max_uses"
        case useCount = "use_count"
        case expiresAt = "expires_at"
        case isActive = "is_active"
    }

    var tripInvite: TripInvite {
        TripInvite(
            id: id,
            tripID: tripID,
            code: code,
            role: TripInvite.Role(rawValue: role) ?? .guest,
            expiresAt: SupabaseDateTimeFormatter.date(from: expiresAt)
        )
    }
}

struct SupabaseInviteLookupParams: Encodable {
    var inviteCode: String

    enum CodingKeys: String, CodingKey {
        case inviteCode = "invite_code"
    }
}

struct SupabaseInviteLookupDTO: Codable, Hashable {
    var inviteID: UUID
    var tripID: UUID
    var tripName: String
    var role: String
    var expiresAt: String?

    enum CodingKeys: String, CodingKey {
        case inviteID = "invite_id"
        case tripID = "trip_id"
        case tripName = "trip_name"
        case role
        case expiresAt = "expires_at"
    }

    var invitePreview: TripInvitePreview {
        TripInvitePreview(
            inviteID: inviteID,
            tripID: tripID,
            tripName: tripName,
            role: TripInvite.Role(rawValue: role) ?? .guest,
            expiresAt: SupabaseDateTimeFormatter.date(from: expiresAt)
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

    init(
        id: UUID,
        tripID: UUID,
        name: String,
        note: String,
        category: String,
        googlePlaceID: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil
    ) {
        self.id = id
        self.tripID = tripID
        self.name = name
        self.note = note
        self.category = category
        self.googlePlaceID = googlePlaceID
        self.latitude = latitude
        self.longitude = longitude
    }

    init(tripID: UUID, place: TripPlace) {
        self.init(
            id: place.id,
            tripID: tripID,
            name: place.name,
            note: place.note,
            category: place.category
        )
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
