import SwiftUI

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
            VStack(alignment: .leading, spacing: 22) {
                ZStack(alignment: .topLeading) {
                    TripPhotoHero(
                        trip: trip,
                        eyebrow: trip.status == .future ? "This trip begins in" : "Trip Overview",
                        title: trip.destination,
                        metadata: "\(trip.fullDateRangeText) · \(travelerCountText)",
                        statusPill: trip.status.badgeText
                    )

                    BackButton()
                        .padding(AppTheme.Spacing.large)
                }

                if store.supportsCloudSync, store.isLoading {
                    WaniCard(padding: AppTheme.Spacing.medium, radius: AppTheme.Radius.medium) {
                        HStack(spacing: AppTheme.Spacing.small) {
                            ProgressView()
                            Text("Syncing latest trip updates…")
                                .font(.caption)
                                .foregroundStyle(AppTheme.Editorial.secondaryText)
                        }
                    }
                }

                TripSectionsGrid(
                    placesCount: trip.places.count,
                    openItineraryCount: trip.planningItems.filter { !$0.isDone }.count,
                    travelerCount: viewModel.calculator.participants.count,
                    expenseCount: viewModel.calculator.expenses.count,
                    placesDestination: AnyView(TripPlacesView(
                        places: placesBinding,
                        savePlace: { place in await store.savePlace(place, to: tripID) },
                        deletePlace: { placeID in await store.removePlace(placeID, from: tripID) },
                        updatePlace: { place in await store.updatePlace(place, in: tripID) },
                        usesExternalPersistence: store.supportsCloudSync
                    )),
                    itineraryDestination: AnyView(TripPlanningView(
                        items: planningItemsBinding,
                        saveItem: { item in await store.savePlanningItem(item, to: tripID) },
                        toggleItem: { itemID in await store.togglePlanningItemRemotely(itemID, for: tripID) },
                        updateItem: { item in await store.updatePlanningItem(item, in: tripID) },
                        deleteItem: { itemID in await store.removePlanningItem(itemID, from: tripID) },
                        usesExternalPersistence: store.supportsCloudSync
                    )),
                    peopleDestination: AnyView(PeopleFeatureView(
                        viewModel: viewModel,
                        tripID: tripID,
                        createdInvite: store.createdInvite,
                        saveParticipants: { names in await store.saveParticipants(names: names, to: tripID) },
                        updateParticipant: { participant in await store.updateParticipant(participant, in: tripID) },
                        createInvite: { Task { await store.createInvite(for: tripID) } },
                        usesExternalPersistence: store.supportsCloudSync
                    )),
                    moneyDestination: AnyView(ExpenseTrackerView(
                        tripName: viewModel.tripName,
                        destination: trip.destination,
                        viewModel: viewModel,
                        saveExpense: { title, paidBy, amount, participants in
                            await store.saveExpense(title: title, paidBy: paidBy, amount: amount, participants: participants, to: tripID)
                        },
                        updateExpense: { expense in await store.updateExpense(expense, in: tripID) },
                        deleteExpense: { expenseID in await store.removeExpense(expenseID, from: tripID) },
                        saveDirectPayment: { title, from, to, amount in
                            await store.saveDirectPayment(title: title, from: from, to: to, amount: amount, in: tripID)
                        },
                        updateDirectPayment: { payment in await store.updateDirectPayment(payment, in: tripID) },
                        saveParticipants: { names in await store.saveParticipants(names: names, to: tripID) },
                        updateParticipant: { participant in await store.updateParticipant(participant, in: tripID) },
                        usesExternalPersistence: store.supportsCloudSync
                    ))
                )

                WhosGoingCard(participants: viewModel.calculator.participants)

                ActivityEmptyStateCard()

                PlaceholderActionCard(title: "Open group chat", description: "Chat is planned for the next shared trip activity milestone.", systemImage: "message.fill", tint: AppTheme.FeatureColor.chat)

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
            }
            .padding(AppTheme.Spacing.large)
        }
        .background(AppTheme.Editorial.background)
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

    private var travelerCountText: String {
        let count = viewModel.calculator.participants.count
        return "\(count) \(count == 1 ? "traveler" : "travelers")"
    }
}

