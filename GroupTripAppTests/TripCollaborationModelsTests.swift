import XCTest
@testable import GroupTripApp

final class SupabaseDTOTests: XCTestCase {
    func testTripDTOMapsSnakeCaseTripRowIntoTripPlan() throws {
        let json = """
        {
          "id": "11111111-1111-1111-1111-111111111111",
          "name": "Austin Weekend",
          "destination": "Austin",
          "emoji": "🤠",
          "image_url": "https://example.com/austin.jpg",
          "start_date": "2026-07-03",
          "end_date": "2026-07-06"
        }
        """.data(using: .utf8)!

        let dto = try JSONDecoder().decode(SupabaseTripDTO.self, from: json)
        let trip = dto.tripPlan()

        XCTAssertEqual(trip.id.uuidString, "11111111-1111-1111-1111-111111111111")
        XCTAssertEqual(trip.viewModel.tripName, "Austin Weekend")
        XCTAssertEqual(trip.destination, "Austin")
        XCTAssertEqual(trip.emoji, "🤠")
        XCTAssertEqual(trip.imageURL, "https://example.com/austin.jpg")
        XCTAssertEqual(SupabaseDateFormatter.string(from: trip.startDate), "2026-07-03")
        XCTAssertEqual(SupabaseDateFormatter.string(from: trip.endDate), "2026-07-06")
    }

    func testMemberDTOMapsAccountAndGuestMembers() throws {
        let accountJSON = """
        {
          "id": "22222222-2222-2222-2222-222222222221",
          "trip_id": "11111111-1111-1111-1111-111111111111",
          "user_id": "33333333-3333-3333-3333-333333333333",
          "guest_member_id": null,
          "display_name": "Alex",
          "role": "member",
          "member_kind": "account"
        }
        """.data(using: .utf8)!
        let guestJSON = """
        {
          "id": "22222222-2222-2222-2222-222222222222",
          "trip_id": "11111111-1111-1111-1111-111111111111",
          "user_id": null,
          "guest_member_id": "44444444-4444-4444-4444-444444444444",
          "display_name": "Sam",
          "role": "guest",
          "member_kind": "guest"
        }
        """.data(using: .utf8)!

        let accountMember = try JSONDecoder().decode(SupabaseTripMemberDTO.self, from: accountJSON).tripMember
        let guestMember = try JSONDecoder().decode(SupabaseTripMemberDTO.self, from: guestJSON).tripMember

        XCTAssertEqual(accountMember.displayName, "Alex")
        XCTAssertEqual(accountMember.role, .member)
        XCTAssertEqual(accountMember.accountID?.uuidString, "33333333-3333-3333-3333-333333333333")
        XCTAssertEqual(guestMember.displayName, "Sam")
        XCTAssertEqual(guestMember.role, .guest)
        XCTAssertNil(guestMember.accountID)
    }

