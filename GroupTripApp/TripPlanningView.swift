import SwiftUI

struct TripPlanningView: View {
    @Binding var items: [TripPlanningItem]
    @State private var isShowingAddItem = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                if items.isEmpty {
                    EmptyFeatureCard(
                        title: "No itinerary items yet",
                        subtitle: "Plans, bookings, and daily schedule ideas for this trip will appear here."
                    )
                } else {
                    VStack(spacing: 12) {
                        ForEach(items) { item in
                            TripPlanningItemCard(item: item) {
                                toggleItem(item)
                            } delete: {
                                deleteItem(item)
                            }
                        }
                    }
                }
            }
            .padding(16)
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
                .tint(AppTheme.warning)
            }
        }
        .sheet(isPresented: $isShowingAddItem) {
            AddTripPlanningItemView { item in
                withAnimation(.snappy) {
                    items.append(item)
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Itinerary")
                .font(.title2.weight(.semibold))

            Text("Planning items, bookings, dates, and schedule notes for this trip.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func deleteItem(_ item: TripPlanningItem) {
        withAnimation(.snappy) {
            items.removeAll { $0.id == item.id }
        }
    }

    private func toggleItem(_ item: TripPlanningItem) {
        withAnimation(.snappy) {
            guard let itemIndex = items.firstIndex(where: { $0.id == item.id }) else { return }
            items[itemIndex].isDone.toggle()
        }
    }
}

private struct TripPlanningItemCard: View {
    let item: TripPlanningItem
    var toggle: () -> Void
    var delete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Button(action: toggle) {
                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(item.isDone ? AppTheme.success : AppTheme.warning)
                    .frame(width: 44, height: 44)
                    .background((item.isDone ? AppTheme.success : AppTheme.warning).opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(item.isDone ? "Mark \(item.title) as to do" : "Mark \(item.title) done")

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(item.title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(item.isDone ? .secondary : .primary)
                        .strikethrough(item.isDone, color: .secondary)

                    Spacer(minLength: 8)

                    statusBadge

                    Button(role: .destructive, action: delete) {
                        Image(systemName: "trash")
                            .font(.subheadline.weight(.semibold))
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
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.paper)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var statusBadge: some View {
        Text(item.isDone ? "Done" : "To do")
            .font(.caption.weight(.semibold))
            .foregroundStyle(item.isDone ? AppTheme.success : AppTheme.warning)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background((item.isDone ? AppTheme.success : AppTheme.warning).opacity(0.1))
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
