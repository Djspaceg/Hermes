//
//  StationEditorView.swift
//  Hermes
//
//  View for editing station details, seeds, and feedback
//

import SwiftUI

struct StationEditView<ViewModel: StationEditViewModelProtocol>: View {
    @ObservedObject var viewModel: ViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var isEditingName = false
    @State private var editedName = ""
    @State private var selectedTab: Tab = .likes

    enum Tab: String, CaseIterable {
        case likes = "Likes"
        case dislikes = "Dislikes"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isLoading {
                loadingView
            } else {
                contentView
            }
        }
        .frame(width: 800, height: 400)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
        .onAppear {
            viewModel.loadDetailsIfNeeded()
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading station details...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Content View
    
    private var contentView: some View {
        HSplitView {
            // Left: Station info and seeds
            VStack(alignment: .leading, spacing: 0) {
                stationInfoSection
                    .padding()
                
                Divider()
                
                seedsSection
                    .padding()
                
                Spacer()
            }
            .frame(minWidth: 400, maxHeight: .infinity, alignment: .top)
            
            // Right: Feedback tabs
            feedbackSection.frame(minWidth: 300, maxHeight: .infinity, alignment: .top)
        }
    }
    
    // MARK: - Station Info Section
    
    private var stationInfoSection: some View {
        HStack(spacing: 16) {
            // Artwork
            AsyncImage(url: viewModel.artworkURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Color.gray.opacity(0.3)
                    .overlay {
                        Image(systemName: "music.note")
                            .font(.system(size: 32))
                            .foregroundColor(.secondary)
                    }
            }
            .frame(width: 100, height: 100)
            .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 8) {
                // Editable name
                if isEditingName {
                    HStack {
                        TextField("Station Name", text: $editedName)
                            .textFieldStyle(.roundedBorder)
                        Button("Save") {
                            viewModel.renameStation(to: editedName)
                            isEditingName = false
                        }
                        .disabled(editedName.isEmpty || viewModel.isSaving)
                        Button("Cancel") {
                            isEditingName = false
                        }
                    }
                } else {
                    HStack {
                        Text(viewModel.stationName)
                            .font(.title2.bold())
                        Button(action: {
                            editedName = viewModel.stationName
                            isEditingName = true
                        }) {
                            Image(systemName: "pencil")
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                if !viewModel.stationCreated.isEmpty {
                    Label(viewModel.stationCreated, systemImage: "calendar")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if !viewModel.stationGenres.isEmpty {
                    Label(viewModel.stationGenres, systemImage: "music.note.list")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Button(action: viewModel.openInPandora) {
                    Label("Open in Pandora", systemImage: "safari")
                }
                .buttonStyle(.link)
            }
        }
    }
    
    // MARK: - Seeds Section
    
    private var seedsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Seeds")
                .font(.headline)
            
            Text("Seeds define what music plays on this station")
                .font(.caption)
                .foregroundColor(.secondary)
            
            // Search to add seeds
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Add artist or song...", text: $viewModel.seedSearchQuery)
                    .textFieldStyle(.plain)
                if viewModel.isSearchingSeeds {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
            .padding(8)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(6)
            
            // Search results (if searching)
            if !viewModel.seedSearchResults.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Search Results")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                    
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(viewModel.seedSearchResults) { result in
                                SeedSearchResultRow(result: result) {
                                    viewModel.addSeed(result)
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 120)
                }
            }
            
            // Current seeds
            if viewModel.seeds.isEmpty {
                Text("No seeds yet")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                List {
                    ForEach(viewModel.seeds) { seed in
                        SeedRow(seed: seed) {
                            viewModel.deleteSeed(seed)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
    }
    
    // MARK: - Feedback Section
    
    private var feedbackSection: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                ForEach(Tab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding()
            
            Divider()
            
            switch selectedTab {
            case .likes:
                feedbackList(items: viewModel.likes, emptyMessage: "No liked songs")
            case .dislikes:
                feedbackList(items: viewModel.dislikes, emptyMessage: "No disliked songs")
            }
        }
    }
    
    private func feedbackList(items: [FeedbackItem], emptyMessage: String) -> some View {
        Group {
            if items.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "music.note")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text(emptyMessage)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(items) { item in
                        FeedbackRow(item: item) {
                            viewModel.deleteFeedback(item)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
    }
}

// MARK: - Seed Row

struct SeedRow: View {
    let seed: Seed
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: seed.type == .artist ? "person.fill" : "music.note")
                .font(.system(size: 16))
                .foregroundColor(.secondary)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(seed.name)
                    .font(.body)
                if let artist = seed.artist {
                    Text(artist)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Seed Search Result Row

struct SeedSearchResultRow: View {
    let result: SeedSearchResult
    let onAdd: () -> Void
    
    var body: some View {
        Button(action: onAdd) {
            HStack(spacing: 12) {
                Image(systemName: result.type == .artist ? "person.fill" : "music.note")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .frame(width: 20)
                
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
                
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(.accentColor)
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Feedback Row

struct FeedbackRow: View {
    let item: FeedbackItem
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.isPositive ? "hand.thumbsup.fill" : "hand.thumbsdown.fill")
                .font(.system(size: 16))
                .foregroundColor(item.isPositive ? .green : .red)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.body)
                Text(item.artist)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}


// MARK: - Preview

#Preview {
    StationEditView(
        viewModel: PreviewStationEditViewModel()
    )
}
