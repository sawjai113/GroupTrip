import SwiftUI

struct ExpenseTrackerView: View {
    let tripName: String
    let destination: String
    @ObservedObject var viewModel: TripCalculatorViewModel
    var saveExpense: (String, Participant.ID, Decimal, Set<Participant.ID>) async -> Void = { _, _, _, _ in }
    var deleteExpense: (ExpenseItem.ID) async -> Void = { _ in }
    var saveDirectPayment: (String, Participant.ID, Participant.ID, Decimal) async -> Void = { _, _, _, _ in }
    var saveParticipants: ([String]) async -> Void = { _ in }
    var usesExternalPersistence: Bool = false
    @State private var selectedTab: ExpenseTab = .expenses
    @State private var activeSheet: ActiveSheet?

    var body: some View {
        VStack(spacing: 0) {
            ExpenseHeader(tripName: tripName, destination: destination, participants: viewModel.calculator.participants)

            ScrollView {
                VStack(spacing: 16) {
                    ExpenseStatsCard(viewModel: viewModel)

                    Picker("Expense view", selection: $selectedTab) {
                        ForEach(ExpenseTab.allCases) { tab in
                            Text(tab.title).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)

                    switch selectedTab {
                    case .expenses:
                        ExpenseTabView(
                            viewModel: viewModel,
                            usesExternalPersistence: usesExternalPersistence,
                            deleteExpenseRemotely: deleteExpense
                        ) {
                            activeSheet = .expense
                        } addPeople: {
                            activeSheet = .person
                        }
                    case .balances:
                        BalancesTabView(
                            viewModel: viewModel,
                            saveDirectPayment: saveDirectPayment,
                            usesExternalPersistence: usesExternalPersistence
                        )
                    case .people:
                        PeopleTabView(viewModel: viewModel) {
                            activeSheet = .person
                        }
                    }
                }
                .padding(16)
            }
        }
        .background(AppTheme.background)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .person:
                AddPersonView(
                    viewModel: viewModel,
                    saveParticipants: saveParticipants,
                    usesExternalPersistence: usesExternalPersistence
                )
            case .expense:
                AddExpenseView(
                    viewModel: viewModel,
                    saveExpense: saveExpense,
                    usesExternalPersistence: usesExternalPersistence
                )
            case .payment:
                AddPaymentView(viewModel: viewModel)
            }
        }
    }
}

enum ExpenseTab: String, CaseIterable, Identifiable {
    case expenses
    case balances
    case people

    var id: String { rawValue }

    var title: String {
        switch self {
        case .expenses: "Expenses"
        case .balances: "Balances"
        case .people: "People"
        }
    }
}

struct ExpenseHeader: View {
    let tripName: String
    let destination: String
    let participants: [Participant]

    var body: some View {
        HStack(spacing: 12) {
            BackButton()
                .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(tripName)
                    .font(.headline)
                    .lineLimit(1)
                if !destination.isEmpty {
                    Text(destination)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            AvatarCluster(participants: participants, size: 32, maxVisible: 3)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.regularMaterial)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
}

struct ExpenseStatsCard: View {
    @ObservedObject var viewModel: TripCalculatorViewModel

    var body: some View {
        HStack(spacing: 14) {
            CompactMetric(systemImage: "receipt.fill", label: "Total", value: viewModel.calculator.totalExpenses.wholeCurrencyText)
            CompactMetric(systemImage: "person.2.fill", label: "People", value: "\(viewModel.calculator.participants.count)")
            CompactMetric(systemImage: "chart.line.uptrend.xyaxis", label: "Per Person", value: perPersonText)
        }
        .padding(16)
        .background(AppTheme.paper)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var perPersonText: String {
        guard !viewModel.calculator.participants.isEmpty else { return "$0" }
        return (viewModel.calculator.totalExpenses / Decimal(viewModel.calculator.participants.count)).wholeCurrencyText
    }
}

struct CompactMetric: View {
    let systemImage: String
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.primary)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }
}

struct ExpenseTabView: View {
    @ObservedObject var viewModel: TripCalculatorViewModel
    var usesExternalPersistence: Bool = false
    var deleteExpenseRemotely: (ExpenseItem.ID) async -> Void = { _ in }
    var addExpense: () -> Void
    var addPeople: () -> Void
    @State private var expensePendingDeletion: ExpenseItem?

