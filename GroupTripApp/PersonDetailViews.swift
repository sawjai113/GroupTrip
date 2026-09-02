import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Detail room for a single person on a trip. Read-only M4 surface: it receives
/// plain snapshot arrays and computes aggregation/breadth locally — no bindings.
struct PersonDetailView: View {
    let participant: Participant
    let tripName: String
    let places: [TripPlace]
    let planningItems: [TripPlanningItem]
    let expenses: [ExpenseItem]
    let balanceNet: Decimal
    var createdInvite: TripInvite?
    var createInvite: () async -> Void = {}
    var usesExternalPersistence: Bool = false
    @State private var isPresentingShareSheet = false
    @State private var shareText: String?
    @State private var isWaitingForInviteToShare = false

    private var footprint: PersonFootprint {
        PersonFootprint.aggregate(
            participantID: participant.id,
            tripID: participant.id,
            expenses: expenses,
            places: places,
            planningItems: planningItems
        )
    }

    private var balancePhrase: PersonBalancePhrase {
        PersonBalancePhrase(net: balanceNet)
    }

    private var hasActivity: Bool {
        footprint.paidExpenses.isEmpty
            && footprint.sharedExpenses.isEmpty
            && footprint.places.isEmpty
            && footprint.plans.isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
                headerCard

                if usesExternalPersistence {
                    metricsGrid
                    shareInviteButton
                }

                if hasActivity {
                    EmptyFeatureCard(
                        title: "No trip activity yet",
                        subtitle: "Places, plans, or expenses this person is part of will appear here."
                    )
                } else {
                    activitySections
                }
            }
            .padding(AppTheme.Spacing.large)
        }
        .background(AppTheme.Editorial.background)
        .navigationTitle(participant.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isPresentingShareSheet) {
            if let shareText {
                ShareSheet(items: [shareText])
            }
        }
        .onChange(of: createdInvite?.code) { _, newCode in
            if let newCode, isWaitingForInviteToShare {
                presentShareText(code: newCode)
            }
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
            HStack(spacing: AppTheme.Spacing.medium) {
                AvatarInitial(name: participant.name, size: 62)
                VStack(alignment: .leading, spacing: AppTheme.Spacing.xSmall) {
                    Text(participant.name)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AppTheme.Editorial.primaryText)
                    if participant.isOrganizer {
                        OrganizerBadge()
                    }
                }
                Spacer(minLength: 0)
            }

            Text(balancePhrase.text)
                .font(.system(size: 28, weight: .semibold, design: .serif))
                .tracking(-0.8)
                .foregroundStyle(balanceTint)
        }
        .padding(AppTheme.Spacing.large)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.Editorial.card)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.xLarge, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.Radius.xLarge, style: .continuous)
                .stroke(AppTheme.Editorial.border, lineWidth: 1)
        }
    }

    private var balanceTint: Color {
        switch balancePhrase {
        case .getsBack: AppTheme.Editorial.forestDeep
        case .owes: AppTheme.Editorial.owed
        case .settled: AppTheme.Editorial.secondaryText
        }
    }

    private var metricsGrid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
            spacing: 10
        ) {
            metricCell(value: footprint.places.count, label: "Places")
            metricCell(value: footprint.paidExpenses.count + footprint.sharedExpenses.count, label: "Expenses")
        }
    }

    private func metricCell(value: Int, label: String) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xSmall) {
            Text("\(value)")
                .font(.system(size: 23, weight: .semibold, design: .serif))
                .foregroundStyle(AppTheme.Editorial.forestDeep)
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(AppTheme.Editorial.secondaryText)
        }
        .padding(AppTheme.Spacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.Editorial.raisedCard)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppTheme.Editorial.border, lineWidth: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(value)")
    }

    private var shareInviteButton: some View {
        Button {
            handleShareTap()
        } label: {
            Label("Share trip invite", systemImage: "square.and.arrow.up")
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppTheme.Spacing.medium)
        }
        .buttonStyle(.borderedProminent)
        .tint(AppTheme.Editorial.forest)
    }

    private var activitySections: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
            if !footprint.places.isEmpty {
                PersonActivitySection(title: "Places they're part of") {
                    ForEach(Array(footprint.places.enumerated()), id: \.element.id) { index, place in
                        Text(place.name)
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, AppTheme.Spacing.medium)
                        if index < footprint.places.count - 1 {
                            Divider()
                        }
                    }
                }
            }

            if !footprint.paidExpenses.isEmpty || !footprint.sharedExpenses.isEmpty {
                PersonActivitySection(
                    title: "Expenses paid",
                    trailingTitle: footprint.sharedExpenses.isEmpty ? nil : "Shared in \(footprint.sharedExpenses.count)"
                ) {
                    ForEach(Array(footprint.paidExpenses.enumerated()), id: \.element.id) { index, expense in
                        Text(expense.title)
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, AppTheme.Spacing.medium)
                        if index < footprint.paidExpenses.count - 1 {
                            Divider()
                        }
                    }
                }
            }

            if !footprint.plans.isEmpty {
                PersonActivitySection(title: "Plans they're part of") {
                    ForEach(Array(footprint.plans.enumerated()), id: \.element.id) { index, plan in
                        Text(plan.title)
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, AppTheme.Spacing.medium)
                        if index < footprint.plans.count - 1 {
                            Divider()
                        }
                    }
                }
            }
        }
    }

    private func handleShareTap() {
        guard let code = createdInvite?.code else {
            isWaitingForInviteToShare = true
            Task { await createInvite() }
            return
        }
        presentShareText(code: code)
    }

    private func presentShareText(code: String) {
        guard let text = TripShareTextBuilder.text(tripName: tripName, inviteCode: code) else { return }
        shareText = text
        isWaitingForInviteToShare = false
        isPresentingShareSheet = true
    }
}

/// Quiet forest pill used to mark the trip organizer.
struct OrganizerBadge: View {
    var body: some View {
        Text("Organizer")
            .font(.caption2.weight(.bold))
            .foregroundStyle(AppTheme.Editorial.forestDeep)
            .padding(.horizontal, AppTheme.Spacing.small)
            .padding(.vertical, 4)
            .background(AppTheme.Editorial.forest.opacity(0.12))
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .stroke(AppTheme.Editorial.forest.opacity(0.2), lineWidth: 1)
            }
    }
}

private struct PersonActivitySection<Content: View>: View {
    let title: String
    var trailingTitle: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(AppTheme.Editorial.primaryText)
                if let trailingTitle {
                    Spacer()
                    Text(trailingTitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.Editorial.secondaryText)
                }
            }

            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppTheme.Spacing.medium)
            .background(AppTheme.Editorial.card)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.large, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.Radius.large, style: .continuous)
                    .stroke(AppTheme.Editorial.border, lineWidth: 1)
            }
        }
    }
}

#if canImport(UIKit)
private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif
