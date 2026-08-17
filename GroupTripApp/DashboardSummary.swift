import Foundation

/// Value-model layer that groups trips and computes safe dashboard metrics.
/// Kept free of SwiftUI so it can be unit-tested without a view.
struct DashboardSummary {
    var currentTrips: [TripPlan]
    var futureTrips: [TripPlan]
    var pastTrips: [TripPlan]
    var featuredTrips: [TripPlan]
    var attentionItems: [DashboardAttentionItem]
    var money: DashboardMoneySummary?
}

/// A single honest "needs your attention" row derived from existing trip data.
struct DashboardAttentionItem: Identifiable, Equatable {
    let id: UUID
    let tripID: UUID
    let tripName: String
    let title: String
    var dueDate: Date?
}

/// User-specific money summary. Only present when a participant ID is known.
struct DashboardMoneySummary: Equatable {
    var owedToYou: Decimal
    var youOwe: Decimal

    var net: Decimal {
        owedToYou - youOwe
    }
}

enum DashboardTripSummaryBuilder {
    static func summary(from trips: [TripPlan], currentParticipantID: Participant.ID?) -> DashboardSummary {
        let currentTrips = trips.filter { $0.status == .current }.sorted { $0.startDate < $1.startDate }
        let futureTrips = trips.filter { $0.status == .future }.sorted { $0.startDate < $1.startDate }
        let pastTrips = trips.filter { $0.status == .past }.sorted { $0.startDate > $1.startDate }

        let featuredTrips: [TripPlan]
        if let currentTrip = currentTrips.first {
            featuredTrips = [currentTrip] + futureTrips
        } else {
            featuredTrips = futureTrips
        }

        return DashboardSummary(
            currentTrips: currentTrips,
            futureTrips: futureTrips,
            pastTrips: pastTrips,
            featuredTrips: featuredTrips,
            attentionItems: attentionItems(from: trips),
            money: moneySummary(from: trips, currentParticipantID: currentParticipantID)
        )
    }

    private static func attentionItems(from trips: [TripPlan]) -> [DashboardAttentionItem] {
        Array(
            trips
                .flatMap { trip in
                    trip.planningItems
                        .filter { !$0.isDone }
                        .map { item in
                            DashboardAttentionItem(
                                id: item.id,
                                tripID: trip.id,
                                tripName: trip.viewModel.tripName,
                                title: item.title,
                                dueDate: item.date
                            )
                        }
                }
                .prefix(3)
        )
    }

    private static func moneySummary(
        from trips: [TripPlan],
        currentParticipantID: Participant.ID?
    ) -> DashboardMoneySummary? {
        guard let currentParticipantID else { return nil }

        var owedToYou: Decimal = 0
        var youOwe: Decimal = 0

        for trip in trips {
            for balance in trip.viewModel.calculator.balances() where balance.participant.id == currentParticipantID {
                if balance.net > 0 {
                    owedToYou += balance.net
                } else if balance.net < 0 {
                    youOwe += -balance.net
                }
            }
        }

        return DashboardMoneySummary(owedToYou: owedToYou, youOwe: youOwe)
    }
}
