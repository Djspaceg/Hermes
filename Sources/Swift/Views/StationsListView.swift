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
    
    var body: some View {
        List(viewModel.sortedStations(by: sortOrder), id: \.id, selection: $selectedStation) { station in
            StationRow(
                station: station,
                isPlaying: station.id == viewModel.playingStationId
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
    
    var body: some View {
        HStack {
            if isPlaying {
                Image(systemName: "speaker.wave.2.fill")
                    .foregroundColor(.accentColor)
                    .font(.caption)
            }
            Text(station.name)
            Spacer()
        }
        .contentShape(Rectangle())
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
            StationRow(
                station: station,
                isPlaying: false
            )
            .tag(station)
        }
        .listStyle(.sidebar)
    }
}
