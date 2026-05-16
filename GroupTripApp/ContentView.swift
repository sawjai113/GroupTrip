import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel: TripCalculatorViewModel

    init(viewModel: TripCalculatorViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ExpenseTrackerView(tripName: viewModel.tripName, destination: "", viewModel: viewModel)
    }
}

struct TripDashboardView: View {
    @StateObject var store: TripStore
    @State private var isShowingNewTrip = false
    @State private var pastTripsOpen = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TravelSplitHeader {
                    isShowingNewTrip = true
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        if store.trips.isEmpty {
                            EmptyTripsView {
                                isShowingNewTrip = true
                            }
                        } else {
                            if !store.featuredTrips.isEmpty {
                                FeaturedTripsCarousel(trips: store.featuredTrips)
                            }

                            if !store.pastTrips.isEmpty {
                                PastTripsSection(trips: store.pastTrips, isOpen: $pastTripsOpen)
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
        }
    }
}

final class TripStore: ObservableObject {
    @Published var trips: [TripPlan]

    init(trips: [TripPlan]) {
        self.trips = trips
    }

    var currentTrips: [TripPlan] {
        trips.filter { $0.status == .current }.sorted { $0.startDate < $1.startDate }
    }

    var futureTrips: [TripPlan] {
        trips.filter { $0.status == .future }.sorted { $0.startDate < $1.startDate }
    }

    var pastTrips: [TripPlan] {
        trips.filter { $0.status == .past }.sorted { $0.startDate > $1.startDate }
    }

    var featuredTrips: [TripPlan] {
        if let currentTrip = currentTrips.first {
            return [currentTrip] + futureTrips
        }

        return futureTrips
    }

    func addTrip(name: String, startDate: Date, endDate: Date) {
        addTrip(
            name: name,
            destination: "New destination",
            emoji: "✈️",
            imageURL: CoverImage.defaultOptions[0].url,
            startDate: startDate,
            endDate: endDate
        )
    }

    func addTrip(name: String, emoji: String, startDate: Date, endDate: Date) {
        addTrip(
            name: name,
            destination: "New destination",
            emoji: emoji,
            imageURL: CoverImage.defaultOptions[0].url,
            startDate: startDate,
            endDate: endDate
        )
    }

    func addTrip(name: String, destination: String, emoji: String, imageURL: String, startDate: Date, endDate: Date) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDestination = destination.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmoji = emoji.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedImageURL = imageURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        trips.append(
            TripPlan(
                destination: trimmedDestination.isEmpty ? "New destination" : trimmedDestination,
                emoji: trimmedEmoji.isEmpty ? "✈️" : trimmedEmoji,
                imageURL: trimmedImageURL.isEmpty ? CoverImage.defaultOptions[0].url : trimmedImageURL,
                startDate: startDate,
                endDate: max(startDate, endDate),
                viewModel: TripCalculatorViewModel.empty(named: trimmedName)
            )
        )
    }
}

extension TripStore {
    static let sample: TripStore = {
        let calendar = Calendar.current
        let today = Date()

        return TripStore(
            trips: [
                TripPlan(
                    destination: "Austin, Texas",
                    emoji: "🤠",
                    imageURL: "https://images.unsplash.com/photo-1529156069898-49953e39b3ac?w=800",
                    startDate: calendar.date(byAdding: .day, value: -2, to: today) ?? today,
                    endDate: calendar.date(byAdding: .day, value: 2, to: today) ?? today,
                    viewModel: .sample
                ),
                TripPlan(
                    destination: "Tokyo, Japan",
                    emoji: "🌸",
                    imageURL: "https://images.unsplash.com/photo-1540959733332-eab4deabeeaf?w=800",
                    startDate: calendar.date(byAdding: .month, value: 2, to: today) ?? today,
                    endDate: calendar.date(byAdding: .month, value: 2, to: calendar.date(byAdding: .day, value: 4, to: today) ?? today) ?? today,
                    viewModel: TripCalculatorViewModel.empty(named: "Japan Spring")
                ),
                TripPlan(
                    destination: "Oahu, Hawaii",
                    emoji: "🏝️",
                    imageURL: "https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=800",
                    startDate: calendar.date(byAdding: .month, value: -4, to: today) ?? today,
                    endDate: calendar.date(byAdding: .month, value: -4, to: calendar.date(byAdding: .day, value: 5, to: today) ?? today) ?? today,
                    viewModel: TripCalculatorViewModel.empty(named: "Oahu 2024")
                )
            ]
        )
    }()
}

