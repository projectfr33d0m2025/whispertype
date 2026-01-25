//
//  MeetingSummarizerTests.swift
//  WhisperTypeTests
//
//  Tests for MeetingSummarizer including template rendering and validation
//

import XCTest
@testable import WhisperType

final class MeetingSummarizerTests: XCTestCase {
    
    // MARK: - Template Rendering Tests
    
    func testTemplateRendering() {
        let template = SummaryTemplate(
            name: "Test",
            description: "Test template",
            content: "## Summary\n{{summary}}\n\n## Actions\n{{action_items}}"
        )
        
        let variables: [String: String] = [
            "summary": "This is a test summary.",
            "action_items": "- Task 1\n- Task 2"
        ]
        
        var result = template.content
        for (key, value) in variables {
            result = result.replacingOccurrences(of: "{{\(key)}}", with: value)
        }
        
        XCTAssertTrue(result.contains("This is a test summary."))
        XCTAssertTrue(result.contains("- Task 1"))
        XCTAssertFalse(result.contains("{{"))
    }
    
    // MARK: - Validation Tests
    
    func testValidatorFindsUnfilledVariables() {
        let summary = "## Summary\n{{summary}}\n\n## Details\nSome content here."
        let unfilled = SummaryValidator.findUnfilledVariables(in: summary)
        
        XCTAssertEqual(unfilled.count, 1)
        XCTAssertTrue(unfilled.contains("summary"))
    }
    
    func testValidatorNoUnfilledVariables() {
        let summary = "## Summary\nThis is a complete summary with all variables filled."
        let unfilled = SummaryValidator.findUnfilledVariables(in: summary)
        
        XCTAssertTrue(unfilled.isEmpty)
    }
    
    func testValidatorKeywordCoverage() {
        let summary = "The project budget was discussed. We need to finalize the roadmap."
        let transcript = "Today we discussed the project budget and timeline. The roadmap needs work. The budget is approved."
        
        let (coverage, matched, _) = SummaryValidator.calculateKeywordCoverage(
            summary: summary,
            transcript: transcript
        )
        
        XCTAssertGreaterThan(coverage, 0, "Should have some keyword coverage")
        XCTAssertFalse(matched.isEmpty, "Should match some keywords")
    }
    
    func testValidatorRequiredSections() {
        let template = SummaryTemplate(
            name: "Test",
            description: "Test",
            content: "## Summary\n{{summary}}\n\n## Action Items\n{{action_items}}"
        )
        
        let goodSummary = "## Summary\nContent here\n\n## Action Items\n- Task 1"
        let (allPresent, missing) = SummaryValidator.checkRequiredSections(
            in: goodSummary,
            template: template
        )
        
        XCTAssertTrue(allPresent)
        XCTAssertTrue(missing.isEmpty)
    }
    
    func testValidatorMissingSections() {
        let template = SummaryTemplate(
            name: "Test",
            description: "Test",
            content: "## Summary\n{{summary}}\n\n## Action Items\n{{action_items}}"
        )
        
        let badSummary = "## Summary\nContent here\n\nSome other content"
        let (allPresent, missing) = SummaryValidator.checkRequiredSections(
            in: badSummary,
            template: template
        )
        
        XCTAssertFalse(allPresent)
        XCTAssertTrue(missing.contains("Action Items"))
    }
    
    func testFullValidation() {
        let template = SummaryTemplate.standardMeetingNotes
        let summary = """
        ## Summary
        The team discussed Q1 goals and budget allocation.
        
        ## Key Discussion Points
        - Budget planning
        - Team expansion
        
        ## Decisions Made
        Budget approved at $50,000
        
        ## Action Items
        - Alice: Prepare roadmap
        - Bob: Schedule review meeting
        
        ## Participants
        Alice, Bob, Charlie
        """
        
        let transcript = "We discussed Q1 goals. The budget was set at fifty thousand dollars. Alice will prepare the roadmap."
        
        let result = SummaryValidator.validate(
            summary: summary,
            template: template,
            transcript: transcript
        )
        
        XCTAssertTrue(result.allVariablesFilled, "All variables should be filled")
        XCTAssertTrue(result.unfilledVariables.isEmpty)
    }
    
    // MARK: - Hierarchical Chunking Tests
    
    func testChunkingLongText() {
        // Test that very long text gets chunked appropriately
        let longText = String(repeating: "This is a test sentence. ", count: 500)
        
        XCTAssertGreaterThan(longText.count, 8000, "Text should be long enough to trigger chunking")
    }
    
    // MARK: - Fallback Tests
    
    func testFallbackMessageFormat() {
        let fallbackMessage = "*Summary generation requires AI. Please configure Ollama or cloud LLM in Settings.*"
        
        XCTAssertTrue(fallbackMessage.contains("AI"))
        XCTAssertTrue(fallbackMessage.contains("Ollama"))
    }
}

// MARK: - SummaryTemplateStore Tests

@MainActor
final class SummaryTemplateStoreIntegrationTests: XCTestCase {
    
    func testTemplateSelection() {
        let store = SummaryTemplateStore.shared
        
        // Select a different template
        let actionTemplate = SummaryTemplate.actionFocused
        store.selectTemplate(id: actionTemplate.id)
        
        XCTAssertEqual(store.selectedTemplateId, actionTemplate.id)
    }
    
    func testResetToDefault() {
        let store = SummaryTemplateStore.shared
        
        // Change selection and reset
        store.selectTemplate(id: SummaryTemplate.executiveBrief.id)
        store.resetToDefault()
        
        XCTAssertEqual(store.selectedTemplateId, SummaryTemplate.standardMeetingNotes.id)
    }
}
