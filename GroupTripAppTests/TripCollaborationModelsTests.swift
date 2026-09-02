import XCTest
import SwiftUI
import UIKit
@testable import GroupTripApp

final class SupabaseDTOTests: XCTestCase {
    func testGoogleOAuthRedirectURLUsesAnIOSCallbackScheme() throws {
        let redirectURL = try XCTUnwrap(SupabaseConfig.googleOAuthRedirectURL)

        XCTAssertEqual(redirectURL.scheme, "com.googleusercontent.apps.698662305037-53om03eo495ihep40hajtarku2bjgktp")
        XCTAssertEqual(redirectURL.host, "auth-callback")
    }

    func testGoogleOAuthRequestsAccountSelectionForManualMultiUserTesting() {
        XCTAssertTrue(
            SupabaseConfig.googleOAuthQueryParams.contains { name, value in
                name == "prompt" && value == "select_account"
            }
        )
        XCTAssertTrue(SupabaseConfig.googleOAuthPrefersEphemeralWebSession)
    }

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

    func testAssemblesLoadedCloudTripsWithOnlyTheirRelatedRows() throws {
        let austinTripID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let kyotoTripID = UUID(uuidString: "11111111-1111-1111-1111-111111111112")!
        let unrelatedTripID = UUID(uuidString: "11111111-1111-1111-1111-111111111113")!
        let alexID = UUID(uuidString: "55555555-5555-5555-5555-555555555551")!
        let samID = UUID(uuidString: "55555555-5555-5555-5555-555555555552")!
        let expenseID = UUID(uuidString: "77777777-7777-7777-7777-777777777777")!
        let unrelatedExpenseID = UUID(uuidString: "77777777-7777-7777-7777-777777777778")!

        let trips = SupabaseTripService.assembleTrips(
            trips: [
                SupabaseTripDTO(id: austinTripID, name: "Austin Weekend", destination: "Austin", emoji: "🤠", imageURL: "https://example.com/austin.jpg", startDate: "2026-07-03", endDate: "2026-07-06"),
                SupabaseTripDTO(id: kyotoTripID, name: "Kyoto Spring", destination: "Kyoto", emoji: "🌸", imageURL: "https://example.com/kyoto.jpg", startDate: "2027-03-24", endDate: "2027-04-04")
            ],
            participants: [
                SupabaseTripParticipantDTO(id: alexID, tripID: austinTripID, displayName: "Alex", linkedMemberID: nil, linkedUserID: nil, isOrganizer: true),
                SupabaseTripParticipantDTO(id: samID, tripID: austinTripID, displayName: "Sam", linkedMemberID: nil, linkedUserID: nil, isOrganizer: false),
                SupabaseTripParticipantDTO(id: UUID(uuidString: "55555555-5555-5555-5555-555555555553")!, tripID: unrelatedTripID, displayName: "Unrelated", linkedMemberID: nil, linkedUserID: nil, isOrganizer: false)
            ],
            places: [
                SupabaseTripPlaceDTO(id: UUID(uuidString: "66666666-6666-6666-6666-666666666661")!, tripID: austinTripID, name: "Zilker Park", note: "Picnic", tag: "Outdoors", googlePlaceID: nil, latitude: nil, longitude: nil),
                SupabaseTripPlaceDTO(id: UUID(uuidString: "66666666-6666-6666-6666-666666666662")!, tripID: unrelatedTripID, name: "Unrelated Place", note: "", tag: "", googlePlaceID: nil, latitude: nil, longitude: nil)
            ],
            planningItems: [
                SupabaseTripPlanningItemDTO(id: UUID(uuidString: "66666666-6666-6666-6666-666666666663")!, tripID: austinTripID, title: "Book dinner", note: "Friday", scheduledDate: "2026-07-03", isDone: false)
            ],
            expenses: [
                SupabaseTripExpenseDTO(id: expenseID, tripID: austinTripID, title: "Hotel", paidByParticipantID: alexID, amount: 200, currencyCode: "USD", incurredOn: "2026-07-03"),
                SupabaseTripExpenseDTO(id: unrelatedExpenseID, tripID: unrelatedTripID, title: "Unrelated", paidByParticipantID: alexID, amount: 999, currencyCode: "USD", incurredOn: nil)
            ],
            splits: [
                SupabaseTripExpenseSplitDTO(expenseID: expenseID, participantID: alexID, shareAmount: 100),
                SupabaseTripExpenseSplitDTO(expenseID: expenseID, participantID: samID, shareAmount: 100),
                SupabaseTripExpenseSplitDTO(expenseID: unrelatedExpenseID, participantID: alexID, shareAmount: 999)
            ],
            directPayments: [
                SupabaseTripDirectPaymentDTO(id: UUID(uuidString: "88888888-8888-8888-8888-888888888888")!, tripID: austinTripID, title: "Sam paid Alex", fromParticipantID: samID, toParticipantID: alexID, amount: 50, currencyCode: "USD", paidOn: "2026-07-04")
            ]
        )

        let austin = try XCTUnwrap(trips.first { $0.id == austinTripID })
        let kyoto = try XCTUnwrap(trips.first { $0.id == kyotoTripID })

        XCTAssertEqual(austin.places.map(\.name), ["Zilker Park"])
        XCTAssertEqual(austin.planningItems.map(\.title), ["Book dinner"])
        XCTAssertEqual(austin.viewModel.calculator.participants.map(\.name), ["Alex", "Sam"])
        XCTAssertEqual(austin.viewModel.calculator.expenses.map(\.title), ["Hotel"])
        XCTAssertEqual(austin.viewModel.calculator.expenses.first?.participants, Set([alexID, samID]))
        XCTAssertEqual(austin.viewModel.calculator.payments.map(\.amount), [50])
        XCTAssertTrue(kyoto.places.isEmpty)
        XCTAssertTrue(kyoto.planningItems.isEmpty)
        XCTAssertTrue(kyoto.viewModel.calculator.participants.isEmpty)
        XCTAssertTrue(kyoto.viewModel.calculator.expenses.isEmpty)
    }

    func testParticipantDTOParticipantPreservesLinkedUserIDAsAccountID() {
        let userID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
        let dto = SupabaseTripParticipantDTO(
            id: UUID(uuidString: "55555555-5555-5555-5555-555555555551")!,
            tripID: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            displayName: "Alex",
            linkedUserID: userID
        )

        XCTAssertEqual(dto.participant.accountID, userID)
        XCTAssertNil(SupabaseTripParticipantDTO(
            id: UUID(uuidString: "55555555-5555-5555-5555-555555555552")!,
            tripID: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            displayName: "Sam"
        ).participant.accountID)
    }

    func testParticipantDTOOrganizerRoundTripsBothDirections() {
        let tripID = UUID(uuidString: "11111111-1111-1111-1111-1111111111A1")!
        let organizerID = UUID(uuidString: "55555555-5555-5555-5555-5555555555A1")!
        let travelerID = UUID(uuidString: "55555555-5555-5555-5555-5555555555A2")!

        let organizerDTO = SupabaseTripParticipantDTO(
            id: organizerID,
            tripID: tripID,
            displayName: "Alex",
            isOrganizer: true
        )
        let travelerDTO = SupabaseTripParticipantDTO(
            id: travelerID,
            tripID: tripID,
            displayName: "Sam"
        )

        XCTAssertTrue(organizerDTO.participant.isOrganizer)
        XCTAssertFalse(travelerDTO.participant.isOrganizer)

        let encodedOrganizer = SupabaseTripParticipantDTO(tripID: tripID, participant: organizerDTO.participant)
        let encodedTraveler = SupabaseTripParticipantDTO(tripID: tripID, participant: travelerDTO.participant)
        XCTAssertTrue(encodedOrganizer.isOrganizer)
        XCTAssertFalse(encodedTraveler.isOrganizer)
    }

    func testAssembledCloudTripParticipantsCarryIsOrganizer() throws {
        let tripID = UUID(uuidString: "11111111-1111-1111-1111-1111111111A2")!
        let alexID = UUID(uuidString: "55555555-5555-5555-5555-5555555555A3")!
        let samID = UUID(uuidString: "55555555-5555-5555-5555-5555555555A4")!

        let trips = SupabaseTripService.assembleTrips(
            trips: [SupabaseTripDTO(id: tripID, name: "Austin Weekend", destination: "Austin", emoji: "🤠", imageURL: nil, startDate: "2026-07-03", endDate: "2026-07-06")],
            participants: [
                SupabaseTripParticipantDTO(id: alexID, tripID: tripID, displayName: "Alex", isOrganizer: true),
                SupabaseTripParticipantDTO(id: samID, tripID: tripID, displayName: "Sam")
            ],
            places: [],
            planningItems: [],
            expenses: [],
            splits: [],
            directPayments: []
        )

        let trip = try XCTUnwrap(trips.first)
        let byID = Dictionary(uniqueKeysWithValues: trip.viewModel.calculator.participants.map { ($0.id, $0) })
        XCTAssertTrue(byID[alexID]?.isOrganizer == true)
        XCTAssertFalse(byID[samID]?.isOrganizer ?? true)
    }

    func testParticipantDTOInitFromParticipantCarriesAccountIDAsLinkedUserID() {
        let accountID = UUID(uuidString: "33333333-3333-3333-3333-333333333334")!
        let participant = Participant(
            id: UUID(uuidString: "55555555-5555-5555-5555-555555555553")!,
            name: "Alex",
            accountID: accountID
        )

        let dto = SupabaseTripParticipantDTO(
            tripID: UUID(uuidString: "11111111-1111-1111-1111-111111111112")!,
            participant: participant
        )

        XCTAssertEqual(dto.linkedUserID, accountID)
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
                SupabaseTripPlaceDTO(id: UUID(uuidString: "66666666-6666-6666-6666-666666666666")!, tripID: tripDTO.id, name: "Zilker Park", note: "Picnic", tag: "Outdoors", googlePlaceID: "zilker", latitude: 30.2669, longitude: -97.7729)
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

    func testItemTagDTOsAndLinkDTOsMapSnakeCaseRows() throws {
        let placeID = UUID(uuidString: "66666666-6666-6666-6666-666666666681")!
        let planID = UUID(uuidString: "66666666-6666-6666-6666-666666666682")!
        let tripID = UUID(uuidString: "11111111-1111-1111-1111-111111111181")!
        let participantID = UUID(uuidString: "55555555-5555-5555-5555-555555555581")!
        let json = """
        {
          "id": "66666666-6666-6666-6666-666666666681",
          "trip_id": "11111111-1111-1111-1111-111111111181",
          "name": "Zilker Park",
          "note": "Picnic",
          "tag": "food",
          "google_place_id": "zilker",
          "latitude": 30.2669,
          "longitude": -97.7729
        }
        """.data(using: .utf8)!

        let place = try JSONDecoder().decode(SupabaseTripPlaceDTO.self, from: json)
        let placeLink = SupabasePlaceParticipantDTO(placeID: placeID, participantID: participantID)
        let planningLink = SupabasePlanningItemParticipantDTO(planningItemID: planID, participantID: participantID)
        let planning = SupabaseTripPlanningItemDTO(
            id: planID,
            tripID: tripID,
            title: "Book dinner",
            note: "Friday",
            scheduledDate: "2026-07-03",
            isDone: false,
            tag: "show"
        )

        XCTAssertEqual(place.tag, "food")
        XCTAssertEqual(place.tripPlace().tag, "food")
        XCTAssertEqual(SupabaseTripPlaceDTO(tripID: tripID, place: TripPlace(id: placeID, name: "Cafe", tag: "food")).tag, "food")
        XCTAssertEqual(planning.tripPlanningItem().tag, "show")
        XCTAssertEqual(SupabaseTripPlanningItemDTO(tripID: tripID, item: planning.tripPlanningItem()).tag, "show")
        XCTAssertEqual(placeLink.placeID, placeID)
        XCTAssertEqual(placeLink.participantID, participantID)
        XCTAssertEqual(planningLink.planningItemID, planID)
        XCTAssertEqual(planningLink.participantID, participantID)
    }

    func testAssemblesItemTagsAndParticipantIDsFromFetchedLinks() throws {
        let tripID = UUID(uuidString: "11111111-1111-1111-1111-111111111182")!
        let placeID = UUID(uuidString: "66666666-6666-6666-6666-666666666683")!
        let planID = UUID(uuidString: "66666666-6666-6666-6666-666666666684")!
        let alexID = UUID(uuidString: "55555555-5555-5555-5555-555555555582")!
        let samID = UUID(uuidString: "55555555-5555-5555-5555-555555555583")!

        let trips = SupabaseTripService.assembleTrips(
            trips: [SupabaseTripDTO(id: tripID, name: "Austin Weekend", destination: "Austin", emoji: "🤠", imageURL: nil, startDate: "2026-07-03", endDate: "2026-07-06")],
            participants: [
                SupabaseTripParticipantDTO(id: alexID, tripID: tripID, displayName: "Alex"),
                SupabaseTripParticipantDTO(id: samID, tripID: tripID, displayName: "Sam")
            ],
            places: [SupabaseTripPlaceDTO(id: placeID, tripID: tripID, name: "Zilker", note: "", tag: "food")],
            planningItems: [SupabaseTripPlanningItemDTO(id: planID, tripID: tripID, title: "Book dinner", note: "", scheduledDate: nil, isDone: false, tag: "show")],
            expenses: [],
            splits: [],
            directPayments: [],
            placeParticipants: [
                SupabasePlaceParticipantDTO(placeID: placeID, participantID: alexID),
                SupabasePlaceParticipantDTO(placeID: placeID, participantID: samID)
            ],
            planningItemParticipants: [SupabasePlanningItemParticipantDTO(planningItemID: planID, participantID: samID)]
        )

        let trip = try XCTUnwrap(trips.first)
        XCTAssertEqual(trip.places.first?.tag, "food")
        XCTAssertEqual(trip.places.first?.participantIDs, [alexID, samID])
        XCTAssertEqual(trip.planningItems.first?.tag, "show")
        XCTAssertEqual(trip.planningItems.first?.participantIDs, [samID])
    }

    func testTripTagVocabularyAndPerItemSubsets() {
        XCTAssertEqual(TripTag.canonical.map(\.rawValue), ["food", "hotel", "flight", "show", "museum", "custom"])
        XCTAssertEqual(TripTag.subset(for: .place).map(\.rawValue), ["food", "hotel", "show", "museum"])
        XCTAssertEqual(TripTag.subset(for: .planningItem).map(\.rawValue), ["flight", "hotel", "show", "museum", "custom"])
        XCTAssertEqual(TripTag("ramen").rawValue, "ramen")
    }
}

final class PeopleRoomsLogicTests: XCTestCase {
    private let tripID = UUID(uuidString: "00000000-0000-4000-8000-00000000C501")!

