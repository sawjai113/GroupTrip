import SwiftUI

struct AuthGateView: View {
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var remoteTripStore = TripStore(service: SupabaseTripService())
    @StateObject private var testTripStore = TripStore.sample

    var body: some View {
        Group {
            if authViewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppTheme.background)
            } else if authViewModel.isAuthenticated {
                TripDashboardView(store: authViewModel.isUsingTestMode ? testTripStore : remoteTripStore) {
                    Task {
                        await authViewModel.signOut()
                    }
                }
            } else {
                LoginView(viewModel: authViewModel)
            }
        }
    }
}

private struct LoginView: View {
    @ObservedObject var viewModel: AuthViewModel
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

                    Button {
                        viewModel.continueWithTestMode()
                    } label: {
                        Text("Continue with Test Data")
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
