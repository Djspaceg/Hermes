//
//  StationsListView.swift
//  Hermes
//
//  List of stations for sidebar
//

import SwiftUI

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
        List(viewModel.sortedStations(by: sortOrder), id: \.id, selection: $selectedStation) { station in
            StationRow(
                station: station,
                isPlaying: station.id == viewModel.playingStationId,
                artworkLoader: viewModel.artworkLoader,
                showThumbnail: showThumbnails
            )
            .tag(station)
        }
        .listStyle(.sidebar)
        .contextMenu(forSelectionType: StationModel.self) { stations in
            // Context menu items for right-click
            if let station = stations.first {
                Button("Play") {
                    viewModel.playStation(station)
                }
                Button("Edit...") {
                    viewModel.editStation(station)
                }
                Button("Rename...") {
                    viewModel.startRenameStation(station)
                }
                Divider()
                Button("Delete", role: .destructive) {
                    viewModel.confirmDeleteStation(station)
                }
            }
        } primaryAction: { stations in
            // Double-click action
            if let station = stations.first {
                viewModel.playStation(station)
            }
        }
        .refreshable {
            await viewModel.refreshStations()
        }
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

struct StationRow: View {
    let station: StationModel
    let isPlaying: Bool
    @ObservedObject var artworkLoader: StationArtworkLoader
    let showThumbnail: Bool
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
            // Trigger lazy loading of artwork URL when row appears
            artworkLoader.loadArtworkIfNeeded(for: station.station)
            // Load image from disk-backed cache
            loadArtwork()
        }
        .onChange(of: artworkLoader.artworkUpdateTrigger) {
            // Artwork URL became available, load the image
            loadArtwork()
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
    
    private func loadArtwork() {
        guard artwork == nil, !isLoading, let url = station.artworkURL else { return }
        isLoading = true
        Task {
            let image = await ImageCache.shared.loadImage(from: url)
            await MainActor.run {
                self.artwork = image
                self.isLoading = false
            }
        }
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

#Preview {
    StationsListPreview()
        .frame(width: 250, height: 400)
}

private struct StationsListPreview: View {
    @StateObject private var viewModel: PreviewStationsViewModel = {
        let stations: [StationModel] = [
            .mock(name: "Rock Classics", stationId: "1"),
            .mock(name: "Chill Vibes", stationId: "2"),
            .mock(name: "90s Alternative", stationId: "3")
        ]
        return PreviewStationsViewModel(stations: stations)
    }()
    @State private var selectedStation: StationModel?
    @State private var sortOrder: StationsViewModel.SortOrder = .name
    
    var body: some View {
        List(viewModel.stations, id: \.id, selection: $selectedStation) { station in
            StationRowPreview(station: station)
                .tag(station)
        }
        .listStyle(.sidebar)
    }
}

/// Simplified row for previews (no artwork loader dependency)
private struct StationRowPreview: View {
    let station: StationModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(station.name)
                .lineLimit(1)
            
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
        .contentShape(Rectangle())
    }
}