struct TripPlan: Identifiable {
    let id: UUID
    var destination: String
    var emoji: String
    var imageURL: String
    var startDate: Date
    var endDate: Date
    var viewModel: TripCalculatorViewModel

    init(
        id: UUID = UUID(),
        destination: String = "New destination",
        emoji: String = "✈️",
        imageURL: String = CoverImage.defaultOptions[0].url,
        startDate: Date,
        endDate: Date,
        viewModel: TripCalculatorViewModel
    ) {
        self.id = id
        self.destination = destination
        self.emoji = emoji
        self.imageURL = imageURL
        self.startDate = startDate
        self.endDate = max(startDate, endDate)
        self.viewModel = viewModel
    }

    var status: TripStatus {
        let today = Calendar.current.startOfDay(for: Date())
        let start = Calendar.current.startOfDay(for: startDate)
        let end = Calendar.current.startOfDay(for: endDate)

        if end < today { return .past }
        if start > today { return .future }
        return .current
    }

    var dateRangeText: String {
        if Calendar.current.isDate(startDate, inSameDayAs: endDate) {
            return Self.shortDateFormatter.string(from: startDate)
        }

        return "\(Self.shortDateFormatter.string(from: startDate)) - \(Self.shortDateFormatter.string(from: endDate))"
    }

    var fullDateRangeText: String {
        "\(Self.longDateFormatter.string(from: startDate)) - \(Self.longDateFormatter.string(from: endDate))"
    }

    private static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMM d")
        return formatter
    }()

    private static let longDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMM d yyyy")
        return formatter
    }()
}

enum TripStatus {
    case past
    case current
    case future

    var badgeText: String? {
        switch self {
        case .past: nil
        case .current: "NOW"
        case .future: "UPCOMING"
        }
    }

    var tint: Color {
        switch self {
        case .past: .secondary
        case .current: AppTheme.success
        case .future: AppTheme.primary
        }
    }
}

private enum AppTheme {
    static let primary = Color(red: 0.10, green: 0.46, blue: 0.82)
    static let success = Color(red: 0.30, green: 0.69, blue: 0.31)
    static let error = Color(red: 0.96, green: 0.26, blue: 0.21)
    static let warning = Color(red: 1.00, green: 0.60, blue: 0.00)
    static let purple = Color(red: 0.61, green: 0.15, blue: 0.69)
    static let lightBlue = Color(red: 0.13, green: 0.59, blue: 0.95)
    static let background = Color(.systemGroupedBackground)
    static let paper = Color(.systemBackground)
    static let card = Color(.secondarySystemGroupedBackground)
}

private struct CoverImage: Identifiable, Hashable {
    let id = UUID()
    var url: String
    var title: String

    static let defaultOptions = [
        CoverImage(url: "https://images.unsplash.com/photo-1506869640319-fe1a24fd76dc?w=800", title: "Mountain adventure"),
        CoverImage(url: "https://images.unsplash.com/photo-1529156069898-49953e39b3ac?w=800", title: "Friends traveling"),
        CoverImage(url: "https://images.unsplash.com/photo-1539635278303-d4002c07eae3?w=800", title: "Group celebration"),
        CoverImage(url: "https://images.unsplash.com/photo-1488646953014-85cb44e25828?w=800", title: "City skyline"),
        CoverImage(url: "https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=800", title: "Beach paradise"),
        CoverImage(url: "https://images.unsplash.com/photo-1476514525535-07fb3b4ae5f1?w=800", title: "Lake view")
    ]
}

