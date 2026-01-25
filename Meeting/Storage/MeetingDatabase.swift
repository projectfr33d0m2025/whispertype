//
//  MeetingDatabase.swift
//  WhisperType
//
//  SQLite database manager for meeting metadata storage.
//  Provides CRUD operations and search functionality for meeting records.
//

import Foundation
import SQLite3

// MARK: - Meeting Status

enum MeetingStatus: String, Codable {
    case recording = "recording"
    case processing = "processing"
    case complete = "complete"
    case error = "error"
    
    var displayName: String {
        switch self {
        case .recording: return "Recording"
        case .processing: return "Processing"
        case .complete: return "Complete"
        case .error: return "Error"
        }
    }
}

// MARK: - Meeting Record

/// Persistent meeting record model for database storage
struct MeetingRecord: Identifiable, Codable, Equatable, Hashable {
    let id: String
    var title: String
    let createdAt: Date
    var durationSeconds: Int
    let audioSource: String
    var speakerCount: Int
    var status: MeetingStatus
    var errorMessage: String?
    let sessionDirectory: String
    var transcriptFile: String?
    var summaryFile: String?
    var audioKept: Bool
    var summaryPreview: String?
    var templateUsed: String?
    
    // MARK: - Hashable
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    // MARK: - Computed Properties
    
    var formattedDuration: String {
        let hours = durationSeconds / 3600
        let minutes = (durationSeconds % 3600) / 60
        let seconds = durationSeconds % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }
    
    var sessionDirectoryURL: URL {
        URL(fileURLWithPath: sessionDirectory)
    }
    
    var transcriptURL: URL? {
        guard let file = transcriptFile else { return nil }
        return sessionDirectoryURL.appendingPathComponent(file)
    }
    
    var summaryURL: URL? {
        guard let file = summaryFile else { return nil }
        return sessionDirectoryURL.appendingPathComponent(file)
    }
}

// MARK: - Meeting Action Item

/// An action item extracted from a meeting
struct MeetingActionItem: Identifiable, Codable, Equatable {
    let id: String
    let meetingId: String
    var assignee: String?
    var actionText: String
    var dueDate: String?
    var timestampSeconds: Int?
    var completed: Bool
    
    init(
        id: String = UUID().uuidString,
        meetingId: String,
        assignee: String? = nil,
        actionText: String,
        dueDate: String? = nil,
        timestampSeconds: Int? = nil,
        completed: Bool = false
    ) {
        self.id = id
        self.meetingId = meetingId
        self.assignee = assignee
        self.actionText = actionText
        self.dueDate = dueDate
        self.timestampSeconds = timestampSeconds
        self.completed = completed
    }
}

// MARK: - Database Error

enum MeetingDatabaseError: LocalizedError {
    case databaseNotOpen
    case prepareFailed(String)
    case executeFailed(String)
    case notFound(String)
    case migrationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .databaseNotOpen:
            return "Database is not open"
        case .prepareFailed(let message):
            return "Failed to prepare statement: \(message)"
        case .executeFailed(let message):
            return "Failed to execute statement: \(message)"
        case .notFound(let id):
            return "Meeting not found: \(id)"
        case .migrationFailed(let message):
            return "Migration failed: \(message)"
        }
    }
}

// MARK: - Meeting Database

/// SQLite database manager for meeting records
class MeetingDatabase {
    
    // MARK: - Singleton
    
    static let shared = MeetingDatabase()
    
    // MARK: - Properties
    
    private var db: OpaquePointer?
    private let dbPath: URL
    private let queue = DispatchQueue(label: "com.whispertype.meetingdb", qos: .userInitiated)
    
    // Current schema version
    private static let schemaVersion = 1
    
    // MARK: - Initialization
    
    init(dbPath: URL? = nil) {
        self.dbPath = dbPath ?? Constants.Paths.meetingsDatabase
        
        do {
            try openDatabase()
            try createTables()
            try runMigrations()
            print("MeetingDatabase: Initialized at \(self.dbPath.path)")
            
            // Import any existing sessions that weren't tracked in the database
            importExistingSessions()
        } catch {
            print("MeetingDatabase: Failed to initialize - \(error.localizedDescription)")
        }
    }
    
