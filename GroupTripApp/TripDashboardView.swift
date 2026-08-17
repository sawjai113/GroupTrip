import SwiftUI

struct TripDashboardView: View {
    enum ModeBadge {
        case demo
        case cloud

        var title: String {
            switch self {
            case .demo: return "Demo Mode"
            case .cloud: return "Signed-in Mode"
            }
        }

        var subtitle: String {
            switch self {
            case .demo: return "Sample data only"
            case .cloud: return "Cloud-backed trips"
            }
        }

        var tint: Color {
            switch self {
            case .demo: return AppTheme.warning
            case .cloud: return AppTheme.success
            }
        }
    }

    @StateObject var store: TripStore
    @State private var isShowingNewTrip = false
    @State private var isShowingJoinInvite = false
    @State private var isShowingSignOutConfirmation = false
    @State private var isShowingAllTrips = false
    @State private var isShowingNoFocusedTrip = false
    var modeBadge: ModeBadge?
    var appearance: Binding<AppAppearance> = .constant(.auto)
    var signOut: (() -> Void)?

    var body: some View {
        let summary = store.dashboardSummary(currentParticipantID: nil)
        let bottomNavTrip = summary.currentTrips.first ?? summary.futureTrips.first
        let bottomNavTripIsNext = summary.currentTrips.isEmpty && !summary.futureTrips.isEmpty

        NavigationStack {
            VStack(spacing: 0) {
                WaniHeader(
                    modeBadge: modeBadge,
                    appearance: appearance,
                    signOut: signOut == nil ? nil : { isShowingSignOutConfirmation = true },
                    joinTrip: modeBadge == .cloud ? { isShowingJoinInvite = true } : nil
                ) {
                    isShowingNewTrip = true
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        if store.isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 64)
                        } else if store.trips.isEmpty {
                            EmptyTripsView(
                                joinTrip: modeBadge == .cloud ? { isShowingJoinInvite = true } : nil
                            ) {
                                isShowingNewTrip = true
                            }
                        } else {
                            if !summary.featuredTrips.isEmpty {
                                FeaturedTripsCarousel(trips: summary.featuredTrips, store: store)
                            }

                            if !summary.attentionItems.isEmpty {
                                NeedsYourAttentionSection(items: summary.attentionItems, trips: store.trips, store: store)
                            }

                            DashboardMoneySection(money: summary.money)

                            if summary.featuredTrips.isEmpty && summary.pastTrips.isEmpty {
                                EmptyFeatureCard(title: "All your trips are in the past", subtitle: "Create a new one to start planning again.")
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 28)
                }

                DashboardBottomNav(
                    primaryTrip: bottomNavTrip,
                    isShowingNextTrip: bottomNavTripIsNext,
                    store: store,
                    showAllTrips: { isShowingAllTrips = true },
                    showNoFocusedTrip: { isShowingNoFocusedTrip = true }
                )
            }
            .background(AppTheme.Editorial.background)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $isShowingNewTrip) {
                NewTripView(store: store)
            }
            .sheet(isPresented: $isShowingJoinInvite) {
                JoinTripInviteView(store: store)
            }
            .sheet(isPresented: $isShowingAllTrips) {
                AllTripsSheet(summary: summary, store: store)
            }
            .task {
                await store.loadTrips()
            }
            .alert("No active or upcoming trips yet", isPresented: $isShowingNoFocusedTrip) {
                Button("Create Trip") { isShowingNewTrip = true }
                Button("OK", role: .cancel) { }
            } message: {
                Text("Create a trip to use this shortcut.")
            }
            .alert(
                "Trip Sync Error",
                isPresented: Binding(
                    get: { store.syncError != nil && !isShowingJoinInvite },
                    set: { isPresented in
                        if !isPresented {
                            store.syncError = nil
                        }
                    }
                )
            ) {
                if store.supportsCloudSync {
                    Button("Retry") {
                        Task { await store.loadTrips() }
                    }
                }
                Button("OK", role: .cancel) { }
            } message: {
                Text(store.syncError ?? "Something went wrong.")
            }
            .confirmationDialog(
                modeBadge == .demo ? "Exit demo mode?" : "Sign out of Wanderaid?",
                isPresented: $isShowingSignOutConfirmation,
                titleVisibility: .visible
            ) {
                Button(modeBadge == .demo ? "Exit Demo" : "Sign Out", role: .destructive) {
                    signOut?()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text(modeBadge == .demo ? "You'll return to mode selection. Demo changes are local only." : "You'll return to the sign-in screen. Cloud trips stay saved and can be loaded again after signing in.")
            }
        }
    }
}