    private func participant(_ name: String, organizer: Bool = false) -> Participant {
        Participant(name: name, isOrganizer: organizer)
    }

    func testHallGroupingSplitsOrganizersAndTravelersAlphabetically() {
        let alex = participant("Alex", organizer: true)
        let sawjai = participant("Sawjai", organizer: true)
        let zoe = participant("Zoe")
        let maya = participant("Maya")

        let grouped = PeopleHall.grouped(alex, zoe, sawjai, maya)

        XCTAssertEqual(grouped.organizers.map(\.name), ["Alex", "Sawjai"])
        XCTAssertEqual(grouped.travelers.map(\.name), ["Maya", "Zoe"])
    }

    func testHallGroupingHidesEmptyGroups() {
        let solo = participant("Solo", organizer: true)
        let grouped = PeopleHall.grouped(solo)

        XCTAssertEqual(grouped.organizers.map(\.name), ["Solo"])
        XCTAssertTrue(grouped.travelers.isEmpty)
    }

    func testBalancePhraseGetsBackOwesAndSettled() {
        XCTAssertEqual(PersonBalancePhrase(net: 128).text, "Gets back $128")
        XCTAssertEqual(PersonBalancePhrase(net: -42).text, "Owes $42")
        XCTAssertEqual(PersonBalancePhrase(net: 0).text, "Settled")
    }

    func testPersonFootprintAggregatesExpensesPlacesAndPlans() {
        let tripID = self.tripID
        let alex = participant("Alex")
        let sam = participant("Sam")
        let expenses = [
            ExpenseItem(title: "Hotel", paidBy: alex.id, amount: 200, participants: [alex.id, sam.id]),
            ExpenseItem(title: "Tacos", paidBy: sam.id, amount: 60, participants: [alex.id, sam.id]),
            ExpenseItem(title: "Solo shirt", paidBy: sam.id, amount: 30, participants: [sam.id])
        ]
        let places = [
            TripPlace(name: "Zilker", participantIDs: [alex.id]),
            TripPlace(name: "Barton Springs", participantIDs: [alex.id, sam.id])
        ]
        let plans = [
            TripPlanningItem(title: "Book dinner", participantIDs: [alex.id]),
            TripPlanningItem(title: "Kayak", participantIDs: [sam.id])
        ]

        let footprint = PersonFootprint.aggregate(
            participantID: alex.id,
            tripID: tripID,
            expenses: expenses,
            places: places,
            planningItems: plans
        )

        XCTAssertEqual(footprint.paidExpenses.map(\.title), ["Hotel"])
        XCTAssertEqual(footprint.sharedExpenses.map(\.title), ["Tacos"])
        XCTAssertEqual(footprint.places.map(\.name), ["Barton Springs", "Zilker"])
        XCTAssertEqual(footprint.plans.map(\.title), ["Book dinner"])
    }

    func testPickerToggleResolutionAddsAndRemovesMembership() {
        let alexID = UUID(uuidString: "00000000-0000-4000-8000-00000000A501")!
        let samID = UUID(uuidString: "00000000-0000-4000-8000-00000000A502")!
        let zoeID = UUID(uuidString: "00000000-0000-4000-8000-00000000A503")!
        var selection = ParticipantSelection()
        XCTAssertFalse(selection.contains(alexID))

        selection.toggle(alexID)
        selection.toggle(samID)
        XCTAssertEqual(selection.orderedIDs, [alexID, samID])
        XCTAssertTrue(selection.contains(alexID))
        XCTAssertFalse(selection.contains(zoeID))

        selection.toggle(alexID)
        XCTAssertEqual(selection.orderedIDs, [samID])
        XCTAssertFalse(selection.contains(alexID))
    }

    func testShareTextBuilderTrimsAndUppercasesCode() {
        XCTAssertEqual(
            TripShareTextBuilder.text(tripName: "  Japan Spring 2027 ", inviteCode: "  abc123 "),
            "Join Japan Spring 2027 on Wanderaid — invite code ABC123"
        )
        XCTAssertNil(TripShareTextBuilder.text(tripName: "Trip", inviteCode: "   "))
    }

    func testPersonBalanceUsesTripRelativeNetFromCalculator() {
        let alex = participant("Alex")
        let sam = participant("Sam")
        let calculator = TripExpenseCalculator(
            participants: [alex, sam],
            expenses: [
                ExpenseItem(title: "Hotel", paidBy: alex.id, amount: 200, participants: [alex.id, sam.id])
            ],
            payments: []
        )

        let alexProfile = PersonBalance.phrase(net: calculator.balances().first { $0.participant.id == alex.id }!.net)
        let samProfile = PersonBalance.phrase(net: calculator.balances().first { $0.participant.id == sam.id }!.net)
        XCTAssertEqual(alexProfile.text, "Gets back $100")
        XCTAssertEqual(samProfile.text, "Owes $100")
    }
}

final class CountdownDurationTests: XCTestCase {
    func testCountdownDurationBreaksIntervalIntoDaysHoursMinutesAndSeconds() {
        let duration = CountdownDuration(from: 0, to: 2 * 86_400 + 3 * 3_600 + 4 * 60 + 5)

        XCTAssertEqual(duration.days, 2)
        XCTAssertEqual(duration.hours, 3)
        XCTAssertEqual(duration.minutes, 4)
        XCTAssertEqual(duration.seconds, 5)
    }

    func testCountdownDurationRollsOverAtUnitBoundaries() {
        let duration = CountdownDuration(from: 0, to: 86_400 + 3_600 + 60 + 1)

        XCTAssertEqual(duration.days, 1)
        XCTAssertEqual(duration.hours, 1)
        XCTAssertEqual(duration.minutes, 1)
        XCTAssertEqual(duration.seconds, 1)
    }

    func testCountdownDurationClampsPastDatesToZero() {
        let duration = CountdownDuration(from: 100, to: 40)

        XCTAssertEqual(duration.days, 0)
        XCTAssertEqual(duration.hours, 0)
        XCTAssertEqual(duration.minutes, 0)
        XCTAssertEqual(duration.seconds, 0)
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
        XCTAssertEqual(viewModel.authMessage, "Check your email for a Wanderaid sign-in link.")
        XCTAssertFalse(viewModel.isLoading)
    }

    func testSignInWithApplePassesIDTokenAndNonceToService() async {
        let service = FakeAuthService()
        let viewModel = AuthViewModel(service: service)

        await viewModel.signInWithApple(idToken: "apple-id-token", nonce: "raw-nonce")

        XCTAssertEqual(service.appleIDToken, "apple-id-token")
        XCTAssertEqual(service.appleNonce, "raw-nonce")
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

    func testSignedInSessionStoresCurrentUserID() async throws {
        let service = FakeAuthService()
        let viewModel = AuthViewModel(service: service)
        let userID = UUID(uuidString: "00000000-0000-0000-0000-00000000A002")!

        service.send(.signedIn(userID: userID, email: "alex@example.com"))
        try await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(viewModel.currentUserID, userID)
        XCTAssertTrue(viewModel.isAuthenticated)
    }

    func testSignedOutSessionClearsCurrentUserID() async throws {
        let service = FakeAuthService()
        let viewModel = AuthViewModel(service: service)

        service.send(.signedIn(userID: UUID(uuidString: "00000000-0000-0000-0000-00000000A003")!, email: "alex@example.com"))
        try await Task.sleep(nanoseconds: 50_000_000)
        service.send(.signedOut)
        try await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertNil(viewModel.currentUserID)
        XCTAssertFalse(viewModel.isAuthenticated)
    }
}

private final class FakeAuthService: AuthServicing {
    private let continuation: AsyncStream<AuthSessionState>.Continuation
    let sessionStates: AsyncStream<AuthSessionState>
    var sentMagicLinkEmail: String?
    var sentMagicLinkDisplayName: String?
    var didSendMagicLink: Bool { sentMagicLinkEmail != nil }
    var appleIDToken: String?
    var appleNonce: String?
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

    func signInWithGoogle() async throws { }

    func signInWithApple(idToken: String, nonce: String?) async throws {
        appleIDToken = idToken
        appleNonce = nonce
    }

    func bootstrapProfile(userID: UUID, email: String?) async throws {
        bootstrappedProfileUserID = userID
        bootstrappedProfileEmail = email
    }
}

final class PlanningTimelineLogicTests: XCTestCase {
    func testPlanningTimelineGroupsDatedItemsAscendingWithTimedItemsFirst() {
        let calendar = Calendar(identifier: .gregorian)
        let september2 = Self.date(2026, 9, 2, calendar: calendar)
        let september3 = Self.date(2026, 9, 3, calendar: calendar)
        let breakfast = TripPlanningItem(title: "Breakfast", date: september2, time: Self.time(8, 20, calendar: calendar))
        let museum = TripPlanningItem(title: "Museum", date: september2, time: Self.time(10, 0, calendar: calendar))
        let wander = TripPlanningItem(title: "Wander", date: september2)
        let flight = TripPlanningItem(title: "Flight", date: september3, time: Self.time(7, 30, calendar: calendar))

        let sections = PlanningTimeline.sections(from: [wander, flight, museum, breakfast], calendar: calendar)

        XCTAssertEqual(sections.dated.map { SupabaseDateFormatter.string(from: $0.date) }, ["2026-09-02", "2026-09-03"])
        XCTAssertEqual(sections.dated[0].items.map(\.title), ["Breakfast", "Museum", "Wander"])
        XCTAssertEqual(sections.dated[1].items.map(\.title), ["Flight"])
        XCTAssertTrue(sections.undated.isEmpty)
    }

