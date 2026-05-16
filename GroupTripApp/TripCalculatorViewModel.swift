import Foundation
import Combine

final class TripCalculatorViewModel: ObservableObject {
    @Published var tripName: String
    @Published var calculator: TripExpenseCalculator

    init(tripName: String, calculator: TripExpenseCalculator) {
        self.tripName = tripName
        self.calculator = calculator
    }

    var balances: [Balance] {
        calculator.balances().sorted { $0.participant.name < $1.participant.name }
    }

    var settlements: [Settlement] {
        calculator.settlements()
    }

    func participantName(for id: Participant.ID) -> String {
        calculator.participants.first { $0.id == id }?.name ?? "Unknown"
    }

    func addParticipant(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        calculator.participants.append(Participant(name: trimmed))
    }

    func addParticipants(names: [String]) {
        for name in names {
            addParticipant(name: name)
        }
    }

    func deleteParticipants(at offsets: IndexSet) {
        let sortedParticipants = calculator.participants.sorted { $0.name < $1.name }
        let removedIDs = Set(offsets.map { sortedParticipants[$0].id })

        calculator.participants.removeAll { removedIDs.contains($0.id) }
        calculator.expenses.removeAll { removedIDs.contains($0.paidBy) }
        calculator.payments.removeAll { removedIDs.contains($0.from) || removedIDs.contains($0.to) }
        calculator.expenses = calculator.expenses.map { expense in
            var updated = expense
            updated.participants.subtract(removedIDs)
            return updated
        }
    }

    func addExpense(title: String, paidBy: Participant.ID, amount: Decimal, participants: Set<Participant.ID>) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, amount > 0 else { return }

        calculator.expenses.insert(
            ExpenseItem(title: trimmed, paidBy: paidBy, amount: amount, participants: participants),
            at: 0
        )
    }

    func deleteExpenses(at offsets: IndexSet) {
        for offset in offsets.sorted(by: >) {
            calculator.expenses.remove(at: offset)
        }
    }

    func addPayment(title: String, from: Participant.ID, to: Participant.ID, amount: Decimal) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, from != to, amount > 0 else { return }

        calculator.payments.insert(
            DirectPayment(title: trimmed, from: from, to: to, amount: amount),
            at: 0
        )
    }

    func deletePayments(at offsets: IndexSet) {
        for offset in offsets.sorted(by: >) {
            calculator.payments.remove(at: offset)
        }
    }
}

extension TripCalculatorViewModel {
    static func empty(named name: String) -> TripCalculatorViewModel {
        TripCalculatorViewModel(
            tripName: name,
            calculator: TripExpenseCalculator(participants: [], expenses: [], payments: [])
        )
    }

    static let sample: TripCalculatorViewModel = {
        let alex = Participant(name: "Alex")
        let sam = Participant(name: "Sam")
        let taylor = Participant(name: "Taylor")
        let jordan = Participant(name: "Jordan")
        let people = [alex, sam, taylor, jordan]
        let everyone = Set(people.map(\.id))

        return TripCalculatorViewModel(
            tripName: "Austin Weekend",
            calculator: TripExpenseCalculator(
                participants: people,
                expenses: [
                    ExpenseItem(title: "Rental house", paidBy: alex.id, amount: 840, participants: everyone),
                    ExpenseItem(title: "Groceries", paidBy: sam.id, amount: 216.48, participants: everyone),
                    ExpenseItem(title: "Museum tickets", paidBy: taylor.id, amount: 96, participants: [alex.id, taylor.id, jordan.id]),
                    ExpenseItem(title: "Late night tacos", paidBy: jordan.id, amount: 58.25, participants: [sam.id, jordan.id])
                ],
                payments: [
                    DirectPayment(title: "Sam paid Alex", from: sam.id, to: alex.id, amount: 100)
                ]
            )
        )
    }()
}
