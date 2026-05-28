import SwiftUI

struct PeopleTabView: View {
    @ObservedObject var viewModel: TripCalculatorViewModel
    var addPeople: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Button(action: addPeople) {
                Label("Add Participant", systemImage: "plus")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.primary)

            if viewModel.calculator.participants.isEmpty {
                EmptyFeatureCard(title: "No people yet", subtitle: "Add travelers before tracking shared expenses.")
            } else {
                VStack(spacing: 12) {
                    ForEach(viewModel.calculator.participants.sorted { $0.name < $1.name }) { participant in
                        PersonCard(participant: participant, expenseCount: viewModel.calculator.expenses.filter { $0.paidBy == participant.id }.count) {
                            deleteParticipant(participant)
                        }
                    }
                }
            }
        }
    }

    private func deleteParticipant(_ participant: Participant) {
        let sortedParticipants = viewModel.calculator.participants.sorted { $0.name < $1.name }
        if let index = sortedParticipants.firstIndex(where: { $0.id == participant.id }) {
            viewModel.deleteParticipants(at: IndexSet(integer: index))
        }
    }
}

struct PeopleFeatureView: View {
    @ObservedObject var viewModel: TripCalculatorViewModel
    @State private var activeSheet: ActiveSheet?

    var body: some View {
        List {
            PeopleSection(viewModel: viewModel)
            SettlementSection(settlements: viewModel.settlements)
        }
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
        .sheet(item: $activeSheet) { _ in
            AddPersonView(viewModel: viewModel)
        }
    }
}

struct PersonCard: View {
    let participant: Participant
    let expenseCount: Int
    var deleteParticipant: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            AvatarInitial(name: participant.name, size: 48)

            VStack(alignment: .leading, spacing: 4) {
                Text(participant.name)
                    .font(.body.weight(.semibold))
                Text("\(expenseCount) expenses paid")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(role: .destructive, action: deleteParticipant) {
                Image(systemName: "trash")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.borderless)
        }
        .padding(16)
        .background(AppTheme.paper)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct BalanceCards: View {
    let balances: [Balance]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Individual Balances")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

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
                                    .foregroundStyle(balance.net > 0 ? AppTheme.success : balance.net < 0 ? AppTheme.error : .secondary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background((balance.net > 0 ? AppTheme.success : balance.net < 0 ? AppTheme.error : Color.secondary).opacity(0.12))
                                    .clipShape(Capsule())
                            }

                            Text(balanceStatusText(for: balance.net))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(14)
                        .background(AppTheme.paper)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Suggested Settlements")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            if settlements.isEmpty {
                EmptyFeatureCard(title: emptyTitle, subtitle: emptySubtitle)
            } else {
                VStack(spacing: 10) {
                    ForEach(settlements) { settlement in
                        HStack(spacing: 10) {
                            AvatarInitial(name: settlement.from.name)
                            Image(systemName: "arrow.right")
                                .foregroundStyle(.secondary)
                            AvatarInitial(name: settlement.to.name)

                            Text("\(settlement.from.name) pays \(settlement.to.name)")
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(2)

                            Spacer()

                            Text(settlement.amount.currencyText)
                                .font(.headline)
                                .foregroundStyle(AppTheme.primary)
                                .monospacedDigit()
                        }
                        .padding(14)
                        .background(AppTheme.paper)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
            }
        }
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

struct PeopleSection: View {
    @ObservedObject var viewModel: TripCalculatorViewModel

    var body: some View {
        Section {
            if viewModel.calculator.participants.isEmpty {
                EmptyRow(title: "No people yet", systemImage: "person.2")
            } else {
                ForEach(viewModel.calculator.participants.sorted { $0.name < $1.name }) { participant in
                    Label(participant.name, systemImage: "person.fill")
                }
                .onDelete(perform: viewModel.deleteParticipants)
            }
        } header: {
            Text("People")
        }
    }
}

struct SettlementSection: View {
    let settlements: [Settlement]

    var body: some View {
        Section {
            if settlements.isEmpty {
                EmptyRow(title: "All settled", systemImage: "checkmark.circle")
            } else {
                ForEach(settlements) { settlement in
                    HStack(spacing: 12) {
                        Image(systemName: "arrow.right.circle.fill")
                            .foregroundStyle(AppTheme.primary)

                        Text("\(settlement.from.name) pays \(settlement.to.name)")
                            .font(.body.weight(.semibold))

                        Spacer()

                        Text(settlement.amount.currencyText)
                            .font(.headline)
                            .monospacedDigit()
                    }
                }
            }
        } header: {
            Text("Suggested payments")
        }
    }
}
