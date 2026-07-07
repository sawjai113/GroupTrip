import SwiftUI

struct TripPlacesView: View {
    @Binding var places: [TripPlace]
    var savePlace: (TripPlace) async -> Void
    var deletePlace: (TripPlace.ID) async -> Void
    var updatePlace: (TripPlace) async -> Void
    var usesExternalPersistence: Bool
    @State private var isShowingAddPlace = false
    @State private var isShowingEditPlace = false
    @State private var placePendingDeletion: TripPlace?
    @State private var placePendingEdit: TripPlace?

    init(
        places: Binding<[TripPlace]>,
        savePlace: @escaping (TripPlace) async -> Void = { _ in },
        deletePlace: @escaping (TripPlace.ID) async -> Void = { _ in },
        updatePlace: @escaping (TripPlace) async -> Void = { _ in },
        usesExternalPersistence: Bool = false
    ) {
        _places = places
        self.savePlace = savePlace
        self.deletePlace = deletePlace
        self.updatePlace = updatePlace
        self.usesExternalPersistence = usesExternalPersistence
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
                header

                if places.isEmpty {
                    EmptyFeatureCard(
                        title: "No places saved yet",
                        subtitle: "Restaurants, shops, and attractions you save for this trip will appear here."
                    )
                } else {
                    VStack(spacing: AppTheme.Spacing.medium) {
                        ForEach(places) { place in
                            TripPlaceCard(place: place) {
                                placePendingDeletion = place
                            } edit: {
                                placePendingEdit = place
                                isShowingEditPlace = true
                            }
                        }
                    }
                }
            }
            .padding(AppTheme.Spacing.large)
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
                .tint(AppTheme.FeatureColor.places)
            }
        }
        .sheet(isPresented: $isShowingAddPlace) {
            AddTripPlaceView { place in
                Task { await addPlace(place) }
            }
        }
        .sheet(isPresented: $isShowingEditPlace) {
            if let place = placePendingEdit {
                AddTripPlaceView(
                    editing: place,
                    title: "Edit Place"
                ) { updated in
                    Task { await updatePlace(updated) }
                }
            }
        }
        .confirmationDialog(
            "Delete this place?",
            isPresented: Binding(
                get: { placePendingDeletion != nil },
                set: { isPresented in
                    if !isPresented { placePendingDeletion = nil }
                }
            ),
            titleVisibility: .visible,
            presenting: placePendingDeletion
        ) { place in
            Button("Delete Place", role: .destructive) {
                Task { await removePlace(place) }
            }
            Button("Cancel", role: .cancel) { placePendingDeletion = nil }
        } message: { place in
            Text("This removes \(place.name) from this trip. Shared cloud trips will remove it for everyone.")
        }
    }

    private var header: some View {
        WaniSectionHeader(
            title: "Places & Interests",
            subtitle: "Saved restaurants, shops, attractions, and ideas for this trip."
        )
    }

    private func addPlace(_ place: TripPlace) async {
        if usesExternalPersistence {
            await savePlace(place)
        } else {
            withAnimation(.snappy) {
                places.append(place)
            }
        }
    }

    private func removePlace(_ place: TripPlace) async {
        if usesExternalPersistence {
            await deletePlace(place.id)
        } else {
            withAnimation(.snappy) {
                places.removeAll { $0.id == place.id }
            }
        }
        placePendingDeletion = nil
    }

    private func updatePlace(_ place: TripPlace) async {
        if usesExternalPersistence {
            await self.updatePlace(place)
        }
        guard let index = places.firstIndex(where: { $0.id == place.id }) else { return }
        places[index] = place
        placePendingEdit = nil
        isShowingEditPlace = false
    }
}

private struct TripPlaceCard: View {
    let place: TripPlace
    var delete: () -> Void
    var edit: () -> Void

    var body: some View {
        WaniCard {
            HStack(alignment: .top, spacing: AppTheme.Spacing.medium + 2) {
                Button(action: edit) {
                    WaniIconBadge(systemImage: "mappin.and.ellipse", tint: AppTheme.FeatureColor.places)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Edit \(place.name)")

                VStack(alignment: .leading, spacing: AppTheme.Spacing.xSmall + 2) {
                    HStack(alignment: .firstTextBaseline, spacing: AppTheme.Spacing.small) {
                        Text(place.name)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.primary)

                        Spacer(minLength: AppTheme.Spacing.small)

                        if let category = place.displayCategory {
                            Text(category)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.FeatureColor.places)
                                .padding(.horizontal, AppTheme.Spacing.small)
                                .padding(.vertical, AppTheme.Spacing.xSmall)
                                .background(AppTheme.FeatureColor.places.opacity(0.1))
                                .clipShape(Capsule())
                        }

                        Button(role: .destructive, action: delete) {
                            Image(systemName: "trash")
                                .font(.subheadline.weight(.semibold))
                                .frame(width: AppTheme.IconSize.large, height: AppTheme.IconSize.large)
                                .contentShape(Rectangle())
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
        }
    }
}

private struct AddTripPlaceView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var category = ""
    @State private var note = ""
    var save: (TripPlace) -> Void
    var navTitle: String

    init(editing place: TripPlace? = nil, title: String = "Add Place", save: @escaping (TripPlace) -> Void) {
        self.save = save
        self.navTitle = title
        _name = State(initialValue: place?.name ?? "")
        _category = State(initialValue: place?.category ?? "")
        _note = State(initialValue: place?.note ?? "")
    }

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
