//
//  SummaryTemplateTests.swift
//  WhisperTypeTests
//
//  Tests for SummaryTemplate and SummaryTemplateStore
//

import XCTest
@testable import WhisperType

final class SummaryTemplateTests: XCTestCase {
    
    // MARK: - Built-in Templates Tests
    
    func testBuiltInTemplatesExist() {
        let templates = SummaryTemplate.allBuiltIn
        XCTAssertEqual(templates.count, 6, "Should have 6 built-in templates")
    }
    
    func testBuiltInTemplatesAreMarkedBuiltIn() {
        for template in SummaryTemplate.allBuiltIn {
            XCTAssertTrue(template.isBuiltIn, "Template '\(template.name)' should be marked as built-in")
        }
    }
    
    func testBuiltInTemplatesHaveUniqueIds() {
        let templates = SummaryTemplate.allBuiltIn
        let ids = Set(templates.map { $0.id })
        XCTAssertEqual(ids.count, templates.count, "All template IDs should be unique")
    }
    
    func testBuiltInTemplatesHaveContent() {
        for template in SummaryTemplate.allBuiltIn {
            XCTAssertFalse(template.content.isEmpty, "Template '\(template.name)' should have content")
        }
    }
    
    func testBuiltInTemplatesHaveVariables() {
        for template in SummaryTemplate.allBuiltIn {
            XCTAssertFalse(template.variables.isEmpty, "Template '\(template.name)' should have variables")
        }
    }
    
    // MARK: - Variable Extraction Tests
    
    func testExtractVariablesFromTemplate() {
        let content = "## Summary\n{{summary}}\n\n## Action Items\n{{action_items}}"
        let variables = TemplateVariableExtractor.extractVariables(from: content)
        
        XCTAssertEqual(variables.count, 2)
        XCTAssertTrue(variables.contains("summary"))
        XCTAssertTrue(variables.contains("action_items"))
    }
    
    func testExtractVariablesNoDuplicates() {
        let content = "{{summary}} and {{summary}} again"
        let variables = TemplateVariableExtractor.extractVariables(from: content)
        
        XCTAssertEqual(variables.count, 1, "Should not contain duplicate variables")
    }
    
    func testExtractVariablesHandlesEmpty() {
        let content = "No variables here"
        let variables = TemplateVariableExtractor.extractVariables(from: content)
        
        XCTAssertTrue(variables.isEmpty)
    }
    
    func testExtractVariablesIgnoresInvalid() {
        let content = "{{}} {{123invalid}} {{ spaces }} {{}}"
        let variables = TemplateVariableExtractor.extractVariables(from: content)
        
        XCTAssertTrue(variables.isEmpty, "Should not extract invalid variable names")
    }
    
    func testUnknownVariables() {
        let content = "{{summary}} {{unknown_var}} {{custom_field}}"
        let unknown = TemplateVariableExtractor.unknownVariables(in: content)
        
        XCTAssertEqual(unknown.count, 2)
        XCTAssertTrue(unknown.contains("unknown_var"))
        XCTAssertTrue(unknown.contains("custom_field"))
    }
    
    // MARK: - Template Variable Enum Tests
    
    func testTemplateVariableHasDisplayName() {
        for variable in TemplateVariable.allCases {
            XCTAssertFalse(variable.displayName.isEmpty, "\(variable) should have display name")
        }
    }
    
    func testTemplateVariableHasPlaceholder() {
        let summary = TemplateVariable.summary
        XCTAssertEqual(summary.placeholder, "{{summary}}")
    }
    
    func testTemplateVariableLLMRequirement() {
        // These should NOT require LLM
        XCTAssertFalse(TemplateVariable.duration.requiresLLM)
        XCTAssertFalse(TemplateVariable.date.requiresLLM)
        XCTAssertFalse(TemplateVariable.transcript.requiresLLM)
        
        // These SHOULD require LLM
        XCTAssertTrue(TemplateVariable.summary.requiresLLM)
        XCTAssertTrue(TemplateVariable.actionItems.requiresLLM)
        XCTAssertTrue(TemplateVariable.decisions.requiresLLM)
    }
    
    // MARK: - Custom Template Tests
    
    func testCreateCustomTemplate() {
        let template = SummaryTemplate(
            name: "My Template",
            description: "A custom template",
            content: "## Custom\n{{summary}}",
            isBuiltIn: false
        )
        
        XCTAssertFalse(template.isBuiltIn)
        XCTAssertEqual(template.name, "My Template")
        XCTAssertEqual(template.variables.count, 1)
    }
    
    func testTemplateEquality() {
        let t1 = SummaryTemplate.standardMeetingNotes
        let t2 = SummaryTemplate.standardMeetingNotes
        
        XCTAssertEqual(t1, t2)
    }
    
    func testTemplateCodable() throws {
        let original = SummaryTemplate(
            name: "Test",
            description: "Test template",
            content: "{{summary}}",
            isBuiltIn: false
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(SummaryTemplate.self, from: data)
        
        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.content, original.content)
    }
}

// MARK: - Summary Template Store Tests

@MainActor
final class SummaryTemplateStoreTests: XCTestCase {
    
    func testStoreLoadsBuiltInTemplates() {
        let store = SummaryTemplateStore.shared
        
        XCTAssertGreaterThanOrEqual(store.templates.count, 6, "Should have at least 6 built-in templates")
        XCTAssertEqual(store.builtInTemplates.count, 6)
    }
    
    func testStoreHasDefaultTemplate() {
        let store = SummaryTemplateStore.shared
        
        XCTAssertNotNil(store.defaultTemplate)
        XCTAssertEqual(store.defaultTemplate.id, SummaryTemplate.standardMeetingNotes.id)
    }
    
    func testStoreSelectedTemplateExists() {
        let store = SummaryTemplateStore.shared
        
        XCTAssertNotNil(store.selectedTemplate, "Selected template should exist")
    }
}
