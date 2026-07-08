import SwiftUI
import AuthenticationServices
import CryptoKit
import Security

struct AuthGateView: View {
    @StateObject private var appSession = AppSession()
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var remoteTripStore = TripStore(service: SupabaseTripService())
    @StateObject private var demoTripStore = TripStore.sample

    var body: some View {
        Group {
            switch appSession.mode {
            case nil:
                if authViewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(AppTheme.background)
                } else {
                    ModeSelectionView(
                        chooseDemoMode: appSession.chooseDemoMode,
                        chooseSignedInMode: appSession.chooseSignedInMode
                    )
                }
            case .demo:
                TripDashboardView(store: demoTripStore, modeBadge: .demo) {
                    appSession.returnToModePicker()
                }
            case .signedIn:
                signedInModeView
            }
        }
        .onAppear {
            appSession.restoreSignedInModeIfAuthenticated(authViewModel.isAuthenticated)
        }
        .onChange(of: authViewModel.isAuthenticated) { _, isAuthenticated in
            appSession.restoreSignedInModeIfAuthenticated(isAuthenticated)
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
                    WanderaidLogoMark(size: 72)

                    Text("Wanderaid")
                        .font(.largeTitle.weight(.bold))

                    Text("Choose how you want to plan right now.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: AppTheme.Spacing.medium) {
                    ModeChoiceCard(
                        title: "Try Demo",
                        subtitle: "Explore Wanderaid with sample trips. Nothing here syncs to Supabase.",
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
    @State private var currentAppleSignInNonce: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                VStack(spacing: 10) {
                    WanderaidLogoMark(size: 68)

                    Text("Wanderaid")
                        .font(.largeTitle.weight(.bold))

                    Text("Sign in with Google or Apple, or use a magic link to save and sync cloud trips.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 12) {
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
                        Task { await viewModel.signInWithGoogle() }
                    } label: {
                        if viewModel.isLoading {
                            ProgressView()
                                .tint(.white)
                                .frame(maxWidth: .infinity)
                        } else {
                            Label("Continue with Google", systemImage: "g.circle.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.primary)
                    .disabled(viewModel.isLoading)

                    SignInWithAppleButton(.continue) { request in
                        let nonce = Self.randomNonceString()
                        currentAppleSignInNonce = nonce
                        request.requestedScopes = [.fullName, .email]
                        request.nonce = Self.sha256(nonce)
                    } onCompletion: { result in
                        handleAppleSignInCompletion(result)
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .disabled(viewModel.isLoading)

                    VStack(spacing: 0) {
                        Divider()
                            .padding(.vertical, 8)

                        Text("Or sign in with a magic link:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

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
                    .tint(AppTheme.warning)
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

    private func handleAppleSignInCompletion(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case let .success(authorization):
            guard
                let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                let identityToken = credential.identityToken,
                let idToken = String(data: identityToken, encoding: .utf8)
            else {
                viewModel.authError = "Apple sign-in did not return a usable identity token."
                return
            }

            let nonce = currentAppleSignInNonce
            currentAppleSignInNonce = nil
            Task {
                await viewModel.signInWithApple(idToken: idToken, nonce: nonce)
            }
        case let .failure(error):
            currentAppleSignInNonce = nil
            viewModel.authError = error.localizedDescription
        }
    }

    private static func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            var randoms = [UInt8](repeating: 0, count: 16)
            let status = SecRandomCopyBytes(kSecRandomDefault, randoms.count, &randoms)
            guard status == errSecSuccess else {
                fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(status)")
            }

            for random in randoms where remainingLength > 0 {
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }

        return result
    }

    private static func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.map { String(format: "%02x", $0) }.joined()
    }
}