private struct TravelSplitHeader: View {
    var createTrip: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 12) {
                Image(systemName: "paperplane.fill")
                    .font(.title2)
                    .foregroundStyle(AppTheme.primary)

                Text("TravelSplit")
                    .font(.title2.weight(.semibold))

                Spacer()

                Button(action: createTrip) {
                    Label("New", systemImage: "plus")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.primary)
            }

            Text("Track expenses with friends")
                .font(.subheadline)
                .foregroundStyle(.secondary)
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

private struct FeaturedTripsCarousel: View {
    let trips: [TripPlan]

    var body: some View {
        TabView {
            ForEach(trips) { trip in
                NavigationLink {
                    TripSummaryView(trip: trip)
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

private struct FeaturedTripCard: View {
    let trip: TripPlan
    @ObservedObject private var viewModel: TripCalculatorViewModel

    init(trip: TripPlan) {
        self.trip = trip
        _viewModel = ObservedObject(wrappedValue: trip.viewModel)
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

                HStack(spacing: 12) {
                    FeaturedStat(systemImage: "calendar", value: TripPlanDate.shortStart.string(from: trip.startDate))
                    FeaturedStat(systemImage: "person.2.fill", value: "\(viewModel.calculator.participants.count) people")
                    FeaturedStat(systemImage: "dollarsign", value: viewModel.calculator.totalExpenses.wholeCurrencyText)
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

private struct FeaturedStat: View {
    let systemImage: String
    let value: String

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
    }
}

private struct PastTripsSection: View {
    let trips: [TripPlan]
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
                            TripSummaryView(trip: trip)
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

private struct CompactTripCard: View {
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

private struct TripSummaryView: View {
    let trip: TripPlan
    @ObservedObject private var viewModel: TripCalculatorViewModel

    init(trip: TripPlan) {
        self.trip = trip
        _viewModel = ObservedObject(wrappedValue: trip.viewModel)
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

                    VStack(spacing: 12) {
                        NavigationLink {
                            ExpenseTrackerView(tripName: viewModel.tripName, destination: trip.destination, viewModel: viewModel)
                        } label: {
                            ActionCard(
                                title: "Expenses",
                                description: "Track and split costs • \(viewModel.calculator.totalExpenses.currencyText) total",
                                systemImage: "receipt.fill",
                                tint: AppTheme.primary
                            )
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            PeopleFeatureView(viewModel: viewModel)
                        } label: {
                            ActionCard(title: "Invite Participants", description: "Add friends to your trip", systemImage: "person.badge.plus", tint: AppTheme.purple)
                        }
                        .buttonStyle(.plain)

                        PlaceholderActionCard(title: "Trip Chat", description: "Discuss plans with your group", systemImage: "message.fill", tint: AppTheme.lightBlue)
                        PlaceholderActionCard(title: "Places & Interests", description: "Save restaurants, shops, and attractions", systemImage: "mappin.and.ellipse", tint: AppTheme.error)
                        PlaceholderActionCard(title: "Itinerary", description: "Plan your daily schedule", systemImage: "calendar", tint: AppTheme.warning)
                        PlaceholderActionCard(title: "Map View", description: "See all your saved places on a map", systemImage: "map.fill", tint: AppTheme.success)
                    }
                }
                .padding(16)
            }
        }
        .background(AppTheme.background)
        .toolbar(.hidden, for: .navigationBar)
    }
}

private struct BackButton: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "arrow.left")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
                .frame(width: 44, height: 44)
                .background(.white.opacity(0.92))
                .clipShape(Circle())
        }
        .accessibilityLabel("Back")
    }
}

private struct ActionCard: View {
    let title: String
    let description: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 48, height: 48)
                .background(tint.opacity(0.09))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.paper)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct PlaceholderActionCard: View {
    let title: String
    let description: String
    let systemImage: String
    let tint: Color
    @State private var isShowingAlert = false

    var body: some View {
        Button {
            isShowingAlert = true
        } label: {
            ActionCard(title: title, description: description, systemImage: systemImage, tint: tint)
        }
        .buttonStyle(.plain)
        .alert("\(title) coming soon", isPresented: $isShowingAlert) {
            Button("OK", role: .cancel) { }
        }
    }
}

private struct ExpenseTrackerView: View {
    let tripName: String
    let destination: String
    @ObservedObject var viewModel: TripCalculatorViewModel
    @State private var selectedTab: ExpenseTab = .expenses
    @State private var activeSheet: ActiveSheet?

