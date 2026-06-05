import XCTest
@testable import GroupTripApp

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
