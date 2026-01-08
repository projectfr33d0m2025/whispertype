//
//  PartialTranscriptStore.swift
//  WhisperType
//
//  In-memory and persistent storage for partial transcripts during live recording.
//

import Foundation
import Combine

/// Storage for partial transcript updates during a recording session
@MainActor
class PartialTranscriptStore: ObservableObject {
    
    // MARK: - Published Properties
    
    /// All stored transcript updates
    @Published private(set) var entries: [TranscriptUpdate] = []
    
    /// Total word count across all entries
    @Published private(set) var wordCount: Int = 0
    
    // MARK: - Properties
    
    /// Session ID for this store
    let sessionId: String
    
    /// Directory for persistent storage
    private let storageDirectory: URL?
    
    // MARK: - Initialization
    
    init(sessionId: String = UUID().uuidString, storageDirectory: URL? = nil) {
        self.sessionId = sessionId
        self.storageDirectory = storageDirectory
        
        print("PartialTranscriptStore: Initialized for session \(sessionId)")
    }
    
    // MARK: - CRUD Operations
    
    /// Append a new transcript update
    /// - Parameter update: The update to append
    func append(_ update: TranscriptUpdate) {
        guard !update.isEmpty else { return }
        
        entries.append(update)
        updateWordCount()
        
        print("PartialTranscriptStore: Appended entry at \(update.formattedTimestamp)")
    }
    
    /// Append multiple updates
    /// - Parameter updates: Array of updates to append
    func appendAll(_ updates: [TranscriptUpdate]) {
        let nonEmpty = updates.filter { !$0.isEmpty }
        entries.append(contentsOf: nonEmpty)
        updateWordCount()
    }
    
    /// Get all entries in chronological order
    /// - Returns: All stored entries sorted by timestamp
    func getAll() -> [TranscriptUpdate] {
        entries.sorted { $0.timestamp < $1.timestamp }
    }
    
    /// Get entries within a time range
    /// - Parameters:
    ///   - start: Start timestamp
    ///   - end: End timestamp
    /// - Returns: Entries within the range
    func getInRange(start: TimeInterval, end: TimeInterval) -> [TranscriptUpdate] {
        entries.filter { $0.timestamp >= start && $0.timestamp <= end }
    }
    
    /// Clear all entries
    func clear() {
        entries = []
        wordCount = 0
        print("PartialTranscriptStore: Cleared all entries")
    }
    
    // MARK: - Combined Text
    
    /// Get combined transcript text
    var combinedText: String {
        entries
            .sorted { $0.timestamp < $1.timestamp }
            .map { $0.text }
            .joined(separator: " ")
    }
    
    /// Get formatted transcript with timestamps
    var formattedTranscript: String {
        entries
            .sorted { $0.timestamp < $1.timestamp }
            .map { "\($0.formattedTimestamp)\n\($0.text)" }
            .joined(separator: "\n\n")
    }
    
    // MARK: - Statistics
    
    private func updateWordCount() {
        wordCount = entries.reduce(0) { count, update in
            count + update.text.split(separator: " ").count
        }
    }
    
    /// Duration covered by stored transcripts
    var durationCovered: TimeInterval {
        guard let first = entries.min(by: { $0.timestamp < $1.timestamp }),
              let last = entries.max(by: { $0.timestamp < $1.timestamp }) else {
            return 0
        }
        return last.timestamp + last.audioDuration - first.timestamp
    }
    
    // MARK: - Persistence
    
    /// Save entries to JSON file
    func save() throws {
        guard let directory = storageDirectory else { return }
        
        let fileURL = directory.appendingPathComponent("partial_transcript.json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        let data = try encoder.encode(entries)
        try data.write(to: fileURL, options: .atomic)
        
        print("PartialTranscriptStore: Saved \(entries.count) entries to \(fileURL.lastPathComponent)")
    }
    
    /// Load entries from JSON file
    func load() throws {
        guard let directory = storageDirectory else { return }
        
        let fileURL = directory.appendingPathComponent("partial_transcript.json")
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("PartialTranscriptStore: No saved file found")
            return
        }
        
        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        entries = try decoder.decode([TranscriptUpdate].self, from: data)
        updateWordCount()
        
        print("PartialTranscriptStore: Loaded \(entries.count) entries")
    }
    
    /// Export to markdown format
    func exportToMarkdown() -> String {
        var markdown = "# Live Transcript\n\n"
        markdown += "**Session ID:** \(sessionId)\n"
        markdown += "**Words:** \(wordCount)\n"
        markdown += "**Duration:** \(String(format: "%.0f", durationCovered)) seconds\n\n"
        markdown += "---\n\n"
        markdown += formattedTranscript
        
        return markdown
    }
}