private struct TripSectionsGrid: View {
    let placesCount: Int
    let openItineraryCount: Int
    let travelerCount: Int
    let expenseCount: Int
    let placesDestination: AnyView
    let itineraryDestination: AnyView
    let peopleDestination: AnyView
    let moneyDestination: AnyView

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
            EditorialSectionHeader(title: "Trip sections", subtitle: "Tap into the room you need.")

            LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                NavigationLink(destination: placesDestination) {
                    TripSectionGridCard(
                        title: "Places",
                        subtitle: placesCount == 0 ? "Start saving ideas" : "\(placesCount) saved",
                        systemImage: "mappin.and.ellipse",
                        tint: AppTheme.FeatureColor.places,
                        showsUnreadDot: placesCount > 0
                    )
                }
                .buttonStyle(.plain)

                NavigationLink(destination: itineraryDestination) {
                    TripSectionGridCard(
                        title: "Itinerary",
                        subtitle: openItineraryCount == 0 ? "No open plans" : "\(openItineraryCount) open",
                        systemImage: "calendar",
                        tint: AppTheme.FeatureColor.itinerary,
                        showsUnreadDot: openItineraryCount > 0
                    )
                }
                .buttonStyle(.plain)

                NavigationLink(destination: peopleDestination) {
                    TripSectionGridCard(
                        title: "People",
                        subtitle: travelerCount == 0 ? "Add travelers" : "\(travelerCount) going",
                        systemImage: "person.2.fill",
                        tint: AppTheme.FeatureColor.people,
                        showsUnreadDot: travelerCount > 0
                    )
                }
                .buttonStyle(.plain)

                NavigationLink(destination: moneyDestination) {
                    TripSectionGridCard(
                        title: "Money",
                        subtitle: expenseCount == 0 ? "No expenses yet" : "\(expenseCount) logged",
                        systemImage: "receipt.fill",
                        tint: AppTheme.FeatureColor.expenses,
                        showsUnreadDot: expenseCount > 0
                    )
                }
                .buttonStyle(.plain)

                PlaceholderTripSectionGridCard(
                    title: "Memories",
                    subtitle: "Guest book later",
                    systemImage: "photo.on.rectangle",
                    tint: AppTheme.Editorial.sand
                )

                PlaceholderTripSectionGridCard(
                    title: "Chat",
                    subtitle: "Group thread later",
                    systemImage: "message.fill",
                    tint: AppTheme.FeatureColor.chat
                )
            }
        }
    }
}

private struct TripSectionGridCard: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color
    var showsUnreadDot: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
            HStack(alignment: .top) {
                WaniIconBadge(systemImage: systemImage, tint: tint, size: AppTheme.IconSize.small, cornerRadius: AppTheme.Radius.small)
                Spacer()
                if showsUnreadDot {
                    Circle()
                        .fill(AppTheme.Editorial.owed)
                        .frame(width: 7, height: 7)
                        .accessibilityHidden(true)
                }
            }

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.Editorial.primaryText)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(AppTheme.Editorial.secondaryText)
                    .lineLimit(2)
            }
        }
        .padding(13)
        .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
        .background(AppTheme.Editorial.card)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(AppTheme.Editorial.border, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct PlaceholderTripSectionGridCard: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color
    @State private var isShowingAlert = false

    var body: some View {
        Button {
            isShowingAlert = true
        } label: {
            TripSectionGridCard(title: title, subtitle: subtitle, systemImage: systemImage, tint: tint)
        }
        .buttonStyle(.plain)
        .alert("\(title) coming soon", isPresented: $isShowingAlert) {
            Button("OK", role: .cancel) { }
        }
    }
}

