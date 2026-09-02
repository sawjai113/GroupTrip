import SwiftUI

struct TripPlanningView: View {
    @Binding var items: [TripPlanningItem]
    var saveItem: (TripPlanningItem) async -> Void
    var toggleItemRemotely: (TripPlanningItem.ID) async -> Void
    var updateItemRemotely: (TripPlanningItem) async -> Void
    var deleteItemRemotely: (TripPlanningItem.ID) async -> Void
    var usesExternalPersistence: Bool
    var participants: [Participant] = []
    @State private var isShowingAddItem = false
    @State private var isShowingEditItem = false
    @State private var itemPendingDeletion: TripPlanningItem?
    @State private var itemPendingEdit: TripPlanningItem?

    private var timelineSections: (dated: [PlanningDaySection], undated: [TripPlanningItem]) {
        PlanningTimeline.sections(from: items)
    }

    init(
        items: Binding<[TripPlanningItem]>,
        saveItem: @escaping (TripPlanningItem) async -> Void = { _ in },
        toggleItem: @escaping (TripPlanningItem.ID) async -> Void = { _ in },
        updateItem: @escaping (TripPlanningItem) async -> Void = { _ in },
        deleteItem: @escaping (TripPlanningItem.ID) async -> Void = { _ in },
        usesExternalPersistence: Bool = false,
        participants: [Participant] = []
    ) {
        _items = items
        self.saveItem = saveItem
        self.toggleItemRemotely = toggleItem
        self.updateItemRemotely = updateItem
        self.deleteItemRemotely = deleteItem
        self.usesExternalPersistence = usesExternalPersistence
        self.participants = participants
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
                header

                if items.isEmpty {
                    EmptyFeatureCard(
                        title: "No itinerary items yet",
                        subtitle: "Plans, bookings, and daily schedule ideas for this trip will appear here."
                    )
                } else {
                    planningSections
                }
            }
            .padding(AppTheme.Spacing.large)
        }
        .background(AppTheme.Editorial.background)
        .navigationTitle("Itinerary")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isShowingAddItem = true
                } label: {
                    Label("Add Item", systemImage: "plus")
                }
                .tint(AppTheme.FeatureColor.itinerary)
            }
        }
        .sheet(isPresented: $isShowingAddItem) {
            AddTripPlanningItemView(participants: participants) { item in
                Task { await addItem(item) }
            }
        }
        .sheet(isPresented: $isShowingEditItem) {
            if let item = itemPendingEdit {
                AddTripPlanningItemView(
                    editing: item,
                    title: "Edit Item",
                    participants: participants
                ) { updated in
                    Task { await updateItem(updated) }
                }
            }
        }
        .confirmationDialog(
            "Delete this itinerary item?",
            isPresented: Binding(
                get: { itemPendingDeletion != nil },
                set: { isPresented in
                    if !isPresented { itemPendingDeletion = nil }
                }
            ),
            titleVisibility: .visible,
            presenting: itemPendingDeletion
        ) { item in
            Button("Delete Item", role: .destructive) {
                Task { await deleteItem(item) }
            }
            Button("Cancel", role: .cancel) { itemPendingDeletion = nil }
        } message: { item in
            Text("This removes \(item.title) from this trip. Shared cloud trips will remove it for everyone.")
        }
    }

    private var header: some View {
        EditorialSectionHeader(
            title: "Itinerary",
            subtitle: "Planning items, bookings, dates, and schedule notes for this trip."
        )
    }

    private var planningSections: some View {
        VStack(alignment: .leading, spacing: 24) {
            ForEach(timelineSections.dated, id: \.date) { section in
                VStack(alignment: .leading, spacing: 10) {
                    PlanningTimelineHeader(
                        title: Self.dayHeaderFormatter.string(from: section.date),
                        meta: Self.itemCountText(for: section.items.count),
                        fontSize: 20
                    )

                    WaniCard {
                        VStack(spacing: 0) {
                            ForEach(Array(section.items.enumerated()), id: \.element.id) { index, item in
                                planningRow(for: item, showsTime: true, isEmbedded: true)

                                if index < section.items.count - 1 {
                                    Divider()
                                        .padding(.leading, AppTheme.IconSize.large + AppTheme.Spacing.medium + 2)
                                }
                            }
                        }
                    }
                }
            }

            if !timelineSections.undated.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    PlanningTimelineHeader(
                        title: "Undated backlog",
                        meta: Self.itemCountText(for: timelineSections.undated.count),
                        fontSize: 18
                    )

                    WaniCard {
                        VStack(spacing: 0) {
                            ForEach(Array(timelineSections.undated.enumerated()), id: \.element.id) { index, item in
                                planningRow(for: item, showsTime: false, isEmbedded: true)

                                if index < timelineSections.undated.count - 1 {
                                    Divider()
                                        .padding(.leading, AppTheme.IconSize.large + AppTheme.Spacing.medium + 2)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func planningRow(for item: TripPlanningItem, showsTime: Bool, isEmbedded: Bool = false) -> some View {
        SwipeRevealActionRow(
            actionTitle: "Delete",
            actionSystemImage: "trash",
            actionAccessibilityLabel: "Delete \(item.title)"
        ) {
            itemPendingDeletion = item
        } content: {
            TripPlanningItemCard(item: item, showsTime: showsTime, isEmbedded: isEmbedded) {
                Task { await toggleItem(item) }
            } delete: {
                itemPendingDeletion = item
            } edit: {
                itemPendingEdit = item
                isShowingEditItem = true
            }
        }
    }

    private static let dayHeaderFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("EEEE MMMM d")
        return formatter
    }()

    private static func itemCountText(for count: Int) -> String {
        count == 1 ? "1 item" : "\(count) items"
    }

    private func addItem(_ item: TripPlanningItem) async {
        if usesExternalPersistence {
            await saveItem(item)
        } else {
            withAnimation(.snappy) {
                items.append(item)
            }
        }
    }

    private func deleteItem(_ item: TripPlanningItem) async {
        if usesExternalPersistence {
            await deleteItemRemotely(item.id)
        } else {
            withAnimation(.snappy) {
                items.removeAll { $0.id == item.id }
            }
        }
        itemPendingDeletion = nil
    }

    private func toggleItem(_ item: TripPlanningItem) async {
        if usesExternalPersistence {
            await toggleItemRemotely(item.id)
        } else {
            withAnimation(.snappy) {
                guard let itemIndex = items.firstIndex(where: { $0.id == item.id }) else { return }
                items[itemIndex].isDone.toggle()
            }
        }
    }

    private func updateItem(_ item: TripPlanningItem) async {
        if usesExternalPersistence {
            await updateItemRemotely(item)
        } else if let index = items.firstIndex(where: { $0.id == item.id }) {
            withAnimation(.snappy) {
                items[index] = item
            }
        }
        itemPendingEdit = nil
        isShowingEditItem = false
    }
}

private struct PlanningTimelineHeader: View {
    let title: String
    let meta: String
    var fontSize: CGFloat

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: AppTheme.Spacing.small) {
            Text(title)
                .font(.system(size: fontSize, weight: .semibold, design: .serif))
                .tracking(-0.3)
                .foregroundStyle(AppTheme.Editorial.primaryText)

            Spacer(minLength: AppTheme.Spacing.small)

            Text(meta)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.Editorial.secondaryText)
        }
    }
}

private struct TripPlanningItemCard: View {
    let item: TripPlanningItem
    var showsTime: Bool = false
    var isEmbedded: Bool = false
    var toggle: () -> Void
    var delete: () -> Void
    var edit: () -> Void

    private var itemTint: Color {
        item.isDone ? AppTheme.Editorial.forest : AppTheme.FeatureColor.itinerary
    }

    @ViewBuilder
    var body: some View {
        if isEmbedded {
            cardContent
                .padding(.vertical, AppTheme.Spacing.medium)
        } else {
            WaniCard {
                cardContent
            }
        }
    }

    private var cardContent: some View {
        HStack(alignment: .top, spacing: AppTheme.Spacing.medium + 2) {
            Button(action: toggle) {
                WaniIconBadge(systemImage: item.isDone ? "checkmark.circle.fill" : "circle", tint: itemTint)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(item.isDone ? "Mark \(item.title) as to do" : "Mark \(item.title) done")

            VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                HStack(alignment: .firstTextBaseline, spacing: AppTheme.Spacing.small) {
                    Text(item.title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(item.isDone ? AppTheme.Editorial.secondaryText : AppTheme.Editorial.primaryText)
                        .strikethrough(item.isDone, color: AppTheme.Editorial.secondaryText)

                    Spacer(minLength: AppTheme.Spacing.small)

                    statusBadge

                    Button(action: edit) {
                        Image(systemName: "pencil")
                            .font(.subheadline.weight(.semibold))
                            .frame(width: AppTheme.IconSize.large, height: AppTheme.IconSize.large)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Edit \(item.title)")

                    Button(role: .destructive, action: delete) {
                        Image(systemName: "trash")
                            .font(.subheadline.weight(.semibold))
                            .frame(width: AppTheme.IconSize.large, height: AppTheme.IconSize.large)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Delete \(item.title)")
                }

                if let note = item.displayNote {
                    Text(note)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Editorial.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if showsTime, let time = item.time {
                    Label(Self.timeFormatter.string(from: time), systemImage: "clock")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppTheme.Editorial.secondaryText)
                }
            }
        }
    }

    private var statusBadge: some View {
        Text(item.isDone ? "Done" : "To do")
            .font(.caption.weight(.semibold))
            .foregroundStyle(itemTint)
            .padding(.horizontal, AppTheme.Spacing.small)
            .padding(.vertical, AppTheme.Spacing.xSmall)
            .background(itemTint.opacity(0.1))
            .clipShape(Capsule())
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("h:mm")
        return formatter
    }()
}

private struct AddTripPlanningItemView: View {
    @Environment(\.dismiss) private var dismiss
    let participants: [Participant]
    @State private var title = ""
    @State private var note = ""
    @State private var hasDate = false
    @State private var hasTime = false
    @State private var date = Date()
    @State private var time = Date()
    @State private var selectedParticipantIDs: [UUID]
    private let existingItem: TripPlanningItem?
    var navTitle: String
    var save: (TripPlanningItem) -> Void

    init(editing item: TripPlanningItem? = nil, title: String = "Add Item", participants: [Participant] = [], save: @escaping (TripPlanningItem) -> Void) {
        self.participants = participants
        self.existingItem = item
        self.navTitle = title
        self.save = save
        _selectedParticipantIDs = State(initialValue: item?.participantIDs ?? [])
        _title = State(initialValue: item?.title ?? "")
        _note = State(initialValue: item?.note ?? "")
        _hasDate = State(initialValue: item?.date != nil)
        _hasTime = State(initialValue: item?.date != nil && item?.time != nil)
        _date = State(initialValue: item?.date ?? Date())
        _time = State(initialValue: item?.time ?? Date())
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    EditorialTextField(
                        label: "Title",
                        placeholder: "e.g. Surf lesson",
                        text: $title
                    )
                } header: {
                    EditorialSectionHeader(title: "Planning item")
                }

                Section {
                    EditorialTextField(
                        label: "Notes",
                        placeholder: "Optional",
                        text: $note,
                        axis: .vertical,
                        lineLimit: 3...6
                    )
                } header: {
                    EditorialSectionHeader(title: "Notes")
                }

                if !participants.isEmpty {
                    ParticipantPickerSection(participants: participants, selectedIDs: $selectedParticipantIDs)
                }

                Section {
                    VStack(spacing: AppTheme.Spacing.medium) {
                        EditorialToggleRow(title: "Add date", isOn: $hasDate)

                        if hasDate {
                            EditorialDateField(label: "Date", selection: $date)

                            EditorialToggleRow(title: "Add time", isOn: addTimeBinding)

                            if hasTime {
                                DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
                                    .datePickerStyle(.compact)
                            }
                        }
                    }
                } header: {
                    EditorialSectionHeader(title: "Date & Time")
                }
                .onChange(of: hasDate) { _, newValue in
                    if !newValue { hasTime = false }
                }
            }
            .editorialForm()
            .background(AppTheme.Editorial.background)
            .navigationTitle(navTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save(
                            TripPlanningItem(
                                id: existingItem?.id ?? UUID(),
                                title: trimmedTitle,
                                note: note.trimmingCharacters(in: .whitespacesAndNewlines),
                                date: PlanningDateTimeInput.resolvedDate(hasDate: hasDate, date: date),
                                time: PlanningDateTimeInput.resolvedTime(hasDate: hasDate, hasTime: hasTime, time: time),
                                isDone: existingItem?.isDone ?? false,
                                tag: existingItem?.tag ?? "",
                                participantIDs: selectedParticipantIDs
                            )
                        )
                        dismiss()
                    }
                    .disabled(trimmedTitle.isEmpty)
                }
            }
        }
    }

    private var addTimeBinding: Binding<Bool> {
        Binding(
            get: { hasTime },
            set: { newValue in
                if newValue { hasDate = true }
                hasTime = newValue
            }
        )
    }
}

private extension TripPlanningItem {
    var displayNote: String? {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
