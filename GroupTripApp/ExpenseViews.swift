import SwiftUI

struct ExpenseTrackerView: View {
    let tripName: String
    let destination: String
    @ObservedObject var viewModel: TripCalculatorViewModel
    var currentAccountID: UUID? = nil
    var saveExpense: (String, Participant.ID, Decimal, Set<Participant.ID>) async -> Void = { _, _, _, _ in }
    var updateExpense: (ExpenseItem) async -> Void = { _ in }
    var deleteExpense: (ExpenseItem.ID) async -> Void = { _ in }
    var saveDirectPayment: (String, Participant.ID, Participant.ID, Decimal) async -> Void = { _, _, _, _ in }
    var updateDirectPayment: (DirectPayment) async -> Void = { _ in }
    var saveParticipants: ([String]) async -> Void = { _ in }
    var updateParticipant: (Participant) async -> Void = { _ in }
    var usesExternalPersistence: Bool = false
    @State private var selectedTab: ExpenseTab = .expenses
    @State private var activeSheet: ActiveSheet?
    @State private var isShowingQuickAdd = false

    /// Resolved account-aware money status. `.unmapped` (demo or no linked
    /// participant) keeps the existing trip-relative framing — honest fallback.
    private var userMoneyStatus: UserMoneyStatus {
        UserMoneyResolver.resolve(
            accountID: currentAccountID,
            participants: viewModel.calculator.participants,
            netByParticipantID: Dictionary(uniqueKeysWithValues: viewModel.calculator.balances().map { ($0.participant.id, $0.net) })
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            ExpenseHeader(tripName: tripName, destination: destination, participants: viewModel.calculator.participants)

            ScrollView {
                VStack(spacing: 16) {
                    if userMoneyStatus != .unmapped {
                        UserMoneyHero(status: userMoneyStatus)
                    }

                    ExpenseStatsCard(viewModel: viewModel)

                    if !viewModel.calculator.participants.isEmpty {
                        quickAddRow
                    }

                    EditorialSegmentedControl(
                        options: ExpenseTab.allCases,
                        selection: $selectedTab,
                        display: { $0.title },
                        accessibilityLabel: "Expense view"
                    )

                    switch selectedTab {
                    case .expenses:
                        ExpenseTabView(
                            viewModel: viewModel,
                            usesExternalPersistence: usesExternalPersistence,
                            updateExpenseRemotely: updateExpense,
                            deleteExpenseRemotely: deleteExpense
                        ) {
                            activeSheet = .expense
                        } addPeople: {
                            activeSheet = .person
                        }
                    case .balances:
                        BalancesTabView(
                            viewModel: viewModel,
                            currentAccountID: currentAccountID,
                            saveDirectPayment: saveDirectPayment,
                            updateDirectPayment: updateDirectPayment,
                            usesExternalPersistence: usesExternalPersistence
                        )
                    case .people:
                        PeopleTabView(
                            viewModel: viewModel,
                            editParticipant: { participant in
                                activeSheet = .editPerson(participant)
                            }
                        ) {
                            activeSheet = .person
                        }
                    }
                }
                .padding(16)
            }
        }
        .background(AppTheme.Editorial.background)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $isShowingQuickAdd) {
            QuickAddExpenseSheet(
                viewModel: viewModel,
                defaultPayerID: quickAddDefaultPayerID
            ) { amount, payerID, participants in
                await saveExpense(QuickAddMoney.autoTitle(), payerID, amount, participants)
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
                AddExpenseView(
                    viewModel: viewModel,
                    saveExpense: saveExpense,
                    usesExternalPersistence: usesExternalPersistence
                )
            }
        }
    }

    private var quickAddRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "bolt.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(AppTheme.Editorial.forest)
                .clipShape(Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("Quick Add")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.Editorial.primaryText)
                Text("Amount, who paid, done — split equally")
                    .font(.caption)
                    .foregroundStyle(AppTheme.Editorial.secondaryText)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.Editorial.secondaryText)
        }
        .padding(AppTheme.Spacing.medium)
        .background(AppTheme.Editorial.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.Editorial.border, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            isShowingQuickAdd = true
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("Quick Add Expense")
    }

    /// Default payer for the quick-add sheet: the account-linked participant
    /// first (demo fallback: first participant — trip-relative framing intact).
    private var quickAddDefaultPayerID: UUID? {
        if let currentAccountID,
           let me = viewModel.calculator.participants.first(where: { $0.accountID == currentAccountID }) {
            return me.id
        }
        return viewModel.calculator.participants.first?.id
    }
}

