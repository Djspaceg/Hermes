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
    @State private var sidebarWidth: CGFloat = 250
    
    var body: some View {
        GeometryReader { geometry in
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
            .onChange(of: geometry.size.width) { _, newWidth in
                withAnimation(.easeInOut(duration: 0.2)) {
                    sidebarWidth = newWidth
                }
            }
            .onAppear {
                sidebarWidth = geometry.size.width
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
            AppKitIconButton(
                systemName: "play.fill",
                isEnabled: selectedStation != nil,
                helpText: "Play Station"
            ) {
                if let station = selectedStation {
                    stationsViewModel.playStation(station)
                }
            }
            
            AppKitIconButton(
                systemName: "plus",
                helpText: "Add Station"
            ) {
                stationsViewModel.showAddStation()
            }
            
            AppKitIconButton(
                systemName: "pencil",
                isEnabled: selectedStation != nil,
                helpText: "Edit Station"
            ) {
                if let station = selectedStation {
                    stationsViewModel.editStation(station)
                }
            }
            
            Spacer()
            
            AppKitIconButton(
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
            AppKitIconButton(
                systemName: "music.note",
                isEnabled: historyViewModel.selectedItem != nil,
                helpText: "Song on Pandora"
            ) {
                historyViewModel.openSongOnPandora()
            }
            
            AppKitIconButton(
                systemName: "person",
                isEnabled: historyViewModel.selectedItem != nil,
                helpText: "Artist on Pandora"
            ) {
                historyViewModel.openArtistOnPandora()
            }
            
            AppKitIconButton(
                systemName: "square.stack",
                isEnabled: historyViewModel.selectedItem != nil,
                helpText: "Album on Pandora"
            ) {
                historyViewModel.openAlbumOnPandora()
            }
            
            AppKitIconButton(
                systemName: "text.quote",
                isEnabled: historyViewModel.selectedItem != nil,
                helpText: "Lyrics"
            ) {
                historyViewModel.showLyrics()
            }
            
            Spacer()
            
            AppKitIconButton(
                systemName: historyViewModel.selectedItem?.rating == 1 ? "hand.thumbsup.fill" : "hand.thumbsup",
                isEnabled: historyViewModel.selectedItem != nil,
                helpText: historyViewModel.selectedItem?.rating == 1 ? "Unlike" : "Like",
                tintColor: historyViewModel.selectedItem?.rating == 1 ? .systemGreen : nil
            ) {
                historyViewModel.likeSelected()
            }
            
            AppKitIconButton(
                systemName: historyViewModel.selectedItem?.rating == -1 ? "hand.thumbsdown.fill" : "hand.thumbsdown",
                isEnabled: historyViewModel.selectedItem != nil,
                helpText: historyViewModel.selectedItem?.rating == -1 ? "Remove Dislike" : "Dislike",
                tintColor: historyViewModel.selectedItem?.rating == -1 ? .systemRed : nil
            ) {
                historyViewModel.dislikeSelected()
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
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

// MARK: - AppKit Icon Button (for proper hover states)

/// An AppKit-backed icon button that provides proper hover states on macOS Tahoe.
/// SwiftUI buttons in content areas don't get hover states with Liquid Glass enabled,
/// but NSButton does, so we use this wrapper for footer buttons.
struct AppKitIconButton: NSViewRepresentable {
    let systemName: String
    let action: () -> Void
    let isEnabled: Bool
    let helpText: String
    var tintColor: NSColor?
    
    init(
        systemName: String,
        isEnabled: Bool = true,
        helpText: String = "",
        tintColor: NSColor? = nil,
        action: @escaping () -> Void
    ) {
        self.systemName = systemName
        self.action = action
        self.isEnabled = isEnabled
        self.helpText = helpText
        self.tintColor = tintColor
    }
    
    func makeNSView(context: Context) -> NSButton {
        let button = NSButton()
        button.bezelStyle = .accessoryBar
        button.isBordered = true
        button.imagePosition = .imageOnly
        button.target = context.coordinator
        button.action = #selector(Coordinator.buttonClicked)
        button.toolTip = helpText
        button.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        return button
    }
    
    func updateNSView(_ button: NSButton, context: Context) {
        let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)
        var image = NSImage(systemSymbolName: systemName, accessibilityDescription: helpText)?
            .withSymbolConfiguration(config)
        
        if let color = tintColor {
            image = image?.withSymbolConfiguration(
                NSImage.SymbolConfiguration(paletteColors: [color])
            )
        }
        
        button.image = image
        button.isEnabled = isEnabled
        button.toolTip = helpText
        context.coordinator.action = action
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(action: action)
    }
    
    class Coordinator: NSObject {
        var action: () -> Void
        
        init(action: @escaping () -> Void) {
            self.action = action
        }
        
        @objc func buttonClicked() {
            action()
        }
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
