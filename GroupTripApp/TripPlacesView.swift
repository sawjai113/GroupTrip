import SwiftUI

struct TripPlacesView: View {
    @Environment(\.openURL) private var openURL
    @Binding var places: [TripPlace]
    var savePlace: (TripPlace) async -> Void
    var deletePlace: (TripPlace.ID) async -> Void
    var updatePlace: (TripPlace) async -> Void
    var usesExternalPersistence: Bool
    @State private var isShowingAddPlace = false
    @State private var isShowingEditPlace = false
    @State private var placePendingDeletion: TripPlace?
    @State private var placePendingEdit: TripPlace?
    @State private var selectedFilter: TripTag?

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

    private var filteredPlaces: [TripPlace] {
        places.filtered(by: selectedFilter)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
                header

                if !places.isEmpty {
                    filterChips
                }

                if places.isEmpty {
                    EmptyFeatureCard(
                        title: "No places saved yet",
                        subtitle: "Restaurants, shops, and attractions you save for this trip will appear here."
                    )
                } else if filteredPlaces.isEmpty {
                    EmptyFeatureCard(
                        title: "No places match this tag",
                        subtitle: "Try All or choose another tag."
                    )
                } else {
                    VStack(spacing: AppTheme.Spacing.medium) {
                        ForEach(filteredPlaces) { place in
                            SwipeRevealActionRow(
                                actionTitle: "Delete",
                                actionSystemImage: "trash",
                                actionAccessibilityLabel: "Delete \(place.name)"
                            ) {
                                placePendingDeletion = place
                            } content: {
                                TripPlaceCard(place: place) {
                                    Task { await openInMaps(place) }
                                } delete: {
                                    placePendingDeletion = place
                                } edit: {
                                    placePendingEdit = place
                                    isShowingEditPlace = true
                                }
                            }
                        }
                    }
                }
            }
            .padding(AppTheme.Spacing.large)
        }
        .background(AppTheme.Editorial.background)
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
                    Task { await performUpdatePlace(updated) }
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
        EditorialSectionHeader(
            title: "Saved places",
            subtitle: "Restaurants, shops, attractions, and ideas for this trip."
        )
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppTheme.Spacing.small) {
                PlaceChip(title: "All", isSelected: selectedFilter == nil) {
                    selectedFilter = nil
                }

                ForEach(TripTag.subset(for: .place)) { tag in
                    PlaceChip(title: tag.displayName, isSelected: selectedFilter == tag) {
                        selectedFilter = tag
                    }
                }
            }
            .padding(.vertical, 2)
        }
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

    private func performUpdatePlace(_ place: TripPlace) async {
        if usesExternalPersistence {
            await updatePlace(place)
        } else if let index = places.firstIndex(where: { $0.id == place.id }) {
            places[index] = place
        }
        placePendingEdit = nil
        isShowingEditPlace = false
    }

    private func openInMaps(_ place: TripPlace) async {
        guard let link = PlaceMapsLink(name: place.name) else { return }
        let didOpenApp = await open(link.appURL)
        if !didOpenApp {
            _ = await open(link.webURL)
        }
    }

    private func open(_ url: URL) async -> Bool {
        await withCheckedContinuation { continuation in
            openURL(url) { accepted in
                continuation.resume(returning: accepted)
            }
        }
    }
}

private struct TripPlaceCard: View {
    let place: TripPlace
    var open: () -> Void
    var delete: () -> Void
    var edit: () -> Void