    var body: some View {
        VStack(spacing: 0) {
            ExpenseHeader(tripName: tripName, destination: destination, participants: viewModel.calculator.participants)

            ScrollView {
                VStack(spacing: 16) {
                    ExpenseStatsCard(viewModel: viewModel)

                    Picker("Expense view", selection: $selectedTab) {
                        ForEach(ExpenseTab.allCases) { tab in
                            Text(tab.title).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)

                    switch selectedTab {
                    case .expenses:
                        ExpenseTabView(viewModel: viewModel) {
                            activeSheet = .expense
                        }
                    case .balances:
                        BalancesTabView(viewModel: viewModel)
                    case .people:
                        PeopleTabView(viewModel: viewModel) {
                            activeSheet = .person
                        }
                    }
                }
                .padding(16)
            }
        }
        .background(AppTheme.background)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .person:
                AddPersonView(viewModel: viewModel)
            case .expense:
                AddExpenseView(viewModel: viewModel)
            case .payment:
                AddPaymentView(viewModel: viewModel)
            }
        }
    }
}

private enum ExpenseTab: String, CaseIterable, Identifiable {
    case expenses
    case balances
    case people

    var id: String { rawValue }

    var title: String {
        switch self {
        case .expenses: "Expenses"
        case .balances: "Balances"
        case .people: "People"
        }
    }
}

private struct ExpenseHeader: View {
    let tripName: String
    let destination: String
    let participants: [Participant]

