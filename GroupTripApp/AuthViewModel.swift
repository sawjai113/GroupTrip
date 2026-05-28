import Foundation
import Supabase

@MainActor
final class AuthViewModel: ObservableObject {
    @Published private(set) var isAuthenticated = false
    @Published private(set) var isLoading = true
    @Published private(set) var isUsingTestMode = false
    @Published var authError: String?
    @Published var authMessage: String?

    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseConfig.client) {
        self.client = client
        listenForAuthChanges()
    }

    func signIn(email: String, password: String) async {
        await runAuthAction {
            try await client.auth.signIn(email: email, password: password)
        }
    }

    func signUp(email: String, password: String) async {
        isLoading = true
        authError = nil
        authMessage = nil

        do {
            try await client.auth.signUp(email: email, password: password)
            authMessage = "Account created. Check your email to confirm your account, then sign in."
        } catch {
            authError = error.localizedDescription
        }

        isLoading = false
    }

    func signOut() async {
        if isUsingTestMode {
            isUsingTestMode = false
            isAuthenticated = false
            return
        }

        await runAuthAction {
            try await client.auth.signOut()
        }
    }

    func continueWithTestMode() {
        authError = nil
        authMessage = nil
        isLoading = false
        isUsingTestMode = true
        isAuthenticated = true
    }

    private func listenForAuthChanges() {
        Task {
            for await (_, session) in await client.auth.authStateChanges {
                guard !isUsingTestMode else { continue }
                isAuthenticated = session != nil
                isLoading = false
            }
        }
    }

    private func runAuthAction(_ action: () async throws -> Void) async {
        isLoading = true
        authError = nil
        authMessage = nil

        do {
            try await action()
            isLoading = false
        } catch {
            authError = error.localizedDescription
            isLoading = false
        }
    }
}
