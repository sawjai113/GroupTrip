import SwiftUI

struct TripPlanningView: View {
    @Binding var items: [TripPlanningItem]
    var saveItem: (TripPlanningItem) async -> Void
    var toggleItemRemotely: (TripPlanningItem.ID) async -> Void
    var deleteItemRemotely: (TripPlanningItem.ID) async -> Void
    var usesExternalPersistence: Bool
    @State private var isShowingAddItem = false

    init(
        items: Binding<[TripPlanningItem]>,
        saveItem: @escaping (TripPlanningItem) async -> Void = { _ in },
        toggleItem: @escaping (TripPlanningItem.ID) async -> Void = { _ in },
        deleteItem: @escaping (TripPlanningItem.ID) async -> Void = { _ in },
        usesExternalPersistence: Bool = false
    ) {
        _items = items
        self.saveItem = saveItem
        self.toggleItemRemotely = toggleItem
        self.deleteItemRemotely = deleteItem
        self.usesExternalPersistence = usesExternalPersistence
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
                header

                calendarPlaceholder

                if items.isEmpty {
                    EmptyFeatureCard(
                        title: "No itinerary items yet",
                        subtitle: "Plans, bookings, and daily schedule ideas for this trip will appear here."
                    )
                } else {
                    VStack(spacing: AppTheme.Spacing.medium) {
                        ForEach(items) { item in
                            TripPlanningItemCard(item: item) {
                                Task { await toggleItem(item) }
                            } delete: {
                                Task { await deleteItem(item) }
                            }
                        }
                    }
                }
            }
            .padding(AppTheme.Spacing.large)
        }
        .background(AppTheme.background)
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
            AddTripPlanningItemView { item in
                Task { await addItem(item) }
            }
        }
    }

    private var header: some View {
        WaniSectionHeader(
            title: "Itinerary",
            subtitle: "Planning items, bookings, dates, and schedule notes for this trip."
        )
    }

    private var calendarPlaceholder: some View {
        WaniCard(radius: AppTheme.Radius.xLarge) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.medium + 2) {
                HStack(alignment: .top, spacing: AppTheme.Spacing.medium) {
                    WaniIconBadge(systemImage: "calendar", tint: AppTheme.FeatureColor.itinerary)

                    VStack(alignment: .leading, spacing: AppTheme.Spacing.xSmall) {
                        Text("Calendar View")
                            .font(.headline)
                        Text("Placeholder for a future native, third-party, or hybrid calendar integration.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)
                }

                CalendarPreviewGrid()
            }
        }
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
}

private struct CalendarPreviewGrid: View {
    private let weekdays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    private let highlightedDays: Set<Int> = [6, 9, 13, 17]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Sample Month")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("Not connected yet")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.FeatureColor.itinerary)
                    .padding(.horizontal, AppTheme.Spacing.small)
                    .padding(.vertical, AppTheme.Spacing.xSmall)
                    .background(AppTheme.FeatureColor.itinerary.opacity(0.12))
                    .clipShape(Capsule())
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: AppTheme.Spacing.small) {
                ForEach(weekdays, id: \.self) { weekday in
                    Text(weekday)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }

                ForEach(1...21, id: \.self) { day in
                    Text("\(day)")
                        .font(.caption.weight(highlightedDays.contains(day) ? .semibold : .regular))
                        .foregroundStyle(highlightedDays.contains(day) ? .white : .secondary)
                        .frame(maxWidth: .infinity, minHeight: 30)
                        .background(highlightedDays.contains(day) ? AppTheme.FeatureColor.itinerary : AppTheme.background)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.small, style: .continuous))
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Calendar placeholder. Calendar integration is not connected yet.")
    }
}

private struct TripPlanningItemCard: View {
    let item: TripPlanningItem
    var toggle: () -> Void
    var delete: () -> Void

    private var itemTint: Color {
        item.isDone ? AppTheme.success : AppTheme.FeatureColor.itinerary
    }

    var body: some View {
        WaniCard {
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
                            .foregroundStyle(item.isDone ? .secondary : .primary)
                            .strikethrough(item.isDone, color: .secondary)

                        Spacer(minLength: AppTheme.Spacing.small)

                        statusBadge

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
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if let date = item.date {
                        Label(Self.dateFormatter.string(from: date), systemImage: "calendar")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
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

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMM d yyyy")
        return formatter
    }()
}

private struct AddTripPlanningItemView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var note = ""
    @State private var hasDate = false
    @State private var date = Date()
    var save: (TripPlanningItem) -> Void

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Planning Item") {
                    TextField("Title", text: $title)
                }

                Section("Notes") {
                    TextField("Note (optional)", text: $note, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("Date") {
                    Toggle("Add date", isOn: $hasDate)

                    if hasDate {
                        DatePicker("Date", selection: $date, displayedComponents: .date)
                    }
                }
            }
            .navigationTitle("Add Item")
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
                                title: trimmedTitle,
                                note: note.trimmingCharacters(in: .whitespacesAndNewlines),
                                date: hasDate ? date : nil
                            )
                        )
                        dismiss()
                    }
                    .disabled(trimmedTitle.isEmpty)
                }
            }
        }
    }
}

private extension TripPlanningItem {
    var displayNote: String? {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
