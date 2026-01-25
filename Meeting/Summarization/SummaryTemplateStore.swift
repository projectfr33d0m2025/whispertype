//
//  SummaryTemplateStore.swift
//  WhisperType
//
//  Manages summary template storage with built-in and custom templates.
//

import Foundation
import Combine

/// Manages summary template storage and persistence
@MainActor
class SummaryTemplateStore: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = SummaryTemplateStore()
    
    // MARK: - Published Properties
    
    /// All available templates (built-in + custom)
    @Published private(set) var templates: [SummaryTemplate] = []
    
    /// Currently selected template ID
    @Published var selectedTemplateId: String {
        didSet {
            UserDefaults.standard.set(selectedTemplateId, forKey: "selectedSummaryTemplateId")
        }
    }
    
    // MARK: - Computed Properties
    
    /// Built-in templates only
    var builtInTemplates: [SummaryTemplate] {
        templates.filter { $0.isBuiltIn }
    }
    
    /// Custom templates only
    var customTemplates: [SummaryTemplate] {
        templates.filter { !$0.isBuiltIn }
    }
    
    /// Currently selected template
    var selectedTemplate: SummaryTemplate? {
        templates.first { $0.id == selectedTemplateId }
    }
    
    /// Default template (Standard Meeting Notes)
    var defaultTemplate: SummaryTemplate {
        .standardMeetingNotes
    }
    
    // MARK: - Private Properties
    
    private let fileManager = FileManager.default
    private var customTemplatesURL: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let whisperType = appSupport.appendingPathComponent("WhisperType")
        return whisperType.appendingPathComponent("custom_templates.json")
    }
    
    // MARK: - Initialization
    
    private init() {
        // Load selected template from UserDefaults
        self.selectedTemplateId = UserDefaults.standard.string(forKey: "selectedSummaryTemplateId") 
            ?? SummaryTemplate.standardMeetingNotes.id
        
        // Load templates
        loadTemplates()
    }
    
    // MARK: - Loading
    
    /// Load all templates (built-in + custom)
    private func loadTemplates() {
        var allTemplates = SummaryTemplate.allBuiltIn
        
        // Load custom templates
        if let customTemplates = loadCustomTemplates() {
            allTemplates.append(contentsOf: customTemplates)
        }
        
        templates = allTemplates
        
        // Ensure selected template exists
        if !templates.contains(where: { $0.id == selectedTemplateId }) {
            selectedTemplateId = defaultTemplate.id
        }
        
        print("SummaryTemplateStore: Loaded \(templates.count) templates (\(builtInTemplates.count) built-in, \(customTemplates.count) custom)")
    }
    
    /// Load custom templates from disk
    private func loadCustomTemplates() -> [SummaryTemplate]? {
        guard fileManager.fileExists(atPath: customTemplatesURL.path) else {
            return nil
        }
        
        do {
            let data = try Data(contentsOf: customTemplatesURL)
            let templates = try JSONDecoder().decode([SummaryTemplate].self, from: data)
            return templates
        } catch {
            print("SummaryTemplateStore: Failed to load custom templates - \(error)")
            return nil
        }
    }
    
    // MARK: - CRUD Operations
    
    /// Add a new custom template
    /// - Parameter template: Template to add
    func addTemplate(_ template: SummaryTemplate) {
        var newTemplate = template
        
        // Ensure it's marked as custom
        if newTemplate.isBuiltIn {
            newTemplate = SummaryTemplate(
                id: newTemplate.id,
                name: newTemplate.name,
                description: newTemplate.description,
                content: newTemplate.content,
                isBuiltIn: false,
                icon: newTemplate.icon,
                createdAt: newTemplate.createdAt,
                modifiedAt: Date()
            )
        }
        
        templates.append(newTemplate)
        saveCustomTemplates()
        
        print("SummaryTemplateStore: Added custom template '\(newTemplate.name)'")
    }
    
    /// Update an existing template
    /// - Parameter template: Updated template
    func updateTemplate(_ template: SummaryTemplate) {
        guard !template.isBuiltIn else {
            print("SummaryTemplateStore: Cannot update built-in template")
            return
        }
        
        guard let index = templates.firstIndex(where: { $0.id == template.id }) else {
            print("SummaryTemplateStore: Template not found for update")
            return
        }
        
        var updatedTemplate = template
        updatedTemplate.modifiedAt = Date()
        
        templates[index] = updatedTemplate
        saveCustomTemplates()
        
        print("SummaryTemplateStore: Updated template '\(template.name)'")
    }
    
    /// Delete a custom template
    /// - Parameter id: Template ID to delete
    func deleteTemplate(id: String) {
        guard let template = templates.first(where: { $0.id == id }) else {
            return
        }
        
        guard !template.isBuiltIn else {
            print("SummaryTemplateStore: Cannot delete built-in template")
            return
        }
        
        templates.removeAll { $0.id == id }
        
        // If deleted template was selected, reset to default
        if selectedTemplateId == id {
            selectedTemplateId = defaultTemplate.id
        }
        
        saveCustomTemplates()
        
        print("SummaryTemplateStore: Deleted template '\(template.name)'")
    }
    
    /// Create a copy of a template
    /// - Parameter id: Template ID to duplicate
    /// - Returns: The new duplicated template
    @discardableResult
    func duplicateTemplate(id: String) -> SummaryTemplate? {
        guard let original = templates.first(where: { $0.id == id }) else {
            return nil
        }
        
        let duplicate = SummaryTemplate(
            name: "\(original.name) (Copy)",
            description: original.description,
            content: original.content,
            isBuiltIn: false,
            icon: original.icon
        )
        
        addTemplate(duplicate)
        return duplicate
    }
    
    // MARK: - Persistence
    
    /// Save custom templates to disk
    private func saveCustomTemplates() {
        let customOnly = templates.filter { !$0.isBuiltIn }
        
        do {
            // Ensure directory exists
            let directory = customTemplatesURL.deletingLastPathComponent()
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(customOnly)
            try data.write(to: customTemplatesURL, options: .atomic)
            
            print("SummaryTemplateStore: Saved \(customOnly.count) custom templates")
        } catch {
            print("SummaryTemplateStore: Failed to save custom templates - \(error)")
        }
    }
    
    // MARK: - Selection
    
    /// Select a template by ID
    /// - Parameter id: Template ID
    func selectTemplate(id: String) {
        guard templates.contains(where: { $0.id == id }) else {
            print("SummaryTemplateStore: Template '\(id)' not found")
            return
        }
        selectedTemplateId = id
    }
    
    /// Reset to default template
    func resetToDefault() {
        selectedTemplateId = defaultTemplate.id
    }
}
