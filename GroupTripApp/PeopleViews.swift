import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct PeopleTabView: View {
    @ObservedObject var viewModel: TripCalculatorViewModel
    var editParticipant: (Participant) -> Void = { _ in }
    var addPeople: () -> Void
    @State private var participantPendingDeletion: Participant?

    var body: some View {
        VStack(spacing: 14) {
            Button(action: addPeople) {
                Label("Add Participant", systemImage: "plus")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.Editorial.forest)

            if viewModel.calculator.participants.isEmpty {
                EmptyFeatureCard(title: "No people yet", subtitle: "Add travelers before tracking shared expenses.")
            } else {
                VStack(spacing: 12) {
                    ForEach(viewModel.calculator.participants.sorted { $0.name < $1.name }) { participant in
                        SwipeRevealActionRow(
                            actionTitle: "Remove",
                            actionSystemImage: "trash",
                            actionAccessibilityLabel: "Remove \(participant.name)"
                        ) {
                            participantPendingDeletion = participant
                        } content: {
                            PersonCard(
                                participant: participant,
                                expenseCount: viewModel.calculator.expenses.filter { $0.paidBy == participant.id }.count,
                                editParticipant: {
                                    editParticipant(participant)
                                },
                                deleteParticipant: {
                                    participantPendingDeletion = participant
                                }
                            )
                        }
                    }
                }
            }
        }
        .confirmationDialog(
            "Remove this person?",
            isPresented: Binding(
                get: { participantPendingDeletion != nil },
                set: { isPresented in
                    if !isPresented { participantPendingDeletion = nil }
                }
            ),
            titleVisibility: .visible,
            presenting: participantPendingDeletion
        ) { participant in
            Button("Remove Person", role: .destructive) {
                deleteParticipant(participant)
            }
            Button("Cancel", role: .cancel) { participantPendingDeletion = nil }
        } message: { participant in
            Text("This removes \(participant.name) from the people list. Existing expense references may change.")
        }
    }

    private func deleteParticipant(_ participant: Participant) {
        let sortedParticipants = viewModel.calculator.participants.sorted { $0.name < $1.name }
        if let index = sortedParticipants.firstIndex(where: { $0.id == participant.id }) {
            viewModel.deleteParticipants(at: IndexSet(integer: index))
        }
        participantPendingDeletion = nil
    }
}

struct PeopleFeatureView: View {
    @ObservedObject var viewModel: TripCalculatorViewModel
    var tripID: TripPlan.ID?
    var tripName: String = ""
    var createdInvite: TripInvite?
    var places: [TripPlace] = []
    var planningItems: [TripPlanningItem] = []
    var saveParticipants: ([String]) async -> Void = { _ in }
    var updateParticipant: (Participant) async -> Void = { _ in }
    var createInvite: () -> Void = { }
    var createInviteAsync: () async -> Void = { }
    var usesExternalPersistence: Bool = false
    @State private var activeSheet: ActiveSheet?
    @State private var participantPendingDeletion: Participant?

    private var balancesByID: [Participant.ID: Decimal] {
        Dictionary(uniqueKeysWithValues: viewModel.calculator.balances().map { ($0.participant.id, $0.net) })
    }

    private var placeCountsByParticipantID: [Participant.ID: Int] {
        var counts: [Participant.ID: Int] = [:]
        for place in places {
            for id in place.participantIDs {
                counts[id, default: 0] += 1
            }
        }
        return counts
    }

