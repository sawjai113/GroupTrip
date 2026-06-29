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

enum AuthSessionState: Equatable {
    case signedIn(userID: UUID, email: String?)
    case signedOut
}

protocol AuthServicing {
    var sessionStates: AsyncStream<AuthSessionState> { get }

    func sendMagicLink(email: String, displayName: String?) async throws
    func signInWithGoogle() async throws
    func signOut() async throws
    func bootstrapProfile(userID: UUID, email: String?) async throws
}

struct SupabaseAuthService: AuthServicing {
    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseConfig.client) {
        self.client = client
    }

    var sessionStates: AsyncStream<AuthSessionState> {
        AsyncStream { continuation in
            let task = Task {
                for await (_, session) in client.auth.authStateChanges {
                    if let user = session?.user {
                        continuation.yield(.signedIn(userID: user.id, email: user.email))
                    } else {
                        continuation.yield(.signedOut)
                    }
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    func sendMagicLink(email: String, displayName: String?) async throws {
        var data: [String: AnyJSON]?
        if let displayName, !displayName.isEmpty {
            data = ["display_name": .string(displayName)]
        }

        try await client.auth.signInWithOTP(
            email: email,
            shouldCreateUser: true,
            data: data
        )
    }

    func signInWithGoogle() async throws {
        try await client.auth.signInWithOAuth(
            provider: .google,
            redirectTo: SupabaseConfig.googleOAuthRedirectURL,
            queryParams: SupabaseConfig.googleOAuthQueryParams
        ) { session in
            session.prefersEphemeralWebBrowserSession = SupabaseConfig.googleOAuthPrefersEphemeralWebSession
        }
    }

    func signOut() async throws {
        try await client.auth.signOut()
    }

    func bootstrapProfile(userID: UUID, email: String?) async throws {
        let profile = SupabaseProfileBootstrapDTO(
            id: userID,
            displayName: email.flatMap(Self.defaultDisplayName)
        )

        try await client
            .from("profiles")
            .upsert(profile, onConflict: "id", ignoreDuplicates: true)
            .execute()
    }

    private static func defaultDisplayName(from email: String) -> String? {
        let name = email.split(separator: "@").first.map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return name?.isEmpty == false ? name : nil
    }
}

struct SupabaseProfileBootstrapDTO: Codable, Hashable {
    var id: UUID
    var displayName: String?

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
    }
}

@MainActor
final class AuthViewModel: ObservableObject {
    @Published private(set) var isAuthenticated = false
    @Published private(set) var isLoading = true
    @Published var authError: String?
    @Published var authMessage: String?

    private let service: AuthServicing

    init(service: AuthServicing = SupabaseAuthService()) {
        self.service = service
        listenForAuthChanges()
    }

    func requestMagicLink(email: String, displayName: String) async {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDisplayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard Self.isValidEmail(trimmedEmail) else {
            authError = "Enter a valid email address."
            authMessage = nil
            isLoading = false
            return
        }

        await runAuthAction(successMessage: "Check your email for a Wanderaid sign-in link.") {
            try await service.sendMagicLink(
                email: trimmedEmail,
                displayName: trimmedDisplayName.isEmpty ? nil : trimmedDisplayName
            )
        }
    }

    func signInWithGoogle() async {
        await runAuthAction {
            try await service.signInWithGoogle()
        }
    }

    func signOut() async {
        await runAuthAction {
            try await service.signOut()
        }
    }

    private func listenForAuthChanges() {
        Task { [service] in
            for await state in service.sessionStates {
                switch state {
                case let .signedIn(userID, email):
                    do {
                        try await service.bootstrapProfile(userID: userID, email: email)
                        isAuthenticated = true
                        authError = nil
                    } catch {
                        authError = error.localizedDescription
                        isAuthenticated = false
                    }
                case .signedOut:
                    isAuthenticated = false
                }
                isLoading = false
            }
        }
    }

    private func runAuthAction(successMessage: String? = nil, _ action: () async throws -> Void) async {
        isLoading = true
        authError = nil
        authMessage = nil

        do {
            try await action()
            authMessage = successMessage
            isLoading = false
        } catch {
            authError = error.localizedDescription
            isLoading = false
        }
    }

    private static func isValidEmail(_ email: String) -> Bool {
        let parts = email.split(separator: "@")
        guard parts.count == 2 else { return false }
        return parts[0].isEmpty == false && parts[1].contains(".")
    }
}
