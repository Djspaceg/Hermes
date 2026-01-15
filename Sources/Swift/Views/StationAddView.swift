//
//  NewStationView.swift
//  Hermes
//
//  View for creating new Pandora stations
//

import SwiftUI

struct StationAddView<ViewModel: StationAddViewModelProtocol>: View {
    @ObservedObject var viewModel: ViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab picker
            Picker("", selection: $viewModel.selectedTab) {
                ForEach(StationAddViewModel.Tab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding()
            
            Divider()
            
            // Content based on tab
            switch viewModel.selectedTab {
            case .search:
                searchView
            case .genres:
                genresView
            }
            
            // Error message
            if let errorMessage = viewModel.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                    Text(errorMessage)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding()
                .background(Color.orange.opacity(0.1))
            }
        }
        .frame(width: 500, height: 550)
        .onAppear {
            viewModel.loadGenres()
        }
        .onChange(of: viewModel.stationCreated) { _, created in
            if created {
                Task { @MainActor in
                    dismiss()
                }
            }
        }
    }
    
    // MARK: - Search View
    
    private var searchView: some View {
        VStack(spacing: 0) {
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search artists or songs...", text: $viewModel.searchQuery)
                    .textFieldStyle(.plain)
                if viewModel.isSearching {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 16, height: 16)
                }
            }
            .padding(10)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
            .padding()
            
            // Results list
            if viewModel.searchResults.isEmpty && !viewModel.searchQuery.isEmpty && !viewModel.isSearching {
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No results found")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Try a different search term")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.searchResults.isEmpty && viewModel.searchQuery.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("Search for artists or songs")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Type in the search field above")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(viewModel.searchResults) { result in
                    SearchResultRow(result: result, isCreating: viewModel.isCreating) {
                        viewModel.createStation(from: result)
                    }
                }
                .listStyle(.plain)
            }
        }
    }
    
    // MARK: - Genres View
    
    private var genresView: some View {
        Group {
            if viewModel.genres.isEmpty {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Loading genres...")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(viewModel.genres) { category in
                        Section(category.name) {
                            ForEach(category.genres) { genre in
                                Button(action: {
                                    viewModel.createStation(fromGenre: genre)
                                }) {
                                    HStack {
                                        Text(genre.name)
                                        Spacer()
                                        if viewModel.isCreating {
                                            ProgressView()
                                                .scaleEffect(0.7)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                                .disabled(viewModel.isCreating)
                            }
                        }
                    }
                }
                .listStyle(.sidebar)
            }
        }
    }
}

// MARK: - Search Result Row

struct SearchResultRow: View {
    let result: SearchResult
    let isCreating: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Image(systemName: iconName)
                    .font(.system(size: 20))
                    .foregroundColor(.secondary)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.name)
                        .font(.body)
                    if let artist = result.artist {
                        Text(artist)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if isCreating {
                    ProgressView()
                        .scaleEffect(0.7)
                } else {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.accentColor)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .disabled(isCreating)
    }
    
    private var iconName: String {
        switch result.type {
        case .artist:
            return "person.fill"
        case .song:
            return "music.note"
        case .genre:
            return "music.note.list"
        }
    }
}


// MARK: - Preview

#Preview {
    StationAddView(viewModel: PreviewNewStationViewModel())
}
