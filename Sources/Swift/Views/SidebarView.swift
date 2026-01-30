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
    @Binding var columnVisibility: NavigationSplitViewVisibility
    
    @State private var selectedView: SidebarSelection = .stations
    @State private var selectedStation: StationModel?
    @State private var sortOrder: StationsViewModel.SortOrder = .dateCreated
    @State private var sidebarWidth: CGFloat = 250
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
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
            .onChange(of: geometry.size.width) { _, newWidth in
                withAnimation(.easeInOut(duration: 0.2)) {
                    sidebarWidth = newWidth
                }
            }
            .onAppear {
                sidebarWidth = geometry.size.width
            }
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                stationsButton
            }
            
            ToolbarItem(placement: .automatic) {
                historyButton
            }
        }
        .environment(\.sidebarWidth, sidebarWidth)
        .sheet(item: $stationsViewModel.stationToEdit) { station in
            StationEditView(
                viewModel: StationEditViewModel(
                    station: station.station,
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
    
    private var sortControls: some View {
        Picker("Sort by", selection: $sortOrder) {
            Text("Name").tag(StationsViewModel.SortOrder.name)
            Text("Date").tag(StationsViewModel.SortOrder.dateCreated)
        }
        .pickerStyle(.segmented)
//        .labelsHidden()
        .padding(.horizontal, 8)
        .padding(.bottom, 4)
    }

var toolbarIconButtonSize: CGFloat = 16

    @ViewBuilder
    private var stationsButton: some View {
        if selectedView == .stations {
            Button { 
                selectedView = .stations
                withAnimation { columnVisibility = .all }
            } label: {
                Label("Stations", systemImage: "radio")
                .frame(width: toolbarIconButtonSize, height: toolbarIconButtonSize)
            }
            .buttonStyle(.glassProminent)
        } else {
            Button { 
                selectedView = .stations
                withAnimation { columnVisibility = .all }
            } label: {
                Label("Stations", systemImage: "radio")
                .frame(width: toolbarIconButtonSize, height: toolbarIconButtonSize)
            }
            .buttonStyle(.glass)
        }
    }
    
    @ViewBuilder
    private var historyButton: some View {
        if selectedView == .history {
            Button { 
                selectedView = .history
                withAnimation { columnVisibility = .all }
            } label: {
                Label("History", systemImage: "clock")
                .frame(width: toolbarIconButtonSize, height: toolbarIconButtonSize)
            }
            .buttonStyle(.glassProminent)
        } else {
            Button { 
                selectedView = .history
                withAnimation { columnVisibility = .all }
            } label: {
                Label("History", systemImage: "clock")
                .frame(width: toolbarIconButtonSize, height: toolbarIconButtonSize)
            }
            .buttonStyle(.glass)
        }
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
            SidebarIconButton(
                systemName: "play.fill",
                isEnabled: selectedStation != nil,
                helpText: "Play Station"
            ) {
                if let station = selectedStation {
                    stationsViewModel.playStation(station)
                }
            }
            
            SidebarIconButton(
                systemName: "plus",
                helpText: "Add Station"
            ) {
                stationsViewModel.showAddStation()
            }
            
            SidebarIconButton(
                systemName: "pencil",
                isEnabled: selectedStation != nil,
                helpText: "Edit Station"
            ) {
                if let station = selectedStation {
                    stationsViewModel.editStation(station)
                }
            }
            
            Spacer()
            
            SidebarIconButton(
                systemName: "trash",
                isEnabled: selectedStation != nil,
                helpText: "Delete Station"
            ) {
                if let station = selectedStation {
                    stationsViewModel.confirmDeleteStation(station)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
    }
    
    private var historyFooter: some View {
        HStack(spacing: 4) {
            SidebarIconButton(
                systemName: "music.note",
                isEnabled: historyViewModel.selectedItem != nil,
                helpText: "Song on Pandora"
            ) {
                historyViewModel.openSongOnPandora()
            }
            
            SidebarIconButton(
                systemName: "person",
                isEnabled: historyViewModel.selectedItem != nil,
                helpText: "Artist on Pandora"
            ) {
                historyViewModel.openArtistOnPandora()
            }
            
            SidebarIconButton(
                systemName: "square.stack",
                isEnabled: historyViewModel.selectedItem != nil,
                helpText: "Album on Pandora"
            ) {
                historyViewModel.openAlbumOnPandora()
            }
            
            SidebarIconButton(
                systemName: "text.quote",
                isEnabled: historyViewModel.selectedItem != nil,
                helpText: "Lyrics"
            ) {
                historyViewModel.showLyrics()
            }
            
            Spacer()
            
            SidebarIconButton(
                systemName: historyViewModel.selectedItem?.rating == 1 ? "hand.thumbsup.fill" : "hand.thumbsup",
                isEnabled: historyViewModel.selectedItem != nil,
                helpText: historyViewModel.selectedItem?.rating == 1 ? "Unlike" : "Like",
                tintColor: historyViewModel.selectedItem?.rating == 1 ? .green : nil
            ) {
                historyViewModel.likeSelected()
            }
            
            SidebarIconButton(
                systemName: historyViewModel.selectedItem?.rating == -1 ? "hand.thumbsdown.fill" : "hand.thumbsdown",
                isEnabled: historyViewModel.selectedItem != nil,
                helpText: historyViewModel.selectedItem?.rating == -1 ? "Remove Dislike" : "Dislike",
                tintColor: historyViewModel.selectedItem?.rating == -1 ? .red : nil
            ) {
                historyViewModel.dislikeSelected()
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
    }
}

// MARK: - Sidebar Icon Button (SwiftUI with hover states)

struct SidebarIconButton: View {
    let systemName: String
    let isEnabled: Bool
    let helpText: String
    var tintColor: Color?
    let action: () -> Void
    
    @State private var isHovering = false
    
    init(
        systemName: String,
        isEnabled: Bool = true,
        helpText: String = "",
        tintColor: Color? = nil,
        action: @escaping () -> Void
    ) {
        self.systemName = systemName
        self.isEnabled = isEnabled
        self.helpText = helpText
        self.tintColor = tintColor
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(tintColor ?? .primary)
                .frame(width: 24, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isHovering && isEnabled ? Color.primary.opacity(0.1) : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.4)
        .help(helpText)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

// MARK: - Preview

#Preview {
    SidebarView(
        stationsViewModel: .mock(
            stations: [
//                .mock(name: "Rock Classics", stationId: "1"),
//                .mock(name: "Chill Vibes", stationId: "2"),
//                .mock(name: "90s Alternative", stationId: "3")
            ],
            playingStationId: "1"
        ),
        historyViewModel: .mock(
            items: [
                .mock(title: "Song 1", artist: "Artist 1", album: "Album 1"),
                .mock(title: "Song 2", artist: "Artist 2", album: "Album 2")
            ]
        ),
        columnVisibility: .constant(.all)
    )
    .frame(width: 250, height: 300)
}
