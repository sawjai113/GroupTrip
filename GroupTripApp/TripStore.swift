import SwiftUI

final class TripStore: ObservableObject {
    @Published var trips: [TripPlan]
    @Published var isLoading = false
    @Published var syncError: String?
    private let service: SupabaseTripService?

    init(trips: [TripPlan], service: SupabaseTripService? = nil) {
        self.trips = trips
        self.service = service
    }

    convenience init(service: SupabaseTripService) {
        self.init(trips: [], service: service)
    }

    var currentTrips: [TripPlan] {
        trips.filter { $0.status == .current }.sorted { $0.startDate < $1.startDate }
    }

    var futureTrips: [TripPlan] {
        trips.filter { $0.status == .future }.sorted { $0.startDate < $1.startDate }
    }

    var pastTrips: [TripPlan] {
        trips.filter { $0.status == .past }.sorted { $0.startDate > $1.startDate }
    }

    var featuredTrips: [TripPlan] {
        if let currentTrip = currentTrips.first {
            return [currentTrip] + futureTrips
        }

        return futureTrips
    }

    func addTrip(name: String, startDate: Date, endDate: Date) {
        addTrip(
            name: name,
            destination: "New destination",
            emoji: "✈️",
            imageURL: CoverImage.defaultOptions[0].url,
            startDate: startDate,
            endDate: endDate
        )
    }

    func addTrip(name: String, emoji: String, startDate: Date, endDate: Date) {
        addTrip(
            name: name,
            destination: "New destination",
            emoji: emoji,
            imageURL: CoverImage.defaultOptions[0].url,
            startDate: startDate,
            endDate: endDate
        )
    }

    func addTrip(name: String, destination: String, emoji: String, imageURL: String, startDate: Date, endDate: Date) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDestination = destination.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmoji = emoji.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedImageURL = imageURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        trips.append(
            TripPlan(
                destination: trimmedDestination.isEmpty ? "New destination" : trimmedDestination,
                emoji: trimmedEmoji.isEmpty ? "✈️" : trimmedEmoji,
                imageURL: trimmedImageURL.isEmpty ? CoverImage.defaultOptions[0].url : trimmedImageURL,
                startDate: startDate,
                endDate: max(startDate, endDate),
                viewModel: TripCalculatorViewModel.empty(named: trimmedName)
            )
        )
    }

    func setPlaces(_ places: [TripPlace], for tripID: TripPlan.ID) {
        updateTrip(withID: tripID) { trip in
            trip.places = places
        }
    }

    func addPlace(_ place: TripPlace, to tripID: TripPlan.ID) {
        updateTrip(withID: tripID) { trip in
            trip.places.append(place)
        }
    }

    func deletePlace(_ placeID: TripPlace.ID, from tripID: TripPlan.ID) {
        updateTrip(withID: tripID) { trip in
            trip.places.removeAll { $0.id == placeID }
        }
    }

    func setPlanningItems(_ items: [TripPlanningItem], for tripID: TripPlan.ID) {
        updateTrip(withID: tripID) { trip in
            trip.planningItems = items
        }
    }

    func addPlanningItem(_ item: TripPlanningItem, to tripID: TripPlan.ID) {
        updateTrip(withID: tripID) { trip in
            trip.planningItems.append(item)
        }
    }

    func deletePlanningItem(_ itemID: TripPlanningItem.ID, from tripID: TripPlan.ID) {
        updateTrip(withID: tripID) { trip in
            trip.planningItems.removeAll { $0.id == itemID }
        }
    }

    func togglePlanningItem(_ itemID: TripPlanningItem.ID, for tripID: TripPlan.ID) {
        updateTrip(withID: tripID) { trip in
            guard let itemIndex = trip.planningItems.firstIndex(where: { $0.id == itemID }) else { return }
            trip.planningItems[itemIndex].isDone.toggle()
        }
    }

    private func updateTrip(withID tripID: TripPlan.ID, mutate: (inout TripPlan) -> Void) {
        guard let index = trips.firstIndex(where: { $0.id == tripID }) else { return }
        var updatedTrips = trips
        mutate(&updatedTrips[index])
        trips = updatedTrips
    }

    @MainActor
    func loadTrips() async {
        guard let service else { return }

        isLoading = true
        syncError = nil

        do {
            trips = try await service.loadTrips()
        } catch {
            syncError = error.localizedDescription
        }

        isLoading = false
    }

    @MainActor
    func addRemoteTrip(name: String, destination: String, emoji: String, imageURL: String, startDate: Date, endDate: Date) async {
        guard let service else {
            addTrip(name: name, destination: destination, emoji: emoji, imageURL: imageURL, startDate: startDate, endDate: endDate)
            return
        }

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDestination = destination.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmoji = emoji.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedImageURL = imageURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        do {
            let trip = try await service.createTrip(
                name: trimmedName,
                destination: trimmedDestination.isEmpty ? "New destination" : trimmedDestination,
                emoji: trimmedEmoji.isEmpty ? "✈️" : trimmedEmoji,
                imageURL: trimmedImageURL.isEmpty ? CoverImage.defaultOptions[0].url : trimmedImageURL,
                startDate: startDate,
                endDate: max(startDate, endDate)
            )
            trips.append(trip)
        } catch {
            syncError = error.localizedDescription
        }
    }

    var errorAlertBinding: Binding<Bool> {
        Binding(
            get: { self.syncError != nil },
            set: { isPresented in
                if !isPresented {
                    self.syncError = nil
                }
            }
        )
    }
}

