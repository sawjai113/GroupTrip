import SwiftUI

struct TripSummaryView: View {
    let tripID: TripPlan.ID
    private let initialTrip: TripPlan
    @ObservedObject private var store: TripStore
    @ObservedObject private var viewModel: TripCalculatorViewModel

    init(trip: TripPlan, store: TripStore) {
        self.tripID = trip.id
        self.initialTrip = trip
        _store = ObservedObject(wrappedValue: store)
        _viewModel = ObservedObject(wrappedValue: trip.viewModel)
    }

    private var trip: TripPlan {
        store.trips.first { $0.id == tripID } ?? initialTrip
    }

    private var placesBinding: Binding<[TripPlace]> {
        Binding(
            get: { trip.places },
            set: { store.setPlaces($0, for: tripID) }
        )
    }

    private var planningItemsBinding: Binding<[TripPlanningItem]> {
        Binding(
            get: { trip.planningItems },
            set: { store.setPlanningItems($0, for: tripID) }
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .topLeading) {
                    RemoteTripImage(urlString: trip.imageURL)
                        .frame(height: 220)
                        .overlay(
                            LinearGradient(
                                colors: [.black.opacity(0.55), .clear],
                                startPoint: .top,
                                endPoint: .center
                            )
                        )

                    BackButton()
                        .padding(16)
                }

                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(viewModel.tripName)
                                    .font(.title2.weight(.semibold))
                                Text(trip.destination)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if let badgeText = trip.status.badgeText {
                                Text(badgeText)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(trip.status.tint)
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                        }

                        Text(trip.fullDateRangeText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 10) {
                            AvatarCluster(participants: viewModel.calculator.participants)
                            Text("\(viewModel.calculator.participants.count) \(viewModel.calculator.participants.count == 1 ? "traveler" : "travelers")")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Trip Overview")
                            .font(.headline)

                        Text("Tap a card to manage that part of the trip.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        NavigationLink {
                            PeopleFeatureView(viewModel: viewModel)
                        } label: {
                            PeoplePreviewCard(participants: viewModel.calculator.participants)
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            TripPlanningView(items: planningItemsBinding)
                        } label: {
                            PlanningPreviewCard(items: trip.planningItems)
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            TripPlacesView(places: placesBinding)
                        } label: {
                            PlacesPreviewCard(places: trip.places)
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            ExpenseTrackerView(tripName: viewModel.tripName, destination: trip.destination, viewModel: viewModel)
                        } label: {
                            ExpenseSnapshotCard(
                                totalExpenses: viewModel.calculator.totalExpenses,
                                expenseCount: viewModel.calculator.expenses.count,
                                settlementHint: expenseSettlementHint
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Coming Soon")
                            .font(.headline)
                        PlaceholderActionCard(title: "Trip Chat", description: "Discuss plans with your group", systemImage: "message.fill", tint: AppTheme.lightBlue)
                        PlaceholderActionCard(title: "Map View", description: "See all your saved places on a map", systemImage: "map.fill", tint: AppTheme.success)
                    }
                }
                .padding(16)
            }
        }
        .background(AppTheme.background)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var expenseSettlementHint: String {
        guard viewModel.calculator.totalExpenses > 0 else {
            return "No expenses logged yet"
        }

        if let settlement = viewModel.settlements.first {
            return "Next settle: \(settlement.from.name) pays \(settlement.to.name) \(settlement.amount.currencyText)"
        }

        return "All settled up"
    }
}

private struct PeoplePreviewCard: View {
    let participants: [Participant]

    private var previewNames: String {
        participants.prefix(3).map(\.name).joined(separator: ", ")
    }

    var body: some View {
        SummaryPreviewCard(title: "People", systemImage: "person.2.fill", tint: AppTheme.purple) {
            if participants.isEmpty {
                PreviewEmptyRow(text: "No travelers added yet")
            } else {
                HStack(spacing: 12) {
                    AvatarCluster(participants: participants, size: 34, maxVisible: 4)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(participants.count) \(participants.count == 1 ? "traveler" : "travelers")")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text(previewNames)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
        }
    }
}

private struct PlanningPreviewCard: View {
    let items: [TripPlanningItem]

    private var previewItems: [TripPlanningItem] {
        Array(items.prefix(2))
    }

    var body: some View {
        SummaryPreviewCard(title: "Planning", systemImage: "calendar", tint: AppTheme.warning) {
            if items.isEmpty {
                PreviewEmptyRow(text: "No itinerary items yet")
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(previewItems) { item in
                        HStack(spacing: 8) {
                            Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(item.isDone ? AppTheme.success : Color.secondary)
                            Text(item.title)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            Text(item.isDone ? "Done" : "To-do")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(item.isDone ? AppTheme.success : .secondary)
                        }
                    }

                    if items.count > previewItems.count {
                        Text("+\(items.count - previewItems.count) more")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

private struct PlacesPreviewCard: View {
    let places: [TripPlace]

    private var previewPlaces: [TripPlace] {
        Array(places.prefix(3))
    }

    var body: some View {
        SummaryPreviewCard(title: "Saved Places", systemImage: "mappin.and.ellipse", tint: AppTheme.error) {
            if places.isEmpty {
                PreviewEmptyRow(text: "No saved places yet")
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(previewPlaces) { place in
                        HStack(spacing: 8) {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundStyle(AppTheme.error)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(place.name)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                if !place.category.isEmpty {
                                    Text(place.category)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            Spacer(minLength: 0)
                        }
                    }

                    if places.count > previewPlaces.count {
                        Text("+\(places.count - previewPlaces.count) more")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

private struct ExpenseSnapshotCard: View {
    let totalExpenses: Decimal
    let expenseCount: Int
    let settlementHint: String

    var body: some View {
        SummaryPreviewCard(title: "Expense Snapshot", systemImage: "receipt.fill", tint: AppTheme.primary) {
            VStack(alignment: .leading, spacing: 6) {
                Text(totalExpenses.currencyText)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                Text("\(expenseCount) \(expenseCount == 1 ? "expense" : "expenses") • \(settlementHint)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }
}

private struct SummaryPreviewCard<Content: View>: View {
    let title: String
    let systemImage: String
    let tint: Color
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .foregroundStyle(tint)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
                Text("View details")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tint)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }

            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.paper)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct PreviewEmptyRow: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }
}
