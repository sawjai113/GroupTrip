import XCTest
@testable import GroupTripApp

final class TripExpenseCalculatorTests: XCTestCase {
    func testBalancesSplitExpensesAcrossSelectedParticipants() {
        let alex = Participant(name: "Alex")
        let sam = Participant(name: "Sam")
        let jordan = Participant(name: "Jordan")

        let calculator = TripExpenseCalculator(
            participants: [alex, sam, jordan],
            expenses: [
                ExpenseItem(
                    title: "House",
                    paidBy: alex.id,
                    amount: 300,
                    participants: [alex.id, sam.id, jordan.id]
                ),
                ExpenseItem(
                    title: "Dinner",
                    paidBy: sam.id,
                    amount: 90,
                    participants: [sam.id, jordan.id]
                )
            ],
            payments: []
        )

        let balances = Dictionary(uniqueKeysWithValues: calculator.balances().map { ($0.participant.name, $0.net) })

        XCTAssertEqual(balances["Alex"], 200)
        XCTAssertEqual(balances["Sam"], -55)
        XCTAssertEqual(balances["Jordan"], -145)
    }

    func testPaymentsReduceOutstandingBalances() {
        let alex = Participant(name: "Alex")
        let sam = Participant(name: "Sam")

        let calculator = TripExpenseCalculator(
            participants: [alex, sam],
            expenses: [
                ExpenseItem(title: "Hotel", paidBy: alex.id, amount: 200, participants: [alex.id, sam.id])
            ],
            payments: [
                DirectPayment(title: "Partial payback", from: sam.id, to: alex.id, amount: 25)
            ]
        )

        let balances = Dictionary(uniqueKeysWithValues: calculator.balances().map { ($0.participant.name, $0.net) })

        XCTAssertEqual(balances["Alex"], 75)
        XCTAssertEqual(balances["Sam"], -75)
    }

    func testSettlementsSuggestMinimalPayments() {
        let alex = Participant(name: "Alex")
        let sam = Participant(name: "Sam")
        let jordan = Participant(name: "Jordan")

        let calculator = TripExpenseCalculator(
            participants: [alex, sam, jordan],
            expenses: [
                ExpenseItem(title: "House", paidBy: alex.id, amount: 300, participants: [alex.id, sam.id, jordan.id])
            ],
            payments: []
        )

        let settlements = calculator.settlements()

        XCTAssertEqual(settlements.count, 2)
        XCTAssertTrue(settlements.allSatisfy { $0.to == alex })
        XCTAssertEqual(settlements.reduce(0) { $0 + $1.amount }, 200)
    }
}
