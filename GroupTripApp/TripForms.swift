import SwiftUI

struct NewTripView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: TripStore
    @State private var name = ""
    @State private var destination = ""
    @State private var emoji = "✈️"
    @State private var startDate = Date()
    @State private var endDate = Date()
    @State private var selectedImageURL = CoverImage.defaultOptions[0].url
    @State private var customImageURL = ""
    @State private var isCreatingTrip = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Trip Name", text: $name)
                    TextField("Destination", text: $destination)
                    TextField("Emoji", text: $emoji)
                        .font(.title2)
                        .multilineTextAlignment(.center)
                        .onChange(of: emoji) { _, newValue in
                            emoji = String(newValue.prefix(2))
                        }
                }

                Section("Dates") {
                    DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                    DatePicker("End Date", selection: $endDate, in: startDate..., displayedComponents: .date)
                }

                Section("Cover Image") {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(CoverImage.defaultOptions) { image in
                            Button {
                                selectedImageURL = image.url
                                customImageURL = ""
                            } label: {
                                RemoteTripImage(urlString: image.url)
                                    .frame(height: 82)
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .stroke(selectedImageURL == image.url && customImageURL.isEmpty ? AppTheme.primary : .clear, lineWidth: 3)
                                    }
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(image.title)
                        }
                    }

                    TextField("Or paste custom image URL", text: $customImageURL)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                }

                if let syncError = store.syncError {
                    Section {
                        Label(syncError, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(AppTheme.error)
                            .font(.footnote)
                    }
                }
            }
            .navigationTitle("Create New Trip")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isCreatingTrip)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            isCreatingTrip = true
                            let didCreate = await store.addRemoteTrip(
                                name: name,
                                destination: destination,
                                emoji: emoji,
                                imageURL: customImageURL.isEmpty ? selectedImageURL : customImageURL,
                                startDate: startDate,
                                endDate: endDate
                            )
                            isCreatingTrip = false
                            if didCreate {
                                dismiss()
                            }
                        }
                    } label: {
                        if isCreatingTrip {
                            ProgressView()
                        } else {
                            Text("Create Trip")
                        }
                    }
                    .disabled(!canSave || isCreatingTrip)
                }
            }
        }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !destination.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

enum ActiveSheet: Identifiable {
    case person
    case editPerson(Participant)
    case expense
    case payment

    var id: String {
        switch self {
        case .person: "person"
        case .editPerson(let participant): "edit-person-\(participant.id)"
        case .expense: "expense"
        case .payment: "payment"
        }
    }
}

