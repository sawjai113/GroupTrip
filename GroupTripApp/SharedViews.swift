import SwiftUI

// MARK: - TripStatus display mapping (view layer)

extension TripStatus {
    var tint: Color {
        switch self {
        case .past: .secondary
        case .current: AppTheme.Editorial.forest
        case .future: AppTheme.Editorial.forestDeep
        }
    }
}

struct BackButton: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "arrow.left")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
                .frame(width: AppTheme.IconSize.medium, height: AppTheme.IconSize.medium)
                .background(.white.opacity(0.92))
                .clipShape(Circle())
        }
        .accessibilityLabel("Back")
    }
}

struct WaniCard<Content: View>: View {
    var padding: CGFloat = AppTheme.Spacing.large
    var radius: CGFloat = AppTheme.Radius.large
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.Editorial.card)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(AppTheme.Editorial.border, lineWidth: 1)
            )
    }
}

extension View {
    func destructiveConfirmationOverlay<Item: Identifiable>(
        item: Binding<Item?>,
        title: String,
        message: @escaping (Item) -> String,
        destructiveTitle: String,
        cancelTitle: String = "Cancel",
        onConfirm: @escaping (Item) -> Void
    ) -> some View {
        modifier(
            DestructiveConfirmationOverlayModifier(
                item: item,
                title: title,
                message: message,
                destructiveTitle: destructiveTitle,
                cancelTitle: cancelTitle,
                onConfirm: onConfirm
            )
        )
    }
}

private struct DestructiveConfirmationOverlayModifier<Item: Identifiable>: ViewModifier {
    @Binding var item: Item?
    let title: String
    let message: (Item) -> String
    let destructiveTitle: String
    let cancelTitle: String
    let onConfirm: (Item) -> Void

    func body(content: Content) -> some View {
        content
            .overlay {
                if let item {
                    ZStack {
                        Color.black.opacity(0.32)
                            .ignoresSafeArea()
                            .onTapGesture { self.item = nil }

                        VStack(spacing: AppTheme.Spacing.large) {
                            VStack(spacing: AppTheme.Spacing.small) {
                                Text(title)
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(AppTheme.Editorial.primaryText)
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: .infinity)

                                Text(message(item))
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.Editorial.secondaryText)
                                    .multilineTextAlignment(.center)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            VStack(spacing: AppTheme.Spacing.small) {
                                Button(role: .destructive) {
                                    onConfirm(item)
                                } label: {
                                    Text(destructiveTitle)
                                        .font(.body.weight(.semibold))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, AppTheme.Spacing.small)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(AppTheme.error)

                                Button(cancelTitle, role: .cancel) {
                                    self.item = nil
                                }
                                .font(.body.weight(.semibold))
                            }
                        }
                        .padding(AppTheme.Spacing.large)
                        .frame(maxWidth: 380)
                        .background(AppTheme.Editorial.raisedCard)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.xLarge, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.Radius.xLarge, style: .continuous)
                                .stroke(AppTheme.Editorial.border, lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.18), radius: 24, y: 12)
                        .padding(.horizontal, AppTheme.Spacing.large)
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    .zIndex(10)
                }
            }
            .animation(.snappy, value: item?.id)
    }
}

struct SwipeRevealActionRow<Content: View>: View {
    let actionTitle: String
    let actionSystemImage: String
    var actionTint: Color = AppTheme.error
    var actionAccessibilityLabel: String? = nil
    var action: () -> Void
    @ViewBuilder var content: Content

    @State private var isActionRevealed = false
    @State private var dragOffset: CGFloat = 0

    private let actionWidth: CGFloat = 96

    private var horizontalOffset: CGFloat {
        let baseOffset = isActionRevealed ? -actionWidth : 0
        return min(0, max(-actionWidth, baseOffset + dragOffset))
    }