    var body: some View {
        HStack(spacing: 12) {
            BackButton()
                .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(tripName)
                    .font(.headline)
                    .lineLimit(1)
                if !destination.isEmpty {
                    Text(destination)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            AvatarCluster(participants: participants, size: 32, maxVisible: 3)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.regularMaterial)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
}

private struct ExpenseStatsCard: View {
    @ObservedObject var viewModel: TripCalculatorViewModel

    var body: some View {
        HStack(spacing: 14) {
            CompactMetric(systemImage: "receipt.fill", label: "Total", value: viewModel.calculator.totalExpenses.wholeCurrencyText)
            CompactMetric(systemImage: "person.2.fill", label: "People", value: "\(viewModel.calculator.participants.count)")
            CompactMetric(systemImage: "chart.line.uptrend.xyaxis", label: "Per Person", value: perPersonText)
        }
        .padding(16)
        .background(AppTheme.paper)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var perPersonText: String {
        guard !viewModel.calculator.participants.isEmpty else { return "$0" }
        return (viewModel.calculator.totalExpenses / Decimal(viewModel.calculator.participants.count)).wholeCurrencyText
    }
}

private struct CompactMetric: View {
    let systemImage: String
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.primary)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct ExpenseTabView: View {
    @ObservedObject var viewModel: TripCalculatorViewModel
    var addExpense: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Button(action: addExpense) {
                Label("Add Expense", systemImage: "plus")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.primary)
            .disabled(viewModel.calculator.participants.isEmpty)

            if viewModel.calculator.expenses.isEmpty {
                EmptyFeatureCard(title: "No expenses yet", subtitle: "Add your first expense to start splitting costs.")
            } else {
                VStack(spacing: 12) {
                    ForEach(viewModel.calculator.expenses) { expense in
                        ExpenseCard(expense: expense, paidBy: viewModel.participantName(for: expense.paidBy)) {
                            if let index = viewModel.calculator.expenses.firstIndex(where: { $0.id == expense.id }) {
                                viewModel.deleteExpenses(at: IndexSet(integer: index))
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct ExpenseCard: View {
    let expense: ExpenseItem
    let paidBy: String
    var deleteExpense: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            AvatarInitial(name: paidBy)

            VStack(alignment: .leading, spacing: 5) {
                Text(expense.title)
                    .font(.body.weight(.semibold))
                Text("Paid by \(paidBy) • \(expense.participants.count) people")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Shared")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(AppTheme.lightBlue)
                    .clipShape(Capsule())
            }

            Spacer()

            Text(expense.amount.currencyText)
                .font(.headline)
                .foregroundStyle(AppTheme.primary)
                .monospacedDigit()

            Button(role: .destructive, action: deleteExpense) {
                Image(systemName: "trash")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.borderless)
        }
        .padding(14)
        .background(AppTheme.paper)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct BalancesTabView: View {
    @ObservedObject var viewModel: TripCalculatorViewModel
    @State private var activeSheet: ActiveSheet?

    var body: some View {
        VStack(spacing: 14) {
            Button {
                activeSheet = .payment
            } label: {
                Label("Record Payment", systemImage: "arrow.left.arrow.right")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.primary)
            .disabled(viewModel.calculator.participants.count < 2)

            BalanceCards(balances: viewModel.balances)
            SettlementCards(settlements: viewModel.settlements)
        }
        .sheet(item: $activeSheet) { _ in
            AddPaymentView(viewModel: viewModel)
        }
    }
}

private struct PeopleTabView: View {
    @ObservedObject var viewModel: TripCalculatorViewModel
    var addPeople: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Button(action: addPeople) {
                Label("Add Participant", systemImage: "plus")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.primary)

            if viewModel.calculator.participants.isEmpty {
                EmptyFeatureCard(title: "No people yet", subtitle: "Add travelers before tracking shared expenses.")
            } else {
                VStack(spacing: 12) {
                    ForEach(viewModel.calculator.participants.sorted { $0.name < $1.name }) { participant in
                        PersonCard(participant: participant, expenseCount: viewModel.calculator.expenses.filter { $0.paidBy == participant.id }.count) {
                            deleteParticipant(participant)
                        }
                    }
                }
            }
        }
    }

    private func deleteParticipant(_ participant: Participant) {
        let sortedParticipants = viewModel.calculator.participants.sorted { $0.name < $1.name }
        if let index = sortedParticipants.firstIndex(where: { $0.id == participant.id }) {
            viewModel.deleteParticipants(at: IndexSet(integer: index))
        }
    }
}

private struct PeopleFeatureView: View {
    @ObservedObject var viewModel: TripCalculatorViewModel
    @State private var activeSheet: ActiveSheet?

    var body: some View {
        List {
            PeopleSection(viewModel: viewModel)
            SettlementSection(settlements: viewModel.settlements)
        }
        .navigationTitle("People")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    activeSheet = .person
                } label: {
                    Label("Add People", systemImage: "person.fill.badge.plus")
                }
            }
        }
        .sheet(item: $activeSheet) { _ in
            AddPersonView(viewModel: viewModel)
        }
    }
}

private struct PersonCard: View {
    let participant: Participant
    let expenseCount: Int
    var deleteParticipant: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            AvatarInitial(name: participant.name, size: 48)

            VStack(alignment: .leading, spacing: 4) {
                Text(participant.name)
                    .font(.body.weight(.semibold))
                Text("\(expenseCount) expenses paid")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(role: .destructive, action: deleteParticipant) {
                Image(systemName: "trash")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.borderless)
        }
        .padding(16)
        .background(AppTheme.paper)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct BalanceCards: View {
    let balances: [Balance]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Individual Balances")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            if balances.isEmpty {
                EmptyFeatureCard(title: "Add people to see balances", subtitle: "Balances appear after travelers and expenses are added.")
            } else {
                VStack(spacing: 10) {
                    ForEach(balances) { balance in
                        HStack(spacing: 12) {
                            AvatarInitial(name: balance.participant.name)

                            Text(balance.participant.name)
                                .font(.body.weight(.semibold))

                            Spacer()

                            Text(balance.net.signedCurrencyText)
                                .font(.headline)
                                .monospacedDigit()
                                .foregroundStyle(balance.net > 0 ? AppTheme.success : balance.net < 0 ? AppTheme.error : .secondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background((balance.net > 0 ? AppTheme.success : balance.net < 0 ? AppTheme.error : Color.secondary).opacity(0.12))
                                .clipShape(Capsule())
                        }
                        .padding(14)
                        .background(AppTheme.paper)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
            }
        }
    }
}

private struct SettlementCards: View {
    let settlements: [Settlement]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Suggested Settlements")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            if settlements.isEmpty {
                EmptyFeatureCard(title: "All settled up", subtitle: "No outstanding balances.")
            } else {
                VStack(spacing: 10) {
                    ForEach(settlements) { settlement in
                        HStack(spacing: 10) {
                            AvatarInitial(name: settlement.from.name)
                            Image(systemName: "arrow.right")
                                .foregroundStyle(.secondary)
                            AvatarInitial(name: settlement.to.name)

                            Text("\(settlement.from.name) pays \(settlement.to.name)")
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(2)

                            Spacer()

                            Text(settlement.amount.currencyText)
                                .font(.headline)
                                .foregroundStyle(AppTheme.primary)
                                .monospacedDigit()
                        }
                        .padding(14)
                        .background(AppTheme.paper)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
            }
        }
    }
}

private struct NewTripView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: TripStore
    @State private var name = ""
    @State private var destination = ""
    @State private var emoji = "✈️"
    @State private var startDate = Date()
    @State private var endDate = Date()
    @State private var selectedImageURL = CoverImage.defaultOptions[0].url
    @State private var customImageURL = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Trip Name", text: $name)
                    TextField("Destination", text: $destination)
                    TextField("Emoji", text: $emoji)
                        .font(.title2)
                        .multilineTextAlignment(.center)
                        .onChange(of: emoji) { _, newValue in
                            emoji = String(newValue.prefix(2))
                        }
                }

                Section("Dates") {
                    DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                    DatePicker("End Date", selection: $endDate, in: startDate..., displayedComponents: .date)
                }

                Section("Cover Image") {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(CoverImage.defaultOptions) { image in
                            Button {
                                selectedImageURL = image.url
                                customImageURL = ""
                            } label: {
                                RemoteTripImage(urlString: image.url)
                                    .frame(height: 82)
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .stroke(selectedImageURL == image.url && customImageURL.isEmpty ? AppTheme.primary : .clear, lineWidth: 3)
                                    }
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(image.title)
                        }
                    }

                    TextField("Or paste custom image URL", text: $customImageURL)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                }
            }
            .navigationTitle("Create New Trip")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Create Trip") {
                        store.addTrip(
                            name: name,
                            destination: destination,
                            emoji: emoji,
                            imageURL: customImageURL.isEmpty ? selectedImageURL : customImageURL,
                            startDate: startDate,
                            endDate: endDate
                        )
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !destination.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

private enum ActiveSheet: Identifiable {
    case person
    case expense
    case payment

