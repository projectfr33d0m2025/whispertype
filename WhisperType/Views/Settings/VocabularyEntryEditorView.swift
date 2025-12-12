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
    
    @State private var validationError: String?
    
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
        .frame(width: 400, height: 450)
        .onAppear {
            loadExistingEntry()
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadExistingEntry() {
        guard let entry = existingEntry else { return }
        
        term = entry.term
        phonetic = entry.phonetic ?? ""
        aliasesText = entry.aliases.joined(separator: ", ")
        isPinned = entry.isPinned
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
                isPinned: isPinned
            )
        }
        
        onSave(entry)
        dismiss()
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
            isPinned: true
        )),
        onSave: { _ in }
    )
}
