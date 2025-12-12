//
//  VocabularySettingsView.swift
//  WhisperType
//
//  Settings tab for managing custom vocabulary entries.
//  Part of the v1.2 Vocabulary System feature.
//

import SwiftUI
import UniformTypeIdentifiers

struct VocabularySettingsView: View {
    @ObservedObject var vocabularyManager = VocabularyManager.shared
    
    @State private var showAddSheet = false
    @State private var editingEntry: VocabularyEntry?
    @State private var showImportPicker = false
    @State private var showImportOptions = false
    @State private var importURL: URL?
    @State private var importMergeStrategy: ImportMergeStrategy = .skipDuplicates
    @State private var showDeleteConfirmation = false
    @State private var entryToDelete: VocabularyEntry?
    @State private var showExportSuccess = false
    @State private var importResult: ImportResult?
    @State private var showImportResult = false
    @State private var errorMessage: String?
    @State private var showError = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            Divider()
            
            // Content
            if vocabularyManager.entries.isEmpty {
                emptyStateView
            } else {
                listView
            }
            
            Divider()
            
            // Footer
            footerView
        }
        .sheet(isPresented: $showAddSheet) {
            VocabularyEntryEditorView(
                mode: .add,
                onSave: { entry in
                    do {
                        try vocabularyManager.add(entry)
                    } catch {
                        errorMessage = error.localizedDescription
                        showError = true
                    }
                }
            )
        }
        .sheet(item: $editingEntry) { entry in
            VocabularyEntryEditorView(
                mode: .edit(entry),
                onSave: { updatedEntry in
                    vocabularyManager.update(updatedEntry)
                }
            )
        }
        .fileImporter(
            isPresented: $showImportPicker,
            allowedContentTypes: [.commaSeparatedText, .plainText],
            allowsMultipleSelection: false
        ) { result in
            handleImportSelection(result)
        }
        .confirmationDialog(
            "Import Options",
            isPresented: $showImportOptions,
            titleVisibility: .visible
        ) {
            importOptionsButtons
        }
        .alert("Delete Entry", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let entry = entryToDelete {
                    vocabularyManager.delete(entry.id)
                }
            }
        } message: {
            if let entry = entryToDelete {
                Text("Are you sure you want to delete '\(entry.term)'?")
            }
        }
        .alert("Export Complete", isPresented: $showExportSuccess) {
            Button("OK") {}
            Button("Show in Finder") {
                if let url = vocabularyManager.exportToCSV() {
                    NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: url.deletingLastPathComponent().path)
                }
            }
        } message: {
            Text("Vocabulary exported successfully.")
        }
        .alert("Import Complete", isPresented: $showImportResult) {
            Button("OK") {}
        } message: {
            if let result = importResult {
                Text(result.summary)
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") {}
        } message: {
            if let error = errorMessage {
                Text(error)
            }
        }
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Custom Vocabulary")
                        .font(.headline)
                    Text("Add names, terms, and jargon for better transcription accuracy")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Entry count badge
                Text("\(vocabularyManager.entryCount) / \(VocabularyManager.maxEntries)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(vocabularyManager.isAtCapacity ? Color.orange.opacity(0.2) : Color.secondary.opacity(0.1))
                    )
            }
            
            HStack(spacing: 8) {
                // Search field
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search vocabulary...", text: $vocabularyManager.searchQuery)
                        .textFieldStyle(.plain)
                    if !vocabularyManager.searchQuery.isEmpty {
                        Button(action: { vocabularyManager.searchQuery = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(6)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(6)
                
                // Sort picker
                Picker("Sort", selection: $vocabularyManager.sortOrder) {
                    ForEach(VocabularySortOrder.allCases) { order in
                        Label(order.displayName, systemImage: order.icon)
                            .tag(order)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 140)
                
                // Add button
                Button(action: { showAddSheet = true }) {
                    Label("Add", systemImage: "plus")
                }
                .disabled(vocabularyManager.isAtCapacity)
            }
        }
        .padding()
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "textformat.abc")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No Vocabulary Entries")
                .font(.headline)
            
            Text("Add custom terms like names, technical jargon, or\nfrequently misrecognized words to improve accuracy.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            HStack(spacing: 12) {
                Button("Add Entry") {
                    showAddSheet = true
                }
                .buttonStyle(.borderedProminent)
                
                Button("Import CSV") {
                    showImportPicker = true
                }
                .buttonStyle(.bordered)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - List View
    
    private var listView: some View {
        List {
            // Pinned section
            if !vocabularyManager.pinnedEntries.isEmpty && vocabularyManager.searchQuery.isEmpty {
                Section {
                    ForEach(vocabularyManager.pinnedEntries) { entry in
                        VocabularyEntryRow(
                            entry: entry,
                            onEdit: { editingEntry = entry },
                            onDelete: { confirmDelete(entry) },
                            onTogglePin: { vocabularyManager.togglePinned(entry.id) }
                        )
                    }
                } header: {
                    Label("Pinned", systemImage: "pin.fill")
                }
            }
            
            // All entries section
            Section {
                ForEach(vocabularyManager.filteredEntries.filter { !$0.isPinned || !vocabularyManager.searchQuery.isEmpty }) { entry in
                    VocabularyEntryRow(
                        entry: entry,
                        onEdit: { editingEntry = entry },
                        onDelete: { confirmDelete(entry) },
                        onTogglePin: { vocabularyManager.togglePinned(entry.id) }
                    )
                }
            } header: {
                if vocabularyManager.searchQuery.isEmpty {
                    Text("All Entries")
                } else {
                    Text("Search Results (\(vocabularyManager.filteredEntries.count))")
                }
            }
        }
        .listStyle(.inset)
    }
    
    // MARK: - Footer View
    
    private var footerView: some View {
        HStack {
            // Import button
            Button(action: { showImportPicker = true }) {
                Label("Import", systemImage: "square.and.arrow.down")
            }
            .disabled(vocabularyManager.isAtCapacity)
            
            // Export button
            Button(action: exportVocabulary) {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            .disabled(vocabularyManager.entries.isEmpty)
            
            Spacer()
            
            // Storage info
            if VocabularyStorage.shared.fileExists {
                Text("Storage: \(VocabularyStorage.shared.fileSizeFormatted)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
    
    // MARK: - Import Options
    
    @ViewBuilder
    private var importOptionsButtons: some View {
        Button("Skip Duplicates") {
            importMergeStrategy = .skipDuplicates
            performImport()
        }
        Button("Merge with Existing") {
            importMergeStrategy = .updateExisting
            performImport()
        }
        Button("Replace Duplicates") {
            importMergeStrategy = .replaceDuplicates
            performImport()
        }
        Button("Cancel", role: .cancel) {
            importURL = nil
        }
    }
    
    // MARK: - Actions
    
    private func confirmDelete(_ entry: VocabularyEntry) {
        entryToDelete = entry
        showDeleteConfirmation = true
    }
    
    private func exportVocabulary() {
        if let _ = vocabularyManager.exportToCSV() {
            showExportSuccess = true
        }
    }
    
    private func handleImportSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            importURL = url
            showImportOptions = true
        case .failure(let error):
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    private func performImport() {
        guard let url = importURL else { return }
        
        // Start accessing security-scoped resource
        guard url.startAccessingSecurityScopedResource() else {
            errorMessage = "Could not access the selected file."
            showError = true
            return
        }
        
        defer { url.stopAccessingSecurityScopedResource() }
        
        do {
            importResult = try vocabularyManager.importFromCSV(url, mergeStrategy: importMergeStrategy)
            showImportResult = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        
        importURL = nil
    }
}

// MARK: - Preview

#Preview {
    VocabularySettingsView()
        .frame(width: 550, height: 450)
}
