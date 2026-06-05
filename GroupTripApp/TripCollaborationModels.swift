import Foundation

struct TripMember: Identifiable, Hashable {
    let id: UUID
    var displayName: String
    var role: Role
    var accessState: AccessState
    var accountID: UUID?

    init(
        id: UUID = UUID(),
        displayName: String,
        role: Role,
        accessState: AccessState = .active,
        accountID: UUID? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.role = role
        self.accessState = accessState
        self.accountID = accountID
    }

    enum Role: Hashable {
        case owner
        case guest
    }

    enum AccessState: Hashable {
        case active
        case revoked
    }
}

struct ExpenseParticipant: Identifiable, Hashable {
    let id: UUID
    var displayName: String
    var linkedMemberID: TripMember.ID?

    init(id: UUID = UUID(), displayName: String, linkedMemberID: TripMember.ID? = nil) {
        self.id = id
        self.displayName = displayName
        self.linkedMemberID = linkedMemberID
    }

    static func guest(displayName: String) -> ExpenseParticipant {
        ExpenseParticipant(displayName: displayName)
    }
}

struct TripCollaboration: Hashable {
    var members: [TripMember]
    var participants: [ExpenseParticipant]

    static func createTrip(organizerDisplayName: String, organizerAccountID: UUID? = nil) -> TripCollaboration {
        let organizerMember = TripMember(
            displayName: organizerDisplayName,
            role: .owner,
            accountID: organizerAccountID
        )
        let organizerParticipant = ExpenseParticipant(
            displayName: organizerDisplayName,
            linkedMemberID: organizerMember.id
        )

        return TripCollaboration(
            members: [organizerMember],
            participants: [organizerParticipant]
        )
    }

    mutating func revokeAccess(for memberID: TripMember.ID) {
        guard let index = members.firstIndex(where: { $0.id == memberID }) else { return }
        members[index].accessState = .revoked
    }
}
