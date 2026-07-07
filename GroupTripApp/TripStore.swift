import SwiftUI

final class TripStore: ObservableObject {
    @Published var trips: [TripPlan]
    @Published var isLoading = false
    @Published var syncError: String?
    @Published var createdInvite: TripInvite?
    @Published var invitePreview: TripInvitePreview?
    private let service: (any TripSyncServicing)?

    var supportsCloudSync: Bool { service != nil }

    init(trips: [TripPlan], service: (any TripSyncServicing)? = nil) {
        self.trips = trips
        self.service = service
    }

    convenience init(service: any TripSyncServicing) {
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

    func replacePlace(_ place: TripPlace, in tripID: TripPlan.ID) {
        updateTrip(withID: tripID) { trip in
            guard let index = trip.places.firstIndex(where: { $0.id == place.id }) else { return }
            trip.places[index] = place
        }
    }

    @MainActor
    func saveParticipants(names: [String], to tripID: TripPlan.ID) async {
        let participants = names
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { Participant(name: $0) }
        guard !participants.isEmpty else { return }

        guard let service else {
            participants.forEach { addParticipant($0, to: tripID) }
            return
        }

        do {
            for participant in participants {
                let savedParticipant = try await service.createParticipant(participant, in: tripID)
                addParticipant(savedParticipant, to: tripID)
            }
            syncError = nil
        } catch {
            syncError = error.localizedDescription
        }
    }

    private func addParticipant(_ participant: Participant, to tripID: TripPlan.ID) {
        objectWillChange.send()
        trips.first { $0.id == tripID }?.viewModel.calculator.participants.append(participant)
    }

    func deletePlace(_ placeID: TripPlace.ID, from tripID: TripPlan.ID) {
        updateTrip(withID: tripID) { trip in
            trip.places.removeAll { $0.id == placeID }
        }
    }

    @MainActor
    func savePlace(_ place: TripPlace, to tripID: TripPlan.ID) async {
        let trimmedPlace = TripPlace(
            id: place.id,
            name: place.name.trimmingCharacters(in: .whitespacesAndNewlines),
            note: place.note.trimmingCharacters(in: .whitespacesAndNewlines),
            category: place.category.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        guard !trimmedPlace.name.isEmpty else { return }

        guard let service else {
            addPlace(trimmedPlace, to: tripID)
            return
        }

        do {
            let savedPlace = try await service.createPlace(trimmedPlace, in: tripID)
            addPlace(savedPlace, to: tripID)
            syncError = nil
        } catch {
            syncError = error.localizedDescription
        }
    }

    @MainActor
    func removePlace(_ placeID: TripPlace.ID, from tripID: TripPlan.ID) async {
        guard let service else {
            deletePlace(placeID, from: tripID)
            return
        }

        do {
            try await service.deletePlace(placeID, from: tripID)
            deletePlace(placeID, from: tripID)
            syncError = nil
        } catch {
            syncError = error.localizedDescription
        }
    }

    @MainActor
    func updatePlace(_ place: TripPlace, in tripID: TripPlan.ID) async {
        let trimmed = TripPlace(
            id: place.id,
            name: place.name.trimmingCharacters(in: .whitespacesAndNewlines),
            note: place.note.trimmingCharacters(in: .whitespacesAndNewlines),
            category: place.category.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        guard !trimmed.name.isEmpty else { return }

        guard let service else {
            replacePlace(trimmed, in: tripID)
            return
        }

        do {
            let updated = try await service.updatePlace(trimmed, in: tripID)
            replacePlace(updated, in: tripID)
            syncError = nil
        } catch {
            syncError = error.localizedDescription
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

    func replacePlanningItem(_ item: TripPlanningItem, in tripID: TripPlan.ID) {
        updateTrip(withID: tripID) { trip in
            guard let itemIndex = trip.planningItems.firstIndex(where: { $0.id == item.id }) else { return }
            trip.planningItems[itemIndex] = item
        }
    }

    @MainActor
    func savePlanningItem(_ item: TripPlanningItem, to tripID: TripPlan.ID) async {
        let trimmedItem = TripPlanningItem(
            id: item.id,
            title: item.title.trimmingCharacters(in: .whitespacesAndNewlines),
            note: item.note.trimmingCharacters(in: .whitespacesAndNewlines),
            date: item.date,
            isDone: item.isDone
        )
        guard !trimmedItem.title.isEmpty else { return }

        guard let service else {
            addPlanningItem(trimmedItem, to: tripID)
            return
        }

        do {
            let savedItem = try await service.createPlanningItem(trimmedItem, in: tripID)
            addPlanningItem(savedItem, to: tripID)
            syncError = nil
        } catch {
            syncError = error.localizedDescription
        }
    }

    @MainActor
    func togglePlanningItemRemotely(_ itemID: TripPlanningItem.ID, for tripID: TripPlan.ID) async {
        guard let item = trips.first(where: { $0.id == tripID })?.planningItems.first(where: { $0.id == itemID }) else { return }
        var updatedItem = item
        updatedItem.isDone.toggle()

        guard let service else {
            togglePlanningItem(itemID, for: tripID)
            return
        }

        do {
            let savedItem = try await service.updatePlanningItem(updatedItem, in: tripID)
            replacePlanningItem(savedItem, in: tripID)
            syncError = nil
        } catch {
            syncError = error.localizedDescription
        }
    }

    @MainActor
    func removePlanningItem(_ itemID: TripPlanningItem.ID, from tripID: TripPlan.ID) async {
        guard let service else {
            deletePlanningItem(itemID, from: tripID)
            return
        }

        do {
            try await service.deletePlanningItem(itemID, from: tripID)
            deletePlanningItem(itemID, from: tripID)
            syncError = nil
        } catch {
            syncError = error.localizedDescription
        }
    }

    private func updateTrip(withID tripID: TripPlan.ID, mutate: (inout TripPlan) -> Void) {
        guard let index = trips.firstIndex(where: { $0.id == tripID }) else { return }
        var updatedTrips = trips
        mutate(&updatedTrips[index])
        trips = updatedTrips
    }

    @MainActor
    func saveExpense(title: String, paidBy: Participant.ID, amount: Decimal, participants: Set<Participant.ID>, to tripID: TripPlan.ID) async {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty, amount > 0, !participants.isEmpty else { return }

        let expense = ExpenseItem(title: trimmedTitle, paidBy: paidBy, amount: amount, participants: participants)

        guard let service else {
            addExpense(expense, to: tripID)
            return
        }

        do {
            let savedExpense = try await service.createExpense(expense, in: tripID)
            addExpense(savedExpense, to: tripID)
            syncError = nil
        } catch {
            syncError = error.localizedDescription
        }
    }

    @MainActor
    func removeExpense(_ expenseID: ExpenseItem.ID, from tripID: TripPlan.ID) async {
        guard let service else {
            deleteExpense(expenseID, from: tripID)
            return
        }

        do {
            try await service.deleteExpense(expenseID, from: tripID)
            deleteExpense(expenseID, from: tripID)
            syncError = nil
        } catch {
            syncError = error.localizedDescription
        }
    }

    private func addExpense(_ expense: ExpenseItem, to tripID: TripPlan.ID) {
        objectWillChange.send()
        trips.first { $0.id == tripID }?.viewModel.calculator.expenses.insert(expense, at: 0)
    }

    private func deleteExpense(_ expenseID: ExpenseItem.ID, from tripID: TripPlan.ID) {
        objectWillChange.send()
        trips.first { $0.id == tripID }?.viewModel.calculator.expenses.removeAll { $0.id == expenseID }
    }

    @MainActor
    func saveDirectPayment(title: String, from: Participant.ID, to: Participant.ID, amount: Decimal, in tripID: TripPlan.ID) async {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty, from != to, amount > 0 else { return }

        let payment = DirectPayment(title: trimmedTitle, from: from, to: to, amount: amount)

        guard let service else {
            addDirectPayment(payment, to: tripID)
            return
        }

        do {
            let savedPayment = try await service.createDirectPayment(payment, in: tripID)
            addDirectPayment(savedPayment, to: tripID)
            syncError = nil
        } catch {
            syncError = error.localizedDescription
        }
    }

    private func addDirectPayment(_ payment: DirectPayment, to tripID: TripPlan.ID) {
        objectWillChange.send()
        trips.first { $0.id == tripID }?.viewModel.calculator.payments.insert(payment, at: 0)
    }

    @MainActor
    func leaveTrip(_ tripID: TripPlan.ID) async {
        guard let service else {
            trips.removeAll { $0.id == tripID }
            return
        }

        do {
            syncError = nil
            try await service.leaveTrip(tripID)
            trips.removeAll { $0.id == tripID }
        } catch {
            syncError = error.localizedDescription
        }
    }

    @MainActor
    func archiveTrip(_ tripID: TripPlan.ID) async {
        guard let service else {
            trips.removeAll { $0.id == tripID }
            return
        }

        do {
            syncError = nil
            try await service.archiveTrip(tripID)
            trips.removeAll { $0.id == tripID }
        } catch {
            syncError = error.localizedDescription
        }
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
    @discardableResult
    func addRemoteTrip(name: String, destination: String, emoji: String, imageURL: String, startDate: Date, endDate: Date) async -> Bool {
        guard let service else {
            addTrip(name: name, destination: destination, emoji: emoji, imageURL: imageURL, startDate: startDate, endDate: endDate)
            return true
        }

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDestination = destination.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmoji = emoji.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedImageURL = imageURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return false }

        isLoading = true
        syncError = nil
        defer { isLoading = false }

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
            syncError = nil
            return true
        } catch {
            syncError = error.localizedDescription
            return false
        }
    }

    @MainActor
    func createInvite(for tripID: TripPlan.ID, role: TripInvite.Role = .guest) async {
        guard let service else { return }

        do {
            syncError = nil
            createdInvite = try await service.createInvite(for: tripID, role: role)
        } catch {
            syncError = error.localizedDescription
        }
    }

    @MainActor
    func lookupInvite(code: String) async {
        guard let service else { return }
        let normalizedCode = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !normalizedCode.isEmpty else {
            invitePreview = nil
            return
        }

        do {
            syncError = nil
            invitePreview = try await service.lookupInvite(code: normalizedCode)
        } catch {
            invitePreview = nil
            syncError = error.localizedDescription
        }
    }

    @MainActor
    func acceptInvite(code: String) async {
        guard let service else { return }
        let normalizedCode = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !normalizedCode.isEmpty else { return }

        do {
            syncError = nil
            try await service.acceptInvite(code: normalizedCode)
            trips = try await service.loadTrips()
            invitePreview = nil
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
        TripStore(trips: [makeJapanSpring2027Trip(), makeLakeTahoeWeekendTrip()])
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

    private static func makeLakeTahoeWeekendTrip() -> TripPlan {
        let calendar = Calendar.current
        let startDate = calendar.date(from: DateComponents(year: 2026, month: 8, day: 14)) ?? Date()
        let endDate = calendar.date(from: DateComponents(year: 2026, month: 8, day: 16)) ?? startDate

        let sawjai = Participant(name: "Sawjai")
        let maya = Participant(name: "Maya")
        let noah = Participant(name: "Noah")
        let people = [sawjai, maya, noah]
        let everyone = Set(people.map(\.id))

        return TripPlan(
            destination: "Lake Tahoe, California",
            emoji: "🏕️",
            imageURL: "https://images.unsplash.com/photo-1500534314209-a25ddb2bd429?w=800",
            startDate: startDate,
            endDate: endDate,
            viewModel: TripCalculatorViewModel(
                tripName: "Tahoe Weekend",
                calculator: TripExpenseCalculator(
                    participants: people,
                    expenses: [
                        ExpenseItem(title: "Cabin deposit", paidBy: maya.id, amount: 540, participants: everyone),
                        ExpenseItem(title: "Groceries", paidBy: sawjai.id, amount: 126.75, participants: everyone),
                        ExpenseItem(title: "Kayak rentals", paidBy: noah.id, amount: 180, participants: everyone)
                    ],
                    payments: [
                        DirectPayment(title: "Noah sent Maya for cabin", from: noah.id, to: maya.id, amount: 120)
                    ]
                )
            ),
            places: [
                TripPlace(name: "Emerald Bay State Park", note: "Morning hike and viewpoints", category: "Hike"),
                TripPlace(name: "Sand Harbor", note: "Beach afternoon if weather is clear", category: "Beach"),
                TripPlace(name: "Base Camp Pizza", note: "Casual dinner after arrival", category: "Food")
            ],
            planningItems: [
                TripPlanningItem(title: "Confirm cabin check-in instructions", isDone: true),
                TripPlanningItem(title: "Reserve kayak rental time"),
                TripPlanningItem(title: "Split grocery list")
            ]
        )
    }
}
