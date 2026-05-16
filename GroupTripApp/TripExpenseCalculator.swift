import Foundation

struct Participant: Identifiable, Hashable {
    let id: UUID
    var name: String

    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }
}

struct ExpenseItem: Identifiable, Hashable {
    let id: UUID
    var title: String
    var paidBy: Participant.ID
    var amount: Decimal
    var participants: Set<Participant.ID>

    init(
        id: UUID = UUID(),
        title: String,
        paidBy: Participant.ID,
        amount: Decimal,
        participants: Set<Participant.ID>
    ) {
        self.id = id
        self.title = title
        self.paidBy = paidBy
        self.amount = amount
        self.participants = participants
    }
}

struct DirectPayment: Identifiable, Hashable {
    let id: UUID
    var title: String
    var from: Participant.ID
    var to: Participant.ID
    var amount: Decimal

    init(id: UUID = UUID(), title: String, from: Participant.ID, to: Participant.ID, amount: Decimal) {
        self.id = id
        self.title = title
        self.from = from
        self.to = to
        self.amount = amount
    }
}

struct Balance: Identifiable, Hashable {
    var id: Participant.ID { participant.id }
    var participant: Participant
    var paid: Decimal
    var share: Decimal
    var paymentsSent: Decimal
    var paymentsReceived: Decimal

    var net: Decimal {
        paid + paymentsSent - share - paymentsReceived
    }
}

struct Settlement: Identifiable, Hashable {
    let id = UUID()
    var from: Participant
    var to: Participant
    var amount: Decimal
}

struct TripExpenseCalculator {
    var participants: [Participant]
    var expenses: [ExpenseItem]
    var payments: [DirectPayment]

    var totalExpenses: Decimal {
        expenses.reduce(0) { $0 + $1.amount }
    }

    var unaccountedExpenses: Decimal {
        expenses
            .filter { $0.participants.isEmpty }
            .reduce(0) { $0 + $1.amount }
    }

    func balances() -> [Balance] {
        participants.map { participant in
            let paid = expenses
                .filter { $0.paidBy == participant.id }
                .reduce(0) { $0 + $1.amount }

            let share = expenses.reduce(Decimal(0)) { total, expense in
                guard expense.participants.contains(participant.id), !expense.participants.isEmpty else {
                    return total
                }

                return total + expense.amount / Decimal(expense.participants.count)
            }

            let sent = payments
                .filter { $0.from == participant.id }
                .reduce(0) { $0 + $1.amount }

            let received = payments
                .filter { $0.to == participant.id }
                .reduce(0) { $0 + $1.amount }

            return Balance(
                participant: participant,
                paid: paid,
                share: share,
                paymentsSent: sent,
                paymentsReceived: received
            )
        }
    }

    func settlements() -> [Settlement] {
        var creditors = balances()
            .filter { $0.net > 0 }
            .map { RunningBalance(participant: $0.participant, amount: $0.net) }
            .sorted { $0.amount > $1.amount }

        var debtors = balances()
            .filter { $0.net < 0 }
            .map { RunningBalance(participant: $0.participant, amount: -$0.net) }
            .sorted { $0.amount > $1.amount }

        var results: [Settlement] = []
        var debtorIndex = 0
        var creditorIndex = 0

        while debtorIndex < debtors.count && creditorIndex < creditors.count {
            let amount = min(debtors[debtorIndex].amount, creditors[creditorIndex].amount)

            if amount > 0 {
                results.append(
                    Settlement(
                        from: debtors[debtorIndex].participant,
                        to: creditors[creditorIndex].participant,
                        amount: amount
                    )
                )
            }

            debtors[debtorIndex].amount -= amount
            creditors[creditorIndex].amount -= amount

            if debtors[debtorIndex].amount == 0 {
                debtorIndex += 1
            }

            if creditors[creditorIndex].amount == 0 {
                creditorIndex += 1
            }
        }

        return results
    }
}

private struct RunningBalance {
    var participant: Participant
    var amount: Decimal
}

extension Decimal {
    var currencyText: String {
        let number = self as NSDecimalNumber
        return CurrencyFormatter.shared.string(from: number) ?? "$0.00"
    }
}

private enum CurrencyFormatter {
    static let shared: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter
    }()
}