    func testPlanningTimelineKeepsDoneItemsInDayGroupAndPreservesTies() {
        let calendar = Calendar(identifier: .gregorian)
        let date = Self.date(2026, 9, 2, calendar: calendar)
        let first = TripPlanningItem(title: "First", date: date, time: Self.time(9, 0, calendar: calendar), isDone: true)
        let second = TripPlanningItem(title: "Second", date: date, time: Self.time(9, 0, calendar: calendar))
        let third = TripPlanningItem(title: "Third", date: date)
        let fourth = TripPlanningItem(title: "Fourth", date: date)

        let firstRun = PlanningTimeline.sections(from: [third, first, second, fourth], calendar: calendar)
        let secondRun = PlanningTimeline.sections(from: [third, first, second, fourth], calendar: calendar)

        XCTAssertEqual(firstRun.dated.single?.items.map(\.title), ["First", "Second", "Third", "Fourth"])
        XCTAssertEqual(firstRun.dated.single?.items.first?.isDone, true)
        XCTAssertEqual(firstRun.dated, secondRun.dated)
        XCTAssertEqual(firstRun.undated, secondRun.undated)
    }

    func testPlanningTimelineSeparatesUndatedBacklogInInputOrder() {
        let calendar = Calendar(identifier: .gregorian)
        let dated = TripPlanningItem(title: "Dated", date: Self.date(2026, 9, 2, calendar: calendar))
        let maybe = TripPlanningItem(title: "Maybe")
        let later = TripPlanningItem(title: "Later")

        let sections = PlanningTimeline.sections(from: [maybe, dated, later], calendar: calendar)

        XCTAssertEqual(sections.dated.single?.items.map(\.title), ["Dated"])
        XCTAssertEqual(sections.undated.map(\.title), ["Maybe", "Later"])
    }

    func testSupabaseTimeFormatterRoundTripsHourAndMinuteOnFixedReferenceDay() throws {
        let time = try XCTUnwrap(SupabaseTimeFormatter.date(from: "08:20"))

        XCTAssertEqual(SupabaseTimeFormatter.string(from: time), "08:20")
        XCTAssertEqual(SupabaseDateFormatter.string(from: time), "2000-01-01")
        XCTAssertNil(SupabaseTimeFormatter.date(from: nil))
        XCTAssertNil(SupabaseTimeFormatter.date(from: ""))
    }

    func testPlanningDateTimeInputDropsTimeWhenDateIsDisabled() {
        let calendar = Calendar(identifier: .gregorian)
        let date = Self.date(2026, 9, 2, calendar: calendar)
        let time = Self.time(8, 20, calendar: calendar)

        XCTAssertEqual(PlanningDateTimeInput.resolvedTime(hasDate: true, hasTime: true, time: time), time)
        XCTAssertNil(PlanningDateTimeInput.resolvedTime(hasDate: false, hasTime: true, time: time))
        XCTAssertNil(PlanningDateTimeInput.resolvedTime(hasDate: true, hasTime: false, time: time))
        XCTAssertEqual(PlanningDateTimeInput.resolvedDate(hasDate: true, date: date), date)
        XCTAssertNil(PlanningDateTimeInput.resolvedDate(hasDate: false, date: date))
    }

    func testPlanningItemDTORoundTripsScheduledTime() throws {
        let tripID = UUID(uuidString: "11111111-1111-1111-1111-111111111184")!
        let itemID = UUID(uuidString: "66666666-6666-6666-6666-666666666685")!
        let json = """
        {
          "id": "66666666-6666-6666-6666-666666666685",
          "trip_id": "11111111-1111-1111-1111-111111111184",
          "title": "Breakfast",
          "note": "Before museum",
          "scheduled_date": "2026-09-02",
          "scheduled_time": "08:20",
          "is_done": false,
          "tag": "food"
        }
        """.data(using: .utf8)!

        let dto = try JSONDecoder().decode(SupabaseTripPlanningItemDTO.self, from: json)
        let item = dto.tripPlanningItem()
        let encoded = SupabaseTripPlanningItemDTO(tripID: tripID, item: item)

        XCTAssertEqual(dto.id, itemID)
        XCTAssertEqual(dto.scheduledTime, "08:20")
        XCTAssertEqual(item.time.map(SupabaseTimeFormatter.string(from:)), "08:20")
        XCTAssertEqual(encoded.scheduledTime, "08:20")
    }

