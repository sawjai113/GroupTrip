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
                .frame(width: 44, height: 44)
                .background(.white.opacity(0.92))
                .clipShape(Circle())
        }
        .accessibilityLabel("Back")
    }
}

struct ActionCard: View {
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
        VStack(spacing: 16) {
            Image(systemName: "paperplane")
                .font(.system(size: 62))
                .foregroundStyle(.tertiary)

            VStack(spacing: 6) {
                Text("No trips yet")
                    .font(.title3.weight(.semibold))
                Text("Create your first trip to start organizing the details")
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

struct EmptyFeatureCard: View {
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
