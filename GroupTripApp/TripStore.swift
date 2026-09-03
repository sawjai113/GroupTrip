import SwiftUI

final class TripStore: ObservableObject {
    @Published var trips: [TripPlan] {
        didSet { cacheTripsIfNeeded() }
    }
    @Published var isLoading = false
    @Published var syncError: String?
    @Published var createdInvite: TripInvite?
    @Published var invitePreview: TripInvitePreview?
    private let service: (any TripSyncServicing)?
    private let cacheStore: UserDefaults?
    private let cacheKey: String

    private static let defaultCacheKey = "wanderaid.cached.cloud.trips.v1"

    var supportsCloudSync: Bool { service != nil }

    init(
        trips: [TripPlan],
        service: (any TripSyncServicing)? = nil,
        cacheStore: UserDefaults? = nil,
        cacheKey: String = TripStore.defaultCacheKey
    ) {
        self.service = service
        self.cacheStore = cacheStore
        self.cacheKey = cacheKey
        if service != nil, trips.isEmpty, let cacheStore {
            self.trips = Self.cachedTrips(in: cacheStore, key: cacheKey)
        } else {
            self.trips = trips
        }
    }

    convenience init(service: any TripSyncServicing, cacheStore: UserDefaults? = nil, cacheKey: String = TripStore.defaultCacheKey) {
        self.init(trips: [], service: service, cacheStore: cacheStore, cacheKey: cacheKey)
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

    /// Tested dashboard summary derived from the current trip list.
    /// The participant ID is passed in by the view/app layer when a mapping
    /// from the signed-in user to a trip participant is known; this store
    /// does not decide who the signed-in user is.
    func dashboardSummary(currentParticipantID: Participant.ID? = nil) -> DashboardSummary {
        DashboardTripSummaryBuilder.summary(from: trips, currentParticipantID: currentParticipantID)
    }

    /// Dashboard summary scoped to a signed-in account. Participant IDs are
    /// resolved per trip via `Participant.accountID`, so a user who has a
    /// different participant per trip is aggregated across all of them.
    /// Money stays nil when the account ID is nil or maps to no participant.
    func dashboardSummary(currentAccountID: UUID?) -> DashboardSummary {
        let participantIDs = currentAccountID.map { accountID in
            Set(
                trips.flatMap { trip in
                    trip.viewModel.calculator.participants.compactMap { participant in
                        participant.accountID == accountID ? participant.id : nil
                    }
                }
            )
        }
        return DashboardTripSummaryBuilder.summary(from: trips, currentParticipantIDs: participantIDs)
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

    @MainActor
    func updateParticipant(_ participant: Participant, in tripID: TripPlan.ID) async {
        let trimmedParticipant = Participant(
            id: participant.id,
            name: participant.name.trimmingCharacters(in: .whitespacesAndNewlines),
            accountID: participant.accountID,
            isOrganizer: participant.isOrganizer
        )
        guard !trimmedParticipant.name.isEmpty else { return }

        guard let service else {
            replaceParticipant(trimmedParticipant, in: tripID)
            return
        }

        do {
            let savedParticipant = try await service.updateParticipant(trimmedParticipant, in: tripID)
            replaceParticipant(savedParticipant, in: tripID)
            syncError = nil
        } catch {
            syncError = error.localizedDescription
        }
    }

    private func replaceParticipant(_ participant: Participant, in tripID: TripPlan.ID) {
        objectWillChange.send()
        trips.first { $0.id == tripID }?.viewModel.updateParticipant(participant)
    }

    func deletePlace(_ placeID: TripPlace.ID, from tripID: TripPlan.ID) {
        updateTrip(withID: tripID) { trip in
            trip.places.removeAll { $0.id == placeID }
        }
    }

    @MainActor
    func savePlace(_ place: TripPlace, to tripID: TripPlan.ID) async {
        let trimmedPlace = trimmedPlace(place)
        guard !trimmedPlace.name.isEmpty else { return }

        guard let service else {
            addPlace(trimmedPlace, to: tripID)
            return
        }

        do {
            let savedPlace = try await service.createPlace(trimmedPlace, in: tripID)
            try await service.setPlaceParticipants(savedPlace.participantIDs, for: savedPlace.id, in: tripID)
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
        let trimmed = trimmedPlace(place)
        guard !trimmed.name.isEmpty else { return }

        guard let service else {
            replacePlace(trimmed, in: tripID)
            return
        }

        do {
            let updated = try await service.updatePlace(trimmed, in: tripID)
            try await service.setPlaceParticipants(updated.participantIDs, for: updated.id, in: tripID)
            replacePlace(updated, in: tripID)
            syncError = nil
        } catch {
            syncError = error.localizedDescription
        }
    }

    @MainActor
    func setVote(_ vote: PlaceVote, for placeID: TripPlace.ID, participantID: Participant.ID, in tripID: TripPlan.ID) async {
        guard let service else {
            setLocalVote(vote, for: placeID, participantID: participantID, in: tripID)
            return
        }

        do {
            try await service.setVote(vote, for: placeID, participantID: participantID, in: tripID)
            setLocalVote(vote, for: placeID, participantID: participantID, in: tripID)
            syncError = nil
        } catch {
            syncError = error.localizedDescription
        }
    }

    @MainActor
    func setPlacePinned(_ isPinned: Bool, for placeID: TripPlace.ID, in tripID: TripPlan.ID, now: Date = Date()) async {
        guard let place = trips.first(where: { $0.id == tripID })?.places.first(where: { $0.id == placeID }) else { return }
        await updatePlace(PlacePinning.updated(place, isPinned: isPinned, now: now), in: tripID)
    }

    @MainActor
    func callForVote(on placeID: TripPlace.ID, by callerID: Participant.ID?, in tripID: TripPlan.ID, now: Date = Date()) async {
        guard let place = trips.first(where: { $0.id == tripID })?.places.first(where: { $0.id == placeID }) else { return }
        await updatePlace(PlaceVotingCall.updated(place, callerID: callerID, now: now), in: tripID)
    }

    private func setLocalVote(_ vote: PlaceVote, for placeID: TripPlace.ID, participantID: Participant.ID, in tripID: TripPlan.ID) {
        updateTrip(withID: tripID) { trip in
            guard let index = trip.places.firstIndex(where: { $0.id == placeID }) else { return }
            trip.places[index].votes[participantID] = vote
        }
    }

    private func trimmedPlace(_ place: TripPlace) -> TripPlace {
        TripPlace(
            id: place.id,
            name: place.name.trimmingCharacters(in: .whitespacesAndNewlines),
            note: place.note.trimmingCharacters(in: .whitespacesAndNewlines),
            tag: place.tag.trimmingCharacters(in: .whitespacesAndNewlines),
            participantIDs: place.participantIDs,
            pinnedAt: place.pinnedAt,
            calledForVoteAt: place.calledForVoteAt,
            calledBy: place.calledBy,
            votes: place.votes
        )
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
            time: item.time,
            isDone: item.isDone,
            tag: item.tag.trimmingCharacters(in: .whitespacesAndNewlines),
            participantIDs: item.participantIDs
        )
        guard !trimmedItem.title.isEmpty else { return }

        guard let service else {
            addPlanningItem(trimmedItem, to: tripID)
            return
        }

        do {
            let savedItem = try await service.createPlanningItem(trimmedItem, in: tripID)
            try await service.setPlanningItemParticipants(savedItem.participantIDs, for: savedItem.id, in: tripID)
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
        await updatePlanningItem(updatedItem, in: tripID)
    }

    @MainActor
    func updatePlanningItem(_ item: TripPlanningItem, in tripID: TripPlan.ID) async {
        let trimmedItem = TripPlanningItem(
            id: item.id,
            title: item.title.trimmingCharacters(in: .whitespacesAndNewlines),
            note: item.note.trimmingCharacters(in: .whitespacesAndNewlines),
            date: item.date,
            time: item.time,
            isDone: item.isDone,
            tag: item.tag.trimmingCharacters(in: .whitespacesAndNewlines),
            participantIDs: item.participantIDs
        )
        guard !trimmedItem.title.isEmpty else { return }

        guard let service else {
            replacePlanningItem(trimmedItem, in: tripID)
            return
        }

        do {
            let savedItem = try await service.updatePlanningItem(trimmedItem, in: tripID)
            try await service.setPlanningItemParticipants(savedItem.participantIDs, for: savedItem.id, in: tripID)
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

    private func replaceExpense(_ expense: ExpenseItem, in tripID: TripPlan.ID) {
        objectWillChange.send()
        guard let expenses = trips.first(where: { $0.id == tripID })?.viewModel.calculator.expenses,
              let index = expenses.firstIndex(where: { $0.id == expense.id }) else { return }
        trips.first { $0.id == tripID }?.viewModel.calculator.expenses[index] = expense
    }

    @MainActor
    func updateExpense(_ expense: ExpenseItem, in tripID: TripPlan.ID) async {
        let trimmed = ExpenseItem(
            id: expense.id,
            title: expense.title.trimmingCharacters(in: .whitespacesAndNewlines),
            paidBy: expense.paidBy,
            amount: expense.amount,
            participants: expense.participants
        )
        guard !trimmed.title.isEmpty, trimmed.amount > 0, !trimmed.participants.isEmpty else { return }

        guard let service else {
            replaceExpense(trimmed, in: tripID)
            return
        }

        do {
            let savedExpense = try await service.updateExpense(trimmed, in: tripID)
            replaceExpense(savedExpense, in: tripID)
            syncError = nil
        } catch {
            syncError = error.localizedDescription
        }
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

    private func replaceDirectPayment(_ payment: DirectPayment, in tripID: TripPlan.ID) {
        objectWillChange.send()
        guard let payments = trips.first(where: { $0.id == tripID })?.viewModel.calculator.payments,
              let index = payments.firstIndex(where: { $0.id == payment.id }) else { return }
        trips.first { $0.id == tripID }?.viewModel.calculator.payments[index] = payment
    }

    @MainActor
    func updateDirectPayment(_ payment: DirectPayment, in tripID: TripPlan.ID) async {
        let trimmed = DirectPayment(
            id: payment.id,
            title: payment.title.trimmingCharacters(in: .whitespacesAndNewlines),
            from: payment.from,
            to: payment.to,
            amount: payment.amount
        )
        guard !trimmed.title.isEmpty, trimmed.from != trimmed.to, trimmed.amount > 0 else { return }

        guard let service else {
            replaceDirectPayment(trimmed, in: tripID)
            return
        }

        do {
            let savedPayment = try await service.updateDirectPayment(trimmed, in: tripID)
            replaceDirectPayment(savedPayment, in: tripID)
            syncError = nil
        } catch {
            syncError = error.localizedDescription
        }
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

        isLoading = trips.isEmpty
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
            syncError = nil
            return
        }

        do {
            syncError = nil
            let preview = try await service.lookupInvite(code: normalizedCode)
            invitePreview = preview
            if preview == nil {
                syncError = "We couldn't find an active trip invite for that code."
            }
        } catch {
            invitePreview = nil
            syncError = error.localizedDescription
        }
    }

    @MainActor
    @discardableResult
    func acceptInvite(code: String) async -> Bool {
        guard let service else { return false }
        let normalizedCode = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !normalizedCode.isEmpty else {
            syncError = nil
            return false
        }

        do {
            syncError = nil
            try await service.acceptInvite(code: normalizedCode)
            trips = try await service.loadTrips()
            invitePreview = nil
            return true
        } catch {
            syncError = error.localizedDescription
            return false
        }
    }
}

extension TripStore {
    static func cacheTrips(_ trips: [TripPlan], in store: UserDefaults, key: String = TripStore.defaultCacheKey) {
        let snapshots = trips.map(CachedTrip.init(trip:))
        guard let data = try? JSONEncoder().encode(snapshots) else { return }
        store.set(data, forKey: key)
    }

    static func cachedTrips(in store: UserDefaults, key: String = TripStore.defaultCacheKey) -> [TripPlan] {
        guard let data = store.data(forKey: key),
              let snapshots = try? JSONDecoder().decode([CachedTrip].self, from: data) else { return [] }
        return snapshots.map(\.trip)
    }

    private func cacheTripsIfNeeded() {
        guard service != nil, let cacheStore else { return }
        Self.cacheTrips(trips, in: cacheStore, key: cacheKey)
    }
}

private struct CachedTrip: Codable {
    var id: UUID
    var destination: String
    var emoji: String
    var imageURL: String
    var startDate: Date
    var endDate: Date
    var tripName: String
    var participants: [CachedParticipant]
    var expenses: [CachedExpense]
    var payments: [CachedDirectPayment]
    var places: [CachedPlace]
    var planningItems: [CachedPlanningItem]

    init(trip: TripPlan) {
        id = trip.id
        destination = trip.destination
        emoji = trip.emoji
        imageURL = trip.imageURL
        startDate = trip.startDate
        endDate = trip.endDate
        tripName = trip.viewModel.tripName
        participants = trip.viewModel.calculator.participants.map(CachedParticipant.init(participant:))
        expenses = trip.viewModel.calculator.expenses.map(CachedExpense.init(expense:))
        payments = trip.viewModel.calculator.payments.map(CachedDirectPayment.init(payment:))
        places = trip.places.map(CachedPlace.init(place:))
        planningItems = trip.planningItems.map(CachedPlanningItem.init(item:))
    }

    var trip: TripPlan {
        TripPlan(
            id: id,
            destination: destination,
            emoji: emoji,
            imageURL: imageURL,
            startDate: startDate,
            endDate: endDate,
            viewModel: TripCalculatorViewModel(
                tripName: tripName,
                calculator: TripExpenseCalculator(
                    participants: participants.map(\.participant),
                    expenses: expenses.map(\.expense),
                    payments: payments.map(\.payment)
                )
            ),
            places: places.map(\.place),
            planningItems: planningItems.map(\.item)
        )
    }
}

private struct CachedParticipant: Codable {
    var id: UUID
    var name: String
    var accountID: UUID?
    /// Optional for forward compatibility: caches written before Chunk 5 omit it.
    var isOrganizer: Bool?

    init(participant: Participant) {
        id = participant.id
        name = participant.name
        accountID = participant.accountID
        isOrganizer = participant.isOrganizer
    }

    var participant: Participant {
        Participant(id: id, name: name, accountID: accountID, isOrganizer: isOrganizer ?? false)
    }
}

private struct CachedExpense: Codable {
    var id: UUID
    var title: String
    var paidBy: UUID
    var amount: Decimal
    var participants: [UUID]

    init(expense: ExpenseItem) {
        id = expense.id
        title = expense.title
        paidBy = expense.paidBy
        amount = expense.amount
        participants = Array(expense.participants)
    }

    var expense: ExpenseItem {
        ExpenseItem(id: id, title: title, paidBy: paidBy, amount: amount, participants: Set(participants))
    }
}

private struct CachedDirectPayment: Codable {
    var id: UUID
    var title: String
    var from: UUID
    var to: UUID
    var amount: Decimal

    init(payment: DirectPayment) {
        id = payment.id
        title = payment.title
        from = payment.from
        to = payment.to
        amount = payment.amount
    }

    var payment: DirectPayment { DirectPayment(id: id, title: title, from: from, to: to, amount: amount) }
}

private struct CachedPlace: Codable {
    var id: UUID
    var name: String
    var note: String
    var tag: String
    var participantIDs: [UUID]
    var pinnedAt: Date?
    var calledForVoteAt: Date?
    var calledBy: UUID?
    var votes: [UUID: PlaceVote]?

    init(place: TripPlace) {
        id = place.id
        name = place.name
        note = place.note
        tag = place.tag
        participantIDs = place.participantIDs
        pinnedAt = place.pinnedAt
        calledForVoteAt = place.calledForVoteAt
        calledBy = place.calledBy
        votes = place.votes
    }

    var place: TripPlace {
        TripPlace(
            id: id,
            name: name,
            note: note,
            tag: tag,
            participantIDs: participantIDs,
            pinnedAt: pinnedAt,
            calledForVoteAt: calledForVoteAt,
            calledBy: calledBy,
            votes: votes ?? [:]
        )
    }
}

private struct CachedPlanningItem: Codable {
    var id: UUID
    var title: String
    var note: String
    var date: Date?
    var isDone: Bool
    var tag: String
    var participantIDs: [UUID]

    init(item: TripPlanningItem) {
        id = item.id
        title = item.title
        note = item.note
        date = item.date
        isDone = item.isDone
        tag = item.tag
        participantIDs = item.participantIDs
    }

    var item: TripPlanningItem {
        TripPlanningItem(id: id, title: title, note: note, date: date, isDone: isDone, tag: tag, participantIDs: participantIDs)
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

        let sawjai = Participant(name: "Sawjai", isOrganizer: true)
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
                TripPlace(name: "Shibuya Sky", note: "City view / sunset idea", tag: "View"),
                TripPlace(name: "Tsukiji Outer Market", note: "Breakfast and street food", tag: "Food"),
                TripPlace(name: "teamLab Planets", note: "Reserve tickets", tag: "Museum"),
                TripPlace(name: "Fushimi Inari", note: "Kyoto morning visit", tag: "Shrine"),
                TripPlace(name: "Arashiyama Bamboo Grove", note: "Kyoto half-day", tag: "Nature")
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

        let sawjai = Participant(name: "Sawjai", isOrganizer: true)
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
                TripPlace(name: "Emerald Bay State Park", note: "Morning hike and viewpoints", tag: "Hike"),
                TripPlace(name: "Sand Harbor", note: "Beach afternoon if weather is clear", tag: "Beach"),
                TripPlace(name: "Base Camp Pizza", note: "Casual dinner after arrival", tag: "Food")
            ],
            planningItems: [
                TripPlanningItem(title: "Confirm cabin check-in instructions", isDone: true),
                TripPlanningItem(title: "Reserve kayak rental time"),
                TripPlanningItem(title: "Split grocery list")
            ]
        )
    }
}