    private static func date(_ year: Int, _ month: Int, _ day: Int, calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private static func time(_ hour: Int, _ minute: Int, calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: 2000, month: 1, day: 1, hour: hour, minute: minute))!
    }
}

private extension Array {
    var single: Element? {
        count == 1 ? first : nil
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

    func testCloudStoreShowsCachedTripsBeforeRemoteLoadCompletes() async throws {
        let service = FakeTripSyncService()
        let cache = UserDefaults(suiteName: "TripStoreCacheTests-shows-cached")!
        cache.removePersistentDomain(forName: "TripStoreCacheTests-shows-cached")
        let cachedTrip = makeTrip(id: UUID(uuidString: "00000000-0000-0000-0000-00000000B080")!, name: "Cached Weekend")
        let remoteTrip = makeTrip(id: UUID(uuidString: "00000000-0000-0000-0000-00000000B081")!, name: "Remote Weekend")
        let cacheKey = "test.cached.trips"
        TripStore.cacheTrips([cachedTrip], in: cache, key: cacheKey)
        service.tripsToLoad = [remoteTrip]

        let store = TripStore(service: service, cacheStore: cache, cacheKey: cacheKey)

        XCTAssertEqual(store.trips.map(\.id), [cachedTrip.id])

        await store.loadTrips()

        XCTAssertEqual(store.trips.map(\.id), [remoteTrip.id])
        XCTAssertEqual(TripStore.cachedTrips(in: cache, key: cacheKey).map(\.id), [remoteTrip.id])
        cache.removePersistentDomain(forName: "TripStoreCacheTests-shows-cached")
    }

    func testCloudStoreKeepsCachedTripsVisibleWhenRemoteLoadFails() async throws {
        let service = FakeTripSyncService()
        service.loadError = TestError.intentional
        let cache = UserDefaults(suiteName: "TripStoreCacheTests-keeps-cached")!
        cache.removePersistentDomain(forName: "TripStoreCacheTests-keeps-cached")
        let cachedTrip = makeTrip(id: UUID(uuidString: "00000000-0000-0000-0000-00000000B082")!, name: "Cached Weekend")
        let cacheKey = "test.cached.trips.failure"
        TripStore.cacheTrips([cachedTrip], in: cache, key: cacheKey)

        let store = TripStore(service: service, cacheStore: cache, cacheKey: cacheKey)

        await store.loadTrips()

        XCTAssertEqual(store.trips.map(\.id), [cachedTrip.id])
        XCTAssertEqual(store.syncError, TestError.intentional.localizedDescription)
        XCTAssertFalse(store.isLoading)
        cache.removePersistentDomain(forName: "TripStoreCacheTests-keeps-cached")
    }

    func testTripCachePreservesParticipantAccountID() throws {
        let cache = UserDefaults(suiteName: "TripStoreCacheTests-participant-account")!
        cache.removePersistentDomain(forName: "TripStoreCacheTests-participant-account")
        let cacheKey = "test.cached.trips.participant.account"
        let participantID = UUID(uuidString: "00000000-0000-0000-0000-00000000B084")!
        let accountID = UUID(uuidString: "00000000-0000-0000-0000-00000000B085")!
        var cachedTrip = makeTrip(id: UUID(uuidString: "00000000-0000-0000-0000-00000000B083")!, name: "Cached Weekend")
        cachedTrip.viewModel.calculator.participants = [
            Participant(id: participantID, name: "Alex", accountID: accountID)
        ]

        TripStore.cacheTrips([cachedTrip], in: cache, key: cacheKey)

        let restoredTrip = try XCTUnwrap(TripStore.cachedTrips(in: cache, key: cacheKey).first)
        XCTAssertEqual(restoredTrip.viewModel.calculator.participants.first?.accountID, accountID)
        cache.removePersistentDomain(forName: "TripStoreCacheTests-participant-account")
    }

    func testTripCachePreservesParticipantIsOrganizer() throws {
        let cache = UserDefaults(suiteName: "TripStoreCacheTests-participant-organizer")!
        cache.removePersistentDomain(forName: "TripStoreCacheTests-participant-organizer")
        let cacheKey = "test.cached.trips.participant.organizer"
        let participantID = UUID(uuidString: "00000000-0000-0000-0000-00000000B091")!
        var cachedTrip = makeTrip(id: UUID(uuidString: "00000000-0000-0000-0000-00000000B090")!, name: "Cached Weekend")
        cachedTrip.viewModel.calculator.participants = [
            Participant(id: participantID, name: "Sawjai", isOrganizer: true),
            Participant(name: "Maya")
        ]

        TripStore.cacheTrips([cachedTrip], in: cache, key: cacheKey)

        let restoredTrip = try XCTUnwrap(TripStore.cachedTrips(in: cache, key: cacheKey).first)
        let byID = Dictionary(uniqueKeysWithValues: restoredTrip.viewModel.calculator.participants.map { ($0.id, $0) })
        XCTAssertTrue(byID[participantID]?.isOrganizer == true)
        XCTAssertFalse(byID[byID.keys.first { $0 != participantID }!]?.isOrganizer ?? true)
        cache.removePersistentDomain(forName: "TripStoreCacheTests-participant-organizer")
    }

    func testCloudStoreCreatesRemoteTripWithTrimmedValuesAndAppendsReturnedTrip() async throws {
        let service = FakeTripSyncService()
        let createdTrip = makeTrip(id: UUID(uuidString: "00000000-0000-0000-0000-00000000B002")!, name: "Kyoto Spring")
        service.tripToCreate = createdTrip
        let store = TripStore(service: service)
        let startDate = SupabaseDateFormatter.date(from: "2027-03-24")!
        let endDate = SupabaseDateFormatter.date(from: "2027-04-04")!

        let didCreateTrip = await store.addRemoteTrip(
            name: " Kyoto Spring ",
            destination: " Kyoto ",
            emoji: " 🌸 ",
            imageURL: " https://example.com/kyoto.jpg ",
            startDate: startDate,
            endDate: endDate
        )

        XCTAssertTrue(didCreateTrip)
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

        let didCreateTrip = await store.addRemoteTrip(
            name: "Kyoto Spring",
            destination: "Kyoto",
            emoji: "🌸",
            imageURL: "https://example.com/kyoto.jpg",
            startDate: date,
            endDate: date
        )

        XCTAssertFalse(didCreateTrip)
        XCTAssertTrue(store.trips.isEmpty)
        XCTAssertEqual(store.syncError, TestError.intentional.localizedDescription)
    }

    func testCloudStorePersistsAddedPlaceAndUpdatesLocalTrip() async throws {
        let service = FakeTripSyncService()
        let tripID = UUID(uuidString: "00000000-0000-0000-0000-00000000B003")!
        let savedPlace = TripPlace(id: UUID(uuidString: "00000000-0000-0000-0000-00000000D001")!, name: "Zilker Park", note: "Picnic", tag: "Outdoors")
        service.placeToCreate = savedPlace
        let store = TripStore(trips: [makeTrip(id: tripID, name: "Austin Weekend")], service: service)

        await store.savePlace(TripPlace(name: " Zilker Park ", note: " Picnic ", tag: " Outdoors "), to: tripID)

        XCTAssertEqual(service.createdPlaceRequest?.tripID, tripID)
        XCTAssertEqual(service.createdPlaceRequest?.place.name, "Zilker Park")
        XCTAssertEqual(service.createdPlaceRequest?.place.note, "Picnic")
        XCTAssertEqual(service.createdPlaceRequest?.place.tag, "Outdoors")
        XCTAssertEqual(store.trips.first?.places, [savedPlace])
        XCTAssertNil(store.syncError)
    }

    func testCloudStoreReportsPlaceCreateFailureWithoutLocalMutation() async {
        let service = FakeTripSyncService()
        service.createError = TestError.intentional
        let tripID = UUID(uuidString: "00000000-0000-0000-0000-00000000B004")!
        let store = TripStore(trips: [makeTrip(id: tripID, name: "Austin Weekend")], service: service)

        await store.savePlace(TripPlace(name: "Zilker Park"), to: tripID)

        XCTAssertTrue(store.trips.first?.places.isEmpty == true)
        XCTAssertEqual(store.syncError, TestError.intentional.localizedDescription)
    }

    func testCloudStorePersistsPlaceParticipantLinksBeforeLocalMutation() async throws {
        let service = FakeTripSyncService()
        let tripID = UUID(uuidString: "00000000-0000-0000-0000-00000000B086")!
        let alexID = UUID(uuidString: "00000000-0000-0000-0000-00000000F086")!
        let samID = UUID(uuidString: "00000000-0000-0000-0000-00000000F087")!
        let place = TripPlace(name: " Zilker Park ", note: " Picnic ", tag: " Food ", participantIDs: [alexID, samID])
        let savedPlace = TripPlace(id: place.id, name: "Zilker Park", note: "Picnic", tag: "Food", participantIDs: [alexID, samID])
        service.placeToCreate = savedPlace
        let store = TripStore(trips: [makeTrip(id: tripID, name: "Austin Weekend")], service: service)

        await store.savePlace(place, to: tripID)

        XCTAssertEqual(service.createdPlaceRequest?.place.tag, "Food")
        XCTAssertEqual(service.createdPlaceRequest?.place.participantIDs, [alexID, samID])
        XCTAssertEqual(service.setPlaceParticipantsRequest?.tripID, tripID)
        XCTAssertEqual(service.setPlaceParticipantsRequest?.placeID, savedPlace.id)
        XCTAssertEqual(service.setPlaceParticipantsRequest?.participantIDs, [alexID, samID])
        XCTAssertEqual(store.trips.first?.places, [savedPlace])
        XCTAssertNil(store.syncError)
    }

    func testCloudStoreReportsPlaceParticipantLinkFailureWithoutLocalMutation() async {
        let service = FakeTripSyncService()
        service.linkError = TestError.intentional
        let tripID = UUID(uuidString: "00000000-0000-0000-0000-00000000B087")!
        let participantID = UUID(uuidString: "00000000-0000-0000-0000-00000000F088")!
        let store = TripStore(trips: [makeTrip(id: tripID, name: "Austin Weekend")], service: service)

        await store.savePlace(TripPlace(name: "Zilker", tag: "food", participantIDs: [participantID]), to: tripID)

        XCTAssertNotNil(service.createdPlaceRequest)
        XCTAssertEqual(service.setPlaceParticipantsRequest?.participantIDs, [participantID])
        XCTAssertTrue(store.trips.first?.places.isEmpty == true)
        XCTAssertEqual(store.syncError, TestError.intentional.localizedDescription)
    }

    func testCloudStorePersistsAddedParticipantBeforeExpensesReferenceThem() async throws {
        let service = FakeTripSyncService()
        let tripID = UUID(uuidString: "00000000-0000-0000-0000-00000000B030")!
        let savedParticipant = Participant(id: UUID(uuidString: "00000000-0000-0000-0000-00000000F030")!, name: "Bill")
        service.participantToCreate = savedParticipant
        let store = TripStore(trips: [makeTrip(id: tripID, name: "Austin Weekend")], service: service)

        await store.saveParticipants(names: [" Bill "], to: tripID)

        XCTAssertEqual(service.createdParticipantRequest?.tripID, tripID)
        XCTAssertEqual(service.createdParticipantRequest?.participant.name, "Bill")
        XCTAssertEqual(store.trips.first?.viewModel.calculator.participants, [savedParticipant])
        XCTAssertNil(store.syncError)
    }

    func testCloudStoreReportsParticipantCreateFailureWithoutLocalMutation() async {
        let service = FakeTripSyncService()
        service.createError = TestError.intentional
        let tripID = UUID(uuidString: "00000000-0000-0000-0000-00000000B031")!
        let store = TripStore(trips: [makeTrip(id: tripID, name: "Austin Weekend")], service: service)

        await store.saveParticipants(names: ["Bill"], to: tripID)

        XCTAssertTrue(store.trips.first?.viewModel.calculator.participants.isEmpty == true)
        XCTAssertEqual(store.syncError, TestError.intentional.localizedDescription)
    }

    func testCloudStoreDeletesPlaceRemotelyBeforeUpdatingLocalTrip() async throws {
        let service = FakeTripSyncService()
        let tripID = UUID(uuidString: "00000000-0000-0000-0000-00000000B005")!
        let placeID = UUID(uuidString: "00000000-0000-0000-0000-00000000D002")!
        var trip = makeTrip(id: tripID, name: "Austin Weekend")
        trip.places = [TripPlace(id: placeID, name: "Zilker Park")]
        let store = TripStore(trips: [trip], service: service)

        await store.removePlace(placeID, from: tripID)

        XCTAssertEqual(service.deletedPlaceRequest?.tripID, tripID)
        XCTAssertEqual(service.deletedPlaceRequest?.placeID, placeID)
        XCTAssertTrue(store.trips.first?.places.isEmpty == true)
        XCTAssertNil(store.syncError)
    }

    func testCloudStoreReportsPlaceDeleteFailureWithoutLocalMutation() async {
        let service = FakeTripSyncService()
        service.createError = TestError.intentional
        let tripID = UUID(uuidString: "00000000-0000-0000-0000-00000000B006")!
        let placeID = UUID(uuidString: "00000000-0000-0000-0000-00000000D003")!
        var trip = makeTrip(id: tripID, name: "Austin Weekend")
        trip.places = [TripPlace(id: placeID, name: "Zilker Park")]
        let store = TripStore(trips: [trip], service: service)

        await store.removePlace(placeID, from: tripID)

        XCTAssertEqual(store.trips.first?.places.map(\.id), [placeID])
        XCTAssertEqual(store.syncError, TestError.intentional.localizedDescription)
    }

    func testCloudStorePersistsAddedPlanningItemAndUpdatesLocalTrip() async throws {
        let service = FakeTripSyncService()
        let tripID = UUID(uuidString: "00000000-0000-0000-0000-00000000B007")!
        let savedItem = TripPlanningItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-00000000E001")!,
            title: "Book dinner",
            note: "Friday night",
            date: SupabaseDateFormatter.date(from: "2026-07-03"),
            isDone: false
        )
        service.planningItemToCreate = savedItem
        let store = TripStore(trips: [makeTrip(id: tripID, name: "Austin Weekend")], service: service)

        await store.savePlanningItem(
            TripPlanningItem(title: " Book dinner ", note: " Friday night ", date: savedItem.date),
            to: tripID
        )

        XCTAssertEqual(service.createdPlanningItemRequest?.tripID, tripID)
        XCTAssertEqual(service.createdPlanningItemRequest?.item.title, "Book dinner")
        XCTAssertEqual(service.createdPlanningItemRequest?.item.note, "Friday night")
        XCTAssertEqual(service.createdPlanningItemRequest?.item.date, savedItem.date)
        XCTAssertEqual(store.trips.first?.planningItems, [savedItem])
        XCTAssertNil(store.syncError)
    }

    func testCloudStorePersistsPlanningItemParticipantLinksBeforeLocalMutation() async throws {
        let service = FakeTripSyncService()
        let tripID = UUID(uuidString: "00000000-0000-0000-0000-00000000B088")!
        let participantID = UUID(uuidString: "00000000-0000-0000-0000-00000000F089")!
        let date = SupabaseDateFormatter.date(from: "2026-07-03")
        let item = TripPlanningItem(title: " Book dinner ", note: " Friday ", date: date, tag: " Show ", participantIDs: [participantID])
        let savedItem = TripPlanningItem(id: item.id, title: "Book dinner", note: "Friday", date: date, tag: "Show", participantIDs: [participantID])
        service.planningItemToCreate = savedItem
        let store = TripStore(trips: [makeTrip(id: tripID, name: "Austin Weekend")], service: service)

        await store.savePlanningItem(item, to: tripID)

        XCTAssertEqual(service.createdPlanningItemRequest?.item.tag, "Show")
        XCTAssertEqual(service.createdPlanningItemRequest?.item.participantIDs, [participantID])
        XCTAssertEqual(service.setPlanningItemParticipantsRequest?.tripID, tripID)
        XCTAssertEqual(service.setPlanningItemParticipantsRequest?.planningItemID, savedItem.id)
        XCTAssertEqual(service.setPlanningItemParticipantsRequest?.participantIDs, [participantID])
        XCTAssertEqual(store.trips.first?.planningItems, [savedItem])
        XCTAssertNil(store.syncError)
    }

    func testCloudStorePersistsPlanningItemTimeThroughTrimmedRebuild() async throws {
        let service = FakeTripSyncService()
        let tripID = UUID(uuidString: "00000000-0000-0000-0000-00000000B090")!
        let date = SupabaseDateFormatter.date(from: "2026-07-03")
        let time = SupabaseTimeFormatter.date(from: "08:20")
        let savedItem = TripPlanningItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-00000000E091")!,
            title: "Fushimi Inari sunrise",
            note: "Early train",
            date: date,
            time: time,
            isDone: false
        )
        service.planningItemToCreate = savedItem
        let store = TripStore(trips: [makeTrip(id: tripID, name: "Kyoto Spring")], service: service)

        await store.savePlanningItem(
            TripPlanningItem(title: " Fushimi Inari sunrise ", note: " Early train ", date: date, time: time),
            to: tripID
        )

        XCTAssertEqual(service.createdPlanningItemRequest?.item.date, date)
        XCTAssertEqual(service.createdPlanningItemRequest?.item.time, time)
        XCTAssertEqual(store.trips.first?.planningItems, [savedItem])
        XCTAssertNil(store.syncError)
    }

    func testCloudStoreUpdatesPlaceRowAndParticipantLinks() async throws {
        let service = FakeTripSyncService()
        let tripID = UUID(uuidString: "00000000-0000-0000-0000-00000000B089")!
        let participantID = UUID(uuidString: "00000000-0000-0000-0000-00000000F08A")!
        let placeID = UUID(uuidString: "00000000-0000-0000-0000-00000000D08A")!
        var trip = makeTrip(id: tripID, name: "Austin Weekend")
        trip.places = [TripPlace(id: placeID, name: "Old", tag: "museum")]
        let store = TripStore(trips: [trip], service: service)

        await store.updatePlace(TripPlace(id: placeID, name: " Zilker ", note: " Picnic ", tag: " Food ", participantIDs: [participantID]), in: tripID)

        XCTAssertEqual(service.updatedPlaceRequest?.place.name, "Zilker")
        XCTAssertEqual(service.updatedPlaceRequest?.place.tag, "Food")
        XCTAssertEqual(service.setPlaceParticipantsRequest?.placeID, placeID)
        XCTAssertEqual(service.setPlaceParticipantsRequest?.participantIDs, [participantID])
        XCTAssertEqual(store.trips.first?.places.first?.name, "Zilker")
        XCTAssertEqual(store.trips.first?.places.first?.participantIDs, [participantID])
        XCTAssertNil(store.syncError)
    }

