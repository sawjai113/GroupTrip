import Foundation
import Supabase

struct SupabaseTripService {
    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseConfig.client) {
        self.client = client
    }

    func loadTrips() async throws -> [TripPlan] {
        let rows: [RemoteTrip] = try await client
            .from("trips")
            .select()
            .order("start_date", ascending: true)
            .execute()
            .value

        return rows.map(\.tripPlan)
    }

    func createTrip(name: String, destination: String, emoji: String, imageURL: String, startDate: Date, endDate: Date) async throws -> TripPlan {
        let session = try await client.auth.session
        let tripID = UUID()
        let remoteTrip = RemoteTrip(
            id: tripID,
            name: name,
            destination: destination,
            emoji: emoji,
            imageURL: imageURL,
            startDate: Self.dateFormatter.string(from: startDate),
            endDate: Self.dateFormatter.string(from: endDate)
        )

        try await client
            .from("trips")
            .insert(remoteTrip)
            .execute()

        let membership = RemoteTripMember(
            tripID: tripID,
            userID: session.user.id,
            role: "owner"
        )

        try await client
            .from("trip_members")
            .insert(membership)
            .execute()

        return remoteTrip.tripPlan
    }

    fileprivate static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

private struct RemoteTrip: Codable {
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

    var tripPlan: TripPlan {
        TripPlan(
            id: id,
            destination: destination ?? "New destination",
            emoji: emoji ?? "✈️",
            imageURL: imageURL ?? CoverImage.defaultOptions[0].url,
            startDate: SupabaseTripService.dateFormatter.date(from: startDate) ?? Date(),
            endDate: SupabaseTripService.dateFormatter.date(from: endDate) ?? Date(),
            viewModel: TripCalculatorViewModel.empty(named: name)
        )
    }
}

private struct RemoteTripMember: Encodable {
    var tripID: UUID
    var userID: UUID
    var role: String

    enum CodingKeys: String, CodingKey {
        case tripID = "trip_id"
        case userID = "user_id"
        case role
    }
}
