//
//  StationsListView.swift
//  Hermes
//
//  List of stations for sidebar
//

import SwiftUI

// MARK: - Outer View (Dependency Injection)

struct StationsListView: View {
    @ObservedObject var viewModel: StationsViewModel
    @Binding var selectedStation: StationModel?
    @Binding var sortOrder: StationsViewModel.SortOrder
    @Environment(\.sidebarWidth) private var sidebarWidth
    
    private let thumbnailWidthThreshold: CGFloat = 240
    
    private var showThumbnails: Bool {
        sidebarWidth >= thumbnailWidthThreshold
    }
    
    var body: some View {
        StationsListContent(
            stations: viewModel.sortedStations(by: sortOrder),
            selectedStation: $selectedStation,
            playingStationId: viewModel.playingStationId,
            showThumbnails: showThumbnails,
            onRowAppear: { station in
                viewModel.artworkLoader.loadArtworkIfNeeded(for: station)
            },
            onPlay: viewModel.playStation,
            onEdit: viewModel.editStation,
            onRename: viewModel.startRenameStation,
            onDelete: viewModel.confirmDeleteStation,
            onRefresh: viewModel.refreshStations
        )
        .confirmationDialog(
            "Delete Station",
            isPresented: $viewModel.showDeleteConfirmation,
            presenting: viewModel.stationToDelete
        ) { station in
            Button("Delete \"\(station.name)\"", role: .destructive) {
                viewModel.performDeleteStation()
            }
            Button("Cancel", role: .cancel) {}
        } message: { station in
            Text("Are you sure you want to delete \"\(station.name)\"? This cannot be undone.")
        }
        .sheet(isPresented: $viewModel.showRenameDialog) {
            RenameStationSheet(
                stationName: $viewModel.newStationName,
                onRename: {
                    viewModel.performRenameStation()
                    viewModel.showRenameDialog = false
                },
                onCancel: {
                    viewModel.showRenameDialog = false
                }
            )
        }
    }
}

// MARK: - Inner View (Pure Presentation)

private struct StationsListContent: View {
    let stations: [StationModel]
    @Binding var selectedStation: StationModel?
    let playingStationId: String?
    let showThumbnails: Bool
    let onRowAppear: (Station) -> Void
    let onPlay: (StationModel) -> Void
    let onEdit: (StationModel) -> Void
    let onRename: (StationModel) -> Void
    let onDelete: (StationModel) -> Void
    let onRefresh: () async -> Void
    
    var body: some View {
        List(stations, id: \.id, selection: $selectedStation) { station in
            StationRow(
                station: station,
                isPlaying: station.id == playingStationId,
                showThumbnail: showThumbnails,
                onAppear: onRowAppear
            )
            .tag(station)
        }
        .listStyle(.sidebar)
        .contextMenu(forSelectionType: StationModel.self) { stations in
            if let station = stations.first {
                Button("Play") { onPlay(station) }
                Button("Edit...") { onEdit(station) }
                Button("Rename...") { onRename(station) }
                Divider()
                Button("Delete", role: .destructive) { onDelete(station) }
            }
        } primaryAction: { stations in
            if let station = stations.first {
                onPlay(station)
            }
        }
        .refreshable {
            await onRefresh()
        }
    }
}

struct StationRow: View {
    @ObservedObject var station: StationModel
    let isPlaying: Bool
    let showThumbnail: Bool
    let onAppear: (Station) -> Void
    @State private var artwork: NSImage?
    @State private var isLoading = false
    
    private let thumbnailSize: CGFloat = 32
    
    var body: some View {
        HStack(spacing: showThumbnail ? 8 : 0) {
            // Artwork thumbnail - always in hierarchy, animated width collapse
            thumbnailView
                .frame(width: showThumbnail ? thumbnailSize : 0, height: thumbnailSize)
                .opacity(showThumbnail ? 1 : 0)
                .clipped()
            
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    if isPlaying {
                        Image(systemName: "speaker.wave.2.fill")
                            .foregroundColor(.accentColor)
                            .font(.caption)
                    }
                    Text(station.name)
                        .lineLimit(1)
                    
                    Spacer(minLength: 0)
                }
                
                // Genre badges (no scroller - just show up to 3)
                if !station.genres.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(station.genres.prefix(3), id: \.self) { genre in
                            Text(genre)
                                .font(.caption2)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(.secondary.opacity(0.15))
                                .clipShape(Capsule())
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showThumbnail)
        .contentShape(Rectangle())
        .onAppear {
            onAppear(station.station)
            Task { await loadArtwork() }
        }
        .onChange(of: station.artworkURL) { _, _ in
            Task { await loadArtwork() }
        }
    }
    
    @ViewBuilder
    private var thumbnailView: some View {
        if let artwork {
            Image(nsImage: artwork)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: thumbnailSize, height: thumbnailSize)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        } else if isLoading {
            ProgressView()
                .scaleEffect(0.5)
                .frame(width: thumbnailSize, height: thumbnailSize)
        } else if station.artworkURL != nil {
            Color.gray.opacity(0.3)
                .frame(width: thumbnailSize, height: thumbnailSize)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay {
                    Image(systemName: "music.note")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
        } else {
            // No artwork URL yet - empty placeholder that takes no space when collapsed
            Color.clear
        }
    }
    
    private func loadArtwork() async {
        guard !isLoading, let url = station.artworkURL else { return }
        isLoading = true
        let image = await ImageCache.shared.loadImage(from: url)
        artwork = image
        isLoading = false
    }
}

// MARK: - Rename Station Sheet

struct RenameStationSheet: View {
    @Binding var stationName: String
    let onRename: () -> Void
    let onCancel: () -> Void
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Rename Station")
                .font(.headline)
            
            TextField("Station Name", text: $stationName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 300)
                .focused($isTextFieldFocused)
                .onSubmit {
                    if !stationName.isEmpty {
                        onRename()
                    }
                }
            
            HStack(spacing: 12) {
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)
                
                Button("Rename") {
                    onRename()
                }
                .buttonStyle(.borderedProminent)
                .disabled(stationName.isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 350)
        .onAppear {
            isTextFieldFocused = true
        }
    }
}


// MARK: - Preview

#Preview("Stations List") {
    StationsListContentPreview()
}

private struct StationsListContentPreview: View {
    @State private var selectedStation: StationModel?
    
    private let mockStations: [StationModel] = [
        .mock(name: "Rock Classics", stationId: "1"),
        .mock(name: "Chill Vibes", stationId: "2"),
        .mock(name: "90s Alternative", stationId: "3")
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            StationsListContent(
                stations: mockStations,
                selectedStation: $selectedStation,
                playingStationId: "1",
                showThumbnails: false,
                onRowAppear: { _ in },
                onPlay: { _ in },
                onEdit: { _ in },
                onRename: { _ in },
                onDelete: { _ in },
                onRefresh: { }
            )
            
            // Footer
            HStack(spacing: 4) {
                Button(action: {}) {
                    Image(systemName: "play.fill")
                }
                .disabled(selectedStation == nil)
                
                Button(action: {}) {
                    Image(systemName: "plus")
                }
                
                Button(action: {}) {
                    Image(systemName: "pencil")
                }
                .disabled(selectedStation == nil)
                
                Spacer()
                
                Button(action: {}) {
                    Image(systemName: "trash")
                }
                .disabled(selectedStation == nil)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial)
        }
        .frame(width: 250, height: 400)
    }
}