struct WaniHeader: View {
    var modeBadge: TripDashboardView.ModeBadge?
    var appearance: Binding<AppAppearance>
    var signOut: (() -> Void)?
    var joinTrip: (() -> Void)?
    var createTrip: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                WanderaidLogoMark(size: 30)

                Text("Wanderaid")
                    .font(.title2.weight(.semibold))

                Spacer()

                Menu {
                    Button {
                        createTrip()
                    } label: {
                        Label("Create Trip", systemImage: "plus")
                    }
                    .accessibilityLabel("Create a new trip")

                    if let joinTrip {
                        Button {
                            joinTrip()
                        } label: {
                            Label("Join by Invite", systemImage: "link.badge.plus")
                        }
                        .accessibilityLabel("Join a trip with an invite code")
                    }

                    Divider()

                    Picker("Appearance", selection: appearance) {
                        ForEach(AppAppearance.allCases) { option in
                            Label(option.displayName, systemImage: option.systemImage)
                                .tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                    .accessibilityLabel("Appearance")
                    .accessibilityValue(appearance.wrappedValue.displayName)

                    if let signOut {
                        Divider()

                        Button(role: .destructive) {
                            signOut()
                        } label: {
                            Label(
                                modeBadge == .demo ? "Exit Demo" : "Sign Out",
                                systemImage: "rectangle.portrait.and.arrow.right"
                            )
                        }
                        .accessibilityLabel(modeBadge == .demo ? "Exit demo mode" : "Sign out of Wanderaid")
                    }
                } label: {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.title2)
                        .foregroundStyle(AppTheme.Editorial.forest)
                        .frame(width: 36, height: 36)
                        .background(AppTheme.Editorial.forest.opacity(0.12))
                        .clipShape(Circle())
                }
                .accessibilityLabel("Profile menu")
            }

            HStack(spacing: AppTheme.Spacing.small) {
                Text("Plan trips with friends")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let modeBadge {
                    Text(modeBadge.title)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, AppTheme.Spacing.small)
                        .padding(.vertical, AppTheme.Spacing.xSmall)
                        .background(modeBadge.tint)
                        .clipShape(Capsule())
                        .accessibilityLabel("\(modeBadge.title): \(modeBadge.subtitle)")
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
}

private struct DashboardBottomNav: View {
    let primaryTrip: TripPlan?
    let isShowingNextTrip: Bool
    @ObservedObject var store: TripStore
    var showAllTrips: () -> Void
    var showNoFocusedTrip: () -> Void

    private var primaryTripTitle: String {
        isShowingNextTrip ? "Next" : "Current"
    }

    private var primaryTripSystemImage: String {
        isShowingNextTrip ? "calendar" : "location.fill"
    }

    var body: some View {
        HStack(spacing: 8) {
            BottomNavItem(title: "Dashboard", systemImage: "rectangle.grid.1x2.fill", isSelected: true) { }

            if let primaryTrip {
                NavigationLink {
                    TripSummaryView(trip: primaryTrip, store: store)
                } label: {
                    BottomNavLabel(title: primaryTripTitle, systemImage: primaryTripSystemImage, isSelected: false)
                }
                .buttonStyle(.plain)
            } else {
                BottomNavItem(title: primaryTripTitle, systemImage: "location", isSelected: false, action: showNoFocusedTrip)
            }

            BottomNavItem(title: "All Trips", systemImage: "list.bullet.rectangle", isSelected: false, action: showAllTrips)
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(.regularMaterial)
        .overlay(alignment: .top) {
            Divider()
        }
    }
}

private struct BottomNavItem: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            BottomNavLabel(title: title, systemImage: systemImage, isSelected: isSelected)
        }
        .buttonStyle(.plain)
    }
}

