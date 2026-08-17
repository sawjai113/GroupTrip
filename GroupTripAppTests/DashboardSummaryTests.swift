import XCTest
@testable import GroupTripApp

final class DashboardSummaryTests: XCTestCase {
    // MARK: - Trip grouping

    func testCurrentTripsSortedAscendingByStartDate() {
        let earlier = makeTrip(id: "D001", name: "Earlier Current", startDay: -2, endDay: 1)
        let later = makeTrip(id: "D002", name: "Later Current", startDay: -1, endDay: 2)

        let summary = DashboardTripSummaryBuilder.summary(from: [later, earlier], currentParticipantID: nil)

        XCTAssertEqual(summary.currentTrips.map(\.id), [earlier.id, later.id])
    }

    func testFutureTripsSortedAscendingByStartDate() {
        let sooner = makeTrip(id: "D003", name: "Sooner Future", startDay: 5, endDay: 7)
        let later = makeTrip(id: "D004", name: "Later Future", startDay: 10, endDay: 12)

        let summary = DashboardTripSummaryBuilder.summary(from: [later, sooner], currentParticipantID: nil)

        XCTAssertEqual(summary.futureTrips.map(\.id), [sooner.id, later.id])
    }

    func testPastTripsSortedDescendingByStartDate() {
        let older = makeTrip(id: "D005", name: "Older Past", startDay: -30, endDay: -28)
        let newer = makeTrip(id: "D006", name: "Newer Past", startDay: -20, endDay: -18)

        let summary = DashboardTripSummaryBuilder.summary(from: [older, newer], currentParticipantID: nil)

        XCTAssertEqual(summary.pastTrips.map(\.id), [newer.id, older.id])
    }

    func testFeaturedTripIsFirstCurrentTripWhenOneExists() {
        let past = makeTrip(id: "D007", name: "Past", startDay: -30, endDay: -28)
        let laterCurrent = makeTrip(id: "D008", name: "Later Current", startDay: -1, endDay: 1)
        let earlierCurrent = makeTrip(id: "D009", name: "Earlier Current", startDay: -2, endDay: 0)
        let future = makeTrip(id: "D00A", name: "Future", startDay: 10, endDay: 12)

        let summary = DashboardTripSummaryBuilder.summary(
            from: [past, laterCurrent, earlierCurrent, future],
            currentParticipantID: nil
        )

        XCTAssertEqual(summary.featuredTrips.first?.id, earlierCurrent.id)
    }

    func testFeaturedTripFallsBackToFirstFutureTripWithoutCurrentTrip() {
        let past = makeTrip(id: "D00B", name: "Past", startDay: -30, endDay: -28)
        let laterFuture = makeTrip(id: "D00C", name: "Later Future", startDay: 10, endDay: 12)
        let soonerFuture = makeTrip(id: "D00D", name: "Sooner Future", startDay: 5, endDay: 7)

        let summary = DashboardTripSummaryBuilder.summary(
            from: [past, laterFuture, soonerFuture],
            currentParticipantID: nil
        )

        XCTAssertEqual(summary.featuredTrips.first?.id, soonerFuture.id)
    }

    // MARK: - Attention derivation

    func testIncompletePlanningItemsBecomeAttentionItems() {
        let itemA = TripPlanningItem(title: "Book flights", isDone: false)
        let itemB = TripPlanningItem(title: "Book hotel", isDone: true)
        let itemC = TripPlanningItem(title: "Get visas", isDone: false)
        let trip = makeTrip(id: "D00E", name: "Kyoto", startDay: 5, endDay: 12, planningItems: [itemA, itemB, itemC])

        let summary = DashboardTripSummaryBuilder.summary(from: [trip], currentParticipantID: nil)

        XCTAssertEqual(summary.attentionItems.count, 2)
        XCTAssertEqual(summary.attentionItems.map(\.title), ["Book flights", "Get visas"])
        XCTAssertEqual(summary.attentionItems.map(\.tripID), [trip.id, trip.id])
    }

