//
//  VocabularyEntryEditorView.swift
//  WhisperType
//
//  Sheet for adding or editing vocabulary entries.
//  Part of the v1.2 Vocabulary System feature.
//

import SwiftUI

struct VocabularyEntryEditorView: View {
    
    enum Mode {
        case add
        case edit(VocabularyEntry)
        
        var title: String {
            switch self {
            case .add: return "Add Vocabulary Entry"
            case .edit: return "Edit Vocabulary Entry"
            }
        }
        
        var saveButtonTitle: String {
            switch self {
            case .add: return "Add"
            case .edit: return "Save"
            }
        }
    }
    
    let mode: Mode
    let onSave: (VocabularyEntry) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var term: String = ""
    @State private var phonetic: String = ""
    @State private var aliasesText: String = ""
    @State private var isPinned: Bool = false
    @State private var selectedContexts: Set<String> = []
    @State private var showContextPicker: Bool = false
    
    @State private var validationError: String?
    
    @ObservedObject private var appAwareManager = AppAwareManager.shared
    
    // For edit mode
    private var existingEntry: VocabularyEntry? {
        if case .edit(let entry) = mode {
            return entry
        }
        return nil
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(mode.title)
                    .font(.headline)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            
            Divider()
            
            // Form
            Form {
                // Term field
                Section {
                    TextField("Term", text: $term)
                        .textFieldStyle(.roundedBorder)
                } header: {
                    Text("Term")
                } footer: {
                    Text("The correct spelling of the word or phrase")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Phonetic field
                Section {
                    TextField("Optional pronunciation", text: $phonetic)
                        .textFieldStyle(.roundedBorder)
                } header: {
                    Text("Phonetic")
                } footer: {
                    Text("How the term sounds (e.g., \"eng lee-ong\")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Aliases field
                Section {
                    TextField("Common misspellings, separated by commas", text: $aliasesText)
                        .textFieldStyle(.roundedBorder)
                } header: {
                    Text("Aliases")
                } footer: {
                    Text("Words that should be corrected to the term (e.g., \"England, English long\")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // App Contexts field
                Section {
                    HStack {
                        if selectedContexts.isEmpty {
                            Text("All apps")
                                .foregroundColor(.secondary)
                        } else {
                            Text(contextDisplayText)
                                .lineLimit(2)
                        }
                        Spacer()
                        Button("Select Apps...") {
                            showContextPicker = true
                        }
                    }
                } header: {
                    Text("App Contexts")
                } footer: {
                    Text("Limit this term to specific apps, or leave empty for all apps")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Pin toggle
                Section {
                    Toggle("Pin this entry", isOn: $isPinned)
                } footer: {
                    Text("Pinned entries are always included in the active vocabulary")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Validation error
                if let error = validationError {
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            
            Divider()
            
            // Footer buttons
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape)
                
                Spacer()
                
                Button(mode.saveButtonTitle) {
                    save()
                }
                .keyboardShortcut(.return)
                .disabled(term.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 400, height: 520)
        .onAppear {
            loadExistingEntry()
        }
        .sheet(isPresented: $showContextPicker) {
            AppContextPickerView(selectedContexts: $selectedContexts)
        }
    }
    
    // MARK: - Computed Properties
    
    private var contextDisplayText: String {
        let entries = appAwareManager.getAllAppEntries()
        let names = selectedContexts.compactMap { bundleId in
            entries.first { $0.bundleIdentifier == bundleId }?.displayName ?? bundleId
        }
        return names.sorted().joined(separator: ", ")
    }
    
    // MARK: - Helper Methods
    
    private func loadExistingEntry() {
        guard let entry = existingEntry else { return }
        
        term = entry.term
        phonetic = entry.phonetic ?? ""
        aliasesText = entry.aliases.joined(separator: ", ")
        isPinned = entry.isPinned
        selectedContexts = Set(entry.contexts)
    }
    
    private func parseAliases() -> [String] {
        aliasesText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
    
    private func validate() -> Bool {
        let trimmedTerm = term.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedTerm.isEmpty {
            validationError = "Term cannot be empty"
            return false
        }
        
        if trimmedTerm.count < 2 {
            validationError = "Term must be at least 2 characters"
            return false
        }
        
        // Check for duplicate (only in add mode)
        if case .add = mode {
            let existing = VocabularyManager.shared.entries.first {
                $0.term.lowercased() == trimmedTerm.lowercased()
            }
            if existing != nil {
                validationError = "An entry for '\(trimmedTerm)' already exists"
                return false
            }
        }
        
        validationError = nil
        return true
    }
    
    private func save() {
        guard validate() else { return }
        
        let trimmedTerm = term.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPhonetic = phonetic.trimmingCharacters(in: .whitespacesAndNewlines)
        let aliases = parseAliases()
        let contexts = Array(selectedContexts)
        
        let entry: VocabularyEntry
        
        if let existing = existingEntry {
            // Update existing entry
            entry = VocabularyEntry(
                id: existing.id,
                term: trimmedTerm,
                phonetic: trimmedPhonetic.isEmpty ? nil : trimmedPhonetic,
                aliases: aliases,
                source: existing.source,
                isPinned: isPinned,
                contexts: contexts,
                useCount: existing.useCount,
                createdAt: existing.createdAt,
                lastUsed: existing.lastUsed
            )
        } else {
            // Create new entry
            entry = VocabularyEntry(
                term: trimmedTerm,
                phonetic: trimmedPhonetic.isEmpty ? nil : trimmedPhonetic,
                aliases: aliases,
                source: .manual,
                isPinned: isPinned,
                contexts: contexts
            )
        }
        
        onSave(entry)
        dismiss()
    }
}

// MARK: - App Context Picker View

struct AppContextPickerView: View {
    @Binding var selectedContexts: Set<String>
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var appAwareManager = AppAwareManager.shared
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Select Apps")
                    .font(.headline)
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.return)
            }
            .padding()
            
            Divider()
            
            // Clear all option
            HStack {
                Text("Clear all (use in all apps)")
                    .foregroundColor(.secondary)
                Spacer()
                if !selectedContexts.isEmpty {
                    Button("Clear") {
                        selectedContexts.removeAll()
                    }
                    .buttonStyle(.link)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            Divider()
            
            // App list
            List {
                ForEach(appAwareManager.getAppEntriesByCategory(), id: \.category) { group in
                    Section(header: Text(group.category.displayName)) {
                        ForEach(group.entries) { entry in
                            AppContextRow(
                                entry: entry,
                                isSelected: selectedContexts.contains(entry.bundleIdentifier)
                            ) {
                                if selectedContexts.contains(entry.bundleIdentifier) {
                                    selectedContexts.remove(entry.bundleIdentifier)
                                } else {
                                    selectedContexts.insert(entry.bundleIdentifier)
                                }
                            }
                        }
                    }
                }
            }
        }
        .frame(width: 350, height: 400)
    }
}

// MARK: - App Context Row

struct AppContextRow: View {
    let entry: AppAwareManager.AppEntry
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isSelected ? .accentColor : .secondary)
            
            Text(entry.displayName)
            
            Spacer()
            
            Text(entry.currentMode.displayName)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onToggle()
        }
    }
}

// MARK: - Preview

#Preview("Add Mode") {
    VocabularyEntryEditorView(
        mode: .add,
        onSave: { _ in }
    )
}

#Preview("Edit Mode") {
    VocabularyEntryEditorView(
        mode: .edit(VocabularyEntry(
            term: "Eng Leong",
            phonetic: "eng lee-ong",
            aliases: ["England", "English long"],
            isPinned: true,
            contexts: ["com.apple.Terminal", "com.microsoft.VSCode"]
        )),
        onSave: { _ in }
    )
}
