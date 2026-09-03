import SwiftUI

struct TripPlacesView: View {
    @Environment(\.openURL) private var openURL
    @Binding var places: [TripPlace]
    var savePlace: (TripPlace) async -> Void
    var deletePlace: (TripPlace.ID) async -> Void
    var updatePlace: (TripPlace) async -> Void
    var setVote: (PlaceVote, TripPlace.ID, Participant.ID) async -> Void
    var setPinned: (Bool, TripPlace.ID) async -> Void
    var callForVote: (TripPlace.ID, Participant.ID?) async -> Void
    var usesExternalPersistence: Bool
    var participants: [Participant] = []
    var currentAccountID: UUID?
    @State private var isShowingAddPlace = false
    @State private var isShowingEditPlace = false
    @State private var placePendingDeletion: TripPlace?
    @State private var placePendingEdit: TripPlace?
    @State private var selectedFilter: PlaceFilter?

    init(
        places: Binding<[TripPlace]>,
        savePlace: @escaping (TripPlace) async -> Void = { _ in },
        deletePlace: @escaping (TripPlace.ID) async -> Void = { _ in },
        updatePlace: @escaping (TripPlace) async -> Void = { _ in },
        setVote: @escaping (PlaceVote, TripPlace.ID, Participant.ID) async -> Void = { _, _, _ in },
        setPinned: @escaping (Bool, TripPlace.ID) async -> Void = { _, _ in },
        callForVote: @escaping (TripPlace.ID, Participant.ID?) async -> Void = { _, _ in },
        usesExternalPersistence: Bool = false,
        participants: [Participant] = [],
        currentAccountID: UUID? = nil
    ) {
        _places = places
        self.savePlace = savePlace
        self.deletePlace = deletePlace
        self.updatePlace = updatePlace
        self.setVote = setVote
        self.setPinned = setPinned
        self.callForVote = callForVote
        self.usesExternalPersistence = usesExternalPersistence
        self.participants = participants
        self.currentAccountID = currentAccountID
    }

    private var filteredPlaces: [TripPlace] {
        places.filtered(by: selectedFilter)
    }