    var id: String {
        switch self {
        case .person: "person"
        case .expense: "expense"
        case .payment: "payment"
        }
    }
}

private struct PeopleSection: View {
    @ObservedObject var viewModel: TripCalculatorViewModel

    var body: some View {
        Section {
            if viewModel.calculator.participants.isEmpty {
                EmptyRow(title: "No people yet", systemImage: "person.2")
            } else {
                ForEach(viewModel.calculator.participants.sorted { $0.name < $1.name }) { participant in
                    Label(participant.name, systemImage: "person.fill")
                }
                .onDelete(perform: viewModel.deleteParticipants)
            }
        } header: {
            Text("People")
        }
    }
}

private struct SettlementSection: View {
    let settlements: [Settlement]

    var body: some View {
        Section {
            if settlements.isEmpty {
                EmptyRow(title: "All settled", systemImage: "checkmark.circle")
            } else {
                ForEach(settlements) { settlement in
                    HStack(spacing: 12) {
                        Image(systemName: "arrow.right.circle.fill")
                            .foregroundStyle(AppTheme.primary)

                        Text("\(settlement.from.name) pays \(settlement.to.name)")
                            .font(.body.weight(.semibold))

                        Spacer()

                        Text(settlement.amount.currencyText)
                            .font(.headline)
                            .monospacedDigit()
                    }
                }
            }
        } header: {
            Text("Suggested payments")
        }
    }
}

private struct AddPersonView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: TripCalculatorViewModel
    @State private var names = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextEditor(text: $names)
                        .frame(minHeight: 140)
                        .overlay(alignment: .topLeading) {
                            if names.isEmpty {
                                Text("Alex\nSam\nTaylor")
                                    .foregroundStyle(.tertiary)
                                    .padding(.top, 8)
                                    .padding(.leading, 5)
                                    .allowsHitTesting(false)
                            }
                        }
                } footer: {
                    Text("Enter one person per line.")
                }
            }
            .navigationTitle("Add People")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        viewModel.addParticipants(names: parsedNames)
                        dismiss()
                    }
                    .disabled(parsedNames.isEmpty)
                }
            }
        }
    }

    private var parsedNames: [String] {
        names
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

private struct AddExpenseView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: TripCalculatorViewModel
    @State private var title = ""
    @State private var amount = ""
    @State private var paidBy: Participant.ID?
    @State private var selectedParticipants = Set<Participant.ID>()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Description", text: $title)
                    TextField("Amount", text: $amount)
                        .keyboardType(.decimalPad)
                }

                Section("Paid By") {
                    Picker("Paid By", selection: paidByBinding) {
                        ForEach(viewModel.calculator.participants) { participant in
                            Text(participant.name).tag(Optional(participant.id))
                        }
                    }
                }

                Section("Split Among") {
                    Button("Select Everyone") {
                        selectedParticipants = Set(viewModel.calculator.participants.map(\.id))
                    }

                    ForEach(viewModel.calculator.participants) { participant in
                        Toggle(participant.name, isOn: participantBinding(for: participant.id))
                    }
                }
            }
            .navigationTitle("Add Expense")
            .onAppear {
                if paidBy == nil {
                    paidBy = viewModel.calculator.participants.first?.id
                    selectedParticipants = Set(viewModel.calculator.participants.map(\.id))
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add Expense") {
                        viewModel.addExpense(
                            title: title,
                            paidBy: paidByBinding.wrappedValue,
                            amount: parsedAmount,
                            participants: selectedParticipants
                        )
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private var paidByBinding: Binding<Participant.ID> {
        Binding(
            get: { paidBy ?? viewModel.calculator.participants.first?.id ?? UUID() },
            set: { paidBy = $0 }
        )
    }

    private var parsedAmount: Decimal {
        Decimal(string: amount.filter { $0 != "$" && $0 != "," }) ?? 0
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        parsedAmount > 0 &&
        paidBy != nil &&
        !selectedParticipants.isEmpty
    }

    private func participantBinding(for id: Participant.ID) -> Binding<Bool> {
        Binding(
            get: { selectedParticipants.contains(id) },
            set: { isSelected in
                if isSelected {
                    selectedParticipants.insert(id)
                } else {
                    selectedParticipants.remove(id)
                }
            }
        )
    }
}

private struct AddPaymentView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: TripCalculatorViewModel
    @State private var title = ""
    @State private var amount = ""
    @State private var from: Participant.ID?
    @State private var to: Participant.ID?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Payment name", text: $title)
                    TextField("Amount", text: $amount)
                        .keyboardType(.decimalPad)
                }

                Section("People") {
                    Picker("From", selection: fromBinding) {
                        ForEach(viewModel.calculator.participants) { participant in
                            Text(participant.name).tag(Optional(participant.id))
                        }
                    }

                    Picker("To", selection: toBinding) {
                        ForEach(viewModel.calculator.participants) { participant in
                            Text(participant.name).tag(Optional(participant.id))
                        }
                    }
                }
            }
            .navigationTitle("Add Payment")
            .onAppear {
                from = viewModel.calculator.participants.first?.id
                to = viewModel.calculator.participants.dropFirst().first?.id ?? viewModel.calculator.participants.first?.id
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        viewModel.addPayment(
                            title: title,
                            from: fromBinding.wrappedValue,
                            to: toBinding.wrappedValue,
                            amount: parsedAmount
                        )
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private var fromBinding: Binding<Participant.ID> {
        Binding(
            get: { from ?? viewModel.calculator.participants.first?.id ?? UUID() },
            set: { from = $0 }
        )
    }

    private var toBinding: Binding<Participant.ID> {
        Binding(
            get: { to ?? viewModel.calculator.participants.first?.id ?? UUID() },
            set: { to = $0 }
        )
    }

    private var parsedAmount: Decimal {
        Decimal(string: amount.filter { $0 != "$" && $0 != "," }) ?? 0
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        parsedAmount > 0 &&
        from != nil &&
        to != nil &&
        from != to
    }
}