    private func detailDestination(for participant: Participant) -> AnyView {
        AnyView(
            PersonDetailView(
                participant: participant,
                tripName: tripName.isEmpty ? viewModel.tripName : tripName,
                places: places,
                planningItems: planningItems,
                expenses: viewModel.calculator.expenses,
                balanceNet: balancesByID[participant.id] ?? 0,
                createdInvite: createdInvite,
                createInvite: createInviteAsync,
                usesExternalPersistence: usesExternalPersistence
            )
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
                if usesExternalPersistence, let tripID {
                    InvitePeopleCard(tripID: tripID, createdInvite: createdInvite, createInvite: createInvite)
                }

                if viewModel.calculator.participants.isEmpty {
                    EmptyFeatureCard(
                        title: "No people yet",
                        subtitle: "Add travelers before tracking shared expenses and places."
                    )
                } else {
                    hallSections
                    settlementCards
                }
            }
            .padding(AppTheme.Spacing.large)
        }
        .background(AppTheme.Editorial.background)
        .navigationTitle("People")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    activeSheet = .person
                } label: {
                    Label("Add People", systemImage: "person.fill.badge.plus")
                }
            }
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .person:
                AddPersonView(
                    viewModel: viewModel,
                    saveParticipants: saveParticipants,
                    updateParticipant: updateParticipant,
                    usesExternalPersistence: usesExternalPersistence
                )
            case .editPerson(let participant):
                AddPersonView(
                    viewModel: viewModel,
                    existingParticipant: participant,
                    saveParticipants: saveParticipants,
                    updateParticipant: updateParticipant,
                    usesExternalPersistence: usesExternalPersistence
                )
            case .expense:
                EmptyView()
            }
        }
        .confirmationDialog(
            "Remove this person?",
            isPresented: Binding(
                get: { participantPendingDeletion != nil },
                set: { isPresented in
                    if !isPresented { participantPendingDeletion = nil }
                }
            ),
            titleVisibility: .visible,
            presenting: participantPendingDeletion
        ) { participant in
            Button("Remove Person", role: .destructive) {
                deleteParticipant(participant)
            }
            Button("Cancel", role: .cancel) { participantPendingDeletion = nil }
        } message: { participant in
            Text("This removes \(participant.name) from the people list. Existing expense references may change.")
        }
    }

    private var hallSections: some View {
        let hall = PeopleHall.grouped(viewModel.calculator.participants)
        return VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
            if !hall.organizers.isEmpty {
                personSection(title: "Organizer", people: hall.organizers)
            }
            if !hall.travelers.isEmpty {
                personSection(title: "Travelers", people: hall.travelers)
            }
        }
    }

    private func personSection(title: String, people: [Participant]) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
            EditorialSectionHeader(
                title: "\(title) · \(people.count)"
            )

            WaniCard(radius: AppTheme.Radius.large) {
                VStack(spacing: 0) {
                    ForEach(Array(people.enumerated()), id: \.element.id) { index, participant in
                        hallRow(for: participant)

                        if index < people.count - 1 {
                            Divider()
                                .padding(.leading, AppTheme.IconSize.large + AppTheme.Spacing.medium + 2)
                        }
                    }
                }
            }
        }
    }

    private func hallRow(for participant: Participant) -> some View {
        HStack(spacing: AppTheme.Spacing.medium) {
            NavigationLink(destination: detailDestination(for: participant)) {
                HStack(spacing: AppTheme.Spacing.medium) {
                    AvatarInitial(name: participant.name, size: 48)

                    VStack(alignment: .leading, spacing: AppTheme.Spacing.xSmall) {
                        HStack(spacing: AppTheme.Spacing.small) {
                            Text(participant.name)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(AppTheme.Editorial.primaryText)
                            if participant.isOrganizer {
                                OrganizerBadge()
                            }
                        }

                        Text(hallMetaText(for: participant))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(hallMetaTint(for: participant))
                    }
                }
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)

            Button {
                activeSheet = .editPerson(participant)
            } label: {
                Image(systemName: "pencil")
                    .font(.subheadline.weight(.semibold))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
                    .foregroundStyle(AppTheme.Editorial.forest)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Edit \(participant.name)")

            Button(role: .destructive) {
                participantPendingDeletion = participant
            } label: {
                Image(systemName: "trash")
                    .font(.subheadline.weight(.semibold))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Delete \(participant.name)")
        }
        .padding(.vertical, AppTheme.Spacing.medium)
    }

    private var settlementCards: some View {
        SettlementCards(
            settlements: viewModel.settlements,
            participantCount: viewModel.calculator.participants.count,
            totalExpenses: viewModel.calculator.totalExpenses
        )
    }

    private func hallMetaText(for participant: Participant) -> String {
        let placeCount = placeCountsByParticipantID[participant.id] ?? 0
        let balanceText = PersonBalancePhrase(net: balancesByID[participant.id] ?? 0).text
        if placeCount > 0 {
            return "\(placeCount) \(placeCount == 1 ? "place" : "places") · \(balanceText)"
        }
        return balanceText
    }

    private func hallMetaTint(for participant: Participant) -> Color {
        let net = balancesByID[participant.id] ?? 0
        if net > 0 {
            return AppTheme.Editorial.forest
        } else if net < 0 {
            return AppTheme.Editorial.owed
        }
        return AppTheme.Editorial.secondaryText
    }

    private func deleteParticipant(_ participant: Participant) {
        viewModel.deleteParticipants(at: IndexSet(integer: viewModel.calculator.participants.firstIndex(where: { $0.id == participant.id }) ?? 0))
        participantPendingDeletion = nil
    }
}

private struct InvitePeopleCard: View {
    let tripID: TripPlan.ID
    let createdInvite: TripInvite?
    var createInvite: () -> Void
    @State private var didCopyInviteCode = false

    private var inviteForTrip: TripInvite? {
        guard createdInvite?.tripID == tripID else { return nil }
        return createdInvite
    }

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                HStack(spacing: AppTheme.Spacing.small) {
                    WaniIconBadge(systemImage: "person.badge.plus", tint: AppTheme.success, size: AppTheme.IconSize.medium)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Invite People")
                            .font(.subheadline.weight(.semibold))
                        Text("Create a code friends can use to join this trip.")
                            .font(.caption)
                            .foregroundStyle(AppTheme.Editorial.secondaryText)
                    }

                    Spacer()
                }

                if let inviteForTrip {
                    HStack(spacing: AppTheme.Spacing.small) {
                        Text(inviteForTrip.code)
                            .font(.title3.monospaced().weight(.semibold))
                            .padding(.vertical, AppTheme.Spacing.xSmall)
                            .accessibilityLabel("Invite code \(inviteForTrip.code)")

                        Spacer()

                        Button {
                            copyInviteCode(inviteForTrip.code)
                        } label: {
                            Label(didCopyInviteCode ? "Copied" : "Copy", systemImage: didCopyInviteCode ? "checkmark" : "doc.on.doc")
                        }
                        .font(.caption.weight(.semibold))
                        .buttonStyle(.bordered)
                        .tint(didCopyInviteCode ? AppTheme.success : AppTheme.Editorial.forest)
                        .accessibilityLabel(didCopyInviteCode ? "Invite code copied" : "Copy invite code")
                    }
                }

                Button(inviteForTrip == nil ? "Create Invite Code" : "Create Another Code", action: createInvite)
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.Editorial.forest)
            }
            .padding(.vertical, AppTheme.Spacing.xSmall)
        }
    }

    private func copyInviteCode(_ code: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = code
        #endif
        didCopyInviteCode = true
        Task {
            try? await Task.sleep(for: .seconds(2))
            await MainActor.run { didCopyInviteCode = false }
        }
    }
}