private struct WhosGoingCard: View {
    let participants: [Participant]

    private var previewNames: String {
        participants.prefix(4).map(\.name).joined(separator: ", ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
            EditorialSectionHeader(title: "Who’s going")

            WaniCard(padding: AppTheme.Spacing.medium, radius: AppTheme.Radius.large) {
                if participants.isEmpty {
                    Text("No travelers added yet")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Editorial.secondaryText)
                } else {
                    HStack(spacing: AppTheme.Spacing.medium) {
                        AvatarCluster(participants: participants, size: 32, maxVisible: 5)

                        VStack(alignment: .leading, spacing: 3) {
                            Text("\(participants.count) \(participants.count == 1 ? "traveler" : "travelers")")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.Editorial.primaryText)
                            Text(previewNames)
                                .font(.caption)
                                .foregroundStyle(AppTheme.Editorial.secondaryText)
                                .lineLimit(1)
                        }
                    }
                }
            }
        }
    }
}

private struct ActivityEmptyStateCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
            EditorialSectionHeader(title: "Activity")

            WaniCard(padding: AppTheme.Spacing.medium, radius: AppTheme.Radius.large) {
                HStack(alignment: .top, spacing: AppTheme.Spacing.small) {
                    WaniIconBadge(systemImage: "sparkles", tint: AppTheme.Editorial.sand, size: AppTheme.IconSize.small, cornerRadius: AppTheme.Radius.small)

                    VStack(alignment: .leading, spacing: AppTheme.Spacing.xSmall) {
                        Text("Nothing here yet")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.Editorial.primaryText)
                        Text("Trip activity will appear here after shared updates are wired in.")
                            .font(.caption)
                            .foregroundStyle(AppTheme.Editorial.secondaryText)
                    }
                }
            }
        }
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
                            .foregroundStyle(AppTheme.Editorial.secondaryText)
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
                            .foregroundStyle(AppTheme.Editorial.secondaryText)
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
                            .foregroundStyle(AppTheme.Editorial.primaryText)
                        Text(previewNames)
                            .font(.caption)
                            .foregroundStyle(AppTheme.Editorial.secondaryText)
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
                            .foregroundStyle(AppTheme.Editorial.secondaryText)
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
                            .foregroundStyle(AppTheme.Editorial.secondaryText)
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
                    .font(.system(size: 26, weight: .semibold, design: .serif))
                    .foregroundStyle(AppTheme.Editorial.primaryText)
                Text("\(expenseCount) \(expenseCount == 1 ? "expense" : "expenses") • \(settlementHint)")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Editorial.secondaryText)
                    .lineLimit(2)
            }
        }
    }
}

private struct TripGlanceCard: View {
    let openPlans: Int
    let places: Int
    let travelers: Int

    var body: some View {
        WaniCard(padding: AppTheme.Spacing.medium, radius: AppTheme.Radius.medium) {
            HStack(spacing: 0) {
                glanceStat(value: "\(openPlans)", label: "Open plans")
                glanceDivider
                glanceStat(value: "\(places)", label: "Saved places")
                glanceDivider
                glanceStat(value: "\(travelers)", label: "Travelers")
            }
        }
    }

    private func glanceStat(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 22, weight: .semibold, design: .serif))
                .foregroundStyle(AppTheme.Editorial.primaryText)
            Text(label)
                .font(.caption)
                .foregroundStyle(AppTheme.Editorial.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var glanceDivider: some View {
        Rectangle()
            .fill(AppTheme.Editorial.border)
            .frame(width: 1, height: 32)
            .padding(.horizontal, AppTheme.Spacing.small)
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
                        .foregroundStyle(AppTheme.Editorial.primaryText)
                    Spacer()
                    Text("View details")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(tint)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.Editorial.secondaryText)
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
            .foregroundStyle(AppTheme.Editorial.secondaryText)
    }
}