    deinit {
        closeDatabase()
    }
    
    // MARK: - Database Lifecycle
    
    private func openDatabase() throws {
        guard sqlite3_open(dbPath.path, &db) == SQLITE_OK else {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            throw MeetingDatabaseError.executeFailed("Could not open database: \(errorMessage)")
        }
    }
    
    func closeDatabase() {
        if db != nil {
            sqlite3_close(db)
            db = nil
        }
    }
    
    // MARK: - Schema Creation
    
    private func createTables() throws {
        // Meetings table
        let createMeetingsSQL = """
            CREATE TABLE IF NOT EXISTS meetings (
                id TEXT PRIMARY KEY,
                title TEXT NOT NULL,
                created_at REAL NOT NULL,
                duration_seconds INTEGER NOT NULL,
                audio_source TEXT NOT NULL,
                speaker_count INTEGER DEFAULT 0,
                status TEXT NOT NULL,
                error_message TEXT,
                session_directory TEXT NOT NULL,
                transcript_file TEXT,
                summary_file TEXT,
                audio_kept INTEGER DEFAULT 0,
                summary_preview TEXT,
                template_used TEXT
            );
            """
        
        try executeSQL(createMeetingsSQL)
        
        // Action items table
        let createActionItemsSQL = """
            CREATE TABLE IF NOT EXISTS meeting_action_items (
                id TEXT PRIMARY KEY,
                meeting_id TEXT NOT NULL,
                assignee TEXT,
                action_text TEXT NOT NULL,
                due_date TEXT,
                timestamp_seconds INTEGER,
                completed INTEGER DEFAULT 0,
                FOREIGN KEY (meeting_id) REFERENCES meetings(id) ON DELETE CASCADE
            );
            """
        
        try executeSQL(createActionItemsSQL)
        
        // Create indexes
        try executeSQL("CREATE INDEX IF NOT EXISTS idx_meetings_created ON meetings(created_at DESC);")
        try executeSQL("CREATE INDEX IF NOT EXISTS idx_meetings_title ON meetings(title);")
        try executeSQL("CREATE INDEX IF NOT EXISTS idx_action_items_meeting ON meeting_action_items(meeting_id);")
        
        // Schema version table
        let createVersionSQL = """
            CREATE TABLE IF NOT EXISTS schema_version (
                version INTEGER PRIMARY KEY
            );
            """
        try executeSQL(createVersionSQL)
    }
    
    private func runMigrations() throws {
        let currentVersion = getSchemaVersion()
        
        if currentVersion < MeetingDatabase.schemaVersion {
            // Run migrations here as needed
            // For now, we're at version 1 so no migrations needed
            
            setSchemaVersion(MeetingDatabase.schemaVersion)
        }
    }
    
    private func getSchemaVersion() -> Int {
        var statement: OpaquePointer?
        let sql = "SELECT version FROM schema_version ORDER BY version DESC LIMIT 1;"
        
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            return 0
        }
        
        defer { sqlite3_finalize(statement) }
        
        if sqlite3_step(statement) == SQLITE_ROW {
            return Int(sqlite3_column_int(statement, 0))
        }
        
