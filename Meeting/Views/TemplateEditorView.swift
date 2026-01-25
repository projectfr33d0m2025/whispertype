//
//  TemplateEditorView.swift
//  WhisperType
//
//  Editor for creating and editing summary templates.
//

import SwiftUI

/// View for editing a summary template
struct TemplateEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var store = SummaryTemplateStore.shared
    
    // Template being edited
    @State private var name: String
    @State private var description: String
    @State private var content: String
    @State private var icon: String
    
    // For editing existing templates
    private let existingTemplate: SummaryTemplate?
    private let isNewTemplate: Bool
    
    // MARK: - Initialization
    
    init(template: SummaryTemplate? = nil) {
        self.existingTemplate = template
        self.isNewTemplate = template == nil
        
        _name = State(initialValue: template?.name ?? "")
        _description = State(initialValue: template?.description ?? "")
        _content = State(initialValue: template?.content ?? Self.defaultContent)
        _icon = State(initialValue: template?.icon ?? "doc.text")
    }
    
    private static let defaultContent = """
    ## Summary
    {{summary}}
    
    ## Key Points
    {{key_points}}
    
    ## Action Items
    {{action_items}}
    """
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            Divider()
            
            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    nameSection
                    descriptionSection
                    contentSection
                    variableHelpSection
                }
                .padding()
            }
            
            Divider()
            
            // Footer
            footerView
        }
        .frame(minWidth: 600, minHeight: 500)
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)
            
            Text(isNewTemplate ? "New Template" : "Edit Template")
                .font(.headline)
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Sections
    
    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Template Name")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            TextField("Enter template name", text: $name)
                .textFieldStyle(.roundedBorder)
        }
    }
    
    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Description")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            TextField("Brief description of when to use this template", text: $description)
                .textFieldStyle(.roundedBorder)
        }
    }
    
    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Template Content")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(extractedVariables.count) variables")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            TextEditor(text: $content)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 200)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                )
            
            // Show extracted variables
            if !extractedVariables.isEmpty {
                HStack {
                    Text("Variables found:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ForEach(extractedVariables, id: \.self) { variable in
                        Text(variable)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(variableColor(for: variable))
                            .cornerRadius(4)
                    }
                }
            }
        }
    }
    
    private var variableHelpSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Available Variables")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(TemplateVariable.allCases, id: \.rawValue) { variable in
                    variableHelpRow(variable)
                }
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }
    
    private func variableHelpRow(_ variable: TemplateVariable) -> some View {
        Button {
            insertVariable(variable)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(variable.placeholder)
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    Text(variable.displayName)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if variable.requiresLLM {
                    Image(systemName: "brain")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }
            .padding(8)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Footer
    
    private var footerView: some View {
        HStack {
            Button("Cancel") {
                dismiss()
            }
            .keyboardShortcut(.escape)
            
            Spacer()
            
            Button(isNewTemplate ? "Create Template" : "Save Changes") {
                saveTemplate()
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!isValid)
            .keyboardShortcut(.return)
        }
        .padding()
    }
    
    // MARK: - Computed Properties
    
    private var extractedVariables: [String] {
        TemplateVariableExtractor.extractVariables(from: content)
    }
    
    private var isValid: Bool {
        !name.isEmpty && !content.isEmpty
    }
    
    // MARK: - Actions
    
    private func insertVariable(_ variable: TemplateVariable) {
        content += variable.placeholder
    }
    
    private func saveTemplate() {
        if let existing = existingTemplate {
            // Update existing
            var updated = existing
            updated.name = name
            updated.description = description
            updated.content = content
            updated.icon = icon
            store.updateTemplate(updated)
        } else {
            // Create new
            let template = SummaryTemplate(
                name: name,
                description: description,
                content: content,
                isBuiltIn: false,
                icon: icon
            )
            store.addTemplate(template)
        }
    }
    
    private func variableColor(for variable: String) -> Color {
        if let knownVar = TemplateVariable(rawValue: variable) {
            return knownVar.requiresLLM ? Color.orange.opacity(0.3) : Color.green.opacity(0.3)
        }
        return Color.red.opacity(0.3) // Unknown variable
    }
}

// MARK: - Preview

#Preview {
    TemplateEditorView()
}
