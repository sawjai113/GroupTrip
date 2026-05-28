import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel: TripCalculatorViewModel

    init(viewModel: TripCalculatorViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ExpenseTrackerView(tripName: viewModel.tripName, destination: "", viewModel: viewModel)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        TripDashboardView(store: .sample)
    }
}