    private var isActionVisible: Bool {
        horizontalOffset < -1
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            Button(role: .destructive) {
                withAnimation(.snappy) {
                    isActionRevealed = false
                }
                action()
            } label: {
                VStack(spacing: AppTheme.Spacing.xSmall) {
                    Image(systemName: actionSystemImage)
                        .font(.headline)
                    Text(actionTitle)
                        .font(.caption.weight(.semibold))
                }
                .frame(width: actionWidth)
                .frame(maxHeight: .infinity)
                .foregroundStyle(.white)
                .background(actionTint)
            }
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.large, style: .continuous))
            .opacity(isActionVisible ? 1 : 0)
            .allowsHitTesting(isActionVisible)
            .accessibilityHidden(!isActionVisible)
            .accessibilityLabel(actionAccessibilityLabel ?? actionTitle)

            content
                .offset(x: horizontalOffset)
                .highPriorityGesture(
                    DragGesture(minimumDistance: 18)
                        .onChanged { value in
                            guard abs(value.translation.width) > abs(value.translation.height) else {
                                dragOffset = 0
                                return
                            }
                            dragOffset = value.translation.width
                        }
                        .onEnded { value in
                            guard abs(value.translation.width) > abs(value.translation.height) else {
                                dragOffset = 0
                                return
                            }
                            let finalOffset = horizontalOffset
                            withAnimation(.snappy) {
                                if value.translation.width < -40 {
                                    isActionRevealed = true
                                } else if value.translation.width > 30 {
                                    isActionRevealed = false
                                } else {
                                    isActionRevealed = finalOffset < -(actionWidth / 2)
                                }
                                dragOffset = 0
                            }
                        }
                )
                .accessibilityAction(named: Text(actionTitle)) {
                    action()
                }
        }
        .clipped()
        .onDisappear {
            isActionRevealed = false
            dragOffset = 0
        }
    }
}

// MARK: - Calm Editorial shared primitives (variant 004)

struct EditorialSectionHeader: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xSmall) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .kerning(1.2)
                .foregroundStyle(AppTheme.Editorial.secondaryText)

            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Editorial.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct EditorialTripRow: View {
    let trip: TripPlan
    var subtitle: String?
    var meta: String?
    var status: TripStatus?
    var action: (() -> Void)?

    var body: some View {
        Group {
            if let action {
                Button(action: action) { rowContent }
                    .buttonStyle(.plain)
            } else {
                rowContent
            }
        }
        .accessibilityLabel(trip.viewModel.tripName)
    }

    private var rowContent: some View {
        HStack(spacing: AppTheme.Spacing.medium) {
                Text(trip.emoji)
                    .font(.title)
                    .frame(width: 48, height: 48)
                    .background(AppTheme.Editorial.raisedCard)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.Radius.medium, style: .continuous)
                            .stroke(AppTheme.Editorial.border, lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(trip.viewModel.tripName)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(AppTheme.Editorial.primaryText)
                            .lineLimit(1)

                        if let status, let badge = status.badgeText {
                            Text(badge)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(status.tint)
                                .clipShape(Capsule())
                        }
                    }

                    Text(subtitle ?? trip.dateRangeText)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Editorial.secondaryText)
                        .lineLimit(1)

                    if let meta {
                        Text(meta)
                            .font(.caption)
                            .foregroundStyle(AppTheme.Editorial.secondaryText)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.Editorial.secondaryText)
            }
            .padding(AppTheme.Spacing.medium)
            .background(AppTheme.Editorial.card)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.large, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radius.large, style: .continuous)
                    .stroke(AppTheme.Editorial.border, lineWidth: 1)
            )
    }
}

struct CountdownDuration: Equatable {
    let days: Int
    let hours: Int
    let minutes: Int
    let seconds: Int

    init(from start: Date, to end: Date) {
        self.init(from: start.timeIntervalSince1970, to: end.timeIntervalSince1970)
    }

    init(from start: TimeInterval, to end: TimeInterval) {
        let totalSeconds = max(0, Int(end.rounded(.down) - start.rounded(.down)))
        days = totalSeconds / 86_400
        hours = (totalSeconds % 86_400) / 3_600
        minutes = (totalSeconds % 3_600) / 60
        seconds = totalSeconds % 60
    }

    var accessibilityText: String {
        [
            unitText(days, singular: "day", plural: "days"),
            unitText(hours, singular: "hour", plural: "hours"),
            unitText(minutes, singular: "minute", plural: "minutes")
        ].joined(separator: ", ")
    }

    private func unitText(_ value: Int, singular: String, plural: String) -> String {
        "\(value) \(value == 1 ? singular : plural)"
    }
}

struct CountdownView: View {
    enum Variant {
        case surface
        case photoOverlay
    }

    let targetDate: Date
    var title: String
    var variant: Variant = .surface

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let duration = CountdownDuration(from: context.date, to: targetDate)