    private var hasParticipants: Bool {
        !viewModel.calculator.participants.isEmpty
    }

    var body: some View {
        VStack(spacing: 14) {
            Button(action: addExpense) {
                Label("Add Expense", systemImage: "plus")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.primary)
            .disabled(!hasParticipants)

            if !hasParticipants {
                Text("Add at least one person before logging shared expenses.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button(action: addPeople) {
                    Label("Add People", systemImage: "person.fill.badge.plus")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.bordered)
            }

            if viewModel.calculator.expenses.isEmpty {
                EmptyFeatureCard(
                    title: "No expenses yet",
                    subtitle: hasParticipants ? "Add your first expense to start splitting costs." : "Start by adding travelers, then log costs to split."
                )
            } else {
                VStack(spacing: 12) {
                    ForEach(viewModel.calculator.expenses) { expense in
                        ExpenseCard(expense: expense, paidBy: viewModel.participantName(for: expense.paidBy)) {
                            expensePendingDeletion = expense
                        }
                    }
                }
            }
        }
        .confirmationDialog(
            "Delete this expense?",
            isPresented: Binding(
                get: { expensePendingDeletion != nil },
                set: { isPresented in
                    if !isPresented { expensePendingDeletion = nil }
                }
            ),
            titleVisibility: .visible,
            presenting: expensePendingDeletion
        ) { expense in
            Button("Delete Expense", role: .destructive) {
                deleteExpense(expense)
            }
            Button("Cancel", role: .cancel) { expensePendingDeletion = nil }
        } message: { expense in
            Text("This removes \(expense.title) from this trip. Shared cloud trips will remove it for everyone.")
        }
    }

    private func deleteExpense(_ expense: ExpenseItem) {
        if usesExternalPersistence {
            Task { await deleteExpenseRemotely(expense.id) }
        } else if let index = viewModel.calculator.expenses.firstIndex(where: { $0.id == expense.id }) {
            viewModel.deleteExpenses(at: IndexSet(integer: index))
        }
        expensePendingDeletion = nil
    }
}

struct ExpenseCard: View {
    let expense: ExpenseItem
    let paidBy: String
    var deleteExpense: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            AvatarInitial(name: paidBy)

            VStack(alignment: .leading, spacing: 5) {
                Text(expense.title)
                    .font(.body.weight(.semibold))
                Text("Paid by \(paidBy) • \(expense.participants.count) people")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Shared")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(AppTheme.lightBlue)
                    .clipShape(Capsule())
            }

            Spacer()

            Text(expense.amount.currencyText)
                .font(.headline)
                .foregroundStyle(AppTheme.primary)
                .monospacedDigit()

            Button(role: .destructive, action: deleteExpense) {
                Image(systemName: "trash")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.borderless)
        }
        .padding(14)
        .background(AppTheme.paper)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct BalancesTabView: View {
    @ObservedObject var viewModel: TripCalculatorViewModel
    var saveDirectPayment: (String, Participant.ID, Participant.ID, Decimal) async -> Void = { _, _, _, _ in }
    var usesExternalPersistence: Bool = false
    @State private var activeSheet: ActiveSheet?

    var body: some View {
        VStack(spacing: 14) {
            Button {
                activeSheet = .payment
            } label: {
                Label("Record Payment", systemImage: "arrow.left.arrow.right")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.primary)
            .disabled(viewModel.calculator.participants.count < 2)

            if viewModel.calculator.participants.count < 2 {
                Text("Add at least two people to record a direct payment between travelers.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            BalanceCards(balances: viewModel.balances)
            SettlementCards(
                settlements: viewModel.settlements,
                participantCount: viewModel.calculator.participants.count,
                totalExpenses: viewModel.calculator.totalExpenses
            )
        }
        .sheet(item: $activeSheet) { _ in
            AddPaymentView(
                viewModel: viewModel,
                saveDirectPayment: saveDirectPayment,
                usesExternalPersistence: usesExternalPersistence
            )
        }
    }
}