    func testCollaborativeTripDTOAssemblesCalculatorPlacesAndPlanningItems() throws {
        let tripDTO = SupabaseTripDTO(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            name: "Austin Weekend",
            destination: "Austin",
            emoji: "🤠",
            imageURL: "https://example.com/austin.jpg",
            startDate: "2026-07-03",
            endDate: "2026-07-06"
        )
        let alexID = UUID(uuidString: "55555555-5555-5555-5555-555555555551")!
        let samID = UUID(uuidString: "55555555-5555-5555-5555-555555555552")!
        let expenseID = UUID(uuidString: "77777777-7777-7777-7777-777777777777")!

        let trip = tripDTO.tripPlan(
            participants: [
                SupabaseTripParticipantDTO(id: alexID, tripID: tripDTO.id, displayName: "Alex", linkedMemberID: nil, linkedUserID: nil, isOrganizer: true),
                SupabaseTripParticipantDTO(id: samID, tripID: tripDTO.id, displayName: "Sam", linkedMemberID: nil, linkedUserID: nil, isOrganizer: false)
            ],
            places: [
                SupabaseTripPlaceDTO(id: UUID(uuidString: "66666666-6666-6666-6666-666666666666")!, tripID: tripDTO.id, name: "Zilker Park", note: "Picnic", category: "Outdoors", googlePlaceID: "zilker", latitude: 30.2669, longitude: -97.7729)
            ],
            planningItems: [
                SupabaseTripPlanningItemDTO(id: UUID(uuidString: "66666666-6666-6666-6666-666666666667")!, tripID: tripDTO.id, title: "Book dinner", note: "Friday night", scheduledDate: "2026-07-03", isDone: false)
            ],
            expenses: [
                SupabaseTripExpenseDTO(id: expenseID, tripID: tripDTO.id, title: "Hotel", paidByParticipantID: alexID, amount: 200, currencyCode: "USD", incurredOn: "2026-07-03")
            ],
            splits: [
                SupabaseTripExpenseSplitDTO(expenseID: expenseID, participantID: alexID, shareAmount: 100),
                SupabaseTripExpenseSplitDTO(expenseID: expenseID, participantID: samID, shareAmount: 100)
            ],
            directPayments: [
                SupabaseTripDirectPaymentDTO(id: UUID(uuidString: "88888888-8888-8888-8888-888888888888")!, tripID: tripDTO.id, title: "Sam paid Alex", fromParticipantID: samID, toParticipantID: alexID, amount: 50, currencyCode: "USD", paidOn: "2026-07-04")
            ]
        )

        XCTAssertEqual(trip.places.map(\.name), ["Zilker Park"])
        XCTAssertEqual(trip.planningItems.map(\.title), ["Book dinner"])
        XCTAssertEqual(trip.viewModel.calculator.participants.map(\.name), ["Alex", "Sam"])
        XCTAssertEqual(trip.viewModel.calculator.expenses.first?.participants, Set([alexID, samID]))
        XCTAssertEqual(trip.viewModel.calculator.payments.first?.amount, 50)
        let balances = Dictionary(uniqueKeysWithValues: trip.viewModel.calculator.balances().map { ($0.participant.name, $0.net) })
        XCTAssertEqual(balances["Alex"], 50)
        XCTAssertEqual(balances["Sam"], -50)
    }
}

@MainActor
final class AuthViewModelTests: XCTestCase {
    func testRequestMagicLinkRejectsInvalidEmailWithoutCallingService() async {
        let service = FakeAuthService()
        let viewModel = AuthViewModel(service: service)

        await viewModel.requestMagicLink(email: "not-an-email", displayName: "Alex")

        XCTAssertFalse(service.didSendMagicLink)
        XCTAssertEqual(viewModel.authError, "Enter a valid email address.")
        XCTAssertFalse(viewModel.isLoading)
    }

    func testRequestMagicLinkSendsTrimmedEmailAndDisplayName() async {
        let service = FakeAuthService()
        let viewModel = AuthViewModel(service: service)

        await viewModel.requestMagicLink(email: " alex@example.com ", displayName: " Alex ")

        XCTAssertEqual(service.sentMagicLinkEmail, "alex@example.com")
        XCTAssertEqual(service.sentMagicLinkDisplayName, "Alex")
        XCTAssertEqual(viewModel.authMessage, "Check your email for a Wani sign-in link.")
        XCTAssertFalse(viewModel.isLoading)
    }

    func testSignedInSessionBootstrapsCurrentProfile() async throws {
        let service = FakeAuthService()
        let viewModel = AuthViewModel(service: service)
        let userID = UUID(uuidString: "00000000-0000-0000-0000-00000000A001")!

        service.send(.signedIn(userID: userID, email: "alex@example.com"))
        try await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertTrue(viewModel.isAuthenticated)
        XCTAssertEqual(service.bootstrappedProfileUserID, userID)
        XCTAssertEqual(service.bootstrappedProfileEmail, "alex@example.com")
        XCTAssertFalse(viewModel.isLoading)
    }

    func testSignedOutSessionClearsAuthenticatedState() async throws {
        let service = FakeAuthService()
        let viewModel = AuthViewModel(service: service)

        service.send(.signedIn(userID: UUID(), email: "alex@example.com"))
        service.send(.signedOut)
        try await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertFalse(viewModel.isAuthenticated)
        XCTAssertFalse(viewModel.isLoading)
    }
}

private final class FakeAuthService: AuthServicing {
    private let continuation: AsyncStream<AuthSessionState>.Continuation
    let sessionStates: AsyncStream<AuthSessionState>
    var sentMagicLinkEmail: String?
    var sentMagicLinkDisplayName: String?
    var didSendMagicLink: Bool { sentMagicLinkEmail != nil }
    var bootstrappedProfileUserID: UUID?
    var bootstrappedProfileEmail: String?