            HStack(spacing: 0) {
                countdownUnit(value: duration.days, label: "Days")
                divider
                countdownUnit(value: duration.hours, label: "Hrs")
                divider
                countdownUnit(value: duration.minutes, label: "Min")
                divider
                countdownUnit(value: duration.seconds, label: "Sec")
            }
            .padding(.top, 9)
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(duration.accessibilityText) until \(title)")
        }
    }

    private func countdownUnit(value: Int, label: String) -> some View {
        VStack(spacing: 2) {
            Text(String(format: "%02d", value))
                .font(.system(size: 22, weight: .semibold, design: .serif))
                .tracking(-1.0)
                .foregroundStyle(numberColor)
                .monospacedDigit()

            Text(label.uppercased())
                .font(.caption2.weight(.bold))
                .tracking(1.0)
                .foregroundStyle(labelColor)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity)
    }

    private var divider: some View {
        Rectangle()
            .fill(dividerColor)
            .frame(width: 1, height: 34)
            .padding(.horizontal, 2)
    }

    private var background: some ShapeStyle {
        switch variant {
        case .surface: return AnyShapeStyle(AppTheme.Editorial.raisedCard)
        case .photoOverlay: return AnyShapeStyle(.white.opacity(0.14))
        }
    }

    private var borderColor: Color {
        switch variant {
        case .surface: return AppTheme.Editorial.border
        case .photoOverlay: return .white.opacity(0.32)
        }
    }

    private var dividerColor: Color {
        switch variant {
        case .surface: return AppTheme.Editorial.border.opacity(0.70)
        case .photoOverlay: return .white.opacity(0.26)
        }
    }

    private var numberColor: Color {
        switch variant {
        case .surface: return AppTheme.Editorial.forestDeep
        case .photoOverlay: return Color(red: 1.0, green: 0.973, blue: 0.929)
        }
    }

    private var labelColor: Color {
        switch variant {
        case .surface: return AppTheme.Editorial.secondaryText
        case .photoOverlay: return .white.opacity(0.82)
        }
    }
}

struct TripPhotoHero: View {
    let trip: TripPlan
    var eyebrow: String
    var title: String
    var metadata: String
    var statusPill: String?
    var showsCountdown: Bool = true

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RemoteTripImage(urlString: trip.imageURL)

            LinearGradient(
                colors: [.black.opacity(0.08), .black.opacity(0.22), .black.opacity(0.82)],
                startPoint: .top,
                endPoint: .bottom
            )

            if let statusPill {
                Text(statusPill)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.white.opacity(0.18))
                    .clipShape(Capsule())
                    .padding(12)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(eyebrow.uppercased())
                    .font(.caption2.weight(.bold))
                    .tracking(1.3)
                    .foregroundStyle(AppTheme.Editorial.sand)

                Text(title)
                    .font(.system(size: 28, weight: .semibold, design: .serif))
                    .tracking(-0.8)
                    .foregroundStyle(Color(red: 1.0, green: 0.973, blue: 0.929))
                    .lineLimit(2)

                Text(metadata)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.86))
                    .lineLimit(2)

                if showsCountdown, trip.status == .future {
                    CountdownView(targetDate: trip.startDate, title: title, variant: .photoOverlay)
                        .padding(.top, 7)
                }
            }
            .padding(16)
        }
        .frame(minHeight: 240)
        .frame(height: 292)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.hero, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.Radius.hero, style: .continuous)
                .stroke(.white.opacity(0.16), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}

struct WanderaidLogoMark: View {
    var size: CGFloat