struct AddPersonView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: TripCalculatorViewModel
    var existingParticipant: Participant?
    var saveParticipants: ([String]) async -> Void = { _ in }
    var updateParticipant: (Participant) async -> Void = { _ in }
    var usesExternalPersistence: Bool = false
    @State private var names = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if existingParticipant == nil {
                        TextEditor(text: $names)
                            .frame(minHeight: 140)
                            .overlay(alignment: .topLeading) {
                                if names.isEmpty {
                                    Text("Alex\nSam\nTaylor")
                                        .foregroundStyle(.tertiary)
                                        .padding(.top, 8)
                                        .padding(.leading, 5)
                                        .allowsHitTesting(false)
                                }
                            }
                    } else {
                        TextField("Name", text: $names)
                    }
                } footer: {
                    Text(existingParticipant == nil ? "Enter one person per line." : "Renaming keeps this person's expense and payment history linked.")
                }
            }
            .navigationTitle(existingParticipant == nil ? "Add People" : "Edit Person")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(existingParticipant == nil ? "Add" : "Save") {
                        if let existingParticipant {
                            let updatedParticipant = Participant(id: existingParticipant.id, name: parsedNames.first ?? "")
                            if usesExternalPersistence {
                                Task {
                                    await updateParticipant(updatedParticipant)
                                    dismiss()
                                }
                            } else {
                                viewModel.updateParticipant(updatedParticipant)
                                dismiss()
                            }
                        } else if usesExternalPersistence {
                            Task {
                                await saveParticipants(parsedNames)
                                dismiss()
                            }
                        } else {
                            viewModel.addParticipants(names: parsedNames)
                            dismiss()
                        }
                    }
                    .disabled(parsedNames.isEmpty)
                }
            }
            .onAppear {
                if let existingParticipant, names.isEmpty {
                    names = existingParticipant.name
                }
            }
        }
    }

    private var parsedNames: [String] {
        names
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

struct AddExpenseView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: TripCalculatorViewModel
    var existingExpense: ExpenseItem?
    var saveExpense: (String, Participant.ID, Decimal, Set<Participant.ID>) async -> Void = { _, _, _, _ in }
    var updateExpense: (ExpenseItem) async -> Void = { _ in }
    var usesExternalPersistence: Bool = false
    @State private var title = ""
    @State private var amount = ""
    @State private var paidBy: Participant.ID?
    @State private var selectedParticipants = Set<Participant.ID>()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Description", text: $title)
                    TextField("Amount", text: $amount)
                        .keyboardType(.decimalPad)
                }

                Section("Paid By") {
                    Picker("Paid By", selection: paidByBinding) {
                        ForEach(viewModel.calculator.participants) { participant in
                            Text(participant.name).tag(Optional(participant.id))
                        }
                    }
                }

                Section("Split Among") {
                    Button("Select Everyone") {
                        selectedParticipants = Set(viewModel.calculator.participants.map(\.id))
                    }

                    ForEach(viewModel.calculator.participants) { participant in
                        Toggle(participant.name, isOn: participantBinding(for: participant.id))
                    }
                }
            }
            .navigationTitle(existingExpense == nil ? "Add Expense" : "Edit Expense")
            .onAppear {
                if let existingExpense, title.isEmpty {
                    title = existingExpense.title
                    amount = existingExpense.amount.currencyText.replacingOccurrences(of: "$", with: "")
                    paidBy = existingExpense.paidBy
                    selectedParticipants = existingExpense.participants
                } else if paidBy == nil {
                    paidBy = viewModel.calculator.participants.first?.id
                    selectedParticipants = Set(viewModel.calculator.participants.map(\.id))
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(existingExpense == nil ? "Add Expense" : "Save") {
                        let selectedPayer = paidByBinding.wrappedValue
                        if let existingExpense {
                            let updated = ExpenseItem(
                                id: existingExpense.id,
                                title: title,
                                paidBy: selectedPayer,
                                amount: parsedAmount,
                                participants: selectedParticipants
                            )
                            if usesExternalPersistence {
                                Task {
                                    await updateExpense(updated)
                                    dismiss()
                                }
                            } else {
                                viewModel.updateExpense(updated)
                                dismiss()
                            }
                        } else if usesExternalPersistence {
                            Task {
                                await saveExpense(title, selectedPayer, parsedAmount, selectedParticipants)
                                dismiss()
                            }
                        } else {
                            viewModel.addExpense(
                                title: title,
                                paidBy: selectedPayer,
                                amount: parsedAmount,
                                participants: selectedParticipants
                            )
                            dismiss()
                        }
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private var paidByBinding: Binding<Participant.ID> {
        Binding(
            get: { paidBy ?? viewModel.calculator.participants.first?.id ?? UUID() },
            set: { paidBy = $0 }
        )
    }

    private var parsedAmount: Decimal {
        Decimal(string: amount.filter { $0 != "$" && $0 != "," }) ?? 0
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        parsedAmount > 0 &&
        paidBy != nil &&
        !selectedParticipants.isEmpty
    }

    private func participantBinding(for id: Participant.ID) -> Binding<Bool> {
        Binding(
            get: { selectedParticipants.contains(id) },
            set: { isSelected in
                if isSelected {
                    selectedParticipants.insert(id)
                } else {
                    selectedParticipants.remove(id)
                }
            }
        )
    }
}

struct AddPaymentView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: TripCalculatorViewModel
    var existingPayment: DirectPayment?
    var saveDirectPayment: (String, Participant.ID, Participant.ID, Decimal) async -> Void = { _, _, _, _ in }
    var updateDirectPayment: (DirectPayment) async -> Void = { _ in }
    var usesExternalPersistence: Bool = false
    @State private var title = ""
    @State private var amount = ""
    @State private var from: Participant.ID?
    @State private var to: Participant.ID?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Payment name", text: $title)
                    TextField("Amount", text: $amount)
                        .keyboardType(.decimalPad)
                }

                Section("People") {
                    Picker("From", selection: fromBinding) {
                        ForEach(viewModel.calculator.participants) { participant in
                            Text(participant.name).tag(Optional(participant.id))
                        }
                    }

                    Picker("To", selection: toBinding) {
                        ForEach(viewModel.calculator.participants) { participant in
                            Text(participant.name).tag(Optional(participant.id))
                        }
                    }
                }
            }
            .navigationTitle(existingPayment == nil ? "Add Payment" : "Edit Payment")
            .onAppear {
                if let existingPayment, title.isEmpty {
                    title = existingPayment.title
                    amount = existingPayment.amount.currencyText.replacingOccurrences(of: "$", with: "")
                    from = existingPayment.from
                    to = existingPayment.to
                } else if from == nil {
                    from = viewModel.calculator.participants.first?.id
                    to = viewModel.calculator.participants.dropFirst().first?.id ?? viewModel.calculator.participants.first?.id
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(existingPayment == nil ? "Add" : "Save") {
                        let fromID = fromBinding.wrappedValue
                        let toID = toBinding.wrappedValue
                        if let existingPayment {
                            let updated = DirectPayment(
                                id: existingPayment.id,
                                title: title,
                                from: fromID,
                                to: toID,
                                amount: parsedAmount
                            )
                            if usesExternalPersistence {
                                Task {
                                    await updateDirectPayment(updated)
                                    dismiss()
                                }
                            } else {
                                viewModel.updatePayment(updated)
                                dismiss()
                            }
                        } else if usesExternalPersistence {
                            Task {
                                await saveDirectPayment(title, fromID, toID, parsedAmount)
                                dismiss()
                            }
                        } else {
                            viewModel.addPayment(
                                title: title,
                                from: fromID,
                                to: toID,
                                amount: parsedAmount
                            )
                            dismiss()
                        }
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private var fromBinding: Binding<Participant.ID> {
        Binding(
            get: { from ?? viewModel.calculator.participants.first?.id ?? UUID() },
            set: { from = $0 }
        )
    }

    private var toBinding: Binding<Participant.ID> {
        Binding(
            get: { to ?? viewModel.calculator.participants.first?.id ?? UUID() },
            set: { to = $0 }
        )
    }

    private var parsedAmount: Decimal {
        Decimal(string: amount.filter { $0 != "$" && $0 != "," }) ?? 0
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        parsedAmount > 0 &&
        from != nil &&
        to != nil &&
        from != to
    }
}