private struct BottomNavLabel: View {
    let title: String
    let systemImage: String
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.caption.weight(.bold))
            Text(title)
                .font(.caption2.weight(.semibold))
        }
        .foregroundStyle(isSelected ? AppTheme.Editorial.forest : AppTheme.Editorial.secondaryText)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(isSelected ? AppTheme.Editorial.forest.opacity(0.12) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct AllTripsSheet: View {
    @Environment(\.dismiss) private var dismiss
    let summary: DashboardSummary
    @ObservedObject var store: TripStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if !summary.currentTrips.isEmpty {
                        AllTripsGroup(title: "Current", trips: summary.currentTrips, store: store)
                    }

                    if !summary.futureTrips.isEmpty {
                        AllTripsGroup(title: "Future", trips: summary.futureTrips, store: store)
                    }

                    if !summary.pastTrips.isEmpty {
                        AllTripsGroup(title: "Past", trips: summary.pastTrips, store: store)
                    }
                }
                .padding(16)
            }
            .background(AppTheme.Editorial.background)
            .navigationTitle("All Trips")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

private struct AllTripsGroup: View {
    let title: String
    let trips: [TripPlan]
    @ObservedObject var store: TripStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            DashboardSectionTitle(title)

            VStack(spacing: 12) {
                ForEach(trips) { trip in
                    NavigationLink {
                        TripSummaryView(trip: trip, store: store)
                    } label: {
                        CompactTripCard(trip: trip)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct JoinTripInviteView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: TripStore
    @State private var inviteCode = ""
    @State private var isLookingUp = false
    @State private var isJoining = false
    @State private var didJoinTrip = false

    private var trimmedCode: String {
        inviteCode.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
                    WaniSectionHeader(
                        title: "Join a Trip",
                        subtitle: "Use a friend’s invite code to add the trip to your signed-in Wanderaid account."
                    )

                    WaniCard {
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                            VStack(alignment: .leading, spacing: AppTheme.Spacing.xSmall) {
                                Label("Signed-in join", systemImage: "person.crop.circle.badge.checkmark")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(AppTheme.success)
                                Text("You’ll join with this account, and Wanderaid will refresh your cloud trips after the invite is accepted.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            TextField("Invite code", text: $inviteCode)
                                .textInputAutocapitalization(.characters)
                                .autocorrectionDisabled()
                                .textFieldStyle(.roundedBorder)

                            Button {
                                Task { await lookupInvite() }
                            } label: {
                                if isLookingUp {
                                    HStack {
                                        ProgressView()
                                        Text("Checking invite…")
                                    }
                                    .frame(maxWidth: .infinity)
                                } else {
                                    Label("Preview Invite", systemImage: "magnifyingglass")
                                        .frame(maxWidth: .infinity)
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(AppTheme.primary)
                            .disabled(trimmedCode.isEmpty || isLookingUp || isJoining || didJoinTrip)
                        }
                    }

                    if didJoinTrip {
                        WaniCard {
                            HStack(alignment: .top, spacing: AppTheme.Spacing.small) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(AppTheme.success)
                                VStack(alignment: .leading, spacing: AppTheme.Spacing.xSmall) {
                                    Text("Trip joined")
                                        .font(.subheadline.weight(.semibold))
                                    Text("Your cloud trips were refreshed. The joined trip is now on your dashboard.")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }

                    if let syncError = store.syncError {
                        WaniCard {
                            HStack(alignment: .top, spacing: AppTheme.Spacing.small) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(AppTheme.error)
                                Text(syncError)
                                    .font(.footnote)
                                    .foregroundStyle(AppTheme.error)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }

                    if let preview = store.invitePreview {
                        WaniCard {
                            VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                                VStack(alignment: .leading, spacing: AppTheme.Spacing.xSmall) {
                                    Text("Ready to join")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(AppTheme.success)
                                    Text(preview.tripName)
                                        .font(.title3.weight(.semibold))
                                    Text("Invite role: \(preview.role.rawValue.capitalized) collaborator")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    Text("Because you’re signed in, this trip will stay linked to your account after relaunch.")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }

                                Button {
                                    Task { await acceptInvite() }
                                } label: {
                                    if isJoining {
                                        HStack {
                                            ProgressView()
                                            Text("Joining and refreshing trips…")
                                        }
                                        .frame(maxWidth: .infinity)
                                    } else {
                                        Label("Join Trip", systemImage: "person.badge.plus")
                                            .frame(maxWidth: .infinity)
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(AppTheme.success)
                                .disabled(isLookingUp || isJoining || didJoinTrip)
                            }
                        }
                    }
                }
                .padding(AppTheme.Spacing.large)
            }
            .background(AppTheme.background)
            .navigationTitle("Invite Code")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    @MainActor
    private func lookupInvite() async {
        didJoinTrip = false
        isLookingUp = true
        await store.lookupInvite(code: inviteCode)
        isLookingUp = false
    }

    @MainActor
    private func acceptInvite() async {
        isJoining = true
        let didJoin = await store.acceptInvite(code: inviteCode)
        isJoining = false

        if didJoin {
            didJoinTrip = true
            try? await Task.sleep(for: .milliseconds(650))
            dismiss()
        }
    }
}

struct FeaturedTripsCarousel: View {
    let trips: [TripPlan]
    @ObservedObject var store: TripStore

    var body: some View {
        TabView {
            ForEach(trips) { trip in
                NavigationLink {
                    TripSummaryView(trip: trip, store: store)
                } label: {
                    FeaturedTripCard(trip: trip)
                }
                .buttonStyle(.plain)
                .padding(.bottom, 32)
            }
        }
        .frame(height: 302)
        .tabViewStyle(.page(indexDisplayMode: .automatic))
    }
}

struct FeaturedTripCard: View {
    let trip: TripPlan
    @ObservedObject private var viewModel: TripCalculatorViewModel

    init(trip: TripPlan) {
        self.trip = trip
        _viewModel = ObservedObject(wrappedValue: trip.viewModel)
    }

    private var nextActionText: String {
        if let planningItem = trip.planningItems.first(where: { !$0.isDone }) {
            return planningItem.title
        }

        return "Tap to open trip details"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                RemoteTripImage(urlString: trip.imageURL)
                    .frame(height: 188)

                LinearGradient(
                    colors: [.black.opacity(0.05), .black.opacity(0.64)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                VStack(alignment: .leading, spacing: 8) {
                    Text(trip.status == .current ? "CURRENT TRIP" : "FUTURE TRIP")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.white.opacity(0.18))
                        .clipShape(Capsule())

                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.tripName)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.white)
                            .lineLimit(2)

                        Text("\(trip.dateRangeText) · \(trip.destination)")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white.opacity(0.88))
                            .lineLimit(2)
                    }
                }
                .padding(16)

                if let badgeText = trip.status.badgeText {
                    Text(badgeText)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(trip.status.tint)
                        .clipShape(Capsule())
                        .padding(8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                }
            }

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "sparkle.magnifyingglass")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.Editorial.forest)
                    .frame(width: 30, height: 30)
                    .background(AppTheme.Editorial.forest.opacity(0.12))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text("Next up")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.Editorial.secondaryText)
                    Text(nextActionText)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.Editorial.primaryText)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.Editorial.secondaryText)
            }
            .padding(14)
        }
        .background(AppTheme.Editorial.card)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(AppTheme.Editorial.border, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.10), radius: 14, y: 8)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens trip details")
    }
}