    var body: some View {
        Image("WanderaidLogoTransparent")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

/// Reusable multi-select participant row list for add/edit sheets.
/// Avatar + name + checkmark rows (not chips); hidden when no people exist.
struct ParticipantPickerSection: View {
    let participants: [Participant]
    @Binding var selectedIDs: [UUID]

    private var sortedParticipants: [Participant] {
        participants.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        Section {
            VStack(spacing: 0) {
                ForEach(Array(sortedParticipants.enumerated()), id: \.element.id) { index, participant in
                    Button {
                        toggle(participant.id)
                    } label: {
                        HStack(spacing: AppTheme.Spacing.medium) {
                            AvatarInitial(name: participant.name, size: 32)

                            Text(participant.name)
                                .font(.body)
                                .foregroundStyle(AppTheme.Editorial.primaryText)

                            Spacer(minLength: 0)

                            Image(systemName: isSelected(participant.id) ? "checkmark.circle.fill" : "circle")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(isSelected(participant.id) ? AppTheme.Editorial.forest : AppTheme.Editorial.border)
                        }
                        .padding(.vertical, AppTheme.Spacing.small)
                        .contentShape(Rectangle())
                        .frame(minHeight: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(participant.name), \(isSelected(participant.id) ? "selected" : "not selected")")

                    if index < sortedParticipants.count - 1 {
                        Divider()
                    }
                }
            }
        } header: {
            EditorialSectionHeader(title: "Who's in?")
        }
    }

    private func isSelected(_ participantID: UUID) -> Bool {
        selectedIDs.contains(participantID)
    }

    private func toggle(_ participantID: UUID) {
        if isSelected(participantID) {
            selectedIDs.removeAll { $0 == participantID }
        } else {
            selectedIDs.append(participantID)
        }
    }
}

struct WaniIconBadge: View {
    enum BadgeShape {
        case roundedSquare
        case circle
    }

    let systemImage: String
    let tint: Color
    var size: CGFloat = AppTheme.IconSize.medium
    var cornerRadius: CGFloat = AppTheme.Radius.medium
    var badgeShape: BadgeShape = .roundedSquare

    var body: some View {
        Group {
            switch badgeShape {
            case .roundedSquare:
                iconBody
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            case .circle:
                iconBody
                    .clipShape(Circle())
            }
        }
    }

    private var iconBody: some View {
        Image(systemName: systemImage)
            .font(.title3.weight(.semibold))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(tint.opacity(0.1))
    }
}

struct WaniPreviewRow: View {
    let icon: String
    let title: String
    var subtitle: String?
    var status: String?
    var tint: Color = AppTheme.Editorial.forest

    var body: some View {
        HStack(spacing: AppTheme.Spacing.small) {
            Image(systemName: icon)
                .foregroundStyle(tint)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(subtitle == nil ? .regular : .medium))
                    .foregroundStyle(AppTheme.Editorial.primaryText)
                    .lineLimit(1)

                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            if let status {
                Text(status)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tint)
            }
        }
    }
}

struct WaniPrimaryActionButton: View {
    let title: String
    var systemImage: String?
    var tint: Color = AppTheme.Editorial.forest
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            if let systemImage {
                Label(title, systemImage: systemImage)
                    .font(.headline)
            } else {
                Text(title)
                    .font(.headline)
            }
        }
        .buttonStyle(.borderedProminent)
        .tint(tint)
    }
}

struct ActionCard: View {
    let title: String
    let description: String
    let systemImage: String
    let tint: Color

    var body: some View {
        WaniCard {
            HStack(spacing: AppTheme.Spacing.large) {
                WaniIconBadge(systemImage: systemImage, tint: tint, size: AppTheme.IconSize.large, cornerRadius: AppTheme.Radius.large)

                VStack(alignment: .leading, spacing: AppTheme.Spacing.xSmall) {
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
                    .foregroundStyle(AppTheme.Editorial.secondaryText)
            }
        }
    }
}

struct PlaceholderActionCard: View {
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

struct EmptyTripsView: View {
    var joinTrip: (() -> Void)?
    var createTrip: () -> Void

