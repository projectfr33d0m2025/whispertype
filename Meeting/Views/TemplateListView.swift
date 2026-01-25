//
//  TemplateListView.swift
//  WhisperType
//
//  Lists all available summary templates with options to select, edit, and delete.
//

import SwiftUI

/// View for listing and managing summary templates
struct TemplateListView: View {
    @StateObject private var store = SummaryTemplateStore.shared
    @State private var showingEditor = false
    @State private var templateToEdit: SummaryTemplate?
    @State private var showingDeleteConfirm = false
    @State private var templateToDelete: SummaryTemplate?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            headerView
            
            // Template list
            ScrollView {
                VStack(spacing: 12) {
                    // Built-in templates section
                    if !store.builtInTemplates.isEmpty {
                        sectionHeader("Built-in Templates")
                        
                        ForEach(store.builtInTemplates) { template in
                            templateRow(template)
                        }
                    }
                    
                    // Custom templates section
                    if !store.customTemplates.isEmpty {
                        sectionHeader("Custom Templates")
                        
                        ForEach(store.customTemplates) { template in
                            templateRow(template)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .sheet(isPresented: $showingEditor) {
            if let template = templateToEdit {
                TemplateEditorView(template: template)
            } else {
                TemplateEditorView()
            }
        }
        .alert("Delete Template?", isPresented: $showingDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let template = templateToDelete {
                    store.deleteTemplate(id: template.id)
                }
            }
        } message: {
            if let template = templateToDelete {
                Text("Are you sure you want to delete \"\(template.name)\"? This cannot be undone.")
            }
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Summary Templates")
                    .font(.headline)
                
                Text("Choose a template for meeting summaries")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button {
                templateToEdit = nil
                showingEditor = true
            } label: {
                Label("New Template", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(.horizontal)
        .padding(.top)
    }
    
    // MARK: - Section Header
    
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.subheadline)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 8)
    }
    
    // MARK: - Template Row
    
    private func templateRow(_ template: SummaryTemplate) -> some View {
        HStack(spacing: 12) {
            // Selection indicator
            Image(systemName: store.selectedTemplateId == template.id ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundColor(store.selectedTemplateId == template.id ? .accentColor : .secondary)
            
            // Icon
            Image(systemName: template.icon)
                .font(.title2)
                .foregroundColor(.accentColor)
                .frame(width: 32)
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(template.name)
                        .font(.body)
                        .fontWeight(.medium)
                    
                    if template.isBuiltIn {
                        Text("Built-in")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.2))
                            .cornerRadius(4)
                    }
                }
                
                Text(template.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                // Variables preview
                HStack(spacing: 4) {
                    ForEach(template.variables.prefix(4), id: \.self) { variable in
                        Text(variable)
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.accentColor.opacity(0.1))
                            .cornerRadius(3)
                    }
                    if template.variables.count > 4 {
                        Text("+\(template.variables.count - 4)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // Actions
            if !template.isBuiltIn {
                Menu {
                    Button {
                        templateToEdit = template
                        showingEditor = true
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    
                    Button {
                        store.duplicateTemplate(id: template.id)
                    } label: {
                        Label("Duplicate", systemImage: "doc.on.doc")
                    }
                    
                    Divider()
                    
                    Button(role: .destructive) {
                        templateToDelete = template
                        showingDeleteConfirm = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .menuStyle(.borderlessButton)
            } else {
                // Built-in templates can only be duplicated
                Button {
                    store.duplicateTemplate(id: template.id)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Duplicate template")
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(store.selectedTemplateId == template.id ? Color.accentColor.opacity(0.1) : Color.secondary.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(store.selectedTemplateId == template.id ? Color.accentColor.opacity(0.5) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            store.selectTemplate(id: template.id)
        }
    }
}

// MARK: - Compact Picker View (for embedding in other views)

/// A compact picker for selecting a summary template
struct TemplatePickerView: View {
    @StateObject private var store = SummaryTemplateStore.shared
    
    var body: some View {
        Picker("Summary Template", selection: $store.selectedTemplateId) {
            ForEach(store.templates) { template in
                HStack {
                    Image(systemName: template.icon)
                    Text(template.name)
                }
                .tag(template.id)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    TemplateListView()
        .frame(width: 500, height: 600)
}