private struct NeedsYourAttentionSection: View {
    let items: [DashboardAttentionItem]
    let trips: [TripPlan]
    @ObservedObject var store: TripStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            DashboardSectionTitle("Needs your attention")

            VStack(spacing: 10) {
                ForEach(items) { item in
                    if let trip = trips.first(where: { $0.id == item.tripID }) {
                        NavigationLink {
                            TripSummaryView(trip: trip, store: store)
                        } label: {
                            AttentionRow(item: item)
                        }
                        .buttonStyle(.plain)
                    } else {
                        AttentionRow(item: item)
                    }
                }
            }
        }
    }
}

private struct AttentionRow: View {
    let item: DashboardAttentionItem

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checklist")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.Editorial.forest)
                .frame(width: 34, height: 34)
                .background(AppTheme.Editorial.forest.opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.Editorial.primaryText)
                    .lineLimit(2)
                Text(attentionSubtitle)
                    .font(.caption)
                    .foregroundStyle(AppTheme.Editorial.secondaryText)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.Editorial.secondaryText)
        }
        .padding(14)
        .dashboardCard()
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens trip details")
    }

    private var attentionSubtitle: String {
        if let dueDate = item.dueDate {
            return "\(item.tripName) · \(dueDate.formatted(date: .abbreviated, time: .omitted))"
        }

        return item.tripName
    }
}