/// Account-aware hero: two metric cells (You owe / You get back) in the
/// chunk-5 raised-card style. Only shown when the user is mapped to a trip
/// participant; otherwise the trip-relative framing stays (honest fallback).
struct UserMoneyHero: View {
    let status: UserMoneyStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            EditorialSectionHeader(title: "Your balance")

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                spacing: 10
            ) {
                metricCell(title: "You owe", amount: oweAmount, color: AppTheme.Editorial.owed, accessory: status)
                metricCell(title: "You get back", amount: getBackAmount, color: AppTheme.Editorial.forestDeep, accessory: status)
            }
        }
    }

    private var oweAmount: Decimal {
        if case let .youOwe(amount) = status { return amount }
        return 0
    }

    private var getBackAmount: Decimal {
        if case let .youGetBack(amount) = status { return amount }
        return 0
    }

    private func metricCell(title: String, amount: Decimal, color: Color, accessory: UserMoneyStatus) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xSmall) {
            Text(amount.wholeCurrencyText)
                .font(.system(size: 23, weight: .semibold, design: .serif))
                .tracking(-0.3)
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.Editorial.secondaryText)
            if accessory == .settled {
                Text("All settled")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AppTheme.Editorial.secondaryText)
            }
        }
        .padding(AppTheme.Spacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.Editorial.raisedCard)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppTheme.Editorial.border, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessoryText(title: title, amount: amount))
    }

    private func accessoryText(title: String, amount: Decimal) -> String {
        if amount > 0 {
            return "\(title) \(amount.wholeCurrencyText)"
        }
        if status == .settled {
            return "\(title) none, all settled"
        }
        return "\(title) none"
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

private struct QuickAddExpenseSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: TripCalculatorViewModel
    let defaultPayerID: UUID?
    var commit: (Decimal, UUID, Set<UUID>) async -> Void
    @State private var amount = ""
    @State private var payerID: UUID?
    @State private var isSaving = false

    private var participants: [Participant] {
        viewModel.calculator.participants
    }

    private var parsedAmount: Decimal {
        Decimal(string: amount.filter { $0 != "$" && $0 != "," }) ?? 0
    }

    private var payerBinding: Binding<UUID> {
        Binding(
            get: { payerID ?? defaultPayerID ?? participants.first?.id ?? UUID() },
            set: { payerID = $0 }
        )
    }

    private var canSave: Bool {
        parsedAmount > 0 && (payerID ?? defaultPayerID ?? participants.first?.id) != nil && !participants.isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                    EditorialTextField(
                        label: "Amount",
                        placeholder: "0.00",
                        text: $amount,
                        keyboardType: .decimalPad
                    )

                    VStack(alignment: .leading, spacing: AppTheme.Spacing.xSmall + 2) {
                        EditorialMenuField(
                            "Who paid?",
                            selection: payerBinding,
                            options: participants.map(\.id),
                            display: { id in participants.first { $0.id == id }?.name ?? "Unknown" }
                        )

                        Text("Split equally among all \(participants.count) travelers")
                            .font(.caption)
                            .foregroundStyle(AppTheme.Editorial.secondaryText)
                    }

                    Button {
                        save()
                    } label: {
                        Text("Add Expense")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, AppTheme.Spacing.medium)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.Editorial.forest)
                    .disabled(!canSave || isSaving)
                }
                .padding(AppTheme.Spacing.large)
            }
            .background(AppTheme.Editorial.background)
            .navigationTitle("Quick Add Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                if payerID == nil {
                    payerID = defaultPayerID ?? participants.first?.id
                }
            }
        }
    }

    private func save() {
        guard let resolvedPayer = payerID ?? defaultPayerID ?? participants.first?.id else { return }
        let split = QuickAddMoney.equalSplitParticipants(
            payerID: resolvedPayer,
            allParticipants: participants
        )
        guard !split.isEmpty else { return }
        isSaving = true
        Task {
            await commit(parsedAmount, resolvedPayer, split)
            dismiss()
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
                        .foregroundStyle(AppTheme.Editorial.secondaryText)
                        .lineLimit(1)
                }
            }

            Spacer()

            AvatarCluster(participants: participants, size: 32, maxVisible: 3)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(AppTheme.Editorial.card)
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
        .background(AppTheme.Editorial.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.Editorial.border, lineWidth: 1)
        )
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
                .foregroundStyle(AppTheme.Editorial.forest)
            Text(label)
                .font(.caption2)
                .foregroundStyle(AppTheme.Editorial.secondaryText)
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
    var updateExpenseRemotely: (ExpenseItem) async -> Void = { _ in }
    var deleteExpenseRemotely: (ExpenseItem.ID) async -> Void = { _ in }
    var addExpense: () -> Void
    var addPeople: () -> Void
    @State private var expensePendingDeletion: ExpenseItem?
    @State private var expenseBeingEdited: ExpenseItem?

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
            .tint(AppTheme.Editorial.forest)
            .disabled(!hasParticipants)

            if !hasParticipants {
                Text("Add at least one person before logging shared expenses.")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.Editorial.secondaryText)
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
                        SwipeRevealActionRow(
                            actionTitle: "Delete",
                            actionSystemImage: "trash",
                            actionAccessibilityLabel: "Delete \(expense.title)"
                        ) {
                            expensePendingDeletion = expense
                        } content: {
                            ExpenseCard(expense: expense, paidBy: viewModel.participantName(for: expense.paidBy)) {
                                expensePendingDeletion = expense
                            } editExpense: {
                                expenseBeingEdited = expense
                            }
                        }
                    }
                }
            }
        }
        .sheet(item: $expenseBeingEdited) { expense in
            AddExpenseView(
                viewModel: viewModel,
                existingExpense: expense,
                updateExpense: { updated in
                    if usesExternalPersistence {
                        await updateExpenseRemotely(updated)
                    } else {
                        viewModel.updateExpense(updated)
                    }
                },
                usesExternalPersistence: usesExternalPersistence
            )
        }
        .destructiveConfirmationOverlay(
            item: $expensePendingDeletion,
            title: "Delete this expense?",
            message: { expense in
                "This removes \(expense.title) from this trip. Shared cloud trips will remove it for everyone."
            },
            destructiveTitle: "Delete Expense"
        ) { expense in
            deleteExpense(expense)
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
    var editExpense: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            AvatarInitial(name: paidBy)

            VStack(alignment: .leading, spacing: 5) {
                Text(expense.title)
                    .font(.body.weight(.semibold))
                Text("Paid by \(paidBy) • \(expense.participants.count) people")
                    .font(.caption)
                    .foregroundStyle(AppTheme.Editorial.secondaryText)
                Text("Shared")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(AppTheme.Editorial.forest)
                    .clipShape(Capsule())
            }

            Spacer()

            Text(expense.amount.currencyText)
                .font(.headline)
                .foregroundStyle(AppTheme.Editorial.forest)
                .monospacedDigit()

            Button(action: editExpense) {
                Image(systemName: "pencil")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Edit \(expense.title)")

            Button(role: .destructive, action: deleteExpense) {
                Image(systemName: "trash")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.borderless)
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

struct BalancesTabView: View {
    @ObservedObject var viewModel: TripCalculatorViewModel
    var currentAccountID: UUID? = nil
    var saveDirectPayment: (String, Participant.ID, Participant.ID, Decimal) async -> Void = { _, _, _, _ in }
    var updateDirectPayment: (DirectPayment) async -> Void = { _ in }
    var usesExternalPersistence: Bool = false
    @State private var paymentBeingEdited: DirectPayment?
    @State private var settlementBeingPaid: QuickAddMoney.PaymentPrefill?

    var body: some View {
        VStack(spacing: 14) {
            BalanceCards(balances: viewModel.balances)
            SettlementCards(
                settlements: viewModel.settlements,
                participantCount: viewModel.calculator.participants.count,
                totalExpenses: viewModel.calculator.totalExpenses,
                onRecordSettlement: { settlement in
                    settlementBeingPaid = QuickAddMoney.paymentPrefill(
                        from: settlement.from.id,
                        to: settlement.to.id,
                        amount: settlement.amount
                    )
                }
            )

            if !viewModel.calculator.payments.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Recorded Payments")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    ForEach(viewModel.calculator.payments) { payment in
                        DirectPaymentCard(
                            payment: payment,
                            fromName: viewModel.participantName(for: payment.from),
                            toName: viewModel.participantName(for: payment.to)
                        ) {
                            paymentBeingEdited = payment
                        }
                    }
                }
            }
        }
        .sheet(item: $settlementBeingPaid) { prefill in
            AddPaymentView(
                viewModel: viewModel,
                prefill: prefill,
                saveDirectPayment: saveDirectPayment,
                usesExternalPersistence: usesExternalPersistence
            )
        }
        .sheet(item: $paymentBeingEdited) { payment in
            AddPaymentView(
                viewModel: viewModel,
                existingPayment: payment,
                updateDirectPayment: { updated in
                    if usesExternalPersistence {
                        await updateDirectPayment(updated)
                    } else {
                        viewModel.updatePayment(updated)
                    }
                },
                usesExternalPersistence: usesExternalPersistence
            )
        }
    }
}

struct DirectPaymentCard: View {
    let payment: DirectPayment
    let fromName: String
    let toName: String
    var editPayment: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.left.arrow.right")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.Editorial.forest)
                .frame(width: 34, height: 34)
                .background(AppTheme.Editorial.forest.opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 5) {
                Text(payment.title)
                    .font(.body.weight(.semibold))
                Text("\(fromName) paid \(toName)")
                    .font(.caption)
                    .foregroundStyle(AppTheme.Editorial.secondaryText)
            }

            Spacer()

            Text(payment.amount.currencyText)
                .font(.headline)
                .foregroundStyle(AppTheme.Editorial.forest)
                .monospacedDigit()

            Button(action: editPayment) {
                Image(systemName: "pencil")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Edit \(payment.title)")
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
