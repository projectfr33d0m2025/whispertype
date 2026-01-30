//
//  ResummarizeSheet.swift
//  WhisperType
//
//  Sheet for selecting a template and triggering re-summarization of a meeting.
//

import SwiftUI

/// Sheet for re-summarizing a meeting with a different template
struct ResummarizeSheet: View {
    @ObservedObject var templateStore: SummaryTemplateStore
    @State private var selectedTemplate: SummaryTemplate
    @Binding var isProcessing: Bool
    @Binding var errorMessage: String?
    
    let currentTemplateName: String?
    let onResummarize: (SummaryTemplate) async -> Void
    let onCancel: () -> Void
    
    init(
        templateStore: SummaryTemplateStore = .shared,
        currentTemplateName: String?,
        isProcessing: Binding<Bool>,
        errorMessage: Binding<String?>,
        onResummarize: @escaping (SummaryTemplate) async -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.templateStore = templateStore
        self.currentTemplateName = currentTemplateName
        self._isProcessing = isProcessing
        self._errorMessage = errorMessage
        self.onResummarize = onResummarize
        self.onCancel = onCancel
        
        // Initialize with currently selected template or default
        _selectedTemplate = State(initialValue: templateStore.selectedTemplate ?? templateStore.defaultTemplate)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
            
            Divider()
            
            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Instructions
                    instructionText
                    
                    // Template picker
                    templatePicker
                    
                    // Template preview
                    if !selectedTemplate.description.isEmpty {
                        templatePreview
                    }
                    
                    // Warning message
                    warningMessage
                    
                    // Error message (if any)
                    if let error = errorMessage {
                        errorView(error)
                    }
                }
                .padding()
            }
            
            Divider()
            
            // Footer with buttons
            footer
        }
        .frame(width: 500, height: 600)
    }
    
    // MARK: - Subviews
    
    private var header: some View {
        HStack {
            Text("Re-Summarize Meeting")
                .font(.headline)
            
            Spacer()
            
            if isProcessing {
                ProgressView()
                    .scaleEffect(0.8)
                    .padding(.trailing, 8)
            }
        }
        .padding()
    }
    
    private var instructionText: some View {
        Text("Choose a template to regenerate the meeting summary.")
            .foregroundStyle(.secondary)
    }
    
    private var templatePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Template")
                .font(.subheadline)
                .fontWeight(.medium)
            
            // Built-in templates
            VStack(alignment: .leading, spacing: 4) {
                Text("Built-in Templates")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
                
                ForEach(templateStore.builtInTemplates) { template in
                    TemplateRow(
                        template: template,
                        isSelected: selectedTemplate.id == template.id,
                        isCurrent: template.name == currentTemplateName,
                        onSelect: { selectedTemplate = template }
                    )
                }
            }
            
            // Custom templates (if any)
            if !templateStore.customTemplates.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Custom Templates")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 4)
                        .padding(.top, 12)
                    
                    ForEach(templateStore.customTemplates) { template in
                        TemplateRow(
                            template: template,
                            isSelected: selectedTemplate.id == template.id,
                            isCurrent: template.name == currentTemplateName,
                            onSelect: { selectedTemplate = template }
                        )
                    }
                }
            }
        }
    }
    
    private var templatePreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Template Description")
                .font(.subheadline)
                .fontWeight(.medium)
            
            Text(selectedTemplate.description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
        }
    }
    
    private var warningMessage: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(.blue)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("This will regenerate the summary using the existing transcript.")
                    .font(.caption)
                
                Text("The original summary will be replaced.")
                    .font(.caption)
                    .fontWeight(.medium)
            }
        }
        .padding(12)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(8)
    }
    
    private func errorView(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.title3)
            
            Text(message)
                .font(.caption)
        }
        .padding(12)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
    }
    
    private var footer: some View {
        HStack {
            Spacer()
            
            Button("Cancel", action: onCancel)
                .keyboardShortcut(.escape)
                .disabled(isProcessing)
            
            Button {
                Task {
                    await onResummarize(selectedTemplate)
                }
            } label: {
                HStack {
                    if isProcessing {
                        ProgressView()
                            .scaleEffect(0.7)
                            .padding(.trailing, 4)
                    }
                    Text("Regenerate")
                }
            }
            .keyboardShortcut(.return)
            .disabled(isProcessing || selectedTemplate.name == currentTemplateName)
        }
        .padding()
    }
}

// MARK: - Template Row

struct TemplateRow: View {
    let template: SummaryTemplate
    let isSelected: Bool
    let isCurrent: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Icon
                Text(template.icon)
                    .font(.title3)
                
                // Name and current indicator
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(template.name)
                            .font(.body)
                        
                        if isCurrent {
                            Text("(Current)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    if !template.description.isEmpty {
                        Text(template.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.blue)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    ResummarizeSheet(
        currentTemplateName: "Standard Meeting Notes",
        isProcessing: .constant(false),
        errorMessage: .constant(nil),
        onResummarize: { _ in },
        onCancel: {}
    )
}