        return 0
    }
    
    private func setSchemaVersion(_ version: Int) {
        try? executeSQL("INSERT OR REPLACE INTO schema_version (version) VALUES (\(version));")
    }
    
    // MARK: - Helper Methods
    
    private func executeSQL(_ sql: String) throws {
        var errorPointer: UnsafeMutablePointer<CChar>?
        
        guard sqlite3_exec(db, sql, nil, nil, &errorPointer) == SQLITE_OK else {
            let errorMessage = errorPointer != nil ? String(cString: errorPointer!) : "Unknown error"
            sqlite3_free(errorPointer)
            throw MeetingDatabaseError.executeFailed(errorMessage)
        }
    }
    
    // MARK: - CRUD Operations
    
    /// Insert a new meeting record
    func insertMeeting(_ meeting: MeetingRecord) throws {
        let sql = """
            INSERT INTO meetings (
                id, title, created_at, duration_seconds, audio_source,
                speaker_count, status, error_message, session_directory,
                transcript_file, summary_file, audio_kept, summary_preview, template_used
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
            """
        
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            throw MeetingDatabaseError.prepareFailed(errorMessage)
        }
        
        defer { sqlite3_finalize(statement) }
        
        // Bind parameters
        sqlite3_bind_text(statement, 1, meeting.id, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        sqlite3_bind_text(statement, 2, meeting.title, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        sqlite3_bind_double(statement, 3, meeting.createdAt.timeIntervalSince1970)
        sqlite3_bind_int(statement, 4, Int32(meeting.durationSeconds))
        sqlite3_bind_text(statement, 5, meeting.audioSource, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        sqlite3_bind_int(statement, 6, Int32(meeting.speakerCount))
        sqlite3_bind_text(statement, 7, meeting.status.rawValue, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        
        if let errorMessage = meeting.errorMessage {
            sqlite3_bind_text(statement, 8, errorMessage, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        } else {
            sqlite3_bind_null(statement, 8)
        }
        
        sqlite3_bind_text(statement, 9, meeting.sessionDirectory, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        
        if let transcriptFile = meeting.transcriptFile {
            sqlite3_bind_text(statement, 10, transcriptFile, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        } else {
            sqlite3_bind_null(statement, 10)
        }
        
        if let summaryFile = meeting.summaryFile {
            sqlite3_bind_text(statement, 11, summaryFile, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        } else {
            sqlite3_bind_null(statement, 11)
        }
        
        sqlite3_bind_int(statement, 12, meeting.audioKept ? 1 : 0)
        
        if let summaryPreview = meeting.summaryPreview {
            sqlite3_bind_text(statement, 13, summaryPreview, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        } else {
            sqlite3_bind_null(statement, 13)
        }
        
        if let templateUsed = meeting.templateUsed {
            sqlite3_bind_text(statement, 14, templateUsed, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        } else {
            sqlite3_bind_null(statement, 14)
        }
        
        guard sqlite3_step(statement) == SQLITE_DONE else {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            throw MeetingDatabaseError.executeFailed(errorMessage)
        }
        
        print("MeetingDatabase: Inserted meeting \(meeting.id)")
    }
    
    /// Update an existing meeting record
    func updateMeeting(_ meeting: MeetingRecord) throws {
        let sql = """
            UPDATE meetings SET
                title = ?,
                duration_seconds = ?,
                speaker_count = ?,
                status = ?,
                error_message = ?,
                transcript_file = ?,
                summary_file = ?,
                audio_kept = ?,
                summary_preview = ?,
                template_used = ?
            WHERE id = ?;
            """
        
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            throw MeetingDatabaseError.prepareFailed(errorMessage)
        }
        
        defer { sqlite3_finalize(statement) }
        
        sqlite3_bind_text(statement, 1, meeting.title, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        sqlite3_bind_int(statement, 2, Int32(meeting.durationSeconds))
        sqlite3_bind_int(statement, 3, Int32(meeting.speakerCount))
        sqlite3_bind_text(statement, 4, meeting.status.rawValue, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        
        if let errorMessage = meeting.errorMessage {
            sqlite3_bind_text(statement, 5, errorMessage, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        } else {
            sqlite3_bind_null(statement, 5)
        }
        
        if let transcriptFile = meeting.transcriptFile {
            sqlite3_bind_text(statement, 6, transcriptFile, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        } else {
            sqlite3_bind_null(statement, 6)
        }
        
        if let summaryFile = meeting.summaryFile {
            sqlite3_bind_text(statement, 7, summaryFile, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        } else {
            sqlite3_bind_null(statement, 7)
        }
        
        sqlite3_bind_int(statement, 8, meeting.audioKept ? 1 : 0)
        
        if let summaryPreview = meeting.summaryPreview {
            sqlite3_bind_text(statement, 9, summaryPreview, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        } else {
            sqlite3_bind_null(statement, 9)
        }
        
        if let templateUsed = meeting.templateUsed {
            sqlite3_bind_text(statement, 10, templateUsed, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        } else {
            sqlite3_bind_null(statement, 10)
        }
        
        sqlite3_bind_text(statement, 11, meeting.id, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        
        guard sqlite3_step(statement) == SQLITE_DONE else {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            throw MeetingDatabaseError.executeFailed(errorMessage)
        }
        
        print("MeetingDatabase: Updated meeting \(meeting.id)")
    }
    
    /// Get a meeting by ID
    func getMeeting(id: String) throws -> MeetingRecord? {
        let sql = "SELECT * FROM meetings WHERE id = ?;"
        
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            throw MeetingDatabaseError.prepareFailed(errorMessage)
        }
        
        defer { sqlite3_finalize(statement) }
        
        sqlite3_bind_text(statement, 1, id, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        
        if sqlite3_step(statement) == SQLITE_ROW {
            return meetingFromRow(statement)
        }
        
        return nil
    }
    
    /// Get all meetings, sorted by creation date (newest first)
    func getAllMeetings() throws -> [MeetingRecord] {
        let sql = "SELECT * FROM meetings ORDER BY created_at DESC;"
        
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            throw MeetingDatabaseError.prepareFailed(errorMessage)
        }
        
        defer { sqlite3_finalize(statement) }
        
        var meetings: [MeetingRecord] = []
        
        while sqlite3_step(statement) == SQLITE_ROW {
            if let meeting = meetingFromRow(statement) {
                meetings.append(meeting)
            }
        }
        
        return meetings
    }
    
    /// Search meetings by title
    func searchMeetings(query: String) throws -> [MeetingRecord] {
        let sql = "SELECT * FROM meetings WHERE title LIKE ? ORDER BY created_at DESC;"
        
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            throw MeetingDatabaseError.prepareFailed(errorMessage)
        }
        
        defer { sqlite3_finalize(statement) }
        
        let searchPattern = "%\(query)%"
        sqlite3_bind_text(statement, 1, searchPattern, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        
        var meetings: [MeetingRecord] = []
        
        while sqlite3_step(statement) == SQLITE_ROW {
            if let meeting = meetingFromRow(statement) {
                meetings.append(meeting)
            }
        }
        
        return meetings
    }
    
    /// Delete a meeting by ID
    func deleteMeeting(id: String) throws {
        // First delete any action items
        try executeSQL("DELETE FROM meeting_action_items WHERE meeting_id = '\(id)';")
        
        // Then delete the meeting
        let sql = "DELETE FROM meetings WHERE id = ?;"
        
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            throw MeetingDatabaseError.prepareFailed(errorMessage)
        }
        
        defer { sqlite3_finalize(statement) }
        
        sqlite3_bind_text(statement, 1, id, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        
        guard sqlite3_step(statement) == SQLITE_DONE else {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            throw MeetingDatabaseError.executeFailed(errorMessage)
        }
        
        print("MeetingDatabase: Deleted meeting \(id)")
    }
    
    /// Get meeting count
    func getMeetingCount() throws -> Int {
        let sql = "SELECT COUNT(*) FROM meetings;"
        
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            throw MeetingDatabaseError.prepareFailed(errorMessage)
        }
        
        defer { sqlite3_finalize(statement) }
        
        if sqlite3_step(statement) == SQLITE_ROW {
            return Int(sqlite3_column_int(statement, 0))
        }
        
        return 0
    }
    
    // MARK: - Action Items
    
    /// Insert an action item
    func insertActionItem(_ item: MeetingActionItem) throws {
        let sql = """
            INSERT INTO meeting_action_items (
                id, meeting_id, assignee, action_text, due_date, timestamp_seconds, completed
            ) VALUES (?, ?, ?, ?, ?, ?, ?);
            """
        
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            throw MeetingDatabaseError.prepareFailed(errorMessage)
        }
        
        defer { sqlite3_finalize(statement) }
        
        sqlite3_bind_text(statement, 1, item.id, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        sqlite3_bind_text(statement, 2, item.meetingId, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        
        if let assignee = item.assignee {
            sqlite3_bind_text(statement, 3, assignee, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        } else {
            sqlite3_bind_null(statement, 3)
        }
        
        sqlite3_bind_text(statement, 4, item.actionText, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        
        if let dueDate = item.dueDate {
            sqlite3_bind_text(statement, 5, dueDate, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        } else {
            sqlite3_bind_null(statement, 5)
        }
        
        if let timestamp = item.timestampSeconds {
            sqlite3_bind_int(statement, 6, Int32(timestamp))
        } else {
            sqlite3_bind_null(statement, 6)
        }
        
        sqlite3_bind_int(statement, 7, item.completed ? 1 : 0)
        
        guard sqlite3_step(statement) == SQLITE_DONE else {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            throw MeetingDatabaseError.executeFailed(errorMessage)
        }
    }
    
    /// Get action items for a meeting
    func getActionItems(meetingId: String) throws -> [MeetingActionItem] {
        let sql = "SELECT * FROM meeting_action_items WHERE meeting_id = ?;"
        
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            throw MeetingDatabaseError.prepareFailed(errorMessage)
        }
        
        defer { sqlite3_finalize(statement) }
        
        sqlite3_bind_text(statement, 1, meetingId, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        
        var items: [MeetingActionItem] = []
        
        while sqlite3_step(statement) == SQLITE_ROW {
            let id = String(cString: sqlite3_column_text(statement, 0))
            let meetingId = String(cString: sqlite3_column_text(statement, 1))
            let assignee = sqlite3_column_text(statement, 2).map { String(cString: $0) }
            let actionText = String(cString: sqlite3_column_text(statement, 3))
            let dueDate = sqlite3_column_text(statement, 4).map { String(cString: $0) }
            let timestampSeconds = sqlite3_column_type(statement, 5) == SQLITE_NULL ? nil : Int(sqlite3_column_int(statement, 5))
            let completed = sqlite3_column_int(statement, 6) != 0
            
            let item = MeetingActionItem(
                id: id,
                meetingId: meetingId,
                assignee: assignee,
                actionText: actionText,
                dueDate: dueDate,
                timestampSeconds: timestampSeconds,
                completed: completed
            )
            items.append(item)
        }
        
        return items
    }
    
    /// Update action item completion status
    func updateActionItemCompletion(id: String, completed: Bool) throws {
        let sql = "UPDATE meeting_action_items SET completed = ? WHERE id = ?;"
        
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            throw MeetingDatabaseError.prepareFailed(errorMessage)
        }
        
        defer { sqlite3_finalize(statement) }
        
        sqlite3_bind_int(statement, 1, completed ? 1 : 0)
        sqlite3_bind_text(statement, 2, id, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        
        guard sqlite3_step(statement) == SQLITE_DONE else {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            throw MeetingDatabaseError.executeFailed(errorMessage)
        }
    }
    
    // MARK: - Private Helpers
    
    private func meetingFromRow(_ statement: OpaquePointer?) -> MeetingRecord? {
        guard let statement = statement else { return nil }
        
        let id = String(cString: sqlite3_column_text(statement, 0))
        let title = String(cString: sqlite3_column_text(statement, 1))
        let createdAt = Date(timeIntervalSince1970: sqlite3_column_double(statement, 2))
        let durationSeconds = Int(sqlite3_column_int(statement, 3))
        let audioSource = String(cString: sqlite3_column_text(statement, 4))
        let speakerCount = Int(sqlite3_column_int(statement, 5))
        let statusString = String(cString: sqlite3_column_text(statement, 6))
        let status = MeetingStatus(rawValue: statusString) ?? .error
        let errorMessage = sqlite3_column_text(statement, 7).map { String(cString: $0) }
        let sessionDirectory = String(cString: sqlite3_column_text(statement, 8))
        let transcriptFile = sqlite3_column_text(statement, 9).map { String(cString: $0) }
        let summaryFile = sqlite3_column_text(statement, 10).map { String(cString: $0) }
        let audioKept = sqlite3_column_int(statement, 11) != 0
        let summaryPreview = sqlite3_column_text(statement, 12).map { String(cString: $0) }
        let templateUsed = sqlite3_column_text(statement, 13).map { String(cString: $0) }
        
        return MeetingRecord(
            id: id,
            title: title,
            createdAt: createdAt,
            durationSeconds: durationSeconds,
            audioSource: audioSource,
            speakerCount: speakerCount,
            status: status,
            errorMessage: errorMessage,
            sessionDirectory: sessionDirectory,
            transcriptFile: transcriptFile,
            summaryFile: summaryFile,
            audioKept: audioKept,
            summaryPreview: summaryPreview,
            templateUsed: templateUsed
        )
    }
    
    // MARK: - Import/Sync
    
    /// Import existing sessions from disk that aren't in the database
    /// This is used when sessions were created before database tracking was added
    func importExistingSessions() {
        let fileManager = FileManager.default
        let meetingsDir = Constants.Paths.meetings
        
        guard fileManager.fileExists(atPath: meetingsDir.path) else {
            print("MeetingDatabase: No meetings directory found")
            return
        }
        
        do {
            let contents = try fileManager.contentsOfDirectory(at: meetingsDir, includingPropertiesForKeys: [.isDirectoryKey, .creationDateKey])
            var importCount = 0
            
            for item in contents {
                var isDirectory: ObjCBool = false
                guard fileManager.fileExists(atPath: item.path, isDirectory: &isDirectory),
                      isDirectory.boolValue,
                      !item.lastPathComponent.hasPrefix(".") else {
                    continue
                }
                
                // Parse session info from directory name: yyyy-MM-dd_HHmmss_UUID
                let dirName = item.lastPathComponent
                let components = dirName.split(separator: "_")
                guard components.count >= 3 else { continue }
                
                // Extract UUID from last component
                let sessionId = String(components.last!)
                
                // Check if already in database
                if let _ = try? getMeeting(id: sessionId) {
                    continue // Already imported
                }
                
                // Parse date from first two components
                let dateStr = "\(components[0])_\(components[1])"
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd_HHmmss"
                let createdAt = dateFormatter.date(from: dateStr) ?? Date()
                
                // Check for transcript and extract title/duration
                let transcriptFile: String?
                var title = "Imported Meeting"
                var summaryPreview: String?
                
                if fileManager.fileExists(atPath: item.appendingPathComponent("transcript.md").path) {
                    transcriptFile = "transcript.md"
                    // Try to extract title from transcript header
                    if let content = try? String(contentsOf: item.appendingPathComponent("transcript.md"), encoding: .utf8) {
                        if let titleLine = content.components(separatedBy: "\n").first(where: { $0.hasPrefix("**Title:**") }) {
                            title = titleLine.replacingOccurrences(of: "**Title:**", with: "").trimmingCharacters(in: .whitespaces)
                        }
                    }
                } else if fileManager.fileExists(atPath: item.appendingPathComponent("transcript.txt").path) {
                    transcriptFile = "transcript.txt"
                } else {
                    transcriptFile = nil
                }
                
                let summaryFile: String?
                if fileManager.fileExists(atPath: item.appendingPathComponent("summary.md").path) {
                    summaryFile = "summary.md"
                    // Extract preview from summary
                    if let content = try? String(contentsOf: item.appendingPathComponent("summary.md"), encoding: .utf8) {
                        let cleanSummary = content
                            .replacingOccurrences(of: "#", with: "")
                            .replacingOccurrences(of: "*", with: "")
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        summaryPreview = String(cleanSummary.prefix(200))
                    }
                } else {
                    summaryFile = nil
                }
                
                // Check for audio files
                let audioDir = item.appendingPathComponent("audio")
                let audioKept = fileManager.fileExists(atPath: audioDir.path) &&
                    ((try? fileManager.contentsOfDirectory(at: audioDir, includingPropertiesForKeys: nil))?.isEmpty == false)
                
                // Create record
                let record = MeetingRecord(
                    id: sessionId,
                    title: title,
                    createdAt: createdAt,
                    durationSeconds: 0, // Unknown for imported sessions
                    audioSource: "both",
                    speakerCount: 0,
                    status: transcriptFile != nil ? .complete : .error,
                    errorMessage: transcriptFile == nil ? "Imported - no transcript" : nil,
                    sessionDirectory: item.path,
                    transcriptFile: transcriptFile,
                    summaryFile: summaryFile,
                    audioKept: audioKept,
                    summaryPreview: summaryPreview,
                    templateUsed: nil
                )
                
                do {
                    try insertMeeting(record)
                    importCount += 1
                } catch {
                    print("MeetingDatabase: Failed to import session \(sessionId) - \(error)")
                }
            }
            
            if importCount > 0 {
                print("MeetingDatabase: Imported \(importCount) existing session(s)")
            }
            
        } catch {
            print("MeetingDatabase: Failed to scan meetings directory - \(error.localizedDescription)")
        }
    }
}