    func testCompletedPlanningItemsDoNotBecomeAttentionItems() {
        let trip = makeTrip(
            id: "D00F",
            name: "Kyoto",
            startDay: 5,
            endDay: 12,
            planningItems: [
                TripPlanningItem(title: "Book hotel", isDone: true),
                TripPlanningItem(title: "Pack bags", isDone: true)
            ]
        )

        let summary = DashboardTripSummaryBuilder.summary(from: [trip], currentParticipantID: nil)

        XCTAssertTrue(summary.attentionItems.isEmpty)
    }

    func testAttentionListIsCappedToThreeRows() {
        let firstTrip = makeTrip(
            id: "D010",
            name: "Kyoto",
            startDay: 5,
            endDay: 12,
            planningItems: [
                TripPlanningItem(title: "Item 1", isDone: false),
                TripPlanningItem(title: "Item 2", isDone: false)
            ]
        )
        let secondTrip = makeTrip(
            id: "D011",
            name: "Austin",
            startDay: 20,
            endDay: 22,
            planningItems: [
                TripPlanningItem(title: "Item 3", isDone: false),
                TripPlanningItem(title: "Item 4", isDone: false)
            ]
        )

        let summary = DashboardTripSummaryBuilder.summary(
            from: [firstTrip, secondTrip],
            currentParticipantID: nil
        )

        XCTAssertEqual(summary.attentionItems.count, 3)
        XCTAssertEqual(summary.attentionItems.map(\.title), ["Item 1", "Item 2", "Item 3"])
    }

    // MARK: - Money summary

    func testPositiveBalanceContributesToOwedToYou() {
        let me = Participant(id: UUID(uuidString: "00000000-0000-0000-0000-00000000F101")!, name: "Me")
        let friend = Participant(id: UUID(uuidString: "00000000-0000-0000-0000-00000000F102")!, name: "Friend")
        let expense = ExpenseItem(title: "Hotel", paidBy: me.id, amount: 100, participants: [me.id, friend.id])
        let trip = makeTrip(
            id: "D012",
            name: "Austin",
            startDay: 5,
            endDay: 7,
            participants: [me, friend],
            expenses: [expense]
        )

        let summary = DashboardTripSummaryBuilder.summary(from: [trip], currentParticipantID: me.id)

        XCTAssertEqual(summary.money?.owedToYou, Decimal(50))
        XCTAssertEqual(summary.money?.youOwe, Decimal(0))
    }

    func testNegativeBalanceContributesToYouOwe() {
        let me = Participant(id: UUID(uuidString: "00000000-0000-0000-0000-00000000F103")!, name: "Me")
        let friend = Participant(id: UUID(uuidString: "00000000-0000-0000-0000-00000000F104")!, name: "Friend")
        let expense = ExpenseItem(title: "Hotel", paidBy: friend.id, amount: 100, participants: [me.id, friend.id])
        let trip = makeTrip(
            id: "D013",
            name: "Austin",
            startDay: 5,
            endDay: 7,
            participants: [me, friend],
            expenses: [expense]
        )

        let summary = DashboardTripSummaryBuilder.summary(from: [trip], currentParticipantID: me.id)

        XCTAssertEqual(summary.money?.owedToYou, Decimal(0))
        XCTAssertEqual(summary.money?.youOwe, Decimal(50))
    }

    func testMoneySummaryUnavailableWithoutParticipantID() {
        let me = Participant(id: UUID(uuidString: "00000000-0000-0000-0000-00000000F105")!, name: "Me")
        let friend = Participant(id: UUID(uuidString: "00000000-0000-0000-0000-00000000F106")!, name: "Friend")
        let expense = ExpenseItem(title: "Hotel", paidBy: me.id, amount: 100, participants: [me.id, friend.id])
        let trip = makeTrip(
            id: "D014",
            name: "Austin",
            startDay: 5,
            endDay: 7,
            participants: [me, friend],
            expenses: [expense]
        )

        let summary = DashboardTripSummaryBuilder.summary(from: [trip], currentParticipantID: nil)

        XCTAssertNil(summary.money)
    }

