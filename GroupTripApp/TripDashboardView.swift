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
    @State private var isShowingAccount = false
    @State private var isShowingAllTrips = false
    @State private var isShowingNoFocusedTrip = false
    var modeBadge: ModeBadge?
    var appearance: Binding<AppAppearance> = .constant(.auto)
    var currentAccountID: UUID?
    var signOut: (() -> Void)?

    var body: some View {
        let summary = store.dashboardSummary(currentAccountID: currentAccountID)
        let bottomNavTrip = summary.currentTrips.first ?? summary.futureTrips.first
        let bottomNavTripIsNext = summary.currentTrips.isEmpty && !summary.futureTrips.isEmpty

        NavigationStack {
            VStack(spacing: 0) {
                WaniHeader(
                    modeBadge: modeBadge,
                    appearance: appearance,
                    openAccount: signOut == nil ? nil : { isShowingAccount = true },
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
            .sheet(isPresented: $isShowingAccount) {
                AccountSettingsView(
                    modeBadge: modeBadge,
                    currentAccountID: currentAccountID,
                    requestSignOut: {
                        isShowingAccount = false
                        DispatchQueue.main.async {
                            isShowingSignOutConfirmation = true
                        }
                    }
                )
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
                modeBadge == .demo ? "Exit demo mode?" : "Log out of Wanderaid?",
                isPresented: $isShowingSignOutConfirmation,
                titleVisibility: .visible
            ) {
                Button(modeBadge == .demo ? "Exit Demo" : "Log Out", role: .destructive) {
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
    var openAccount: (() -> Void)?
    var joinTrip: (() -> Void)?
    var createTrip: () -> Void

    private var syncStatusText: String {
        switch modeBadge {
        case .cloud:
            return "Cloud synced"
        case .demo:
            return "Demo mode"
        case nil:
            return "Ready"
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text("Wanderaid")
                        .font(.custom("Georgia", size: 25).weight(.semibold))
                        .tracking(-0.75)
                        .foregroundStyle(AppTheme.Editorial.primaryText)

                    Text(".")
                        .font(.custom("Georgia", size: 25).weight(.semibold))
                        .tracking(-0.75)
                        .foregroundStyle(AppTheme.Editorial.forest)
                }

                HStack(spacing: 4) {
                    Text("Good morning ·")
                        .font(.caption)
                        .foregroundStyle(AppTheme.Editorial.secondaryText)

                    Text(syncStatusText)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.Editorial.forest)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Good morning, \(syncStatusText)")
            }
            .frame(maxWidth: .infinity, alignment: .leading)

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

                if let openAccount {
                    Divider()

                    Button {
                        openAccount()
                    } label: {
                        Label("Account", systemImage: "person.crop.circle")
                    }
                    .accessibilityLabel("Open account settings")
                }
            } label: {
                Text("S")
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(AppTheme.Editorial.forestDeep)
                    .frame(width: 40, height: 40)
                    .background(AppTheme.Editorial.border.opacity(0.62))
                    .clipShape(Circle())
                    .overlay {
                        Circle()
                            .stroke(AppTheme.Editorial.card.opacity(0.9), lineWidth: 2)
                    }
                    .shadow(color: AppTheme.Editorial.primaryText.opacity(0.08), radius: 12, x: 0, y: 6)
            }
            .accessibilityLabel("Profile menu")
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .padding(.bottom, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.Editorial.background)
    }
}

private struct AccountSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    let modeBadge: TripDashboardView.ModeBadge?
    let currentAccountID: UUID?
    var requestSignOut: () -> Void

    @State private var displayName = ""
    @State private var username = ""
    @State private var email = ""
    @State private var password = ""
    @State private var accountMessage: String?

    private var signOutTitle: String {
        modeBadge == .demo ? "Exit Demo" : "Log Out"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    EditorialFieldCard {
                        HStack(spacing: 14) {
                            Text("S")
                                .font(.title3.weight(.heavy))
                                .foregroundStyle(AppTheme.Editorial.forestDeep)
                                .frame(width: 48, height: 48)
                                .background(AppTheme.Editorial.border.opacity(0.62))
                                .clipShape(Circle())

                            VStack(alignment: .leading, spacing: 4) {
                                Text(displayName.isEmpty ? "Your account" : displayName)
                                    .font(.headline)
                                    .foregroundStyle(AppTheme.Editorial.primaryText)
                                Text(modeBadge?.title ?? "Account")
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.Editorial.secondaryText)
                            }
                        }
                    }
                }

                Section {
                    VStack(spacing: AppTheme.Spacing.medium) {
                        EditorialTextField(
                            label: "Name",
                            placeholder: "Your name",
                            text: $displayName,
                            textContentType: .name
                        )

                        EditorialTextField(
                            label: "Username",
                            placeholder: "username",
                            text: $username,
                            autocapitalization: .never,
                            autocorrectionDisabled: true
                        )

                        EditorialTextField(
                            label: "Email",
                            placeholder: "you@example.com",
                            text: $email,
                            keyboardType: .emailAddress,
                            textContentType: .emailAddress,
                            autocapitalization: .never
                        )

                        Button("Save Profile") {
                            accountMessage = "Profile editing is staged in the account screen. The next backend step is saving these fields to Supabase profiles."
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.Editorial.forest)
                    }
                } header: {
                    EditorialSectionHeader(title: "Profile")
                } footer: {
                    Text("Profile editing is staged here for the account settings flow; cloud save wiring can connect this to Supabase profiles next.")
                        .foregroundStyle(AppTheme.Editorial.secondaryText)
                }

                Section {
                    VStack(spacing: AppTheme.Spacing.medium) {
                        EditorialTextField(
                            label: "New password",
                            placeholder: "••••••••",
                            text: $password,
                            isSecure: true,
                            textContentType: .newPassword
                        )

                        Button("Update Password") {
                            accountMessage = "Password update controls now live in Account. Provider-specific password update wiring can be connected next."
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.Editorial.forest)
                        .disabled(password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                } header: {
                    EditorialSectionHeader(title: "Security")
                } footer: {
                    Text("Password updates are available for email/password accounts. Google and Apple sign-ins manage passwords with their provider.")
                        .foregroundStyle(AppTheme.Editorial.secondaryText)
                }

                if let currentAccountID {
                    Section {
                        Text(currentAccountID.uuidString)
                            .font(.footnote.monospaced())
                            .foregroundStyle(AppTheme.Editorial.secondaryText)
                            .textSelection(.enabled)
                    } header: {
                        EditorialSectionHeader(title: "Account ID")
                    }
                }

                Section {
                    Button(role: .destructive) {
                        requestSignOut()
                    } label: {
                        Label(signOutTitle, systemImage: "rectangle.portrait.and.arrow.right")
                    }
                } footer: {
                    Text(modeBadge == .demo ? "You’ll return to mode selection. Demo changes are local only." : "You’ll return to the sign-in screen. Cloud trips stay saved and can be loaded again after signing in.")
                        .foregroundStyle(AppTheme.Editorial.secondaryText)
                }
            }
            .editorialForm()
            .background(AppTheme.Editorial.background)
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Account", isPresented: Binding(
                get: { accountMessage != nil },
                set: { isPresented in
                    if !isPresented { accountMessage = nil }
                }
            )) {
                Button("OK", role: .cancel) { accountMessage = nil }
            } message: {
                Text(accountMessage ?? "")
            }
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
        .background(AppTheme.Editorial.card)
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
            EditorialSectionHeader(title: title)

            VStack(spacing: 12) {
                ForEach(trips) { trip in
                    NavigationLink {
                        TripSummaryView(trip: trip, store: store)
                    } label: {
                        EditorialTripRow(
                            trip: trip,
                            meta: tripMeta(trip),
                            status: trip.status
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func tripMeta(_ trip: TripPlan) -> String {
        let travelers = trip.viewModel.calculator.participants.count
        let openPlans = trip.planningItems.filter { !$0.isDone }.count
        return "\\(travelers) travelers · \\(openPlans) open plans"
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
                    EditorialSectionHeader(
                        title: "Join a trip",
                        subtitle: "Use a friend’s invite code to add the trip to your signed-in Wanderaid account."
                    )

                    WaniCard {
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                            VStack(alignment: .leading, spacing: AppTheme.Spacing.xSmall) {
                                Label("Signed-in join", systemImage: "person.crop.circle.badge.checkmark")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(AppTheme.Editorial.forest)
                                Text("You’ll join with this account, and Wanderaid will refresh your cloud trips after the invite is accepted.")
                                    .font(.footnote)
                                    .foregroundStyle(AppTheme.Editorial.secondaryText)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            EditorialTextField(
                                label: "Invite code",
                                placeholder: "e.g. ABCD-1234",
                                text: $inviteCode,
                                autocapitalization: .characters,
                                autocorrectionDisabled: true
                            )

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
                            .tint(AppTheme.Editorial.forest)
                            .disabled(trimmedCode.isEmpty || isLookingUp || isJoining || didJoinTrip)
                        }
                    }

                    if didJoinTrip {
                        WaniCard {
                            HStack(alignment: .top, spacing: AppTheme.Spacing.small) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(AppTheme.Editorial.forest)
                                VStack(alignment: .leading, spacing: AppTheme.Spacing.xSmall) {
                                    Text("Trip joined")
                                        .font(.subheadline.weight(.semibold))
                                    Text("Your cloud trips were refreshed. The joined trip is now on your dashboard.")
                                        .font(.footnote)
                                        .foregroundStyle(AppTheme.Editorial.secondaryText)
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
                                        .foregroundStyle(AppTheme.Editorial.secondaryText)
                                    Text("Because you’re signed in, this trip will stay linked to your account after relaunch.")
                                        .font(.footnote)
                                        .foregroundStyle(AppTheme.Editorial.secondaryText)
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
                                .tint(AppTheme.Editorial.forest)
                                .disabled(isLookingUp || isJoining || didJoinTrip)
                            }
                        }
                    }
                }
                .padding(AppTheme.Spacing.large)
            }
            .background(AppTheme.Editorial.background)
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
        .frame(height: 336)
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

    private var eyebrow: String {
        trip.status == .current ? "Current trip" : "Next trip"
    }

    private var statusPill: String {
        switch trip.status {
        case .current: return "Current"
        case .future: return "Next"
        case .past: return "Past"
        }
    }

    private var metadata: String {
        "\(trip.dateRangeText) · Tap to open the trip"
    }

    var body: some View {
        TripPhotoHero(
            trip: trip,
            eyebrow: eyebrow,
            title: viewModel.tripName,
            metadata: metadata,
            statusPill: statusPill
        )
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
