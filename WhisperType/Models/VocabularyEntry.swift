//
//  VocabularyEntry.swift
//  WhisperType
//
//  Data model for custom vocabulary entries.
//  Part of the v1.2 Vocabulary System feature.
//

import Foundation

// MARK: - Vocabulary Source

/// Indicates how a vocabulary entry was created
enum VocabularySource: String, Codable, CaseIterable {
    case manual     // User manually added
    case imported   // Imported from CSV/file
    
    var displayName: String {
        switch self {
        case .manual: return "Manual"
        case .imported: return "Imported"
        }
    }
    
    var icon: String {
        switch self {
        case .manual: return "hand.draw"
        case .imported: return "square.and.arrow.down"
        }
    }
}

// MARK: - Vocabulary Entry

/// A custom vocabulary entry for improving transcription accuracy
struct VocabularyEntry: Identifiable, Codable, Hashable {
    
    // MARK: - Properties
    
    /// Unique identifier
    let id: UUID
    
    /// The correct spelling of the term (e.g., "Eng Leong")
    var term: String
    
    /// Optional pronunciation hint (e.g., "eng lee-ong")
    var phonetic: String?
    
    /// Common misrecognitions that should be corrected to this term
    /// e.g., ["England", "English long", "Ing Leong"]
    var aliases: [String]
    
    /// Origin of this entry
    var source: VocabularySource
    
    /// If true, always include in active vocabulary regardless of usage
    var isPinned: Bool
    
    /// App contexts where this term is relevant (bundle identifiers)
    /// Empty array means term is relevant in all contexts
    var contexts: [String]
    
    /// Number of times this term has been used/matched
    var useCount: Int
    
    /// When this entry was created
    let createdAt: Date
    
    /// When this entry was last used in transcription
    var lastUsed: Date?
    
    // MARK: - Initialization
    
    init(
        id: UUID = UUID(),
        term: String,
        phonetic: String? = nil,
        aliases: [String] = [],
        source: VocabularySource = .manual,
        isPinned: Bool = false,
        contexts: [String] = [],
        useCount: Int = 0,
        createdAt: Date = Date(),
        lastUsed: Date? = nil
    ) {
        self.id = id
        self.term = term
        self.phonetic = phonetic
        self.aliases = aliases
        self.source = source
        self.isPinned = isPinned
        self.contexts = contexts
        self.useCount = useCount
        self.createdAt = createdAt
        self.lastUsed = lastUsed
    }
    
    // MARK: - Computed Properties
    
    /// All terms to match against (term + aliases)
    var allMatchTerms: [String] {
        [term] + aliases
    }
    
    /// Display string for aliases
    var aliasesDisplayString: String {
        aliases.isEmpty ? "None" : aliases.joined(separator: ", ")
    }
    
    /// Display string for contexts
    var contextsDisplayString: String {
        contexts.isEmpty ? "All apps" : "\(contexts.count) app(s)"
    }
    
    /// Check if this entry is relevant for a given app context
    /// - Parameter bundleId: The bundle identifier of the current app (nil means no specific context)
    /// - Returns: True if the entry should be used in this context
    func isRelevantForContext(_ bundleId: String?) -> Bool {
        // If no contexts specified, term is relevant everywhere
        if contexts.isEmpty {
            return true
        }
        // If no bundle ID provided, include all entries
        guard let bundleId = bundleId else {
            return true
        }
        // Check if bundle ID is in the contexts list
        return contexts.contains(bundleId)
    }
    
    /// Formatted date string for createdAt
    var createdAtFormatted: String {
        Self.dateFormatter.string(from: createdAt)
    }
    
    /// Formatted date string for lastUsed
    var lastUsedFormatted: String? {
        guard let lastUsed = lastUsed else { return nil }
        return Self.dateFormatter.string(from: lastUsed)
    }
    
    // MARK: - Date Formatter
    
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
    
    // MARK: - Hashable
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: VocabularyEntry, rhs: VocabularyEntry) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Sorting

