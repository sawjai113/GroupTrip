import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct TripSummaryView: View {
    @Environment(\.dismiss) private var dismiss
    let tripID: TripPlan.ID
    private let initialTrip: TripPlan
    @ObservedObject private var store: TripStore
    @ObservedObject private var viewModel: TripCalculatorViewModel
    @State private var isShowingLeaveTripConfirmation = false
    @State private var isLeavingTrip = false
    @State private var isShowingArchiveTripConfirmation = false
    @State private var isArchivingTrip = false

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
                        .padding(AppTheme.Spacing.large)
                }

                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: AppTheme.Spacing.xSmall) {
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
                                    .padding(.horizontal, AppTheme.Spacing.medium)
                                    .padding(.vertical, AppTheme.Spacing.xSmall + 2)
                                    .background(trip.status.tint)
                                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.small, style: .continuous))
                            }
                        }

                        Text(trip.fullDateRangeText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        if store.supportsCloudSync, store.isLoading {
                            WaniCard(padding: AppTheme.Spacing.medium, radius: AppTheme.Radius.medium) {
                                HStack(spacing: AppTheme.Spacing.small) {
                                    ProgressView()
                                    Text("Syncing latest trip updates…")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        if store.supportsCloudSync {
                            InvitePeopleCard(tripID: tripID, createdInvite: store.createdInvite) {
                                Task { await store.createInvite(for: tripID) }
                            }
                        }

                    }

                    VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                        Text("Trip Overview")
                            .font(.headline)

                        Text("Tap a card to manage that part of the trip.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        NavigationLink {
                            PeopleFeatureView(
                                viewModel: viewModel,
                                saveParticipants: { names in
                                    await store.saveParticipants(names: names, to: tripID)
                                },
                                usesExternalPersistence: store.supportsCloudSync
                            )
                        } label: {
                            PeoplePreviewCard(participants: viewModel.calculator.participants)
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            TripPlanningView(
                                items: planningItemsBinding,
                                saveItem: { item in
                                    await store.savePlanningItem(item, to: tripID)
                                },
                                toggleItem: { itemID in
                                    await store.togglePlanningItemRemotely(itemID, for: tripID)
                                },
                                updateItem: { item in
                                    await store.updatePlanningItem(item, in: tripID)
                                },
                                deleteItem: { itemID in
                                    await store.removePlanningItem(itemID, from: tripID)
                                },
                                usesExternalPersistence: store.supportsCloudSync
                            )
                        } label: {
                            PlanningPreviewCard(items: trip.planningItems)
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            TripPlacesView(
                                places: placesBinding,
                                savePlace: { place in
                                    await store.savePlace(place, to: tripID)
                                },
                                deletePlace: { placeID in
                                    await store.removePlace(placeID, from: tripID)
                                },
                                updatePlace: { place in
                                    await store.updatePlace(place, in: tripID)
                                },
                                usesExternalPersistence: store.supportsCloudSync
                            )
                        } label: {
                            PlacesPreviewCard(places: trip.places)
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            ExpenseTrackerView(
                                tripName: viewModel.tripName,
                                destination: trip.destination,
                                viewModel: viewModel,
                                saveExpense: { title, paidBy, amount, participants in
                                    await store.saveExpense(title: title, paidBy: paidBy, amount: amount, participants: participants, to: tripID)
                                },
                                deleteExpense: { expenseID in
                                    await store.removeExpense(expenseID, from: tripID)
                                },
                                saveDirectPayment: { title, from, to, amount in
                                    await store.saveDirectPayment(title: title, from: from, to: to, amount: amount, in: tripID)
                                },
                                saveParticipants: { names in
                                    await store.saveParticipants(names: names, to: tripID)
                                },
                                usesExternalPersistence: store.supportsCloudSync
                            )
                        } label: {
                            ExpenseSnapshotCard(
                                totalExpenses: viewModel.calculator.totalExpenses,
                                expenseCount: viewModel.calculator.expenses.count,
                                settlementHint: expenseSettlementHint
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    if store.supportsCloudSync {
                        VStack(spacing: AppTheme.Spacing.medium) {
                            ArchiveTripCard(isArchiving: isArchivingTrip) {
                                isShowingArchiveTripConfirmation = true
                            }

                            LeaveTripCard(isLeaving: isLeavingTrip) {
                                isShowingLeaveTripConfirmation = true
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                        Text("Coming Soon")
                            .font(.headline)
                        PlaceholderActionCard(title: "Trip Chat", description: "Discuss plans with your group", systemImage: "message.fill", tint: AppTheme.FeatureColor.chat)
                        PlaceholderActionCard(title: "Map View", description: "See all your saved places on a map", systemImage: "map.fill", tint: AppTheme.FeatureColor.map)
                    }
                }
                .padding(AppTheme.Spacing.large)
            }
        }
        .background(AppTheme.background)
        .toolbar(.hidden, for: .navigationBar)
        .confirmationDialog(
            "Leave this trip?",
            isPresented: $isShowingLeaveTripConfirmation,
            titleVisibility: .visible
        ) {
            Button("Leave Trip", role: .destructive) {
                Task { await leaveTrip() }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This removes the trip from your account only. Other collaborators keep access, and shared trip data is not deleted.")
        }
        .confirmationDialog(
            "Archive this trip?",
            isPresented: $isShowingArchiveTripConfirmation,
            titleVisibility: .visible
        ) {
            Button("Archive Trip", role: .destructive) {
                Task { await archiveTrip() }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Trip owners can archive a shared trip for everyone. This hides it from active trip lists without deleting expenses, people, places, or planning items.")
        }
    }

    @MainActor
    private func leaveTrip() async {
        isLeavingTrip = true
        await store.leaveTrip(tripID)
        isLeavingTrip = false

        if !store.trips.contains(where: { $0.id == tripID }) {
            dismiss()
        }
    }

    @MainActor
    private func archiveTrip() async {
        isArchivingTrip = true
        await store.archiveTrip(tripID)
        isArchivingTrip = false

        if !store.trips.contains(where: { $0.id == tripID }) {
            dismiss()
        }
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

private struct ArchiveTripCard: View {
    var isArchiving: Bool
    var archiveTrip: () -> Void

    var body: some View {
        WaniCard(padding: AppTheme.Spacing.medium, radius: AppTheme.Radius.medium) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                HStack(alignment: .top, spacing: AppTheme.Spacing.small) {
                    WaniIconBadge(systemImage: "archivebox", tint: AppTheme.warning, size: AppTheme.IconSize.medium)

                    VStack(alignment: .leading, spacing: AppTheme.Spacing.xSmall) {
                        Text("Archive Trip")
                            .font(.subheadline.weight(.semibold))
                        Text("Owners can hide this shared trip from active lists without deleting trip data.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }

                Button(role: .destructive, action: archiveTrip) {
                    if isArchiving {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Label("Archive Trip", systemImage: "archivebox")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.bordered)
                .disabled(isArchiving)
            }
        }
    }
}

private struct LeaveTripCard: View {
    var isLeaving: Bool
    var leaveTrip: () -> Void

    var body: some View {
        WaniCard(padding: AppTheme.Spacing.medium, radius: AppTheme.Radius.medium) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                HStack(alignment: .top, spacing: AppTheme.Spacing.small) {
                    WaniIconBadge(systemImage: "rectangle.portrait.and.arrow.right", tint: AppTheme.error, size: AppTheme.IconSize.medium)

                    VStack(alignment: .leading, spacing: AppTheme.Spacing.xSmall) {
                        Text("Leave Trip")
                            .font(.subheadline.weight(.semibold))
                        Text("Remove this trip from your account without deleting it for anyone else.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }

                Button(role: .destructive, action: leaveTrip) {
                    if isLeaving {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Label("Leave Trip", systemImage: "rectangle.portrait.and.arrow.right")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.bordered)
                .disabled(isLeaving)
            }
        }
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
        WaniCard(padding: AppTheme.Spacing.medium, radius: AppTheme.Radius.medium) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                HStack(spacing: AppTheme.Spacing.small) {
                    WaniIconBadge(systemImage: "person.badge.plus", tint: AppTheme.success, size: AppTheme.IconSize.medium)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Invite People")
                            .font(.subheadline.weight(.semibold))
                        Text("Create a code friends can use to join this trip.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
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
                        .tint(didCopyInviteCode ? AppTheme.success : AppTheme.primary)
                        .accessibilityLabel(didCopyInviteCode ? "Invite code copied" : "Copy invite code")
                    }
                }

                Button(inviteForTrip == nil ? "Create Invite Code" : "Create Another Code", action: createInvite)
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.success)
            }
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

private struct PeoplePreviewCard: View {
    let participants: [Participant]

    private var previewNames: String {
        participants.prefix(3).map(\.name).joined(separator: ", ")
    }

    var body: some View {
        SummaryPreviewCard(title: "People", systemImage: "person.2.fill", tint: AppTheme.FeatureColor.people) {
            if participants.isEmpty {
                PreviewEmptyRow(text: "No travelers added yet")
            } else {
                HStack(spacing: AppTheme.Spacing.medium) {
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
        SummaryPreviewCard(title: "Planning", systemImage: "calendar", tint: AppTheme.FeatureColor.itinerary) {
            if items.isEmpty {
                PreviewEmptyRow(text: "No itinerary items yet")
            } else {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                    ForEach(previewItems) { item in
                        WaniPreviewRow(
                            icon: item.isDone ? "checkmark.circle.fill" : "circle",
                            title: item.title,
                            status: item.isDone ? "Done" : "To-do",
                            tint: item.isDone ? AppTheme.success : AppTheme.FeatureColor.itinerary
                        )
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
        SummaryPreviewCard(title: "Saved Places", systemImage: "mappin.and.ellipse", tint: AppTheme.FeatureColor.places) {
            if places.isEmpty {
                PreviewEmptyRow(text: "No saved places yet")
            } else {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                    ForEach(previewPlaces) { place in
                        WaniPreviewRow(
                            icon: "mappin.circle.fill",
                            title: place.name,
                            subtitle: place.category.isEmpty ? nil : place.category,
                            tint: AppTheme.FeatureColor.places
                        )
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
        SummaryPreviewCard(title: "Expense Snapshot", systemImage: "receipt.fill", tint: AppTheme.FeatureColor.expenses) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xSmall + 2) {
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
        WaniCard {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                HStack(spacing: AppTheme.Spacing.small) {
                    WaniIconBadge(systemImage: systemImage, tint: tint, size: AppTheme.IconSize.small, cornerRadius: AppTheme.Radius.small)
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
        }
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