    init() {
        var capturedContinuation: AsyncStream<AuthSessionState>.Continuation!
        sessionStates = AsyncStream { continuation in
            capturedContinuation = continuation
        }
        continuation = capturedContinuation
    }

    func send(_ state: AuthSessionState) {
        continuation.yield(state)
    }

    func sendMagicLink(email: String, displayName: String?) async throws {
        sentMagicLinkEmail = email
        sentMagicLinkDisplayName = displayName
    }

    func signOut() async throws { }

    func bootstrapProfile(userID: UUID, email: String?) async throws {
        bootstrappedProfileUserID = userID
        bootstrappedProfileEmail = email
    }
}

@MainActor
final class TripStoreCloudSyncTests: XCTestCase {
    func testCloudStoreLoadsTripsFromInjectedService() async throws {
        let service = FakeTripSyncService()
        let remoteTrip = makeTrip(id: UUID(uuidString: "00000000-0000-0000-0000-00000000B001")!, name: "Austin Weekend")
        service.tripsToLoad = [remoteTrip]
        let store = TripStore(service: service)

        await store.loadTrips()

        XCTAssertTrue(service.didLoadTrips)
        XCTAssertEqual(store.trips.map(\.id), [remoteTrip.id])
        XCTAssertFalse(store.isLoading)
        XCTAssertNil(store.syncError)
    }

    func testCloudStoreCreatesRemoteTripWithTrimmedValuesAndAppendsReturnedTrip() async throws {
        let service = FakeTripSyncService()
        let createdTrip = makeTrip(id: UUID(uuidString: "00000000-0000-0000-0000-00000000B002")!, name: "Kyoto Spring")
        service.tripToCreate = createdTrip
        let store = TripStore(service: service)
        let startDate = SupabaseDateFormatter.date(from: "2027-03-24")!
        let endDate = SupabaseDateFormatter.date(from: "2027-04-04")!

        await store.addRemoteTrip(
            name: " Kyoto Spring ",
            destination: " Kyoto ",
            emoji: " 🌸 ",
            imageURL: " https://example.com/kyoto.jpg ",
            startDate: startDate,
            endDate: endDate
        )

        XCTAssertEqual(service.createdTripRequest?.name, "Kyoto Spring")
        XCTAssertEqual(service.createdTripRequest?.destination, "Kyoto")
        XCTAssertEqual(service.createdTripRequest?.emoji, "🌸")
        XCTAssertEqual(service.createdTripRequest?.imageURL, "https://example.com/kyoto.jpg")
        XCTAssertEqual(store.trips.map(\.id), [createdTrip.id])
        XCTAssertNil(store.syncError)
    }

    func testCloudStoreReportsCreateFailureWithoutAppendingLocalTrip() async {
        let service = FakeTripSyncService()
        service.createError = TestError.intentional
        let store = TripStore(service: service)
        let date = SupabaseDateFormatter.date(from: "2027-03-24")!

        await store.addRemoteTrip(
            name: "Kyoto Spring",
            destination: "Kyoto",
            emoji: "🌸",
            imageURL: "https://example.com/kyoto.jpg",
            startDate: date,
            endDate: date
        )

        XCTAssertTrue(store.trips.isEmpty)
        XCTAssertEqual(store.syncError, TestError.intentional.localizedDescription)
    }

    func testCloudStoreCreatesGuestInviteForTrip() async throws {
        let service = FakeTripSyncService()
        let tripID = UUID(uuidString: "00000000-0000-0000-0000-00000000B003")!
        let invite = TripInvite(id: UUID(uuidString: "00000000-0000-0000-0000-00000000C001")!, tripID: tripID, code: "WANI2027", role: .guest)
        service.inviteToCreate = invite
        let store = TripStore(service: service)

        await store.createInvite(for: tripID)

        XCTAssertEqual(service.createdInviteRequest?.tripID, tripID)
        XCTAssertEqual(service.createdInviteRequest?.role, .guest)
        XCTAssertEqual(store.createdInvite, invite)
        XCTAssertNil(store.syncError)
    }

    func testCloudStoreLooksUpTrimmedUppercaseInviteCode() async throws {
        let service = FakeTripSyncService()
        let preview = TripInvitePreview(
            inviteID: UUID(uuidString: "00000000-0000-0000-0000-00000000C002")!,
            tripID: UUID(uuidString: "00000000-0000-0000-0000-00000000B004")!,
            tripName: "Austin Weekend",
            role: .guest,
            expiresAt: nil
        )
        service.invitePreviewToLookup = preview
        let store = TripStore(service: service)

        await store.lookupInvite(code: " wani2027 ")

        XCTAssertEqual(service.lookedUpInviteCode, "WANI2027")
        XCTAssertEqual(store.invitePreview, preview)
        XCTAssertNil(store.syncError)
    }

