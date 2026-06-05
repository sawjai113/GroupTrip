import SwiftUI

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
            .background(AppTheme.paper)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

struct WaniSectionHeader: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xSmall + 2) {
            Text(title)
                .font(.title2.weight(.semibold))

            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
    var tint: Color = AppTheme.primary

    var body: some View {
        HStack(spacing: AppTheme.Spacing.small) {
            Image(systemName: icon)
                .foregroundStyle(tint)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(subtitle == nil ? .regular : .medium))
                    .foregroundStyle(.primary)
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
    var tint: Color = AppTheme.primary
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
                    .foregroundStyle(.tertiary)
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
    var createTrip: () -> Void

    var body: some View {
        VStack(spacing: AppTheme.Spacing.large) {
            Image(systemName: "paperplane")
                .font(.system(size: AppTheme.IconSize.xLarge))
                .foregroundStyle(.tertiary)

            VStack(spacing: AppTheme.Spacing.xSmall + 2) {
                Text("No trips yet")
                    .font(.title3.weight(.semibold))
                Text("Create your first trip to start organizing the details")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            WaniPrimaryActionButton(title: "Create Your First Trip", systemImage: "plus", action: createTrip)
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

struct AvatarCluster: View {
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