private struct EmptyTripsView: View {
    var createTrip: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "paperplane")
                .font(.system(size: 62))
                .foregroundStyle(.tertiary)

            VStack(spacing: 6) {
                Text("No trips yet")
                    .font(.title3.weight(.semibold))
                Text("Create your first trip to start tracking expenses")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button(action: createTrip) {
                Label("Create Your First Trip", systemImage: "plus")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 64)
    }
}

private struct EmptyFeatureCard: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.body.weight(.semibold))
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(AppTheme.paper)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct EmptyRow: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .foregroundStyle(.secondary)
    }
}

private struct RemoteTripImage: View {
    let urlString: String

    var body: some View {
        GeometryReader { proxy in
            AsyncImage(url: URL(string: urlString)) { phase in
                switch phase {
                case .empty:
                    Rectangle()
                        .fill(AppTheme.card)
                        .overlay {
                            ProgressView()
                        }
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                case .failure:
                    Rectangle()
                        .fill(AppTheme.primary.opacity(0.15))
                        .overlay {
                            Image(systemName: "photo")
                                .font(.title2)
                                .foregroundStyle(AppTheme.primary)
                        }
                @unknown default:
                    Rectangle().fill(AppTheme.card)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
    }
}

private struct AvatarCluster: View {
    let participants: [Participant]
    var size: CGFloat = 32
    var maxVisible: Int = 5

    var body: some View {
        HStack(spacing: -8) {
            ForEach(Array(participants.prefix(maxVisible).enumerated()), id: \.element.id) { index, participant in
                AvatarInitial(name: participant.name, size: size, color: avatarColor(index))
                    .overlay {
                        Circle().stroke(AppTheme.background, lineWidth: 2)
                    }
            }

            if participants.count > maxVisible {
                Text("+\(participants.count - maxVisible)")
                    .font(.caption.weight(.semibold))
                    .frame(width: size, height: size)
                    .background(Color(.tertiarySystemFill))
                    .clipShape(Circle())
            }
        }
    }
}

private struct AvatarInitial: View {
    let name: String
    var size: CGFloat = 40
    var color: Color = AppTheme.primary

    var body: some View {
        Text(String(name.prefix(1)).uppercased())
            .font(.system(size: size * 0.38, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(color)
            .clipShape(Circle())
    }
}

private func avatarColor(_ index: Int) -> Color {
    let colors = [AppTheme.primary, AppTheme.purple, AppTheme.success, AppTheme.warning, AppTheme.error, AppTheme.lightBlue]
    return colors[index % colors.count]
}

private extension TripPlanDate {
    static let shortStart: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMM d")
        return formatter
    }()
}

private enum TripPlanDate { }

private extension Decimal {
    var wholeCurrencyText: String {
        let number = self as NSDecimalNumber
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter.string(from: number) ?? "$0"
    }

    var signedCurrencyText: String {
        if self > 0 {
            return "+\(currencyText)"
        }

        if self < 0 {
            return "-\(abs(self).currencyText)"
        }

        return "$0.00"
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        TripDashboardView(store: .sample)
    }
}