    func testCloudStoreAcceptsInviteThenReloadsTrips() async throws {
        let service = FakeTripSyncService()
        let tripID = UUID(uuidString: "00000000-0000-0000-0000-00000000B005")!
        let joinedTrip = makeTrip(id: tripID, name: "Austin Weekend")
        service.tripsToLoad = [joinedTrip]
        let store = TripStore(service: service)
        store.invitePreview = TripInvitePreview(
            inviteID: UUID(uuidString: "00000000-0000-0000-0000-00000000C003")!,
            tripID: tripID,
            tripName: "Austin Weekend",
            role: .guest,
            expiresAt: nil
        )

        await store.acceptInvite(code: " wani2027 ")

        XCTAssertEqual(service.acceptedInviteCode, "WANI2027")
        XCTAssertTrue(service.didLoadTrips)
        XCTAssertEqual(store.trips.map(\.id), [tripID])
        XCTAssertNil(store.invitePreview)
        XCTAssertNil(store.syncError)
    }

    func testCloudStoreReportsInviteAcceptFailureWithoutReloadingTrips() async {
        let service = FakeTripSyncService()
        service.createError = TestError.intentional
        let store = TripStore(service: service)

        await store.acceptInvite(code: "WANI2027")

        XCTAssertEqual(service.acceptedInviteCode, "WANI2027")
        XCTAssertFalse(service.didLoadTrips)
        XCTAssertTrue(store.trips.isEmpty)
        XCTAssertEqual(store.syncError, TestError.intentional.localizedDescription)
    }

    private func makeTrip(id: UUID, name: String) -> TripPlan {
        TripPlan(
            id: id,
            destination: "Austin",
            emoji: "🤠",
            imageURL: "https://example.com/austin.jpg",
            startDate: SupabaseDateFormatter.date(from: "2026-07-03")!,
            endDate: SupabaseDateFormatter.date(from: "2026-07-06")!,
            viewModel: TripCalculatorViewModel.empty(named: name)
        )
    }
}

private final class FakeTripSyncService: TripSyncServicing {
    struct CreateTripRequest: Equatable {
        var name: String
        var destination: String
        var emoji: String
        var imageURL: String
        var startDate: Date
        var endDate: Date
    }

    struct CreateInviteRequest: Equatable {
        var tripID: UUID
        var role: TripInvite.Role
    }

    var tripsToLoad: [TripPlan] = []
    var tripToCreate: TripPlan?
    var inviteToCreate: TripInvite?
    var invitePreviewToLookup: TripInvitePreview?
    var didLoadTrips = false
    var createdTripRequest: CreateTripRequest?
    var createdInviteRequest: CreateInviteRequest?
    var lookedUpInviteCode: String?
    var acceptedInviteCode: String?
    var createError: Error?

    func loadTrips() async throws -> [TripPlan] {
        didLoadTrips = true
        return tripsToLoad
    }

    func createTrip(name: String, destination: String, emoji: String, imageURL: String, startDate: Date, endDate: Date) async throws -> TripPlan {
        if let createError { throw createError }
        createdTripRequest = CreateTripRequest(name: name, destination: destination, emoji: emoji, imageURL: imageURL, startDate: startDate, endDate: endDate)
        return tripToCreate ?? TripPlan(destination: destination, emoji: emoji, imageURL: imageURL, startDate: startDate, endDate: endDate, viewModel: TripCalculatorViewModel.empty(named: name))
    }

    func createInvite(for tripID: UUID, role: TripInvite.Role) async throws -> TripInvite {
        if let createError { throw createError }
        createdInviteRequest = CreateInviteRequest(tripID: tripID, role: role)
        return inviteToCreate ?? TripInvite(tripID: tripID, code: "WANI2027", role: role)
    }

    func lookupInvite(code: String) async throws -> TripInvitePreview? {
        if let createError { throw createError }
        lookedUpInviteCode = code
        return invitePreviewToLookup
    }

    func acceptInvite(code: String) async throws {
        acceptedInviteCode = code
        if let createError { throw createError }
    }
}

