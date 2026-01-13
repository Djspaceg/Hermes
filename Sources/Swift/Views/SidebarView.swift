//
//  SidebarView.swift
//  Hermes
//
//  Sidebar with proper structure: fixed header, conditional sort controls,
//  scrollable content, and conditional footer buttons
//

import SwiftUI

enum SidebarSelection {
    case stations
    case history
}

struct SidebarView: View {
    @ObservedObject var stationsViewModel: StationsViewModel
    @ObservedObject var historyViewModel: HistoryViewModel
    
    @State private var selectedView: SidebarSelection = .stations
    @State private var selectedStation: StationModel?
    @State private var sortOrder: StationsViewModel.SortOrder = .dateCreated
    
    var body: some View {
        VStack(spacing: 0) {
            navigationHeader
            
            if selectedView == .stations {
                sortControls
            }
            
            contentArea
            
            if selectedView == .stations {
                stationsFooter
            } else {
                historyFooter
            }
        }
        .sheet(item: $stationsViewModel.stationToEdit) { station in
            StationEditView(
                viewModel: StationEditViewModel(
                    station: station.objcStation,
                    pandora: stationsViewModel.pandora
                )
            )
            .onAppear {
                WindowTracker.shared.windowOpened("stationEditor")
            }
            .onDisappear {
                WindowTracker.shared.windowClosed("stationEditor")
            }
        }
        .sheet(isPresented: $stationsViewModel.showAddStationSheet) {
            StationAddView(
                viewModel: StationAddViewModel(pandora: stationsViewModel.pandora)
            )
            .onAppear {
                WindowTracker.shared.windowOpened("newStation")
            }
            .onDisappear {
                WindowTracker.shared.windowClosed("newStation")
            }
        }
        .onReceive(stationsViewModel.$selectedStationId) { stationId in
            // Sync selection from view model (e.g., when restoring last played station)
            if let stationId = stationId,
               selectedStation?.id != stationId,
               let station = stationsViewModel.stations.first(where: { $0.id == stationId }) {
                selectedStation = station
            }
        }
    }
    
    private var navigationHeader: some View {
        HStack(spacing: 0) {
            Button(action: { selectedView = .stations }) {
                Text("Stations")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(NavigationHeaderButtonStyle(isSelected: selectedView == .stations))
            
            Button(action: { selectedView = .history }) {
                Text("History")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(NavigationHeaderButtonStyle(isSelected: selectedView == .history))
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
    }
    
    private var sortControls: some View {
        HStack(spacing: 0) {
            Button(action: { sortOrder = .name }) {
                Text("Name")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(SortButtonStyle(isSelected: sortOrder == .name))
            
            Button(action: { sortOrder = .dateCreated }) {
                Text("Date")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(SortButtonStyle(isSelected: sortOrder == .dateCreated))
        }
        .padding(.horizontal, 8)
        .padding(.top, 4)
    }
    
    @ViewBuilder
    private var contentArea: some View {
        switch selectedView {
        case .stations:
            StationsListView(
                viewModel: stationsViewModel,
                selectedStation: $selectedStation,
                sortOrder: $sortOrder
            )
        case .history:
            HistoryListView(
                viewModel: historyViewModel,
                selectedItem: $historyViewModel.selectedItem
            )
        }
    }
    
    private var stationsFooter: some View {
        HStack(spacing: 4) {
            Button(action: {
                if let station = selectedStation {
                    stationsViewModel.playStation(station)
                }
            }) {
                Image(systemName: "play.fill")
                    .frame(width: 32, height: 28)
            }
            .disabled(selectedStation == nil)
            .help("Play Station")
            
            Button(action: { stationsViewModel.showAddStation() }) {
                Image(systemName: "plus")
                    .frame(width: 32, height: 28)
            }
            .help("Add Station")
            
            Button(action: {
                if let station = selectedStation {
                    stationsViewModel.editStation(station)
                }
            }) {
                Image(systemName: "pencil")
                    .frame(width: 32, height: 28)
            }
            .disabled(selectedStation == nil)
            .help("Edit Station")
            
            Spacer()
            
            Button(action: {
                if let station = selectedStation {
                    stationsViewModel.confirmDeleteStation(station)
                }
            }) {
                Image(systemName: "trash")
                    .frame(width: 32, height: 28)
            }
            .disabled(selectedStation == nil)
            .help("Delete Station")
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color(nsColor: .controlBackgroundColor))
    }
    
    private var historyFooter: some View {
        HStack(spacing: 4) {
            Button(action: { historyViewModel.openSongOnPandora() }) {
                Image(systemName: "music.note")
                    .frame(width: 32, height: 28)
            }
            .disabled(historyViewModel.selectedItem == nil)
            .help("Song on Pandora")
            
            Button(action: { historyViewModel.openArtistOnPandora() }) {
                Image(systemName: "person")
                    .frame(width: 32, height: 28)
            }
            .disabled(historyViewModel.selectedItem == nil)
            .help("Artist on Pandora")
            
            Button(action: { historyViewModel.openAlbumOnPandora() }) {
                Image(systemName: "square.stack")
                    .frame(width: 32, height: 28)
            }
            .disabled(historyViewModel.selectedItem == nil)
            .help("Album on Pandora")
            
            Button(action: { historyViewModel.showLyrics() }) {
                Image(systemName: "text.quote")
                    .frame(width: 32, height: 28)
            }
            .disabled(historyViewModel.selectedItem == nil)
            .help("Lyrics")
            
            Spacer()
            
            Button(action: { historyViewModel.likeSelected() }) {
                Image(systemName: "hand.thumbsup")
                    .frame(width: 32, height: 28)
            }
            .disabled(historyViewModel.selectedItem == nil)
            .help("Like")
            
            Button(action: { historyViewModel.dislikeSelected() }) {
                Image(systemName: "hand.thumbsdown")
                    .frame(width: 32, height: 28)
            }
            .disabled(historyViewModel.selectedItem == nil)
            .help("Dislike")
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

// MARK: - Button Styles

struct NavigationHeaderButtonStyle: ButtonStyle {
    let isSelected: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(isSelected ? .primary : .secondary)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.7 : 1.0)
    }
}

struct SortButtonStyle: ButtonStyle {
    let isSelected: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11))
            .foregroundColor(isSelected ? .primary : .secondary)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isSelected ? Color(nsColor: .selectedControlColor) : Color.clear)
            )
            .opacity(configuration.isPressed ? 0.7 : 1.0)
    }
}


// MARK: - Preview

#Preview {
    SidebarPreview()
        .frame(width: 250, height: 600)
}

private struct SidebarPreview: View {
    @State private var selectedView: SidebarSelection = .stations
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Button("Stations") { selectedView = .stations }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                Button("History") { selectedView = .history }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)
            
            List {
                Text("Rock Classics")
                Text("Chill Vibes")
                Text("90s Alternative")
            }
            .listStyle(.sidebar)
        }
    }
}
