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
    @State private var pastTripsOpen = false
    var modeBadge: ModeBadge?
    var signOut: (() -> Void)?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                WaniHeader(modeBadge: modeBadge, signOut: signOut) {
                    isShowingNewTrip = true
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        if store.isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 64)
                        } else if store.trips.isEmpty {
                            EmptyTripsView {
                                isShowingNewTrip = true
                            }
                        } else {
                            if !store.featuredTrips.isEmpty {
                                FeaturedTripsCarousel(trips: store.featuredTrips, store: store)
                            }

                            if !store.pastTrips.isEmpty {
                                PastTripsSection(trips: store.pastTrips, store: store, isOpen: $pastTripsOpen)
                            }

                            if store.featuredTrips.isEmpty && store.pastTrips.isEmpty {
                                EmptyFeatureCard(title: "All your trips are in the past", subtitle: "Create a new one to start planning again.")
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 28)
                }
            }
            .background(AppTheme.background)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $isShowingNewTrip) {
                NewTripView(store: store)
            }
            .task {
                await store.loadTrips()
            }
            .alert("Trip Sync Error", isPresented: store.errorAlertBinding) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(store.syncError ?? "Something went wrong.")
            }
        }
    }
}

struct WaniHeader: View {
    var modeBadge: TripDashboardView.ModeBadge?
    var signOut: (() -> Void)?
    var createTrip: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: "paperplane.fill")
                    .font(.title2)
                    .foregroundStyle(AppTheme.primary)

                Text("Wani")
                    .font(.title2.weight(.semibold))

                Spacer()

                if let signOut {
                    Button(action: signOut) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.headline)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel(modeBadge == .demo ? "Exit demo" : "Sign out")
                }

                Button(action: createTrip) {
                    Label("New", systemImage: "plus")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.primary)
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
        .frame(height: 386)
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

    private var personCountText: String {
        formattedCount(viewModel.calculator.participants.count, singular: "person", plural: "people")
    }

    private var placeCountText: String {
        formattedCount(trip.places.count, singular: "place", plural: "places")
    }

    private func formattedCount(_ count: Int, singular: String, plural: String) -> String {
        "\(count) \(count == 1 ? singular : plural)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topTrailing) {
                RemoteTripImage(urlString: trip.imageURL)
                    .frame(height: 160)

                if let badgeText = trip.status.badgeText {
                    Text(badgeText)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(trip.status.tint)
                        .clipShape(Capsule())
                        .padding(8)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(trip.status == .current ? "CURRENT TRIP" : "NEXT TRIP")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.tripName)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(trip.destination)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 10) {
                    FeaturedStat(
                        systemImage: "calendar",
                        value: trip.dateRangeText,
                        accessibilityLabel: "Trip dates \(trip.dateRangeText)"
                    )
                    FeaturedStat(
                        systemImage: "person.2.fill",
                        value: personCountText,
                        accessibilityLabel: personCountText
                    )
                    FeaturedStat(
                        systemImage: "mappin.and.ellipse",
                        value: placeCountText,
                        accessibilityLabel: placeCountText
                    )
                    FeaturedStat(
                        systemImage: "dollarsign",
                        value: viewModel.calculator.totalExpenses.wholeCurrencyText,
                        accessibilityLabel: "Total expenses \(viewModel.calculator.totalExpenses.wholeCurrencyText)"
                    )
                }

                HStack {
                    Text("View Details")
                        .font(.headline)
                    Image(systemName: "arrow.right")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(AppTheme.primary)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .padding(16)
        }
        .background(AppTheme.paper)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
    }
}

struct FeaturedStat: View {
    let systemImage: String
    let value: String
    let accessibilityLabel: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.primary)
            Text(value)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }
}

struct PastTripsSection: View {
    let trips: [TripPlan]
    @ObservedObject var store: TripStore
    @Binding var isOpen: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.snappy) {
                    isOpen.toggle()
                }
            } label: {
                HStack {
                    Text("Past Trips")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)
                    Spacer()
                    Text("\(trips.count)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Image(systemName: isOpen ? "chevron.up" : "chevron.down")
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)

            if isOpen {
                VStack(spacing: 16) {
                    ForEach(trips) { trip in
                        NavigationLink {
                            TripSummaryView(trip: trip, store: store)
                        } label: {
                            CompactTripCard(trip: trip)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .clipped()
                .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
            }
        }
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
        .background(AppTheme.paper)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