    func testMoneySummaryAggregatesBalancesAcrossTripsForMultipleParticipantIDs() {
        let accountID = UUID(uuidString: "00000000-0000-0000-0000-00000000F301")!
        let me = Participant(id: UUID(uuidString: "00000000-0000-0000-0000-00000000F201")!, name: "Me", accountID: accountID)
        let friend = Participant(id: UUID(uuidString: "00000000-0000-0000-0000-00000000F202")!, name: "Friend")
        let firstTrip = makeTrip(
            id: "D018",
            name: "Austin",
            startDay: 5,
            endDay: 7,
            participants: [me, friend],
            expenses: [ExpenseItem(title: "Hotel", paidBy: me.id, amount: 100, participants: [me.id, friend.id])]
        )

        let otherMe = Participant(id: UUID(uuidString: "00000000-0000-0000-0000-00000000F203")!, name: "Me Two", accountID: accountID)
        let otherFriend = Participant(id: UUID(uuidString: "00000000-0000-0000-0000-00000000F204")!, name: "Friend Two")
        let secondTrip = makeTrip(
            id: "D019",
            name: "Kyoto",
            startDay: 10,
            endDay: 12,
            participants: [otherMe, otherFriend],
            expenses: [ExpenseItem(title: "Dinner", paidBy: otherFriend.id, amount: 80, participants: [otherMe.id, otherFriend.id])]
        )

        let summary = DashboardTripSummaryBuilder.summary(
            from: [firstTrip, secondTrip],
            currentParticipantIDs: Set([me.id, otherMe.id])
        )

        XCTAssertEqual(summary.money?.owedToYou, Decimal(50))
        XCTAssertEqual(summary.money?.youOwe, Decimal(40))
    }

    func testMoneySummaryNilForNilParticipantIDSet() {
        let me = Participant(id: UUID(uuidString: "00000000-0000-0000-0000-00000000F205")!, name: "Me")
        let friend = Participant(id: UUID(uuidString: "00000000-0000-0000-0000-00000000F206")!, name: "Friend")
        let expense = ExpenseItem(title: "Hotel", paidBy: me.id, amount: 100, participants: [me.id, friend.id])
        let trip = makeTrip(
            id: "D01A",
            name: "Austin",
            startDay: 5,
            endDay: 7,
            participants: [me, friend],
            expenses: [expense]
        )

        let summary = DashboardTripSummaryBuilder.summary(from: [trip], currentParticipantIDs: nil)

        XCTAssertNil(summary.money)
    }

    func testMoneySummaryNilForEmptyParticipantIDSet() {
        let me = Participant(id: UUID(uuidString: "00000000-0000-0000-0000-00000000F207")!, name: "Me")
        let friend = Participant(id: UUID(uuidString: "00000000-0000-0000-0000-00000000F208")!, name: "Friend")
        let expense = ExpenseItem(title: "Hotel", paidBy: me.id, amount: 100, participants: [me.id, friend.id])
        let trip = makeTrip(
            id: "D01B",
            name: "Austin",
            startDay: 5,
            endDay: 7,
            participants: [me, friend],
            expenses: [expense]
        )

        let summary = DashboardTripSummaryBuilder.summary(from: [trip], currentParticipantIDs: Set<Participant.ID>())

        XCTAssertNil(summary.money)
    }

    // MARK: - TripStore exposure

    func testStoreDashboardSummaryMatchesSummaryBuilder() {
        let me = Participant(id: UUID(uuidString: "00000000-0000-0000-0000-00000000F107")!, name: "Me")
        let friend = Participant(id: UUID(uuidString: "00000000-0000-0000-0000-00000000F108")!, name: "Friend")
        let expense = ExpenseItem(title: "Hotel", paidBy: me.id, amount: 100, participants: [me.id, friend.id])
        let current = makeTrip(
            id: "D015",
            name: "Current Trip",
            startDay: -1,
            endDay: 1,
            planningItems: [TripPlanningItem(title: "Pack bags", isDone: false)],
            participants: [me, friend],
            expenses: [expense]
        )
        let future = makeTrip(id: "D016", name: "Future Trip", startDay: 10, endDay: 12)
        let past = makeTrip(id: "D017", name: "Past Trip", startDay: -30, endDay: -28)
        let store = TripStore(trips: [future, past, current])

        let direct = DashboardTripSummaryBuilder.summary(from: store.trips, currentParticipantID: me.id)
        let viaStore = store.dashboardSummary(currentParticipantID: me.id)

        XCTAssertEqual(viaStore.currentTrips.map(\.id), direct.currentTrips.map(\.id))
        XCTAssertEqual(viaStore.futureTrips.map(\.id), direct.futureTrips.map(\.id))
        XCTAssertEqual(viaStore.pastTrips.map(\.id), direct.pastTrips.map(\.id))
        XCTAssertEqual(viaStore.featuredTrips.map(\.id), direct.featuredTrips.map(\.id))
        XCTAssertEqual(viaStore.attentionItems, direct.attentionItems)
        XCTAssertEqual(viaStore.money, direct.money)
    }

