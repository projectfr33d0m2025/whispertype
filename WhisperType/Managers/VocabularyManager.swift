//
//  VocabularyManager.swift
//  WhisperType
//
//  Manages custom vocabulary entries with CRUD operations and prioritization.
//  Part of the v1.2 Vocabulary System feature.
//

import Foundation
import Combine

/// Manages custom vocabulary for transcription improvement
@MainActor
class VocabularyManager: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = VocabularyManager()
    
    // MARK: - Constants
    
    static let maxEntries = 200
    static let whisperHintLimit = 20
    static let llmVocabularyLimit = 50
    
    // MARK: - Published Properties
    
    @Published private(set) var entries: [VocabularyEntry] = []
    @Published var searchQuery: String = ""
    @Published var sortOrder: VocabularySortOrder = .nameAscending
    
    // MARK: - Dependencies
    
    private let storage: VocabularyStorage
    
    // MARK: - Computed Properties
    
    /// Number of entries
    var entryCount: Int { entries.count }
    
    /// Whether we're at capacity
    var isAtCapacity: Bool { entries.count >= Self.maxEntries }
    
    /// Remaining capacity
    var remainingCapacity: Int { max(0, Self.maxEntries - entries.count) }
    
    /// Pinned entries
    var pinnedEntries: [VocabularyEntry] {
        entries.filter { $0.isPinned }
    }
    
    /// Frequently used entries (top 20 by usage)
    var frequentlyUsedEntries: [VocabularyEntry] {
        entries
            .filter { $0.useCount > 0 && !$0.isPinned }
            .sorted { $0.useCount > $1.useCount }
            .prefix(20)
            .map { $0 }
    }
    
    /// Filtered and sorted entries based on search and sort order
    var filteredEntries: [VocabularyEntry] {
        var result = entries
        
        // Apply search filter
        if !searchQuery.isEmpty {
            let query = searchQuery.lowercased()
            result = result.filter { entry in
                entry.term.lowercased().contains(query) ||
                entry.aliases.contains { $0.lowercased().contains(query) } ||
                (entry.phonetic?.lowercased().contains(query) ?? false)
            }
        }
        
        // Apply sort
        return sortOrder.sort(result)
    }
    
    // MARK: - Initialization
    
    private init(storage: VocabularyStorage = .shared) {
        self.storage = storage
        loadFromDisk()
    }
    
    // MARK: - CRUD Operations
    
    /// Add a new vocabulary entry
    func add(_ entry: VocabularyEntry) throws {
        guard !isAtCapacity else {
            throw VocabularyError.capacityExceeded
        }
        
        // Check for duplicate term
        if entries.contains(where: { $0.term.lowercased() == entry.term.lowercased() }) {
            throw VocabularyError.duplicateTerm(entry.term)
        }
        
        entries.append(entry)
        saveToDisk()
        print("VocabularyManager: Added entry '\(entry.term)'")
    }
    
    /// Add a new entry with just a term (convenience method)
    func addTerm(_ term: String, phonetic: String? = nil, aliases: [String] = [], isPinned: Bool = false) throws {
        let entry = VocabularyEntry(
            term: term,
            phonetic: phonetic,
            aliases: aliases,
            source: .manual,
            isPinned: isPinned
        )
        try add(entry)
    }
    
    /// Update an existing entry
    func update(_ entry: VocabularyEntry) {
        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else {
            print("VocabularyManager: Entry not found for update: \(entry.id)")
            return
        }
        
        entries[index] = entry
        saveToDisk()
        print("VocabularyManager: Updated entry '\(entry.term)'")
    }
    
    /// Delete an entry by ID
    func delete(_ id: UUID) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else {
            print("VocabularyManager: Entry not found for delete: \(id)")
            return
        }
        
        let term = entries[index].term
        entries.remove(at: index)
        saveToDisk()
        print("VocabularyManager: Deleted entry '\(term)'")
    }
    
    /// Delete multiple entries
    func delete(_ ids: Set<UUID>) {
        entries.removeAll { ids.contains($0.id) }
        saveToDisk()
        print("VocabularyManager: Deleted \(ids.count) entries")
    }
    
    /// Get entry by ID
    func get(_ id: UUID) -> VocabularyEntry? {
        entries.first { $0.id == id }
    }
    
    /// Toggle pinned status
    func togglePinned(_ id: UUID) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[index].isPinned.toggle()
        saveToDisk()
    }
    
    // MARK: - Usage Tracking
    
    /// Increment usage count for a term
    func incrementUsage(_ term: String) {
        let lowercasedTerm = term.lowercased()
        
        for i in entries.indices {
            if entries[i].term.lowercased() == lowercasedTerm ||
               entries[i].aliases.contains(where: { $0.lowercased() == lowercasedTerm }) {
                entries[i].useCount += 1
                entries[i].lastUsed = Date()
                saveToDisk()
                print("VocabularyManager: Incremented usage for '\(entries[i].term)' to \(entries[i].useCount)")
                return
            }
        }
    }
    
    // MARK: - Prioritization (for Whisper and LLM)
    
    /// Get top vocabulary hints for Whisper initial_prompt (max 20)
    /// - Parameter context: Optional bundle ID to filter context-specific terms
    func getWhisperHints(context: String? = nil) -> [String] {
        // Filter by context, then prioritize: pinned first, then by usage
        let contextFiltered = entries.filter { $0.isRelevantForContext(context) }
        
        let pinned = contextFiltered.filter { $0.isPinned }.map { $0.term }
        let byUsage = contextFiltered
            .filter { !$0.isPinned }
            .sorted { $0.useCount > $1.useCount }
            .map { $0.term }
        
        let combined = pinned + byUsage
        return Array(combined.prefix(Self.whisperHintLimit))
    }
    
    /// Get vocabulary for LLM prompt injection (max 50)
    /// - Parameter context: Optional bundle ID to filter context-specific terms
    func getLLMVocabulary(context: String? = nil) -> [String] {
        // Filter by context, then prioritize: pinned first, then by usage
        let contextFiltered = entries.filter { $0.isRelevantForContext(context) }
        
        let pinned = contextFiltered.filter { $0.isPinned }.map { $0.term }
        let byUsage = contextFiltered
            .filter { !$0.isPinned }
            .sorted { $0.useCount > $1.useCount }
            .map { $0.term }
        
        let combined = pinned + byUsage
        return Array(combined.prefix(Self.llmVocabularyLimit))
    }
    
    /// Get all entries for post-processing correction
    /// - Parameter context: Optional bundle ID to filter context-specific terms
    func getAllForCorrection(context: String? = nil) -> [VocabularyEntry] {
        if let context = context {
            return entries.filter { $0.isRelevantForContext(context) }
        }
        return entries
    }
    
    /// Get entries that have specific contexts defined
    func getContextSpecificEntries() -> [VocabularyEntry] {
        entries.filter { !$0.contexts.isEmpty }
    }
    
    /// Get all unique contexts across all entries
    func getAllContexts() -> [String] {
        let allContexts = entries.flatMap { $0.contexts }
        return Array(Set(allContexts)).sorted()
    }
    
    // MARK: - Import/Export
    
    /// Export all entries to CSV
    func exportToCSV() -> URL? {
        storage.exportToCSV(entries)
    }
    
    /// Import entries from CSV (merge with existing)
    func importFromCSV(_ url: URL, mergeStrategy: ImportMergeStrategy = .skipDuplicates) throws -> ImportResult {
        let importedEntries = try storage.importFromCSV(url)
        
        var added = 0
        var skipped = 0
        var updated = 0
        
        for imported in importedEntries {
            // Check capacity
            if entries.count >= Self.maxEntries && mergeStrategy != .updateExisting {
                skipped += importedEntries.count - added - skipped - updated
                break
            }
            
            // Check for existing entry with same term
            if let existingIndex = entries.firstIndex(where: { $0.term.lowercased() == imported.term.lowercased() }) {
                switch mergeStrategy {
                case .skipDuplicates:
                    skipped += 1
                case .updateExisting:
                    // Merge: keep existing ID, update other fields
                    var merged = imported
                    merged = VocabularyEntry(
                        id: entries[existingIndex].id,
                        term: imported.term,
                        phonetic: imported.phonetic ?? entries[existingIndex].phonetic,
                        aliases: Array(Set(entries[existingIndex].aliases + imported.aliases)),
                        source: entries[existingIndex].source,
                        isPinned: entries[existingIndex].isPinned || imported.isPinned,
                        useCount: max(entries[existingIndex].useCount, imported.useCount),
                        createdAt: entries[existingIndex].createdAt,
                        lastUsed: entries[existingIndex].lastUsed
                    )
                    entries[existingIndex] = merged
                    updated += 1
                case .replaceDuplicates:
                    entries[existingIndex] = imported
                    updated += 1
                }
            } else {
                // New entry
                entries.append(imported)
                added += 1
            }
        }
        
        saveToDisk()
        
        let result = ImportResult(added: added, skipped: skipped, updated: updated)
        print("VocabularyManager: Import complete - \(result)")
        return result
    }
    
    // MARK: - Persistence
    
    private func loadFromDisk() {
        entries = storage.load()
        print("VocabularyManager: Loaded \(entries.count) entries")
    }
    
    private func saveToDisk() {
        storage.save(entries)
    }
    
    /// Force reload from disk
    func reload() {
        loadFromDisk()
    }
    
    /// Clear all entries
    func clearAll() {
        entries.removeAll()
        saveToDisk()
        print("VocabularyManager: Cleared all entries")
    }
}