struct PersonCard: View {
    let participant: Participant
    let expenseCount: Int
    var editParticipant: () -> Void
    var deleteParticipant: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            AvatarInitial(name: participant.name, size: 48)

            VStack(alignment: .leading, spacing: 4) {
                Text(participant.name)
                    .font(.body.weight(.semibold))
                Text("\(expenseCount) expenses paid")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Editorial.secondaryText)
            }

            Spacer()

            Button(action: editParticipant) {
                Image(systemName: "pencil")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Edit \(participant.name)")

            Button(role: .destructive, action: deleteParticipant) {
                Image(systemName: "trash")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.borderless)
        }
        .padding(16)
        .background(AppTheme.Editorial.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.Editorial.border, lineWidth: 1)
        )
    }
}

struct BalanceCards: View {
    let balances: [Balance]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            EditorialSectionHeader(title: "Balances")

            if balances.isEmpty {
                EmptyFeatureCard(title: "Add people to see balances", subtitle: "Balances appear after travelers and expenses are added.")
            } else {
                VStack(spacing: 10) {
                    ForEach(balances) { balance in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 12) {
                                AvatarInitial(name: balance.participant.name)

                                Text(balance.participant.name)
                                    .font(.body.weight(.semibold))

                                Spacer()

                                Text(balance.net.signedCurrencyText)
                                    .font(.headline)
                                    .monospacedDigit()
                                    .foregroundStyle(balance.net > 0 ? AppTheme.Editorial.forest : balance.net < 0 ? AppTheme.error : .secondary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background((balance.net > 0 ? AppTheme.Editorial.forest : balance.net < 0 ? AppTheme.error : Color.secondary).opacity(0.12))
                                    .clipShape(Capsule())
                            }

                            Text(balanceStatusText(for: balance.net))
                                .font(.caption)
                                .foregroundStyle(AppTheme.Editorial.secondaryText)
                        }
                        .padding(14)
                        .background(AppTheme.Editorial.card)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(AppTheme.Editorial.border, lineWidth: 1)
                        )
                    }
                }
            }
        }
    }

    private func balanceStatusText(for net: Decimal) -> String {
        if net > 0 {
            return "Gets back \(net.currencyText)"
        } else if net < 0 {
            return "Owes \((-net).currencyText)"
        } else {
            return "Settled"
        }
    }
}