extension TripStore {
    static var sample: TripStore {
        TripStore(trips: [makeJapanSpring2027Trip()])
    }

    private static func makeJapanSpring2027Trip() -> TripPlan {
        let calendar = Calendar.current
        let startDate = calendar.date(from: DateComponents(year: 2027, month: 3, day: 24)) ?? Date()
        let endDate = calendar.date(from: DateComponents(year: 2027, month: 4, day: 4)) ?? startDate

        let sawjai = Participant(name: "Sawjai")
        let alex = Participant(name: "Alex")
        let sam = Participant(name: "Sam")
        let taylor = Participant(name: "Taylor")
        let jordan = Participant(name: "Jordan")
        let morgan = Participant(name: "Morgan")
        let people = [sawjai, alex, sam, taylor, jordan, morgan]
        let everyone = Set(people.map(\.id))

        return TripPlan(
            destination: "Tokyo & Kyoto, Japan",
            emoji: "🌸",
            imageURL: "https://images.unsplash.com/photo-1540959733332-eab4deabeeaf?w=800",
            startDate: startDate,
            endDate: endDate,
            viewModel: TripCalculatorViewModel(
                tripName: "Japan Spring 2027",
                calculator: TripExpenseCalculator(
                    participants: people,
                    expenses: [
                        ExpenseItem(title: "Shared hotel deposit", paidBy: sawjai.id, amount: 2400, participants: everyone),
                        ExpenseItem(title: "JR passes or train booking placeholder", paidBy: alex.id, amount: 1800, participants: everyone),
                        ExpenseItem(title: "Group dinner", paidBy: sam.id, amount: 420, participants: everyone),
                        ExpenseItem(title: "Museum/ticket purchase", paidBy: taylor.id, amount: 210, participants: everyone)
                    ],
                    payments: [
                        DirectPayment(title: "Morgan paid Jordan for ramen night", from: morgan.id, to: jordan.id, amount: 75)
                    ]
                )
            ),
            places: [
                TripPlace(name: "Shibuya Sky", note: "City view / sunset idea", category: "View"),
                TripPlace(name: "Tsukiji Outer Market", note: "Breakfast and street food", category: "Food"),
                TripPlace(name: "teamLab Planets", note: "Reserve tickets", category: "Museum"),
                TripPlace(name: "Fushimi Inari", note: "Kyoto morning visit", category: "Shrine"),
                TripPlace(name: "Arashiyama Bamboo Grove", note: "Kyoto half-day", category: "Nature")
            ],
            planningItems: [
                TripPlanningItem(title: "Book pocket Wi‑Fi or eSIM"),
                TripPlanningItem(title: "Reserve teamLab tickets"),
                TripPlanningItem(title: "Pick Kyoto day trip date"),
                TripPlanningItem(title: "Confirm shared hotel payment"),
                TripPlanningItem(title: "Collect passport names for reservations")
            ]
        )
    }
}