private enum TestError: LocalizedError {
    case intentional

    var errorDescription: String? { "Intentional failure" }
}

final class AppSessionTests: XCTestCase {
    func testStartsWithoutSelectedMode() {
        let session = AppSession()

        XCTAssertNil(session.mode)
        XCTAssertFalse(session.shouldUseDemoTripStore)
        XCTAssertFalse(session.shouldUseCloudTripStore)
    }

    func testChoosingDemoModeUsesOnlyDemoTripStore() {
        let session = AppSession()

        session.chooseDemoMode()

        XCTAssertEqual(session.mode, .demo)
        XCTAssertTrue(session.shouldUseDemoTripStore)
        XCTAssertFalse(session.shouldUseCloudTripStore)
    }

    func testChoosingSignedInModeUsesOnlyCloudTripStore() {
        let session = AppSession()

        session.chooseSignedInMode()

        XCTAssertEqual(session.mode, .signedIn)
        XCTAssertFalse(session.shouldUseDemoTripStore)
        XCTAssertTrue(session.shouldUseCloudTripStore)
    }

    func testReturningToModePickerClearsSelectedMode() {
        let session = AppSession()
        session.chooseDemoMode()

        session.returnToModePicker()

        XCTAssertNil(session.mode)
        XCTAssertFalse(session.shouldUseDemoTripStore)
        XCTAssertFalse(session.shouldUseCloudTripStore)
    }
}

final class TripCollaborationModelsTests: XCTestCase {
    func testTripMemberAndExpenseParticipantAreSeparateConcepts() {
        let memberID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let participantID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!

        let member = TripMember(id: memberID, displayName: "Alex", role: .owner)
        let participant = ExpenseParticipant(id: participantID, displayName: "Alex", linkedMemberID: member.id)

        XCTAssertEqual(member.displayName, participant.displayName)
        XCTAssertEqual(participant.linkedMemberID, member.id)
        XCTAssertNotEqual(member.id, participant.id)
    }

    func testOrganizerIsOwnerMemberAndParticipantWhenCreatingTrip() {
        let accountID = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!

        let collaboration = TripCollaboration.createTrip(
            organizerDisplayName: "Alex",
            organizerAccountID: accountID
        )

        XCTAssertEqual(collaboration.members.count, 1)
        XCTAssertEqual(collaboration.participants.count, 1)

        let organizerMember = collaboration.members[0]
        let organizerParticipant = collaboration.participants[0]

        XCTAssertEqual(organizerMember.displayName, "Alex")
        XCTAssertEqual(organizerMember.role, .owner)
        XCTAssertEqual(organizerMember.accountID, accountID)
        XCTAssertEqual(organizerMember.accessState, .active)
        XCTAssertEqual(organizerParticipant.displayName, "Alex")
        XCTAssertEqual(organizerParticipant.linkedMemberID, organizerMember.id)
    }

    func testDuplicateGuestDisplayNamesRemainDistinctThroughInternalIDs() {
        let firstGuest = ExpenseParticipant.guest(displayName: "Sam")
        let secondGuest = ExpenseParticipant.guest(displayName: "Sam")

        XCTAssertEqual(firstGuest.displayName, "Sam")
        XCTAssertEqual(secondGuest.displayName, "Sam")
        XCTAssertNil(firstGuest.linkedMemberID)
        XCTAssertNil(secondGuest.linkedMemberID)
        XCTAssertNotEqual(firstGuest.id, secondGuest.id)
    }

    func testRevokingMemberAccessKeepsHistoricalExpenseParticipantIdentity() {
        let memberID = UUID(uuidString: "00000000-0000-0000-0000-000000000004")!
        let participantID = UUID(uuidString: "00000000-0000-0000-0000-000000000005")!
        let member = TripMember(id: memberID, displayName: "Jordan", role: .guest)
        let participant = ExpenseParticipant(id: participantID, displayName: "Jordan", linkedMemberID: member.id)
        var collaboration = TripCollaboration(members: [member], participants: [participant])

        collaboration.revokeAccess(for: member.id)

        XCTAssertEqual(collaboration.members[0].accessState, .revoked)
        XCTAssertEqual(collaboration.participants.count, 1)
        XCTAssertEqual(collaboration.participants[0].id, participantID)
        XCTAssertEqual(collaboration.participants[0].linkedMemberID, memberID)
    }
}
