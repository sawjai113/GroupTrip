import SwiftUI

struct TripPlacesView: View {
    @Binding var places: [TripPlace]
    @State private var isShowingAddPlace = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                if places.isEmpty {
                    EmptyFeatureCard(
                        title: "No places saved yet",
                        subtitle: "Restaurants, shops, and attractions you save for this trip will appear here."
                    )
                } else {
                    VStack(spacing: 12) {
                        ForEach(places) { place in
                            TripPlaceCard(place: place) {
                                deletePlace(place)
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(AppTheme.background)
        .navigationTitle("Places")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isShowingAddPlace = true
                } label: {
                    Label("Add Place", systemImage: "plus")
                }
                .tint(AppTheme.error)
            }
        }
        .sheet(isPresented: $isShowingAddPlace) {
            AddTripPlaceView { place in
                withAnimation(.snappy) {
                    places.append(place)
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Places & Interests")
                .font(.title2.weight(.semibold))

            Text("Saved restaurants, shops, attractions, and ideas for this trip.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func deletePlace(_ place: TripPlace) {
        withAnimation(.snappy) {
            places.removeAll { $0.id == place.id }
        }
    }
}

private struct TripPlaceCard: View {
    let place: TripPlace
    var delete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "mappin.and.ellipse")
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.error)
                .frame(width: 44, height: 44)
                .background(AppTheme.error.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(place.name)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)

                    Spacer(minLength: 8)

                    if let category = place.displayCategory {
                        Text(category)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.error)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(AppTheme.error.opacity(0.1))
                            .clipShape(Capsule())
                    }

                    Button(role: .destructive, action: delete) {
                        Image(systemName: "trash")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Delete \(place.name)")
                }

                if let note = place.displayNote {
                    Text(note)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.paper)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct AddTripPlaceView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var category = ""
    @State private var note = ""
    var save: (TripPlace) -> Void

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Place") {
                    TextField("Name", text: $name)
                    TextField("Category (optional)", text: $category)
                }

                Section("Notes") {
                    TextField("Note (optional)", text: $note, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Add Place")
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
                            TripPlace(
                                name: trimmedName,
                                note: note.trimmingCharacters(in: .whitespacesAndNewlines),
                                category: category.trimmingCharacters(in: .whitespacesAndNewlines)
                            )
                        )
                        dismiss()
                    }
                    .disabled(trimmedName.isEmpty)
                }
            }
        }
    }
}

private extension TripPlace {
    var displayCategory: String? {
        let trimmed = category.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var displayNote: String? {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
