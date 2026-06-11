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
    @State private var password = ""
    @State private var isCreatingAccount = false

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

                    Text("Sign in to save and sync trips.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
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

                    SecureField("Password", text: $password)
                        .textContentType(isCreatingAccount ? .newPassword : .password)
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
                            if isCreatingAccount {
                                await viewModel.signUp(email: trimmedEmail, password: password)
                            } else {
                                await viewModel.signIn(email: trimmedEmail, password: password)
                            }
                        }
                    } label: {
                        if viewModel.isLoading {
                            ProgressView()
                                .tint(.white)
                                .frame(maxWidth: .infinity)
                        } else {
                            Text(isCreatingAccount ? "Create Account" : "Sign In")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.primary)
                    .disabled(!canSubmit || viewModel.isLoading)

                    Button {
                        isCreatingAccount.toggle()
                    } label: {
                        Text(isCreatingAccount ? "Already have an account? Sign in" : "Need an account? Create one")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(AppTheme.primary)

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
        trimmedEmail.contains("@") && password.count >= 6
    }
}