struct SettlementCards: View {
    let settlements: [Settlement]
    var participantCount: Int = 0
    var totalExpenses: Decimal = 0
    /// Invoked when a suggested settlement row is tapped ("Pay Maya $42").
    /// When nil the rows are informational (People hall read-only surface).
    var onRecordSettlement: ((Settlement) -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            EditorialSectionHeader(title: "Suggested settlements")

            if settlements.isEmpty {
                EmptyFeatureCard(title: emptyTitle, subtitle: emptySubtitle)
            } else {
                VStack(spacing: 10) {
                    ForEach(settlements) { settlement in
                        settlementRow(settlement)
                    }
                }
            }
        }
    }

    private func settlementRow(_ settlement: Settlement) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                AvatarInitial(name: settlement.from.name)
                Image(systemName: "arrow.right")
                    .foregroundStyle(AppTheme.Editorial.secondaryText)
                AvatarInitial(name: settlement.to.name)

                Text("\(settlement.from.name) pays \(settlement.to.name)")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)

                Spacer()

                Text(settlement.amount.currencyText)
                    .font(.headline)
                    .foregroundStyle(AppTheme.Editorial.forest)
                    .monospacedDigit()
            }

            if let onRecordSettlement {
                Button {
                    onRecordSettlement(settlement)
                } label: {
                    Label(
                        "Pay \(settlement.to.name) \(settlement.amount.wholeCurrencyText)",
                        systemImage: "arrow.left.arrow.right"
                    )
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.bordered)
                .tint(AppTheme.Editorial.forest)
            }
        }
        .padding(14)
        .background(AppTheme.Editorial.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.Editorial.border, lineWidth: 1)
        )
    }

    private var emptyTitle: String {
        if participantCount == 0 {
            return "Add people to settle up"
        }

        if totalExpenses == 0 {
            return "No settlements yet"
        }

        return "All settled up"
    }

    private var emptySubtitle: String {
        if participantCount == 0 {
            return "Suggested payments appear after people and expenses are added."
        }

        if totalExpenses == 0 {
            return "Add expenses or record payments to see what is owed."
        }

        return "No outstanding balances."
    }
}
