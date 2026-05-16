import SwiftUI

@main
struct GroupTripApp: App {
    var body: some Scene {
        WindowGroup {
            TripDashboardView(store: .sample)
        }
    }
}