    func testDemoStoreAddsTaggedPlaceLocallyWithoutCloudCalls() async {
        let tripID = UUID(uuidString: "00000000-0000-0000-0000-00000000B08A")!
        let participantID = UUID(uuidString: "00000000-0000-0000-0000-00000000F08B")!
        let store = TripStore(trips: [makeTrip(id: tripID, name: "Austin Weekend")])

        await store.savePlace(TripPlace(name: " Zilker ", tag: " Food ", participantIDs: [participantID]), to: tripID)

        XCTAssertEqual(store.trips.first?.places.first?.name, "Zilker")
        XCTAssertEqual(store.trips.first?.places.first?.tag, "Food")
        XCTAssertEqual(store.trips.first?.places.first?.participantIDs, [participantID])
        XCTAssertNil(store.syncError)
    }

    func testCloudStoreReportsPlanningItemCreateFailureWithoutLocalMutation() async {
        let service = FakeTripSyncService()
        service.createError = TestError.intentional
        let tripID = UUID(uuidString: "00000000-0000-0000-0000-00000000B008")!
        let store = TripStore(trips: [makeTrip(id: tripID, name: "Austin Weekend")], service: service)

        await store.savePlanningItem(TripPlanningItem(title: "Book dinner"), to: tripID)

        XCTAssertTrue(store.trips.first?.planningItems.isEmpty == true)
        XCTAssertEqual(store.syncError, TestError.intentional.localizedDescription)
    }

    func testCloudStoreTogglesPlanningItemRemotelyBeforeUpdatingLocalTrip() async throws {
        let service = FakeTripSyncService()
        let tripID = UUID(uuidString: "00000000-0000-0000-0000-00000000B009")!
        let itemID = UUID(uuidString: "00000000-0000-0000-0000-00000000E002")!
        let item = TripPlanningItem(id: itemID, title: "Book dinner", isDone: false)
        var trip = makeTrip(id: tripID, name: "Austin Weekend")
        trip.planningItems = [item]
        let store = TripStore(trips: [trip], service: service)

        await store.togglePlanningItemRemotely(itemID, for: tripID)

        XCTAssertEqual(service.updatedPlanningItemRequest?.tripID, tripID)
        XCTAssertEqual(service.updatedPlanningItemRequest?.item.id, itemID)
        XCTAssertEqual(service.updatedPlanningItemRequest?.item.isDone, true)
        XCTAssertEqual(store.trips.first?.planningItems.first?.isDone, true)
        XCTAssertNil(store.syncError)
    }

    func testCloudStoreReportsPlanningItemToggleFailureWithoutLocalMutation() async {
        let service = FakeTripSyncService()
        service.createError = TestError.intentional
        let tripID = UUID(uuidString: "00000000-0000-0000-0000-00000000B010")!
        let itemID = UUID(uuidString: "00000000-0000-0000-0000-00000000E003")!
        var trip = makeTrip(id: tripID, name: "Austin Weekend")
        trip.planningItems = [TripPlanningItem(id: itemID, title: "Book dinner", isDone: false)]
        let store = TripStore(trips: [trip], service: service)

        await store.togglePlanningItemRemotely(itemID, for: tripID)

        XCTAssertEqual(store.trips.first?.planningItems.first?.isDone, false)
        XCTAssertEqual(store.syncError, TestError.intentional.localizedDescription)
    }

    func testCloudStoreDeletesPlanningItemRemotelyBeforeUpdatingLocalTrip() async throws {
        let service = FakeTripSyncService()
        let tripID = UUID(uuidString: "00000000-0000-0000-0000-00000000B011")!
        let itemID = UUID(uuidString: "00000000-0000-0000-0000-00000000E004")!
        var trip = makeTrip(id: tripID, name: "Austin Weekend")
        trip.planningItems = [TripPlanningItem(id: itemID, title: "Book dinner")]
        let store = TripStore(trips: [trip], service: service)

        await store.removePlanningItem(itemID, from: tripID)

        XCTAssertEqual(service.deletedPlanningItemRequest?.tripID, tripID)
        XCTAssertEqual(service.deletedPlanningItemRequest?.itemID, itemID)
        XCTAssertTrue(store.trips.first?.planningItems.isEmpty == true)
        XCTAssertNil(store.syncError)
    }

    func testCloudStoreReportsPlanningItemDeleteFailureWithoutLocalMutation() async {
        let service = FakeTripSyncService()
        service.createError = TestError.intentional
        let tripID = UUID(uuidString: "00000000-0000-0000-0000-00000000B012")!
        let itemID = UUID(uuidString: "00000000-0000-0000-0000-00000000E005")!
        var trip = makeTrip(id: tripID, name: "Austin Weekend")
        trip.planningItems = [TripPlanningItem(id: itemID, title: "Book dinner")]
        let store = TripStore(trips: [trip], service: service)

        await store.removePlanningItem(itemID, from: tripID)

        XCTAssertEqual(store.trips.first?.planningItems.map(\.id), [itemID])
        XCTAssertEqual(store.syncError, TestError.intentional.localizedDescription)
    }

    func testCloudStorePersistsAddedExpenseAndUpdatesLocalTrip() async throws {
        let service = FakeTripSyncService()
        let tripID = UUID(uuidString: "00000000-0000-0000-0000-00000000B013")!
        let alexID = UUID(uuidString: "00000000-0000-0000-0000-00000000F001")!
        let samID = UUID(uuidString: "00000000-0000-0000-0000-00000000F002")!
        let savedExpense = ExpenseItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-00000000F003")!,
            title: "Hotel deposit",
            paidBy: alexID,
            amount: 240,
            participants: Set([alexID, samID])
        )
        service.expenseToCreate = savedExpense
        var trip = makeTrip(id: tripID, name: "Austin Weekend")
        trip.viewModel.calculator.participants = [Participant(id: alexID, name: "Alex"), Participant(id: samID, name: "Sam")]
        let store = TripStore(trips: [trip], service: service)

        await store.saveExpense(
            title: " Hotel deposit ",
            paidBy: alexID,
            amount: 240,
            participants: Set([alexID, samID]),
            to: tripID
        )

