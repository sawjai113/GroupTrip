import Foundation
import Supabase

enum AppMode: Equatable {
    case demo
    case signedIn
}

final class AppSession: ObservableObject {
    @Published private(set) var mode: AppMode?

    var shouldUseDemoTripStore: Bool {
        mode == .demo
    }

    var shouldUseCloudTripStore: Bool {
        mode == .signedIn
    }

    func chooseDemoMode() {
        mode = .demo
    }

    func chooseSignedInMode() {
        mode = .signedIn
    }

    func returnToModePicker() {
        mode = nil
    }
}

@MainActor
final class AuthViewModel: ObservableObject {
    @Published private(set) var isAuthenticated = false
    @Published private(set) var isLoading = true
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
        await runAuthAction {
            try await client.auth.signOut()
        }
    }

    private func listenForAuthChanges() {
        Task {
            for await (_, session) in await client.auth.authStateChanges {
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
