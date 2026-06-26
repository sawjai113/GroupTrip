import SwiftUI

@main
struct GroupTripApp: App {
    var body: some Scene {
        WindowGroup {
            AuthGateView()
                .onOpenURL { url in
                    SupabaseConfig.client.auth.handle(url)
                }
        }
    }
}