// MARK: - Error Types

enum VocabularyError: LocalizedError {
    case capacityExceeded
    case duplicateTerm(String)
    case invalidEntry(String)
    
    var errorDescription: String? {
        switch self {
        case .capacityExceeded:
            return "Maximum vocabulary capacity (\(VocabularyManager.maxEntries) entries) reached."
        case .duplicateTerm(let term):
            return "A vocabulary entry for '\(term)' already exists."
        case .invalidEntry(let reason):
            return "Invalid vocabulary entry: \(reason)"
        }
    }
}

// MARK: - Import Types

enum ImportMergeStrategy: String, CaseIterable, Identifiable {
    case skipDuplicates = "skip"
    case updateExisting = "update"
    case replaceDuplicates = "replace"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .skipDuplicates: return "Skip Duplicates"
        case .updateExisting: return "Merge with Existing"
        case .replaceDuplicates: return "Replace Duplicates"
        }
    }
    
    var description: String {
        switch self {
        case .skipDuplicates: return "Keep existing entries, skip imported duplicates"
        case .updateExisting: return "Merge imported data into existing entries"
        case .replaceDuplicates: return "Replace existing entries with imported ones"
        }
    }
}

struct ImportResult: CustomStringConvertible {
    let added: Int
    let skipped: Int
    let updated: Int
    
    var total: Int { added + skipped + updated }
    
    var description: String {
        "Added: \(added), Skipped: \(skipped), Updated: \(updated)"
    }
    
    var summary: String {
        var parts: [String] = []
        if added > 0 { parts.append("\(added) added") }
        if updated > 0 { parts.append("\(updated) updated") }
        if skipped > 0 { parts.append("\(skipped) skipped") }
        return parts.isEmpty ? "No changes" : parts.joined(separator: ", ")
    }
}