    func testStoreDashboardSummaryResolvesMoneyByAccountIDAcrossTrips() {
        let accountID = UUID(uuidString: "00000000-0000-0000-0000-00000000F302")!
        let me = Participant(id: UUID(uuidString: "00000000-0000-0000-0000-00000000F209")!, name: "Me", accountID: accountID)
        let friend = Participant(id: UUID(uuidString: "00000000-0000-0000-0000-00000000F20A")!, name: "Friend")
        let firstTrip = makeTrip(
            id: "D01C",
            name: "Austin",
            startDay: 5,
            endDay: 7,
            participants: [me, friend],
            expenses: [ExpenseItem(title: "Hotel", paidBy: me.id, amount: 100, participants: [me.id, friend.id])]
        )

        let otherMe = Participant(id: UUID(uuidString: "00000000-0000-0000-0000-00000000F20B")!, name: "Me Two", accountID: accountID)
        let otherFriend = Participant(id: UUID(uuidString: "00000000-0000-0000-0000-00000000F20C")!, name: "Friend Two")
        let secondTrip = makeTrip(
            id: "D01D",
            name: "Kyoto",
            startDay: 10,
            endDay: 12,
            participants: [otherMe, otherFriend],
            expenses: [ExpenseItem(title: "Dinner", paidBy: otherFriend.id, amount: 80, participants: [otherMe.id, otherFriend.id])]
        )

        let store = TripStore(trips: [firstTrip, secondTrip])

        let summary = store.dashboardSummary(currentAccountID: accountID)

        XCTAssertEqual(summary.money?.owedToYou, Decimal(50))
        XCTAssertEqual(summary.money?.youOwe, Decimal(40))
    }

    func testStoreDashboardSummaryKeepsMoneyNilWhenAccountIDIsNilOrUnmapped() {
        let accountID = UUID(uuidString: "00000000-0000-0000-0000-00000000F303")!
        let me = Participant(id: UUID(uuidString: "00000000-0000-0000-0000-00000000F20D")!, name: "Me", accountID: accountID)
        let friend = Participant(id: UUID(uuidString: "00000000-0000-0000-0000-00000000F20E")!, name: "Friend")
        let expense = ExpenseItem(title: "Hotel", paidBy: me.id, amount: 100, participants: [me.id, friend.id])
        let trip = makeTrip(
            id: "D01E",
            name: "Austin",
            startDay: 5,
            endDay: 7,
            participants: [me, friend],
            expenses: [expense]
        )
        let store = TripStore(trips: [trip])

        let nilAccountSummary = store.dashboardSummary(currentAccountID: nil)
        let unmappedAccountSummary = store.dashboardSummary(
            currentAccountID: UUID(uuidString: "00000000-0000-0000-0000-00000000F304")!
        )

        XCTAssertNil(nilAccountSummary.money)
        XCTAssertNil(unmappedAccountSummary.money)
    }

    // MARK: - Helpers

    private func daysFromNow(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: Date())!
    }

    private func makeTrip(
        id: String,
        name: String,
        startDay: Int,
        endDay: Int,
        planningItems: [TripPlanningItem] = [],
        participants: [Participant] = [],
        expenses: [ExpenseItem] = [],
        payments: [DirectPayment] = []
    ) -> TripPlan {
        TripPlan(
            id: UUID(uuidString: "00000000-0000-0000-0000-00000000\(id)")!,
            destination: "Austin",
            emoji: "🤠",
            imageURL: "https://example.com/austin.jpg",
            startDate: daysFromNow(startDay),
            endDate: daysFromNow(endDay),
            viewModel: TripCalculatorViewModel(
                tripName: name,
                calculator: TripExpenseCalculator(
                    participants: participants,
                    expenses: expenses,
                    payments: payments
                )
            ),
            planningItems: planningItems
        )
    }
}