enum VocabularySortOrder: String, CaseIterable, Identifiable {
    case nameAscending = "name_asc"
    case nameDescending = "name_desc"
    case usageDescending = "usage_desc"
    case usageAscending = "usage_asc"
    case dateNewest = "date_newest"
    case dateOldest = "date_oldest"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .nameAscending: return "Name (A-Z)"
        case .nameDescending: return "Name (Z-A)"
        case .usageDescending: return "Most Used"
        case .usageAscending: return "Least Used"
        case .dateNewest: return "Newest First"
        case .dateOldest: return "Oldest First"
        }
    }
    
    var icon: String {
        switch self {
        case .nameAscending, .nameDescending: return "textformat.abc"
        case .usageDescending, .usageAscending: return "chart.bar"
        case .dateNewest, .dateOldest: return "calendar"
        }
    }
    
    func sort(_ entries: [VocabularyEntry]) -> [VocabularyEntry] {
        switch self {
        case .nameAscending:
            return entries.sorted { $0.term.localizedCaseInsensitiveCompare($1.term) == .orderedAscending }
        case .nameDescending:
            return entries.sorted { $0.term.localizedCaseInsensitiveCompare($1.term) == .orderedDescending }
        case .usageDescending:
            return entries.sorted { $0.useCount > $1.useCount }
        case .usageAscending:
            return entries.sorted { $0.useCount < $1.useCount }
        case .dateNewest:
            return entries.sorted { $0.createdAt > $1.createdAt }
        case .dateOldest:
            return entries.sorted { $0.createdAt < $1.createdAt }
        }
    }
}

// MARK: - CSV Export/Import

extension VocabularyEntry {
    
    /// CSV header for export
    static var csvHeader: String {
        "term,phonetic,aliases,isPinned,useCount"
    }
    
    /// Convert entry to CSV row
    var csvRow: String {
        let escapedTerm = term.csvEscaped
        let escapedPhonetic = (phonetic ?? "").csvEscaped
        let escapedAliases = aliases.joined(separator: "|").csvEscaped
        return "\(escapedTerm),\(escapedPhonetic),\(escapedAliases),\(isPinned),\(useCount)"
    }
    
    /// Create entry from CSV row
    static func fromCSV(_ row: String) -> VocabularyEntry? {
        let columns = row.csvColumns
        guard columns.count >= 1 else { return nil }
        
        let term = columns[0]
        guard !term.isEmpty else { return nil }
        
        let phonetic = columns.count > 1 && !columns[1].isEmpty ? columns[1] : nil
        let aliases = columns.count > 2 && !columns[2].isEmpty ? columns[2].split(separator: "|").map(String.init) : []
        let isPinned = columns.count > 3 ? columns[3].lowercased() == "true" : false
        let useCount = columns.count > 4 ? Int(columns[4]) ?? 0 : 0
        
        return VocabularyEntry(
            term: term,
            phonetic: phonetic,
            aliases: aliases,
            source: .imported,
            isPinned: isPinned,
            useCount: useCount
        )
    }
}

// MARK: - String CSV Helpers

private extension String {
    /// Escape string for CSV (handle commas and quotes)
    var csvEscaped: String {
        if contains(",") || contains("\"") || contains("\n") {
            return "\"\(replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return self
    }
    
    /// Parse CSV row into columns (handling quoted values)
    var csvColumns: [String] {
        var columns: [String] = []
        var current = ""
        var inQuotes = false
        var chars = Array(self)
        var i = 0
        
        while i < chars.count {
            let char = chars[i]
            
            if char == "\"" {
                if inQuotes && i + 1 < chars.count && chars[i + 1] == "\"" {
                    // Escaped quote
                    current.append("\"")
                    i += 1
                } else {
                    // Toggle quote mode
                    inQuotes.toggle()
                }
            } else if char == "," && !inQuotes {
                columns.append(current)
                current = ""
            } else {
                current.append(char)
            }
            
            i += 1
        }
        
        columns.append(current)
        return columns
    }
}