private struct DashboardMoneySection: View {
    let money: DashboardMoneySummary?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            DashboardSectionTitle("Your money")

            if let money {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Net across trips")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.Editorial.secondaryText)
                            Text(money.net.wholeCurrencyText)
                                .font(.title2.weight(.bold))
                                .foregroundStyle(money.net >= 0 ? AppTheme.Editorial.owed : AppTheme.Editorial.due)
                        }

                        Spacer()

                        Image(systemName: "wallet.pass.fill")
                            .font(.title3)
                            .foregroundStyle(AppTheme.Editorial.forest)
                    }

                    HStack(spacing: 10) {
                        MoneyMetric(title: "Owed to you", amount: money.owedToYou, color: AppTheme.Editorial.owed)
                        MoneyMetric(title: "You owe", amount: money.youOwe, color: AppTheme.Editorial.due)
                    }
                }
                .padding(16)
                .dashboardCard()
            } else {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "person.crop.circle.badge.questionmark")
                        .font(.headline)
                        .foregroundStyle(AppTheme.Editorial.forest)
                        .frame(width: 36, height: 36)
                        .background(AppTheme.Editorial.forest.opacity(0.12))
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 5) {
                        Text("Money across trips")
                            .font(.headline)
                            .foregroundStyle(AppTheme.Editorial.primaryText)
                        Text("Personal balances will appear here once Wanderaid knows which traveler is you. We won’t substitute total trip spending for your balance.")
                            .font(.footnote)
                            .foregroundStyle(AppTheme.Editorial.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(16)
                .dashboardCard()
            }
        }
    }
}

private struct MoneyMetric: View {
    let title: String
    let amount: Decimal
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption)
                .foregroundStyle(AppTheme.Editorial.secondaryText)
            Text(amount.wholeCurrencyText)
                .font(.headline.weight(.bold))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(AppTheme.Editorial.raisedCard)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct DashboardSectionTitle: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title.uppercased())
            .font(.caption.weight(.bold))
            .foregroundStyle(AppTheme.Editorial.secondaryText)
            .tracking(0.8)
    }
}

private struct DashboardCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(AppTheme.Editorial.card)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(AppTheme.Editorial.border, lineWidth: 1)
            }
    }
}

private extension View {
    func dashboardCard() -> some View {
        modifier(DashboardCardModifier())
    }
}

struct CompactTripCard: View {
    let trip: TripPlan
    @ObservedObject private var viewModel: TripCalculatorViewModel

    init(trip: TripPlan) {
        self.trip = trip
        _viewModel = ObservedObject(wrappedValue: trip.viewModel)
    }

    var body: some View {
        HStack(spacing: 12) {
            RemoteTripImage(urlString: trip.imageURL)
                .frame(width: 120, height: 108)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 8) {
                Text(viewModel.tripName)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                Text(trip.destination)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                HStack {
                    Label(trip.dateRangeText, systemImage: "calendar")
                    Spacer(minLength: 4)
                    Text(viewModel.calculator.totalExpenses.wholeCurrencyText)
                        .fontWeight(.semibold)
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(AppTheme.Editorial.card)
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.Editorial.border, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