    private var currentParticipant: Participant? {
        guard let participantID = PlaceVotingParticipantResolver.participantID(accountID: currentAccountID, participants: participants) else {
            return nil
        }
        return participants.first { $0.id == participantID }
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
                                TripPlaceCard(
                                    place: place,
                                    participants: participants,
                                    currentParticipant: currentParticipant
                                ) {
                                    Task { await openInMaps(place) }
                                } delete: {
                                    placePendingDeletion = place
                                } edit: {
                                    placePendingEdit = place
                                    isShowingEditPlace = true
                                } vote: { vote in
                                    Task { await setVoteForCurrentParticipant(vote, place: place) }
                                } pin: {
                                    Task { await togglePinned(place) }
                                } callForVote: {
                                    Task { await performCallForVote(place) }
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
            AddTripPlaceView(participants: participants) { place in
                Task { await addPlace(place) }
            }
        }
        .sheet(isPresented: $isShowingEditPlace) {
            if let place = placePendingEdit {
                AddTripPlaceView(
                    editing: place,
                    title: "Edit Place",
                    participants: participants
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

                PlaceChip(title: "Pinned", isSelected: selectedFilter == .pinned) {
                    selectedFilter = .pinned
                }

                PlaceChip(title: "Calls", isSelected: selectedFilter == .calls) {
                    selectedFilter = .calls
                }

                ForEach(TripTag.subset(for: .place)) { tag in
                    PlaceChip(title: tag.displayName, isSelected: selectedFilter == .tag(tag)) {
                        selectedFilter = .tag(tag)
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

    private func setVoteForCurrentParticipant(_ vote: PlaceVote, place: TripPlace) async {
        guard let participantID = currentParticipant?.id else { return }
        if usesExternalPersistence {
            await setVote(vote, place.id, participantID)
        } else if let index = places.firstIndex(where: { $0.id == place.id }) {
            places[index].votes[participantID] = vote
        }
    }

    private func togglePinned(_ place: TripPlace) async {
        let shouldPin = place.pinnedAt == nil
        if usesExternalPersistence {
            await setPinned(shouldPin, place.id)
        } else if let index = places.firstIndex(where: { $0.id == place.id }) {
            places[index] = PlacePinning.updated(place, isPinned: shouldPin)
        }
    }

    private func performCallForVote(_ place: TripPlace) async {
        if usesExternalPersistence {
            await callForVote(place.id, currentParticipant?.id)
        } else if let index = places.firstIndex(where: { $0.id == place.id }) {
            places[index] = PlaceVotingCall.updated(place, callerID: currentParticipant?.id)
        }
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
    let participants: [Participant]
    let currentParticipant: Participant?
    var open: () -> Void
    var delete: () -> Void
    var edit: () -> Void
    var vote: (PlaceVote) -> Void
    var pin: () -> Void
    var callForVote: () -> Void

    private var summary: PlaceVoteSummary {
        PlaceVoteSummary(place: place, participants: participants)
    }

    private var currentVote: PlaceVote? {
        guard let currentParticipant else { return nil }
        return place.votes[currentParticipant.id]
    }

    var body: some View {
        WaniCard {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
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

                        if place.calledForVoteAt != nil {
                            Text("Vote called")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.Editorial.owed)
                                .padding(.horizontal, AppTheme.Spacing.small)
                                .padding(.vertical, AppTheme.Spacing.xSmall)
                                .background(AppTheme.Editorial.owed.opacity(0.10))
                                .clipShape(Capsule())
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

                    Button(action: pin) {
                        Image(systemName: place.pinnedAt == nil ? "pin" : "pin.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(place.pinnedAt == nil ? AppTheme.Editorial.secondaryText : AppTheme.Editorial.forest)
                            .frame(width: AppTheme.IconSize.large, height: AppTheme.IconSize.large)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(place.pinnedAt == nil ? "Pin \(place.name)" : "Unpin \(place.name)")

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

                Text(summary.scoreLine)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.Editorial.secondaryText)

                HStack(spacing: AppTheme.Spacing.small) {
                    ForEach(PlaceVote.allCases, id: \.self) { option in
                        PlaceVoteButton(
                            vote: option,
                            isSelected: currentVote == option,
                            isEnabled: currentParticipant != nil
                        ) {
                            vote(option)
                        }
                    }

                    Spacer(minLength: AppTheme.Spacing.small)

                    Button(place.calledForVoteAt == nil ? "Call for vote" : "Vote called") {
                        callForVote()
                    }
                    .font(.caption.weight(.bold))
                    .foregroundStyle(place.calledForVoteAt == nil ? AppTheme.Editorial.forest : AppTheme.Editorial.owed)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 8)
                    .frame(minHeight: 44)
                    .background(AppTheme.Editorial.card)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(AppTheme.Editorial.border, lineWidth: 1))
                    .disabled(place.calledForVoteAt != nil)
                }
            }
        }
    }
}

private struct PlaceVoteButton: View {
    let vote: PlaceVote
    let isSelected: Bool
    let isEnabled: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(vote.shortLabel)
                .font(.caption.weight(.bold))
                .foregroundStyle(isSelected ? .white : AppTheme.Editorial.secondaryText)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .frame(minHeight: 44)
                .background(isSelected ? AppTheme.Editorial.forest : AppTheme.Editorial.card)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(isSelected ? Color.clear : AppTheme.Editorial.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.55)
        .accessibilityLabel("Vote \(vote.label)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct AddTripPlaceView: View {
    @Environment(\.dismiss) private var dismiss
    let participants: [Participant]
    @State private var name = ""
    @State private var tagInput = PlaceTagInput()
    @State private var note = ""
    @State private var selectedParticipantIDs: [UUID]
    private let editingID: TripPlace.ID?
    private let editingMetadata: (pinnedAt: Date?, calledForVoteAt: Date?, calledBy: UUID?, votes: [UUID: PlaceVote])
    var save: (TripPlace) -> Void
    var navTitle: String

    init(editing place: TripPlace? = nil, title: String = "Add Place", participants: [Participant] = [], save: @escaping (TripPlace) -> Void) {
        self.participants = participants
        self.save = save
        self.navTitle = title
        self.editingID = place?.id
        self.editingMetadata = (place?.pinnedAt, place?.calledForVoteAt, place?.calledBy, place?.votes ?? [:])
        _selectedParticipantIDs = State(initialValue: place?.participantIDs ?? [])
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

                if !participants.isEmpty {
                    ParticipantPickerSection(participants: participants, selectedIDs: $selectedParticipantIDs)
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
                                participantIDs: selectedParticipantIDs,
                                pinnedAt: editingMetadata.pinnedAt,
                                calledForVoteAt: editingMetadata.calledForVoteAt,
                                calledBy: editingMetadata.calledBy,
                                votes: editingMetadata.votes
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
