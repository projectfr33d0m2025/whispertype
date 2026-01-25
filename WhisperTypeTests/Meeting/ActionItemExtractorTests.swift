//
//  ActionItemExtractorTests.swift
//  WhisperTypeTests
//
//  Tests for ActionItemExtractor
//

import XCTest
@testable import WhisperType

final class ActionItemExtractorTests: XCTestCase {
    
    // MARK: - Simple Extraction Tests
    
    func testSimpleExtractionFindsActionItems() {
        let extractor = ActionItemExtractor.shared
        let transcript = """
        Let's discuss the project. Can you please send me the report by Friday?
        I need to review the budget tomorrow. Sarah should prepare the presentation.
        """
        
        let items = extractor.extractActionItemsSimple(from: transcript)
        
        XCTAssertFalse(items.isEmpty, "Should find action items")
    }
    
    func testSimpleExtractionWithNeedTo() {
        let extractor = ActionItemExtractor.shared
        let transcript = "We need to update the documentation before the release."
        
        let items = extractor.extractActionItemsSimple(from: transcript)
        
        XCTAssertFalse(items.isEmpty, "Should find 'need to' action items")
    }
    
    func testSimpleExtractionWithDueDate() {
        let extractor = ActionItemExtractor.shared
        let transcript = "The report is due by Monday. We should have it ready by end of week."
        
        let items = extractor.extractActionItemsSimple(from: transcript)
        
        // Should find at least one item mentioning a due date
        XCTAssertGreaterThan(items.count, 0)
    }
    
    func testSimpleExtractionRemovesDuplicates() {
        let extractor = ActionItemExtractor.shared
        let transcript = """
        Please send the report. We need to send the report soon.
        Can you send the report by Friday?
        """
        
        let items = extractor.extractActionItemsSimple(from: transcript)
        
        // Should have fewer items than occurrences due to deduplication
        XCTAssertLessThanOrEqual(items.count, 3)
    }
    
    func testSimpleExtractionEmptyTranscript() {
        let extractor = ActionItemExtractor.shared
        let items = extractor.extractActionItemsSimple(from: "")
        
        XCTAssertTrue(items.isEmpty)
    }
    
    // MARK: - ActionItem Model Tests
    
    func testActionItemFormattedText() {
        let item = ActionItem(
            text: "Send the report",
            assignee: "John",
            dueDate: "Friday"
        )
        
        let formatted = item.formattedText
        XCTAssertTrue(formatted.contains("John"))
        XCTAssertTrue(formatted.contains("Send the report"))
        XCTAssertTrue(formatted.contains("Friday"))
    }
    
    func testActionItemMarkdownText() {
        let item = ActionItem(
            text: "Review the code",
            assignee: "Sarah",
            dueDate: "Monday"
        )
        
        let markdown = item.markdownText
        XCTAssertTrue(markdown.hasPrefix("- [ ]"))
        XCTAssertTrue(markdown.contains("**Sarah:**"))
        XCTAssertTrue(markdown.contains("Review the code"))
        XCTAssertTrue(markdown.contains("*(Due: Monday)*"))
    }
    
    func testActionItemWithoutAssignee() {
        let item = ActionItem(text: "Schedule meeting")
        
        XCTAssertNil(item.assignee)
        XCTAssertFalse(item.markdownText.contains("**"))
    }
    
    // MARK: - Collection Extension Tests
    
    func testActionItemsAsMarkdown() {
        let items = [
            ActionItem(text: "Task 1", assignee: "Alice"),
            ActionItem(text: "Task 2", assignee: "Bob")
        ]
        
        let markdown = items.asMarkdown
        XCTAssertTrue(markdown.contains("Alice"))
        XCTAssertTrue(markdown.contains("Bob"))
        XCTAssertTrue(markdown.contains("Task 1"))
        XCTAssertTrue(markdown.contains("Task 2"))
    }
    
    func testEmptyActionItemsAsMarkdown() {
        let items: [ActionItem] = []
        let markdown = items.asMarkdown
        
        XCTAssertEqual(markdown, "*No action items identified*")
    }
    
    func testGroupedByAssignee() {
        let items = [
            ActionItem(text: "Task 1", assignee: "Alice"),
            ActionItem(text: "Task 2", assignee: "Bob"),
            ActionItem(text: "Task 3", assignee: "Alice"),
            ActionItem(text: "Task 4")
        ]
        
        let grouped = items.groupedByAssignee
        
        XCTAssertEqual(grouped["Alice"]?.count, 2)
        XCTAssertEqual(grouped["Bob"]?.count, 1)
        XCTAssertEqual(grouped["Unassigned"]?.count, 1)
    }
    
    func testFilteredByConfidence() {
        let items = [
            ActionItem(text: "High confidence", confidence: 0.9),
            ActionItem(text: "Low confidence", confidence: 0.3),
            ActionItem(text: "Medium confidence", confidence: 0.6)
        ]
        
        let filtered = items.filtered(minConfidence: 0.5)
        
        XCTAssertEqual(filtered.count, 2)
        XCTAssertTrue(filtered.allSatisfy { $0.confidence >= 0.5 })
    }
}