        XCTAssertEqual(service.createdExpenseRequest?.tripID, tripID)
        XCTAssertEqual(service.createdExpenseRequest?.expense.title, "Hotel deposit")
        XCTAssertEqual(service.createdExpenseRequest?.expense.paidBy, alexID)
        XCTAssertEqual(service.createdExpenseRequest?.expense.amount, 240)
        XCTAssertEqual(service.createdExpenseRequest?.expense.participants, Set([alexID, samID]))
        XCTAssertEqual(store.trips.first?.viewModel.calculator.expenses, [savedExpense])
        XCTAssertNil(store.syncError)
    }

    func testCloudStoreReportsExpenseCreateFailureWithoutLocalMutation() async {
        let service = FakeTripSyncService()
        service.createError = TestError.intentional
        let tripID = UUID(uuidString: "00000000-0000-0000-0000-00000000B014")!
        let alexID = UUID(uuidString: "00000000-0000-0000-0000-00000000F004")!
        var trip = makeTrip(id: tripID, name: "Austin Weekend")
        trip.viewModel.calculator.participants = [Participant(id: alexID, name: "Alex")]
        let store = TripStore(trips: [trip], service: service)

        await store.saveExpense(title: "Hotel", paidBy: alexID, amount: 100, participants: [alexID], to: tripID)

        XCTAssertTrue(store.trips.first?.viewModel.calculator.expenses.isEmpty == true)
        XCTAssertEqual(store.syncError, TestError.intentional.localizedDescription)
    }

    func testCloudStoreDeletesExpenseRemotelyBeforeUpdatingLocalTrip() async throws {
        let service = FakeTripSyncService()
        let tripID = UUID(uuidString: "00000000-0000-0000-0000-00000000B015")!
        let alexID = UUID(uuidString: "00000000-0000-0000-0000-00000000F005")!
        let expenseID = UUID(uuidString: "00000000-0000-0000-0000-00000000F006")!
        var trip = makeTrip(id: tripID, name: "Austin Weekend")
        trip.viewModel.calculator.participants = [Participant(id: alexID, name: "Alex")]
        trip.viewModel.calculator.expenses = [ExpenseItem(id: expenseID, title: "Hotel", paidBy: alexID, amount: 100, participants: [alexID])]
        let store = TripStore(trips: [trip], service: service)

        await store.removeExpense(expenseID, from: tripID)

        XCTAssertEqual(service.deletedExpenseRequest?.tripID, tripID)
        XCTAssertEqual(service.deletedExpenseRequest?.expenseID, expenseID)
        XCTAssertTrue(store.trips.first?.viewModel.calculator.expenses.isEmpty == true)
        XCTAssertNil(store.syncError)
    }

    func testCloudStoreReportsExpenseDeleteFailureWithoutLocalMutation() async {
        let service = FakeTripSyncService()
        service.createError = TestError.intentional
        let tripID = UUID(uuidString: "00000000-0000-0000-0000-00000000B016")!
        let alexID = UUID(uuidString: "00000000-0000-0000-0000-00000000F007")!
        let expenseID = UUID(uuidString: "00000000-0000-0000-0000-00000000F008")!
        var trip = makeTrip(id: tripID, name: "Austin Weekend")
        trip.viewModel.calculator.participants = [Participant(id: alexID, name: "Alex")]
        trip.viewModel.calculator.expenses = [ExpenseItem(id: expenseID, title: "Hotel", paidBy: alexID, amount: 100, participants: [alexID])]
        let store = TripStore(trips: [trip], service: service)

        await store.removeExpense(expenseID, from: tripID)

        XCTAssertEqual(store.trips.first?.viewModel.calculator.expenses.map(\.id), [expenseID])
        XCTAssertEqual(store.syncError, TestError.intentional.localizedDescription)
    }

    func testCloudStorePersistsAddedDirectPaymentAndUpdatesBalances() async throws {
        let service = FakeTripSyncService()
        let tripID = UUID(uuidString: "00000000-0000-0000-0000-00000000B017")!
        let alexID = UUID(uuidString: "00000000-0000-0000-0000-00000000F009")!
        let samID = UUID(uuidString: "00000000-0000-0000-0000-00000000F010")!
        let savedPayment = DirectPayment(
            id: UUID(uuidString: "00000000-0000-0000-0000-00000000F011")!,
            title: "Sam paid Alex",
            from: samID,
            to: alexID,
            amount: 60
        )
        service.paymentToCreate = savedPayment
        var trip = makeTrip(id: tripID, name: "Austin Weekend")
        trip.viewModel.calculator.participants = [Participant(id: alexID, name: "Alex"), Participant(id: samID, name: "Sam")]
        let store = TripStore(trips: [trip], service: service)

        await store.saveDirectPayment(title: " Sam paid Alex ", from: samID, to: alexID, amount: 60, in: tripID)

        XCTAssertEqual(service.createdPaymentRequest?.tripID, tripID)
        XCTAssertEqual(service.createdPaymentRequest?.payment.title, "Sam paid Alex")
        XCTAssertEqual(service.createdPaymentRequest?.payment.from, samID)
        XCTAssertEqual(service.createdPaymentRequest?.payment.to, alexID)
        XCTAssertEqual(service.createdPaymentRequest?.payment.amount, 60)
        XCTAssertEqual(store.trips.first?.viewModel.calculator.payments, [savedPayment])
        XCTAssertNil(store.syncError)
    }

    func testCloudStoreReportsDirectPaymentCreateFailureWithoutLocalMutation() async {
        let service = FakeTripSyncService()
        service.createError = TestError.intentional
        let tripID = UUID(uuidString: "00000000-0000-0000-0000-00000000B018")!
        let alexID = UUID(uuidString: "00000000-0000-0000-0000-00000000F012")!
        let samID = UUID(uuidString: "00000000-0000-0000-0000-00000000F013")!
        var trip = makeTrip(id: tripID, name: "Austin Weekend")
        trip.viewModel.calculator.participants = [Participant(id: alexID, name: "Alex"), Participant(id: samID, name: "Sam")]
        let store = TripStore(trips: [trip], service: service)

        await store.saveDirectPayment(title: "Sam paid Alex", from: samID, to: alexID, amount: 60, in: tripID)

        XCTAssertTrue(store.trips.first?.viewModel.calculator.payments.isEmpty == true)
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

    func testCloudStoreClearsInviteLookupStateForBlankCode() async {
        let service = FakeTripSyncService()
        let tripID = UUID(uuidString: "00000000-0000-0000-0000-00000000B03B")!
        let store = TripStore(service: service)
        store.invitePreview = TripInvitePreview(
            inviteID: UUID(uuidString: "00000000-0000-0000-0000-00000000C03B")!,
            tripID: tripID,
            tripName: "Austin Weekend",
            role: .guest,
            expiresAt: nil
        )
        store.syncError = TestError.intentional.localizedDescription

        await store.lookupInvite(code: "   ")

        XCTAssertNil(service.lookedUpInviteCode)
        XCTAssertNil(store.invitePreview)
        XCTAssertNil(store.syncError)
    }

    func testCloudStoreReportsMissingInvitePreview() async {
        let service = FakeTripSyncService()
        service.invitePreviewToLookup = nil
        let store = TripStore(service: service)

        await store.lookupInvite(code: "missing-code")

        XCTAssertEqual(service.lookedUpInviteCode, "MISSING-CODE")
        XCTAssertNil(store.invitePreview)
        XCTAssertEqual(store.syncError, "We couldn't find an active trip invite for that code.")
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

        let didJoin = await store.acceptInvite(code: " wani2027 ")

        XCTAssertTrue(didJoin)
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

        let didJoin = await store.acceptInvite(code: "WANI2027")

        XCTAssertFalse(didJoin)
        XCTAssertEqual(service.acceptedInviteCode, "WANI2027")
        XCTAssertFalse(service.didLoadTrips)
        XCTAssertTrue(store.trips.isEmpty)
        XCTAssertEqual(store.syncError, TestError.intentional.localizedDescription)
    }

    func testCloudStoreRejectsBlankInviteAcceptWithoutCallingService() async {
        let service = FakeTripSyncService()
        let store = TripStore(service: service)
        store.syncError = TestError.intentional.localizedDescription

        let didJoin = await store.acceptInvite(code: "   ")

        XCTAssertFalse(didJoin)
        XCTAssertNil(service.acceptedInviteCode)
        XCTAssertNil(store.syncError)
    }

    func testCloudStoreLeavesTripRemotelyBeforeRemovingLocalTrip() async {
        let service = FakeTripSyncService()
        let tripID = UUID(uuidString: "00000000-0000-0000-0000-00000000B019")!
        let otherTripID = UUID(uuidString: "00000000-0000-0000-0000-00000000B020")!
        let store = TripStore(
            trips: [
                makeTrip(id: tripID, name: "Austin Weekend"),
                makeTrip(id: otherTripID, name: "Seattle Visit")
            ],
            service: service
        )

        await store.leaveTrip(tripID)

        XCTAssertEqual(service.leftTripID, tripID)
        XCTAssertEqual(store.trips.map(\.id), [otherTripID])
        XCTAssertNil(store.syncError)
    }

    func testCloudStoreReportsLeaveTripFailureWithoutLocalRemoval() async {
        let service = FakeTripSyncService()
        service.createError = TestError.intentional
        let tripID = UUID(uuidString: "00000000-0000-0000-0000-00000000B021")!
        let store = TripStore(trips: [makeTrip(id: tripID, name: "Austin Weekend")], service: service)

        await store.leaveTrip(tripID)

        XCTAssertEqual(service.leftTripID, tripID)
        XCTAssertEqual(store.trips.map(\.id), [tripID])
        XCTAssertEqual(store.syncError, TestError.intentional.localizedDescription)
    }

    func testCloudStoreArchivesTripRemotelyBeforeRemovingLocalTrip() async {
        let service = FakeTripSyncService()
        let tripID = UUID(uuidString: "00000000-0000-0000-0000-00000000B022")!
        let otherTripID = UUID(uuidString: "00000000-0000-0000-0000-00000000B023")!
        let store = TripStore(
            trips: [
                makeTrip(id: tripID, name: "Austin Weekend"),
                makeTrip(id: otherTripID, name: "Seattle Visit")
            ],
            service: service
        )

        await store.archiveTrip(tripID)

        XCTAssertEqual(service.archivedTripID, tripID)
        XCTAssertEqual(store.trips.map(\.id), [otherTripID])
        XCTAssertNil(store.syncError)
    }

    func testCloudStoreReportsArchiveTripFailureWithoutLocalRemoval() async {
        let service = FakeTripSyncService()
        service.createError = TestError.intentional
        let tripID = UUID(uuidString: "00000000-0000-0000-0000-00000000B024")!
        let store = TripStore(trips: [makeTrip(id: tripID, name: "Austin Weekend")], service: service)

        await store.archiveTrip(tripID)

        XCTAssertEqual(service.archivedTripID, tripID)
        XCTAssertEqual(store.trips.map(\.id), [tripID])
        XCTAssertEqual(store.syncError, TestError.intentional.localizedDescription)
    }

    func testCloudStoreUpdatesPlaceRemotelyBeforeReplacingLocalPlace() async throws {
        let service = FakeTripSyncService()
        let tripID = UUID(uuidString: "00000000-0000-0000-0000-00000000B025")!
        let place = TripPlace(name: "  Zilker Park  ", note: "  Picnic spot  ", tag: "  Outdoors  ")
        var trip = makeTrip(id: tripID, name: "Austin Weekend")
        trip.places = [place]
        let store = TripStore(trips: [trip], service: service)

        await store.updatePlace(place, in: tripID)

        let request = try XCTUnwrap(service.updatedPlaceRequest)
        XCTAssertEqual(request.place.name, "Zilker Park")
        XCTAssertEqual(request.place.note, "Picnic spot")
        XCTAssertEqual(request.place.tag, "Outdoors")
        XCTAssertEqual(store.trips.first?.places.first?.name, "Zilker Park")
        XCTAssertNil(store.syncError)
    }

    func testCloudStoreReportsPlaceUpdateFailureWithoutLocalMutation() async {
        let service = FakeTripSyncService()
        service.createError = TestError.intentional
        let tripID = UUID(uuidString: "00000000-0000-0000-0000-00000000B026")!
        let place = TripPlace(name: "Zilker Park", note: "Picnic", tag: "Outdoors")
        var trip = makeTrip(id: tripID, name: "Austin Weekend")
        trip.places = [place]
        let store = TripStore(trips: [trip], service: service)

        await store.updatePlace(place, in: tripID)

        XCTAssertEqual(service.updatedPlaceRequest?.place.name, "Zilker Park")
        // Local place should be unchanged because the remote update failed
        XCTAssertEqual(store.trips.first?.places.first?.name, "Zilker Park")
        XCTAssertEqual(store.syncError, TestError.intentional.localizedDescription)
    }

    func testCloudStoreUpdatesPlanningItemRemotelyBeforeReplacingLocalItem() async throws {
        let service = FakeTripSyncService()
        let tripID = UUID(uuidString: "00000000-0000-0000-0000-00000000B027")!
        let original = TripPlanningItem(title: "Book dinner", note: "Friday", date: nil, isDone: false)
        let updated = TripPlanningItem(id: original.id, title: "  Book brunch  ", note: "  Saturday morning  ", date: SupabaseDateFormatter.date(from: "2026-07-04"), isDone: true)
        var trip = makeTrip(id: tripID, name: "Austin Weekend")
        trip.planningItems = [original]
        let store = TripStore(trips: [trip], service: service)

        await store.updatePlanningItem(updated, in: tripID)

        let request = try XCTUnwrap(service.updatedPlanningItemRequest)
        XCTAssertEqual(request.tripID, tripID)
        XCTAssertEqual(request.item.id, original.id)
        XCTAssertEqual(request.item.title, "Book brunch")
        XCTAssertEqual(request.item.note, "Saturday morning")
        XCTAssertTrue(request.item.isDone)
        XCTAssertEqual(store.trips.first?.planningItems.first?.title, "Book brunch")
        XCTAssertEqual(store.trips.first?.planningItems.first?.note, "Saturday morning")
        XCTAssertTrue(store.trips.first?.planningItems.first?.isDone == true)
        XCTAssertNil(store.syncError)
    }

    func testCloudStoreReportsPlanningItemUpdateFailureWithoutLocalMutation() async {
        let service = FakeTripSyncService()
        service.createError = TestError.intentional
        let tripID = UUID(uuidString: "00000000-0000-0000-0000-00000000B028")!
        let original = TripPlanningItem(title: "Book dinner", note: "Friday", date: nil, isDone: false)
        let updated = TripPlanningItem(id: original.id, title: "Book brunch", note: "Saturday", date: nil, isDone: true)
        var trip = makeTrip(id: tripID, name: "Austin Weekend")
        trip.planningItems = [original]
        let store = TripStore(trips: [trip], service: service)

        await store.updatePlanningItem(updated, in: tripID)

        XCTAssertEqual(service.updatedPlanningItemRequest?.item.title, "Book brunch")
        XCTAssertEqual(store.trips.first?.planningItems.first?.title, "Book dinner")
        XCTAssertEqual(store.trips.first?.planningItems.first?.note, "Friday")
        XCTAssertFalse(store.trips.first?.planningItems.first?.isDone == true)
        XCTAssertEqual(store.syncError, TestError.intentional.localizedDescription)
    }

    func testCloudStoreUpdatesExpenseRemotelyBeforeReplacingLocalExpense() async throws {
        let service = FakeTripSyncService()
        let tripID = UUID(uuidString: "00000000-0000-0000-0000-00000000B029")!
        let alex = Participant(name: "Alex")
        let sam = Participant(name: "Sam")
        let original = ExpenseItem(title: "Dinner", paidBy: alex.id, amount: 80, participants: [alex.id, sam.id])
        let updated = ExpenseItem(id: original.id, title: "  Brunch  ", paidBy: sam.id, amount: 120, participants: [sam.id])
        var trip = makeTrip(id: tripID, name: "Austin Weekend")
        trip.viewModel.calculator.participants = [alex, sam]
        trip.viewModel.calculator.expenses = [original]
        let store = TripStore(trips: [trip], service: service)

        await store.updateExpense(updated, in: tripID)

        let request = try XCTUnwrap(service.updatedExpenseRequest)
        XCTAssertEqual(request.tripID, tripID)
        XCTAssertEqual(request.expense.id, original.id)
        XCTAssertEqual(request.expense.title, "Brunch")
        XCTAssertEqual(request.expense.paidBy, sam.id)
        XCTAssertEqual(request.expense.amount, 120)
        XCTAssertEqual(request.expense.participants, [sam.id])
        XCTAssertEqual(store.trips.first?.viewModel.calculator.expenses.first?.title, "Brunch")
        XCTAssertEqual(store.trips.first?.viewModel.calculator.expenses.first?.paidBy, sam.id)
        XCTAssertEqual(store.trips.first?.viewModel.calculator.expenses.first?.participants, [sam.id])
        XCTAssertNil(store.syncError)
    }

    func testCloudStoreReportsExpenseUpdateFailureWithoutLocalMutation() async {
        let service = FakeTripSyncService()
        service.createError = TestError.intentional
        let tripID = UUID(uuidString: "00000000-0000-0000-0000-00000000B02A")!
        let alex = Participant(name: "Alex")
        let sam = Participant(name: "Sam")
        let original = ExpenseItem(title: "Dinner", paidBy: alex.id, amount: 80, participants: [alex.id, sam.id])
        let updated = ExpenseItem(id: original.id, title: "Brunch", paidBy: sam.id, amount: 120, participants: [sam.id])
        var trip = makeTrip(id: tripID, name: "Austin Weekend")
        trip.viewModel.calculator.participants = [alex, sam]
        trip.viewModel.calculator.expenses = [original]
        let store = TripStore(trips: [trip], service: service)

        await store.updateExpense(updated, in: tripID)

        XCTAssertEqual(service.updatedExpenseRequest?.expense.title, "Brunch")
        XCTAssertEqual(store.trips.first?.viewModel.calculator.expenses.first?.title, "Dinner")
        XCTAssertEqual(store.trips.first?.viewModel.calculator.expenses.first?.paidBy, alex.id)
        XCTAssertEqual(store.syncError, TestError.intentional.localizedDescription)
    }

    func testCloudStoreUpdatesDirectPaymentRemotelyBeforeReplacingLocalPayment() async throws {
        let service = FakeTripSyncService()
        let tripID = UUID(uuidString: "00000000-0000-0000-0000-00000000B02B")!
        let alex = Participant(name: "Alex")
        let sam = Participant(name: "Sam")
        let original = DirectPayment(title: "Payback", from: alex.id, to: sam.id, amount: 40)
        let updated = DirectPayment(id: original.id, title: "  Brunch payback  ", from: sam.id, to: alex.id, amount: 65)
        var trip = makeTrip(id: tripID, name: "Austin Weekend")
        trip.viewModel.calculator.participants = [alex, sam]
        trip.viewModel.calculator.payments = [original]
        let store = TripStore(trips: [trip], service: service)

        await store.updateDirectPayment(updated, in: tripID)

        let request = try XCTUnwrap(service.updatedPaymentRequest)
        XCTAssertEqual(request.tripID, tripID)
        XCTAssertEqual(request.payment.id, original.id)
        XCTAssertEqual(request.payment.title, "Brunch payback")
        XCTAssertEqual(request.payment.from, sam.id)
        XCTAssertEqual(request.payment.to, alex.id)
        XCTAssertEqual(request.payment.amount, 65)
        XCTAssertEqual(store.trips.first?.viewModel.calculator.payments.first?.title, "Brunch payback")
        XCTAssertEqual(store.trips.first?.viewModel.calculator.payments.first?.from, sam.id)
        XCTAssertEqual(store.trips.first?.viewModel.calculator.payments.first?.to, alex.id)
        XCTAssertNil(store.syncError)
    }

    func testCloudStoreReportsDirectPaymentUpdateFailureWithoutLocalMutation() async {
        let service = FakeTripSyncService()
        service.createError = TestError.intentional
        let tripID = UUID(uuidString: "00000000-0000-0000-0000-00000000B02C")!
        let alex = Participant(name: "Alex")
        let sam = Participant(name: "Sam")
        let original = DirectPayment(title: "Payback", from: alex.id, to: sam.id, amount: 40)
        let updated = DirectPayment(id: original.id, title: "Brunch payback", from: sam.id, to: alex.id, amount: 65)
        var trip = makeTrip(id: tripID, name: "Austin Weekend")
        trip.viewModel.calculator.participants = [alex, sam]
        trip.viewModel.calculator.payments = [original]
        let store = TripStore(trips: [trip], service: service)

        await store.updateDirectPayment(updated, in: tripID)

        XCTAssertEqual(service.updatedPaymentRequest?.payment.title, "Brunch payback")
        XCTAssertEqual(store.trips.first?.viewModel.calculator.payments.first?.title, "Payback")
        XCTAssertEqual(store.trips.first?.viewModel.calculator.payments.first?.from, alex.id)
        XCTAssertEqual(store.syncError, TestError.intentional.localizedDescription)
    }

    func testCloudStoreUpdatesParticipantNameRemotelyWithoutChangingExpenseReferences() async throws {
        let service = FakeTripSyncService()
        let tripID = UUID(uuidString: "00000000-0000-0000-0000-00000000B02D")!
        let alex = Participant(name: "Alex")
        let sam = Participant(name: "Sam")
        let expense = ExpenseItem(title: "Dinner", paidBy: alex.id, amount: 80, participants: [alex.id, sam.id])
        let payment = DirectPayment(title: "Payback", from: sam.id, to: alex.id, amount: 40)
        let trip = makeTrip(id: tripID, name: "Austin Weekend")
        trip.viewModel.calculator.participants = [alex, sam]
        trip.viewModel.calculator.expenses = [expense]
        trip.viewModel.calculator.payments = [payment]
        let store = TripStore(trips: [trip], service: service)

        await store.updateParticipant(Participant(id: alex.id, name: "  Alex Rivera  "), in: tripID)

        let request = try XCTUnwrap(service.updatedParticipantRequest)
        XCTAssertEqual(request.tripID, tripID)
        XCTAssertEqual(request.participant.id, alex.id)
        XCTAssertEqual(request.participant.name, "Alex Rivera")
        XCTAssertEqual(store.trips.first?.viewModel.calculator.participants.first?.id, alex.id)
        XCTAssertEqual(store.trips.first?.viewModel.calculator.participants.first?.name, "Alex Rivera")
        XCTAssertEqual(store.trips.first?.viewModel.calculator.expenses.first?.paidBy, alex.id)
        XCTAssertEqual(store.trips.first?.viewModel.calculator.expenses.first?.participants, [alex.id, sam.id])
        XCTAssertEqual(store.trips.first?.viewModel.calculator.payments.first?.to, alex.id)
        XCTAssertNil(store.syncError)
    }

    func testCloudStoreReportsParticipantUpdateFailureWithoutLocalMutation() async {
        let service = FakeTripSyncService()
        service.createError = TestError.intentional
        let tripID = UUID(uuidString: "00000000-0000-0000-0000-00000000B02E")!
        let alex = Participant(name: "Alex")
        let sam = Participant(name: "Sam")
        let expense = ExpenseItem(title: "Dinner", paidBy: alex.id, amount: 80, participants: [alex.id, sam.id])
        let trip = makeTrip(id: tripID, name: "Austin Weekend")
        trip.viewModel.calculator.participants = [alex, sam]
        trip.viewModel.calculator.expenses = [expense]
        let store = TripStore(trips: [trip], service: service)

        await store.updateParticipant(Participant(id: alex.id, name: "Alex Rivera"), in: tripID)

        XCTAssertEqual(service.updatedParticipantRequest?.participant.name, "Alex Rivera")
        XCTAssertEqual(store.trips.first?.viewModel.calculator.participants.first?.name, "Alex")
        XCTAssertEqual(store.trips.first?.viewModel.calculator.expenses.first?.paidBy, alex.id)
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

    struct CreatePlaceRequest: Equatable {
        var tripID: UUID
        var place: TripPlace
    }

    struct CreateParticipantRequest: Equatable {
        var tripID: UUID
        var participant: Participant
    }

    struct UpdateParticipantRequest: Equatable {
        var tripID: UUID
        var participant: Participant
    }

    struct DeletePlaceRequest: Equatable {
        var tripID: UUID
        var placeID: UUID
    }

    struct SetPlaceParticipantsRequest: Equatable {
        var tripID: UUID
        var placeID: UUID
        var participantIDs: [UUID]
    }

    struct CreatePlanningItemRequest: Equatable {
        var tripID: UUID
        var item: TripPlanningItem
    }

    struct UpdatePlanningItemRequest: Equatable {
        var tripID: UUID
        var item: TripPlanningItem
    }

    struct DeletePlanningItemRequest: Equatable {
        var tripID: UUID
        var itemID: UUID
    }

    struct SetPlanningItemParticipantsRequest: Equatable {
        var tripID: UUID
        var planningItemID: UUID
        var participantIDs: [UUID]
    }

    struct CreateExpenseRequest: Equatable {
        var tripID: UUID
        var expense: ExpenseItem
    }

    struct UpdatePlaceRequest: Equatable {
        var tripID: UUID
        var place: TripPlace
    }

    struct UpdateExpenseRequest: Equatable {
        var tripID: UUID
        var expense: ExpenseItem
    }

    struct UpdateDirectPaymentRequest: Equatable {
        var tripID: UUID
        var payment: DirectPayment
    }

    struct DeleteExpenseRequest: Equatable {
        var tripID: UUID
        var expenseID: UUID
    }

    struct CreateDirectPaymentRequest: Equatable {
        var tripID: UUID
        var payment: DirectPayment
    }

    var tripsToLoad: [TripPlan] = []
    var tripToCreate: TripPlan?
    var participantToCreate: Participant?
    var placeToCreate: TripPlace?
    var planningItemToCreate: TripPlanningItem?
    var expenseToCreate: ExpenseItem?
    var paymentToCreate: DirectPayment?
    var inviteToCreate: TripInvite?
    var invitePreviewToLookup: TripInvitePreview?
    var didLoadTrips = false
    var createdTripRequest: CreateTripRequest?
    var createdParticipantRequest: CreateParticipantRequest?
    var updatedParticipantRequest: UpdateParticipantRequest?
    var createdPlaceRequest: CreatePlaceRequest?
    var setPlaceParticipantsRequest: SetPlaceParticipantsRequest?
    var deletedPlaceRequest: DeletePlaceRequest?
    var createdPlanningItemRequest: CreatePlanningItemRequest?
    var updatedPlanningItemRequest: UpdatePlanningItemRequest?
    var setPlanningItemParticipantsRequest: SetPlanningItemParticipantsRequest?
    var deletedPlanningItemRequest: DeletePlanningItemRequest?
    var createdExpenseRequest: CreateExpenseRequest?
    var deletedExpenseRequest: DeleteExpenseRequest?
    var createdPaymentRequest: CreateDirectPaymentRequest?
    var createdInviteRequest: CreateInviteRequest?
    var lookedUpInviteCode: String?
    var acceptedInviteCode: String?
    var leftTripID: UUID?
    var archivedTripID: UUID?
    var updatedPlaceRequest: UpdatePlaceRequest?
    var updatedExpenseRequest: UpdateExpenseRequest?
    var updatedPaymentRequest: UpdateDirectPaymentRequest?
    var createError: Error?
    var linkError: Error?
    var loadError: Error?

    func loadTrips() async throws -> [TripPlan] {
        if let loadError { throw loadError }
        didLoadTrips = true
        return tripsToLoad
    }

    func createTrip(name: String, destination: String, emoji: String, imageURL: String, startDate: Date, endDate: Date) async throws -> TripPlan {
        if let createError { throw createError }
        createdTripRequest = CreateTripRequest(name: name, destination: destination, emoji: emoji, imageURL: imageURL, startDate: startDate, endDate: endDate)
        return tripToCreate ?? TripPlan(destination: destination, emoji: emoji, imageURL: imageURL, startDate: startDate, endDate: endDate, viewModel: TripCalculatorViewModel.empty(named: name))
    }

    func createParticipant(_ participant: Participant, in tripID: UUID) async throws -> Participant {
        if let createError { throw createError }
        createdParticipantRequest = CreateParticipantRequest(tripID: tripID, participant: participant)
        return participantToCreate ?? participant
    }

    func updateParticipant(_ participant: Participant, in tripID: UUID) async throws -> Participant {
        updatedParticipantRequest = UpdateParticipantRequest(tripID: tripID, participant: participant)
        if let createError { throw createError }
        return participant
    }

    func createPlace(_ place: TripPlace, in tripID: UUID) async throws -> TripPlace {
        if let createError { throw createError }
        createdPlaceRequest = CreatePlaceRequest(tripID: tripID, place: place)
        return placeToCreate ?? place
    }

    func setPlaceParticipants(_ participantIDs: [UUID], for placeID: UUID, in tripID: UUID) async throws {
        setPlaceParticipantsRequest = SetPlaceParticipantsRequest(tripID: tripID, placeID: placeID, participantIDs: participantIDs)
        if let linkError { throw linkError }
    }

    func deletePlace(_ placeID: UUID, from tripID: UUID) async throws {
        deletedPlaceRequest = DeletePlaceRequest(tripID: tripID, placeID: placeID)
        if let createError { throw createError }
    }

    func createPlanningItem(_ item: TripPlanningItem, in tripID: UUID) async throws -> TripPlanningItem {
        if let createError { throw createError }
        createdPlanningItemRequest = CreatePlanningItemRequest(tripID: tripID, item: item)
        return planningItemToCreate ?? item
    }

    func updatePlanningItem(_ item: TripPlanningItem, in tripID: UUID) async throws -> TripPlanningItem {
        updatedPlanningItemRequest = UpdatePlanningItemRequest(tripID: tripID, item: item)
        if let createError { throw createError }
        return item
    }

    func setPlanningItemParticipants(_ participantIDs: [UUID], for planningItemID: UUID, in tripID: UUID) async throws {
        setPlanningItemParticipantsRequest = SetPlanningItemParticipantsRequest(tripID: tripID, planningItemID: planningItemID, participantIDs: participantIDs)
        if let linkError { throw linkError }
    }

    func deletePlanningItem(_ itemID: UUID, from tripID: UUID) async throws {
        deletedPlanningItemRequest = DeletePlanningItemRequest(tripID: tripID, itemID: itemID)
        if let createError { throw createError }
    }

    func createExpense(_ expense: ExpenseItem, in tripID: UUID) async throws -> ExpenseItem {
        if let createError { throw createError }
        createdExpenseRequest = CreateExpenseRequest(tripID: tripID, expense: expense)
        return expenseToCreate ?? expense
    }

    func deleteExpense(_ expenseID: UUID, from tripID: UUID) async throws {
        deletedExpenseRequest = DeleteExpenseRequest(tripID: tripID, expenseID: expenseID)
        if let createError { throw createError }
    }

    func createDirectPayment(_ payment: DirectPayment, in tripID: UUID) async throws -> DirectPayment {
        if let createError { throw createError }
        createdPaymentRequest = CreateDirectPaymentRequest(tripID: tripID, payment: payment)
        return paymentToCreate ?? payment
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

    func leaveTrip(_ tripID: UUID) async throws {
        leftTripID = tripID
        if let createError { throw createError }
    }

    func archiveTrip(_ tripID: UUID) async throws {
        archivedTripID = tripID
        if let createError { throw createError }
    }

    func updatePlace(_ place: TripPlace, in tripID: UUID) async throws -> TripPlace {
        updatedPlaceRequest = UpdatePlaceRequest(tripID: tripID, place: place)
        if let createError { throw createError }
        return place
    }

    func updateExpense(_ expense: ExpenseItem, in tripID: UUID) async throws -> ExpenseItem {
        updatedExpenseRequest = UpdateExpenseRequest(tripID: tripID, expense: expense)
        if let createError { throw createError }
        return expense
    }

    func updateDirectPayment(_ payment: DirectPayment, in tripID: UUID) async throws -> DirectPayment {
        updatedPaymentRequest = UpdateDirectPaymentRequest(tripID: tripID, payment: payment)
        if let createError { throw createError }
        return payment
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

    func testRestoredAuthenticatedSessionSelectsSignedInModeFromModePicker() {
        let session = AppSession()

        session.restoreSignedInModeIfAuthenticated(true)

        XCTAssertEqual(session.mode, .signedIn)
        XCTAssertTrue(session.shouldUseCloudTripStore)
    }

    func testRestoredAuthenticatedSessionDoesNotOverrideDemoMode() {
        let session = AppSession()
        session.chooseDemoMode()

        session.restoreSignedInModeIfAuthenticated(true)

        XCTAssertEqual(session.mode, .demo)
        XCTAssertTrue(session.shouldUseDemoTripStore)
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

final class TripStatusTintTests: XCTestCase {
    private func rgba(_ color: Color) -> (CGFloat, CGFloat, CGFloat, CGFloat) {
        let uiColor = UIColor(color)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (r, g, b, a)
    }

    func testTripStatusTintsAreDistinct() {
        let past = rgba(TripStatus.past.tint)
        let current = rgba(TripStatus.current.tint)
        let future = rgba(TripStatus.future.tint)

        XCTAssertNotEqual(past.0, current.0)
        XCTAssertNotEqual(current.0, future.0)
        XCTAssertNotEqual(past.1, current.1)
    }

    func testCurrentTripTintUsesForestAccent() {
        let current = rgba(TripStatus.current.tint)
        let forest = rgba(AppTheme.Editorial.forest)

        XCTAssertEqual(current.0, forest.0, accuracy: 0.001)
        XCTAssertEqual(current.1, forest.1, accuracy: 0.001)
        XCTAssertEqual(current.2, forest.2, accuracy: 0.001)
    }

    func testFutureTripTintUsesForestDeepAccent() {
        let future = rgba(TripStatus.future.tint)
        let forestDeep = rgba(AppTheme.Editorial.forestDeep)

        XCTAssertEqual(future.0, forestDeep.0, accuracy: 0.001)
        XCTAssertEqual(future.1, forestDeep.1, accuracy: 0.001)
        XCTAssertEqual(future.2, forestDeep.2, accuracy: 0.001)
    }
}

final class SupabaseRenameParticipantParamsTests: XCTestCase {
    func testRenameParamsEncodeLinkedUserIDWhenPresent() throws {
        let params = SupabaseRenameTripParticipantParams(
            participantID: UUID(uuidString: "00000000-0000-0000-0000-00000000B040")!,
            tripID: UUID(uuidString: "00000000-0000-0000-0000-00000000B041")!,
            displayName: "Alex Rivera",
            linkedUserID: UUID(uuidString: "00000000-0000-0000-0000-00000000B042")!
        )

        let json = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(params)) as? [String: Any]
        )

        XCTAssertEqual(json["p_participant_id"] as? String, "00000000-0000-0000-0000-00000000B040")
        XCTAssertEqual(json["p_trip_id"] as? String, "00000000-0000-0000-0000-00000000B041")
        XCTAssertEqual(json["p_display_name"] as? String, "Alex Rivera")
        XCTAssertEqual(json["p_linked_user_id"] as? String, "00000000-0000-0000-0000-00000000B042")
    }

    func testRenameParamsOmitLinkedUserIDWhenNil() throws {
        let params = SupabaseRenameTripParticipantParams(
            participantID: UUID(uuidString: "00000000-0000-0000-0000-00000000B043")!,
            tripID: UUID(uuidString: "00000000-0000-0000-0000-00000000B044")!,
            displayName: "Sam",
            linkedUserID: nil
        )

        let json = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(params)) as? [String: Any]
        )

        XCTAssertNil(json["p_linked_user_id"])
        XCTAssertEqual(json["p_display_name"] as? String, "Sam")
    }
}

final class TripPlacesLogicTests: XCTestCase {
    func testPlaceTagInputResolvesSelectedCanonicalTag() {
        let input = PlaceTagInput(selectedTag: TripTag.food, customText: "")

        XCTAssertEqual(input.resolvedTag, "food")
    }

    func testPlaceTagInputCustomTextWinsOverSelectedChip() {
        let input = PlaceTagInput(selectedTag: TripTag.food, customText: "  Rooftop  ")

        XCTAssertEqual(input.resolvedTag, "Rooftop")
    }

    func testPlaceTagInputWhitespaceCustomFallsBackToChip() {
        let input = PlaceTagInput(selectedTag: TripTag.hotel, customText: "   ")

        XCTAssertEqual(input.resolvedTag, "hotel")
    }

    func testPlaceTagInputResolvesEmptyWhenNoChipOrCustomText() {
        let input = PlaceTagInput(selectedTag: nil, customText: "")

        XCTAssertEqual(input.resolvedTag, "")
    }

    func testPlaceTagInputPrefillsCanonicalCustomAndEmptyTags() {
        XCTAssertEqual(PlaceTagInput(prefilling: "food").selectedTag, TripTag.food)
        XCTAssertEqual(PlaceTagInput(prefilling: "food").customText, "")
        XCTAssertEqual(PlaceTagInput(prefilling: " Rooftop ").selectedTag, TripTag.custom)
        XCTAssertEqual(PlaceTagInput(prefilling: " Rooftop ").customText, "Rooftop")
        XCTAssertNil(PlaceTagInput(prefilling: "   ").selectedTag)
        XCTAssertEqual(PlaceTagInput(prefilling: "   ").customText, "")
    }

    func testPlacesFilterReturnsAllForNilAndExactMatchesForTags() {
        let places = [
            TripPlace(name: "Cafe", tag: "food"),
            TripPlace(name: "Hotel", tag: "hotel"),
            TripPlace(name: "No Tag", tag: "")
        ]

        XCTAssertEqual(places.filtered(by: nil).map(\.name), ["Cafe", "Hotel", "No Tag"])
        XCTAssertEqual(places.filtered(by: TripTag.food).map(\.name), ["Cafe"])
        XCTAssertTrue(places.filtered(by: TripTag.show).isEmpty)
    }

    func testPlacesFilterMatchesTitleCaseAndWhitespacePaddedTagsCaseInsensitively() {
        // Legacy/migrated/demo data preserves old category casing (e.g. "Food")
        // after the chunk 2 category→tag rename — filtering must be case-insensitive.
        let places = [
            TripPlace(name: "Nishiki", tag: "Food"),
            TripPlace(name: "Museum A", tag: " Museum "),
            TripPlace(name: "Cafe", tag: "food"),
            TripPlace(name: "No Tag", tag: "")
        ]

        XCTAssertEqual(places.filtered(by: TripTag.food).map(\.name), ["Nishiki", "Cafe"])
        XCTAssertEqual(places.filtered(by: TripTag.museum).map(\.name), ["Museum A"])
        XCTAssertEqual(places.filtered(by: TripTag.hotel).map(\.name), [])
    }

    func testPlaceMapsLinkBuildsAppAndWebURLsWithURLComponentsEncoding() throws {
        let diner = try XCTUnwrap(PlaceMapsLink(name: "D&D Diner"))
        let cafe = try XCTUnwrap(PlaceMapsLink(name: "Café"))

        XCTAssertEqual(diner.appURL.absoluteString, "comgooglemaps://?q=D%26D%20Diner")
        XCTAssertEqual(diner.webURL.absoluteString, "https://www.google.com/maps/search/?api=1&query=D%26D%20Diner")
        XCTAssertEqual(cafe.appURL.absoluteString, "comgooglemaps://?q=Caf%C3%A9")
        XCTAssertEqual(cafe.webURL.absoluteString, "https://www.google.com/maps/search/?api=1&query=Caf%C3%A9")
    }

    func testPlaceMapsLinkReturnsNilForEmptyName() {
        XCTAssertNil(PlaceMapsLink(name: "   "))
    }

    func testTripTagPlaceSubsetExcludesCustomFilterTag() {
        XCTAssertEqual(TripTag.subset(for: .place).map(\.rawValue), ["food", "hotel", "show", "museum"])
    }
}

final class TripStoreParticipantAccountIDTests: XCTestCase {
    func testCloudStoreUpdateParticipantPreservesAccountIDThroughService() async throws {
        let service = FakeTripSyncService()
        let tripID = UUID(uuidString: "00000000-0000-0000-0000-00000000B045")!
        let accountID = UUID(uuidString: "00000000-0000-0000-0000-00000000B046")!
        let alex = Participant(
            id: UUID(uuidString: "00000000-0000-0000-0000-00000000B047")!,
            name: "Alex",
            accountID: accountID
        )
        var trip = TripPlan(
            id: tripID,
            destination: "Austin",
            emoji: "🤠",
            imageURL: "https://example.com/austin.jpg",
            startDate: SupabaseDateFormatter.date(from: "2026-07-03")!,
            endDate: SupabaseDateFormatter.date(from: "2026-07-06")!,
            viewModel: TripCalculatorViewModel.empty(named: "Austin Weekend")
        )
        trip.viewModel.calculator.participants = [alex]
        let store = TripStore(trips: [trip], service: service)

        await store.updateParticipant(Participant(id: alex.id, name: "Alex Rivera", accountID: accountID), in: tripID)

        let request = try XCTUnwrap(service.updatedParticipantRequest)
        XCTAssertEqual(request.participant.id, alex.id)
        XCTAssertEqual(request.participant.name, "Alex Rivera")
        XCTAssertEqual(request.participant.accountID, accountID)
        XCTAssertNil(store.syncError)
    }
}
