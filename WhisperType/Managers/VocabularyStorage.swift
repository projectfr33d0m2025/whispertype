//
//  VocabularyStorage.swift
//  WhisperType
//
//  Handles persistence of vocabulary entries to disk.
//  Part of the v1.2 Vocabulary System feature.
//

import Foundation

/// Handles loading and saving vocabulary entries to disk
class VocabularyStorage {
    
    // MARK: - Singleton
    
    static let shared = VocabularyStorage()
    
    // MARK: - Constants
    
    private let fileName = "vocabulary.json"
    
    // MARK: - Storage Path
    
    /// Directory for WhisperType data
    private var storageDirectory: URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        
        return appSupport.appendingPathComponent("WhisperType", isDirectory: true)
    }
    
    /// Full path to vocabulary file
    private var vocabularyFileURL: URL {
        storageDirectory.appendingPathComponent(fileName)
    }
    
    // MARK: - Initialization
    
    private init() {
        ensureStorageDirectoryExists()
    }
    
    // MARK: - Directory Management
    
    private func ensureStorageDirectoryExists() {
        let fm = FileManager.default
        if !fm.fileExists(atPath: storageDirectory.path) {
            do {
                try fm.createDirectory(at: storageDirectory, withIntermediateDirectories: true)
                print("VocabularyStorage: Created storage directory at \(storageDirectory.path)")
            } catch {
                print("VocabularyStorage: Failed to create storage directory: \(error)")
            }
        }
    }
    
    // MARK: - Load
    
    /// Load vocabulary entries from disk
    func load() -> [VocabularyEntry] {
        let fm = FileManager.default
        
        guard fm.fileExists(atPath: vocabularyFileURL.path) else {
            print("VocabularyStorage: No vocabulary file found, returning empty array")
            return []
        }
        
        do {
            let data = try Data(contentsOf: vocabularyFileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let entries = try decoder.decode([VocabularyEntry].self, from: data)
            print("VocabularyStorage: Loaded \(entries.count) entries from disk")
            return entries
        } catch {
            print("VocabularyStorage: Failed to load vocabulary: \(error)")
            return []
        }
    }
    
    // MARK: - Save
    
    /// Save vocabulary entries to disk (atomic write)
    func save(_ entries: [VocabularyEntry]) {
        ensureStorageDirectoryExists()
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(entries)
            
            // Atomic write: write to temp file, then rename
            let tempURL = storageDirectory.appendingPathComponent("vocabulary_temp.json")
            try data.write(to: tempURL, options: .atomic)
            
            // Move temp to final location
            let fm = FileManager.default
            if fm.fileExists(atPath: vocabularyFileURL.path) {
                try fm.removeItem(at: vocabularyFileURL)
            }
            try fm.moveItem(at: tempURL, to: vocabularyFileURL)
            
            print("VocabularyStorage: Saved \(entries.count) entries to disk")
        } catch {
            print("VocabularyStorage: Failed to save vocabulary: \(error)")
        }
    }
    
    // MARK: - Export
    
    /// Export vocabulary to CSV file
    func exportToCSV(_ entries: [VocabularyEntry]) -> URL? {
        let csvContent = ([VocabularyEntry.csvHeader] + entries.map { $0.csvRow }).joined(separator: "\n")
        
        let exportURL = storageDirectory.appendingPathComponent("vocabulary_export.csv")
        
        do {
            try csvContent.write(to: exportURL, atomically: true, encoding: .utf8)
            print("VocabularyStorage: Exported \(entries.count) entries to CSV")
            return exportURL
        } catch {
            print("VocabularyStorage: Failed to export CSV: \(error)")
            return nil
        }
    }
    
    // MARK: - Import
    
    /// Import vocabulary from CSV file
    func importFromCSV(_ url: URL) throws -> [VocabularyEntry] {
        let content = try String(contentsOf: url, encoding: .utf8)
        let lines = content.components(separatedBy: .newlines)
        
        var entries: [VocabularyEntry] = []
        var startIndex = 0
        
        // Skip header if present
        if let firstLine = lines.first?.lowercased(),
           firstLine.contains("term") {
            startIndex = 1
        }
        
        for i in startIndex..<lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }
            
            if let entry = VocabularyEntry.fromCSV(line) {
                entries.append(entry)
            }
        }
        
        print("VocabularyStorage: Imported \(entries.count) entries from CSV")
        return entries
    }
    
    // MARK: - Storage Info
    
    /// Get storage file size in bytes
    var fileSizeBytes: Int64 {
        let fm = FileManager.default
        guard let attrs = try? fm.attributesOfItem(atPath: vocabularyFileURL.path),
              let size = attrs[.size] as? Int64 else {
            return 0
        }
        return size
    }
    
    /// Get storage file size formatted
    var fileSizeFormatted: String {
        let bytes = fileSizeBytes
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    /// Check if vocabulary file exists
    var fileExists: Bool {
        FileManager.default.fileExists(atPath: vocabularyFileURL.path)
    }
}
