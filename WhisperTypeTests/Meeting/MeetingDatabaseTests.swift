//
//  MeetingDatabaseTests.swift
//  WhisperTypeTests
//
//  Unit tests for MeetingDatabase SQLite operations.
//

import XCTest
@testable import WhisperType

final class MeetingDatabaseTests: XCTestCase {
    
    var database: MeetingDatabase!
    var tempDatabasePath: URL!
    
    override func setUpWithError() throws {
        // Create a temporary database for testing
        let tempDir = FileManager.default.temporaryDirectory
        tempDatabasePath = tempDir.appendingPathComponent("test_meetings_\(UUID().uuidString).db")
        database = MeetingDatabase(dbPath: tempDatabasePath)
    }
    
    override func tearDownWithError() throws {
        database.closeDatabase()
        try? FileManager.default.removeItem(at: tempDatabasePath)
        database = nil
    }
    
    // MARK: - Database Initialization Tests
    
    func testDatabaseInitialization() throws {
        // Database should be created at the temp path
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempDatabasePath.path))
    }
    
    // MARK: - Insert Tests
    
    func testInsertMeeting() throws {
        let meeting = createTestMeeting(id: "test-1", title: "Test Meeting")
        
        XCTAssertNoThrow(try database.insertMeeting(meeting))
        
        // Verify it was inserted
        let retrieved = try database.getMeeting(id: "test-1")
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.id, "test-1")
        XCTAssertEqual(retrieved?.title, "Test Meeting")
    }
    
    func testInsertMultipleMeetings() throws {
        let meeting1 = createTestMeeting(id: "test-1", title: "Meeting 1")
        let meeting2 = createTestMeeting(id: "test-2", title: "Meeting 2")
        let meeting3 = createTestMeeting(id: "test-3", title: "Meeting 3")
        
        try database.insertMeeting(meeting1)
        try database.insertMeeting(meeting2)
        try database.insertMeeting(meeting3)
        
        let count = try database.getMeetingCount()
        XCTAssertEqual(count, 3)
    }
    
    // MARK: - Update Tests
    
    func testUpdateMeeting() throws {
        var meeting = createTestMeeting(id: "test-update", title: "Original Title")
        try database.insertMeeting(meeting)
        
        // Update the meeting
        meeting.title = "Updated Title"
        meeting.durationSeconds = 3600
        meeting.status = .complete
        
        try database.updateMeeting(meeting)
        
        // Verify updates
        let retrieved = try database.getMeeting(id: "test-update")
        XCTAssertEqual(retrieved?.title, "Updated Title")
        XCTAssertEqual(retrieved?.durationSeconds, 3600)
        XCTAssertEqual(retrieved?.status, .complete)
    }
    
    // MARK: - Get Tests
    
    func testGetMeetingByID() throws {
        let meeting = createTestMeeting(id: "test-get", title: "Get Test")
        try database.insertMeeting(meeting)
        
        let retrieved = try database.getMeeting(id: "test-get")
        
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.id, "test-get")
        XCTAssertEqual(retrieved?.title, "Get Test")
    }
    
    func testGetNonExistentMeeting() throws {
        let retrieved = try database.getMeeting(id: "non-existent")
        XCTAssertNil(retrieved)
    }
    
    func testGetAllMeetings() throws {
        // Insert meetings with different creation times
        let meeting1 = createTestMeeting(id: "test-1", title: "Meeting 1", createdAt: Date().addingTimeInterval(-3600))
        let meeting2 = createTestMeeting(id: "test-2", title: "Meeting 2", createdAt: Date().addingTimeInterval(-7200))
        let meeting3 = createTestMeeting(id: "test-3", title: "Meeting 3", createdAt: Date())
        
        try database.insertMeeting(meeting1)
        try database.insertMeeting(meeting2)
        try database.insertMeeting(meeting3)
        
        let allMeetings = try database.getAllMeetings()
        
        XCTAssertEqual(allMeetings.count, 3)
        // Should be sorted by created_at DESC (newest first)
        XCTAssertEqual(allMeetings[0].id, "test-3")
        XCTAssertEqual(allMeetings[1].id, "test-1")
        XCTAssertEqual(allMeetings[2].id, "test-2")
    }
    
    // MARK: - Search Tests
    
    func testSearchByTitle() throws {
        let meeting1 = createTestMeeting(id: "test-1", title: "Budget Review Meeting")
        let meeting2 = createTestMeeting(id: "test-2", title: "Product Planning")
        let meeting3 = createTestMeeting(id: "test-3", title: "Team Standup")
        let meeting4 = createTestMeeting(id: "test-4", title: "Budget Discussion")
        
        try database.insertMeeting(meeting1)
        try database.insertMeeting(meeting2)
        try database.insertMeeting(meeting3)
        try database.insertMeeting(meeting4)
        
        // Search for "Budget"
        let results = try database.searchMeetings(query: "Budget")
        
        XCTAssertEqual(results.count, 2)
        XCTAssertTrue(results.allSatisfy { $0.title.contains("Budget") })
    }
    
    func testSearchCaseInsensitive() throws {
        let meeting = createTestMeeting(id: "test-1", title: "IMPORTANT Meeting")
        try database.insertMeeting(meeting)
        
        let results = try database.searchMeetings(query: "important")
        
        XCTAssertEqual(results.count, 1)
    }
    
    func testSearchNoResults() throws {
        let meeting = createTestMeeting(id: "test-1", title: "Budget Meeting")
        try database.insertMeeting(meeting)
        
        let results = try database.searchMeetings(query: "xyz123nonexistent")
        
        XCTAssertTrue(results.isEmpty)
    }
    
    // MARK: - Delete Tests
    
    func testDeleteMeeting() throws {
        let meeting = createTestMeeting(id: "test-delete", title: "To Delete")
        try database.insertMeeting(meeting)
        
        // Verify it exists
        XCTAssertNotNil(try database.getMeeting(id: "test-delete"))
        
        // Delete it
        try database.deleteMeeting(id: "test-delete")
        
        // Verify it's gone
        XCTAssertNil(try database.getMeeting(id: "test-delete"))
    }
    
    func testDeleteNonExistentMeeting() throws {
        // Should not throw
        XCTAssertNoThrow(try database.deleteMeeting(id: "non-existent"))
    }
    
    // MARK: - Action Items Tests
    
    func testInsertActionItem() throws {
        let meeting = createTestMeeting(id: "test-meeting", title: "Meeting with Actions")
        try database.insertMeeting(meeting)
        
        let actionItem = MeetingActionItem(
            meetingId: "test-meeting",
            assignee: "John",
            actionText: "Review the proposal",
            dueDate: "2025-01-30"
        )
        
        try database.insertActionItem(actionItem)
        
        let items = try database.getActionItems(meetingId: "test-meeting")
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].assignee, "John")
        XCTAssertEqual(items[0].actionText, "Review the proposal")
    }
    
    func testGetActionItems() throws {
        let meeting = createTestMeeting(id: "test-meeting", title: "Meeting with Actions")
        try database.insertMeeting(meeting)
        
        // Insert multiple action items
        try database.insertActionItem(MeetingActionItem(meetingId: "test-meeting", actionText: "Action 1"))
        try database.insertActionItem(MeetingActionItem(meetingId: "test-meeting", actionText: "Action 2"))
        try database.insertActionItem(MeetingActionItem(meetingId: "test-meeting", actionText: "Action 3"))
        
        let items = try database.getActionItems(meetingId: "test-meeting")
        XCTAssertEqual(items.count, 3)
    }
    
    func testUpdateActionItemCompletion() throws {
        let meeting = createTestMeeting(id: "test-meeting", title: "Meeting")
        try database.insertMeeting(meeting)
        
        let actionItem = MeetingActionItem(
            id: "action-1",
            meetingId: "test-meeting",
            actionText: "Complete this task"
        )
        try database.insertActionItem(actionItem)
        
        // Initially not completed
        var items = try database.getActionItems(meetingId: "test-meeting")
        XCTAssertFalse(items[0].completed)
        
        // Mark as completed
        try database.updateActionItemCompletion(id: "action-1", completed: true)
        
        items = try database.getActionItems(meetingId: "test-meeting")
        XCTAssertTrue(items[0].completed)
    }
    
    func testDeleteMeetingCascadesActionItems() throws {
        let meeting = createTestMeeting(id: "test-meeting", title: "Meeting")
        try database.insertMeeting(meeting)
        
        try database.insertActionItem(MeetingActionItem(meetingId: "test-meeting", actionText: "Action 1"))
        try database.insertActionItem(MeetingActionItem(meetingId: "test-meeting", actionText: "Action 2"))
        
        // Verify action items exist
        XCTAssertEqual(try database.getActionItems(meetingId: "test-meeting").count, 2)
        
        // Delete meeting
        try database.deleteMeeting(id: "test-meeting")
        
        // Action items should also be deleted
        XCTAssertEqual(try database.getActionItems(meetingId: "test-meeting").count, 0)
    }
    
    // MARK: - Count Tests
    
    func testGetMeetingCount() throws {
        XCTAssertEqual(try database.getMeetingCount(), 0)
        
        try database.insertMeeting(createTestMeeting(id: "test-1", title: "Meeting 1"))
        XCTAssertEqual(try database.getMeetingCount(), 1)
        
        try database.insertMeeting(createTestMeeting(id: "test-2", title: "Meeting 2"))
        XCTAssertEqual(try database.getMeetingCount(), 2)
        
        try database.deleteMeeting(id: "test-1")
        XCTAssertEqual(try database.getMeetingCount(), 1)
    }
    
    // MARK: - Data Integrity Tests
    
    func testAllFieldsPersisted() throws {
        let meeting = MeetingRecord(
            id: "full-test",
            title: "Full Test Meeting",
            createdAt: Date(),
            durationSeconds: 1800,
            audioSource: "both",
            speakerCount: 3,
            status: .complete,
            errorMessage: nil,
            sessionDirectory: "/path/to/session",
            transcriptFile: "transcript.md",
            summaryFile: "summary.md",
            audioKept: true,
            summaryPreview: "This is a preview...",
            templateUsed: "standard"
        )
        
        try database.insertMeeting(meeting)
        
        let retrieved = try database.getMeeting(id: "full-test")!
        
        XCTAssertEqual(retrieved.id, meeting.id)
        XCTAssertEqual(retrieved.title, meeting.title)
        XCTAssertEqual(retrieved.durationSeconds, meeting.durationSeconds)
        XCTAssertEqual(retrieved.audioSource, meeting.audioSource)
        XCTAssertEqual(retrieved.speakerCount, meeting.speakerCount)
        XCTAssertEqual(retrieved.status, meeting.status)
        XCTAssertEqual(retrieved.sessionDirectory, meeting.sessionDirectory)
        XCTAssertEqual(retrieved.transcriptFile, meeting.transcriptFile)
        XCTAssertEqual(retrieved.summaryFile, meeting.summaryFile)
        XCTAssertEqual(retrieved.audioKept, meeting.audioKept)
        XCTAssertEqual(retrieved.summaryPreview, meeting.summaryPreview)
        XCTAssertEqual(retrieved.templateUsed, meeting.templateUsed)
    }
    
    // MARK: - Helper Methods
    
    private func createTestMeeting(
        id: String,
        title: String,
        createdAt: Date = Date()
    ) -> MeetingRecord {
        MeetingRecord(
            id: id,
            title: title,
            createdAt: createdAt,
            durationSeconds: 300,
            audioSource: "microphone",
            speakerCount: 1,
            status: .processing,
            errorMessage: nil,
            sessionDirectory: "/tmp/test-session",
            transcriptFile: nil,
            summaryFile: nil,
            audioKept: false,
            summaryPreview: nil,
            templateUsed: nil
        )
    }
}