    var body: some View {
        VStack(spacing: AppTheme.Spacing.large) {
            WanderaidLogoMark(size: AppTheme.IconSize.xLarge + AppTheme.Spacing.medium)

            VStack(spacing: AppTheme.Spacing.xSmall + 2) {
                Text("No trips yet")
                    .font(.title3.weight(.semibold))
                Text(joinTrip == nil ? "Create your first trip to start organizing the details" : "Create a new trip or join one from a friend’s invite code.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: AppTheme.Spacing.small) {
                WaniPrimaryActionButton(title: "Create Your First Trip", systemImage: "plus", action: createTrip)

                if let joinTrip {
                    Button(action: joinTrip) {
                        Label("Join with Invite Code", systemImage: "link.badge.plus")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Join a trip with an invite code")
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 64)
    }
}

struct EmptyFeatureCard: View {
    let title: String
    let subtitle: String

    var body: some View {
        WaniCard {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xSmall + 2) {
                Text(title)
                    .font(.body.weight(.semibold))
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct EmptyRow: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .foregroundStyle(.secondary)
    }
}

struct RemoteTripImage: View {
    let urlString: String

    var body: some View {
        GeometryReader { proxy in
            AsyncImage(url: URL(string: urlString)) { phase in
                switch phase {
                case .empty:
                    Rectangle()
                        .fill(AppTheme.Editorial.card)
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
                        .fill(AppTheme.Editorial.forest.opacity(0.15))
                        .overlay {
                            Image(systemName: "photo")
                                .font(.title2)
                                .foregroundStyle(AppTheme.Editorial.forest)
                        }
                @unknown default:
                    Rectangle().fill(AppTheme.Editorial.card)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
    }
}

struct AvatarCluster: View {
    let participants: [Participant]
    var size: CGFloat = 32
    var maxVisible: Int = 5

    var body: some View {
        HStack(spacing: -8) {
            ForEach(Array(participants.prefix(maxVisible).enumerated()), id: \.element.id) { index, participant in
                AvatarInitial(name: participant.name, size: size, color: avatarColor(index))
                    .overlay {
                        Circle().stroke(AppTheme.Editorial.background, lineWidth: 2)
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

struct AvatarInitial: View {
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

extension TripPlanDate {
    static let shortStart: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMM d")
        return formatter
    }()
}

// MARK: - Calm Editorial form controls (inputs & dropdowns)

/// Shared label style for editorial form fields: uppercase caption with letterspacing.
struct EditorialFieldLabel: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(.caption.weight(.semibold))
            .kerning(1.2)
            .foregroundStyle(AppTheme.Editorial.secondaryText)
    }
}

/// Card shell for a form control: raised surface, hairline border, soft radius.
/// Pass `isHighlighted` (e.g. focused text input) for the forest emphasis ring.
struct EditorialFieldCard<Content: View>: View {
    var isHighlighted: Bool = false
    @ViewBuilder var content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppTheme.Spacing.large)
            .padding(.vertical, AppTheme.Spacing.medium)
            .background(AppTheme.Editorial.raisedCard)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radius.medium, style: .continuous)
                    .stroke(
                        isHighlighted ? AppTheme.Editorial.forest : AppTheme.Editorial.border,
                        lineWidth: isHighlighted ? 1.5 : 1
                    )
            )
    }
}

/// Text input matching the Calm Editorial language: optional uppercase label,
/// raised card field, muted placeholder, forest focus ring.
struct EditorialTextField: View {
    var label: String? = nil
    let placeholder: String
    @Binding var text: String
    var axis: Axis = .horizontal
    var lineLimit: ClosedRange<Int>? = nil
    var isSecure: Bool = false
    var keyboardType: UIKeyboardType = .default
    var textContentType: UITextContentType? = nil
    var autocapitalization: TextInputAutocapitalization? = nil
    var autocorrectionDisabled: Bool = false
    var multilineTextAlignment: TextAlignment = .leading
    var font: Font = .body

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xSmall + 2) {
            if let label {
                EditorialFieldLabel(title: label)
            }

            EditorialFieldCard(isHighlighted: isFocused) {
                ZStack(alignment: .leading) {
                    if text.isEmpty {
                        Text(placeholder)
                            .font(font)
                            .foregroundStyle(AppTheme.Editorial.secondaryText)
                            .multilineTextAlignment(multilineTextAlignment)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }

                    inputControl
                        .font(font)
                        .focused($isFocused)
                        .foregroundStyle(AppTheme.Editorial.primaryText)
                        .tint(AppTheme.Editorial.forest)
                        .keyboardType(keyboardType)
                        .textContentType(textContentType)
                        .textInputAutocapitalization(autocapitalization)
                        .autocorrectionDisabled(autocorrectionDisabled)
                        .multilineTextAlignment(multilineTextAlignment)
                        .accessibilityLabel(label ?? placeholder)
                }
            }
        }
    }

    @ViewBuilder
    private var inputControl: some View {
        if isSecure {
            SecureField("", text: $text)
        } else if let lineLimit {
            TextField("", text: $text, axis: axis)
                .lineLimit(lineLimit.lowerBound...lineLimit.upperBound)
        } else {
            TextField("", text: $text, axis: axis)
        }
    }
}

/// Dropdown matching the editorial field language: a menu with checkmark
/// selection, shown as a raised card field with a chevron affordance.
struct EditorialMenuField<Value: Hashable>: View {
    let label: String?
    let accessibilityLabel: String?
    @Binding var selection: Value
    let options: [Value]
    let display: (Value) -> String

    init(
        _ label: String? = nil,
        selection: Binding<Value>,
        options: [Value],
        display: @escaping (Value) -> String,
        accessibilityLabel: String? = nil
    ) {
        self.label = label
        self.accessibilityLabel = accessibilityLabel
        self._selection = selection
        self.options = options
        self.display = display
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xSmall + 2) {
            if let label {
                EditorialFieldLabel(title: label)
            }

            Menu {
                ForEach(options, id: \.self) { option in
                    Button {
                        selection = option
                    } label: {
                        if option == selection {
                            Label(display(option), systemImage: "checkmark")
                        } else {
                            Text(display(option))
                        }
                    }
                }
            } label: {
                HStack(spacing: AppTheme.Spacing.medium) {
                    Text(display(selection))
                        .font(.body)
                        .foregroundStyle(AppTheme.Editorial.primaryText)
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.Editorial.secondaryText)
                }
                .padding(.horizontal, AppTheme.Spacing.large)
                .padding(.vertical, AppTheme.Spacing.medium)
                .frame(maxWidth: .infinity)
                .background(AppTheme.Editorial.raisedCard)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.Radius.medium, style: .continuous)
                        .stroke(AppTheme.Editorial.border, lineWidth: 1)
                )
            }
            .accessibilityLabel(accessibilityLabel ?? label ?? "Selection")
            .accessibilityValue(display(selection))
        }
    }
}

/// Date picker shown as an editorial field card (compact picker inside a raised card).
struct EditorialDateField: View {
    let label: String?
    @Binding var selection: Date
    var displayedComponents: DatePickerComponents = .date
    var inRange: ClosedRange<Date>? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xSmall + 2) {
            if let label {
                EditorialFieldLabel(title: label)
            }

            EditorialFieldCard {
                HStack(spacing: AppTheme.Spacing.medium) {
                    Image(systemName: "calendar")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Editorial.forest)
                        .accessibilityHidden(true)

                    Spacer(minLength: 0)

                    Group {
                        if let inRange {
                            DatePicker("", selection: $selection, in: inRange, displayedComponents: displayedComponents)
                        } else {
                            DatePicker("", selection: $selection, displayedComponents: displayedComponents)
                        }
                    }
                    .labelsHidden()
                    .tint(AppTheme.Editorial.forest)
                    .foregroundStyle(AppTheme.Editorial.primaryText)
                    .accessibilityLabel(label ?? "Date")
                }
            }
        }
    }
}

