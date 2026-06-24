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