    var body: some View {
        WaniCard {
            HStack(alignment: .top, spacing: AppTheme.Spacing.medium + 2) {
                WaniIconBadge(systemImage: "mappin.and.ellipse", tint: AppTheme.FeatureColor.places)

                VStack(alignment: .leading, spacing: AppTheme.Spacing.xSmall + 2) {
                    HStack(alignment: .firstTextBaseline, spacing: AppTheme.Spacing.small) {
                        Text(place.name)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(AppTheme.Editorial.primaryText)

                        Spacer(minLength: AppTheme.Spacing.small)

                        if let tag = place.displayTag {
                            Text(tag)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.Editorial.secondaryText)
                                .padding(.horizontal, AppTheme.Spacing.small)
                                .padding(.vertical, AppTheme.Spacing.xSmall)
                                .background(AppTheme.Editorial.card)
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(AppTheme.Editorial.border, lineWidth: 1)
                                )
                        }
                    }

                    if let note = place.displayNote {
                        Text(note)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.Editorial.secondaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Label("Open in Maps", systemImage: "arrow.up.right.square")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.Editorial.secondaryText)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture(perform: open)
                .accessibilityLabel("Open \(place.name) in Maps")
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { open() }

                HStack(spacing: AppTheme.Spacing.xSmall) {
                    Button(action: edit) {
                        Image(systemName: "pencil")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.Editorial.forest)
                            .frame(width: AppTheme.IconSize.large, height: AppTheme.IconSize.large)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Edit \(place.name)")

                    Button(role: .destructive, action: delete) {
                        Image(systemName: "trash")
                            .font(.subheadline.weight(.semibold))
                            .frame(width: AppTheme.IconSize.large, height: AppTheme.IconSize.large)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Delete \(place.name)")
                }
            }
        }
    }
}

private struct AddTripPlaceView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var tagInput = PlaceTagInput()
    @State private var note = ""
    private let editingID: TripPlace.ID?
    private let editingParticipantIDs: [UUID]
    var save: (TripPlace) -> Void
    var navTitle: String

    init(editing place: TripPlace? = nil, title: String = "Add Place", save: @escaping (TripPlace) -> Void) {
        self.save = save
        self.navTitle = title
        self.editingID = place?.id
        self.editingParticipantIDs = place?.participantIDs ?? []
        _name = State(initialValue: place?.name ?? "")
        _tagInput = State(initialValue: PlaceTagInput(prefilling: place?.tag ?? ""))
        _note = State(initialValue: place?.note ?? "")
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                        EditorialTextField(
                            label: "Name",
                            placeholder: "e.g. Praça do Comércio",
                            text: $name
                        )

                        tagPicker
                    }
                } header: {
                    EditorialSectionHeader(title: "Place")
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
                            TripPlace(
                                id: editingID ?? UUID(),
                                name: trimmedName,
                                note: note.trimmingCharacters(in: .whitespacesAndNewlines),
                                tag: tagInput.resolvedTag,
                                participantIDs: editingParticipantIDs
                            )
                        )
                        dismiss()
                    }
                    .disabled(trimmedName.isEmpty)
                }
            }
        }
    }

    private var tagPicker: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
            Text("Tag")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.Editorial.secondaryText)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppTheme.Spacing.small) {
                    ForEach(TripTag.subset(for: .place)) { tag in
                        PlaceChip(title: tag.displayName, isSelected: tagInput.selectedTag == tag) {
                            toggleTag(tag)
                        }
                    }

                    PlaceChip(title: "Custom", isSelected: tagInput.selectedTag == .custom) {
                        toggleTag(.custom)
                    }
                }
                .padding(.vertical, 2)
            }

            if tagInput.selectedTag == .custom {
                EditorialTextField(
                    label: "Custom tag",
                    placeholder: "Optional, e.g. Landmark",
                    text: Binding(
                        get: { tagInput.customText },
                        set: { tagInput.customText = $0 }
                    )
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.snappy, value: tagInput.selectedTag?.rawValue)
    }

    private func toggleTag(_ tag: TripTag) {
        if tagInput.selectedTag == tag {
            tagInput.selectedTag = nil
            if tag == .custom {
                tagInput.customText = ""
            }
        } else {
            tagInput.selectedTag = tag
            if tag != .custom {
                tagInput.customText = ""
            }
        }
    }
}

private struct PlaceChip: View {
    let title: String
    let isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(isSelected ? .white : AppTheme.Editorial.secondaryText)
                .padding(.horizontal, 11)
                .padding(.vertical, 8)
                .frame(minHeight: 44)
                .background(isSelected ? AppTheme.Editorial.forest : AppTheme.Editorial.card)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.clear : AppTheme.Editorial.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

private extension TripTag {
    var displayName: String {
        rawValue.capitalized
    }
}

private extension TripPlace {
    var displayTag: String? {
        let trimmed = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var displayNote: String? {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