/// Toggle row for editorial card lists (e.g. split-among participants).
struct EditorialToggleRow: View {
    let title: String
    var subtitle: String? = nil
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: AppTheme.Spacing.medium) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .foregroundStyle(AppTheme.Editorial.primaryText)

                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(AppTheme.Editorial.secondaryText)
                }
            }

            Spacer(minLength: 0)

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(AppTheme.Editorial.forest)
                .accessibilityLabel(title)
        }
    }
}

/// Capsule segmented control in editorial colors (raised card shell, forest active pill).
struct EditorialSegmentedControl<Value: Hashable>: View {
    let options: [Value]
    @Binding var selection: Value
    var display: (Value) -> String
    var accessibilityLabel: String? = nil

    var body: some View {
        HStack(spacing: AppTheme.Spacing.xSmall) {
            ForEach(options, id: \.self) { option in
                let isSelected = option == selection
                Button {
                    withAnimation(.snappy) {
                        selection = option
                    }
                } label: {
                    Text(display(option))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isSelected ? AppTheme.Editorial.forestDeep : AppTheme.Editorial.secondaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppTheme.Spacing.small)
                        .background(isSelected ? AppTheme.Editorial.forest.opacity(0.14) : .clear)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : AccessibilityTraits())
            }
        }
        .padding(AppTheme.Spacing.xSmall)
        .background(AppTheme.Editorial.raisedCard)
        .clipShape(Capsule())
        .overlay(
            Capsule().stroke(AppTheme.Editorial.border, lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityLabel ?? "")
    }
}

extension View {
    /// Strips a Form's stock grouped chrome so rows read as editorial cards
    /// floating on the warm paper background. Pair with the paper background:
    /// `.editorialForm().background(AppTheme.Editorial.background)`.
    func editorialForm() -> some View {
        self
            .scrollContentBackground(.hidden)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(
                EdgeInsets(
                    top: AppTheme.Spacing.small,
                    leading: AppTheme.Spacing.large,
                    bottom: AppTheme.Spacing.small,
                    trailing: AppTheme.Spacing.large
                )
            )
    }
}
