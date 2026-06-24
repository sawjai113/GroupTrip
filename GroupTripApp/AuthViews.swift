import SwiftUI

struct AuthGateView: View {
    @StateObject private var appSession = AppSession()
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var remoteTripStore = TripStore(service: SupabaseTripService())
    @StateObject private var demoTripStore = TripStore.sample

    var body: some View {
        Group {
            switch appSession.mode {
            case nil:
                ModeSelectionView(
                    chooseDemoMode: appSession.chooseDemoMode,
                    chooseSignedInMode: appSession.chooseSignedInMode
                )
            case .demo:
                TripDashboardView(store: demoTripStore, modeBadge: .demo) {
                    appSession.returnToModePicker()
                }
            case .signedIn:
                signedInModeView
            }
        }
    }

    @ViewBuilder
    private var signedInModeView: some View {
        if authViewModel.isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppTheme.background)
        } else if authViewModel.isAuthenticated {
            TripDashboardView(store: remoteTripStore, modeBadge: .cloud) {
                Task {
                    await authViewModel.signOut()
                }
            }
        } else {
            LoginView(viewModel: authViewModel, exitToModePicker: appSession.returnToModePicker)
        }
    }
}

private struct ModeSelectionView: View {
    var chooseDemoMode: () -> Void
    var chooseSignedInMode: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: AppTheme.Spacing.xLarge) {
                Spacer()

                VStack(spacing: AppTheme.Spacing.medium) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(AppTheme.primary)

                    Text("Wani")
                        .font(.largeTitle.weight(.bold))

                    Text("Choose how you want to plan right now.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: AppTheme.Spacing.medium) {
                    ModeChoiceCard(
                        title: "Try Demo",
                        subtitle: "Explore Wani with sample trips. Nothing here syncs to Supabase.",
                        systemImage: "sparkles",
                        tint: AppTheme.warning,
                        action: chooseDemoMode
                    )

                    ModeChoiceCard(
                        title: "Sign in / Create account",
                        subtitle: "Use your cloud-backed trips and collaboration features.",
                        systemImage: "person.crop.circle.badge.checkmark",
                        tint: AppTheme.primary,
                        action: chooseSignedInMode
                    )
                }

                Spacer()
            }
            .padding(AppTheme.Spacing.xLarge)
            .background(AppTheme.background)
        }
    }
}

private struct ModeChoiceCard: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            WaniCard {
                HStack(spacing: AppTheme.Spacing.large) {
                    WaniIconBadge(systemImage: systemImage, tint: tint, size: AppTheme.IconSize.large)

                    VStack(alignment: .leading, spacing: AppTheme.Spacing.xSmall) {
                        Text(title)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.right")
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

private struct LoginView: View {
    @ObservedObject var viewModel: AuthViewModel
    var exitToModePicker: () -> Void
    @State private var email = ""
    @State private var displayName = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                VStack(spacing: 10) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 52))
                        .foregroundStyle(AppTheme.primary)

                    Text("Wani")
                        .font(.largeTitle.weight(.bold))

                    Text("Send yourself a magic link to save and sync cloud trips.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 12) {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(12)
                        .background(AppTheme.paper)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    TextField("Display name", text: $displayName)
                        .textContentType(.name)
                        .padding(12)
                        .background(AppTheme.paper)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    if let authError = viewModel.authError {
                        Text(authError)
                            .font(.footnote)
                            .foregroundStyle(AppTheme.error)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if let authMessage = viewModel.authMessage {
                        Text(authMessage)
                            .font(.footnote)
                            .foregroundStyle(AppTheme.success)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button {
                        Task {
                            await viewModel.requestMagicLink(email: trimmedEmail, displayName: displayName)
                        }
                    } label: {
                        if viewModel.isLoading {
                            ProgressView()
                                .tint(.white)
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Send Magic Link")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.primary)
                    .disabled(!canSubmit || viewModel.isLoading)

                    Text("No password needed. Supabase will email a secure sign-in link.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    Button(action: exitToModePicker) {
                        Text("Back to mode selection")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()
            }
            .padding(24)
            .background(AppTheme.background)
        }
    }

    private var trimmedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSubmit: Bool {
        trimmedEmail.contains("@")
    }
}
