//
//  ModelSettingsView.swift
//  WhisperType
//
//  SwiftUI view for managing Whisper model downloads and selection.
//

import SwiftUI

struct ModelSettingsView: View {
    
    @ObservedObject private var modelManager = ModelManager.shared
    @State private var showDeleteConfirmation = false
    @State private var modelToDelete: WhisperModelType?
    @State private var downloadError: String?
    @State private var showError = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            headerSection
            
            Divider()
            
            // Model List
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(WhisperModelType.allCases) { model in
                        ModelRowView(
                            model: model,
                            downloadState: modelManager.downloadStates[model] ?? .notDownloaded,
                            isActive: modelManager.activeModel == model,
                            onDownload: { downloadModel(model) },
                            onCancel: { modelManager.cancelDownload(model) },
                            onSetActive: { modelManager.setActiveModel(model) },
                            onDelete: { confirmDelete(model) }
                        )
                    }
                }
                .padding(.horizontal, 4)
            }
            
            Divider()
            
            // Footer with storage info
            footerSection
        }
        .padding()
        .frame(minWidth: 500, minHeight: 400)
        .alert("Delete Model", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let model = modelToDelete {
                    deleteModel(model)
                }
            }
        } message: {
            if let model = modelToDelete {
                Text("Are you sure you want to delete \(model.displayName)? This will free up \(model.fileSizeFormatted) of storage.")
            }
        }
        .alert("Download Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(downloadError ?? "An unknown error occurred")
        }
    }

    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Whisper Models")
                .font(.headline)
            
            Text("Download and manage transcription models. Larger models are more accurate but slower.")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            if let activeModel = modelManager.activeModel {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Active: \(activeModel.displayName)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .padding(.top, 4)
            } else {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("No model active. Download a model to get started.")
                        .font(.subheadline)
                }
                .padding(.top, 4)
            }
        }
    }
    
    // MARK: - Footer Section
    
    private var footerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Storage Used: \(modelManager.totalStorageFormatted)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("Models: \(modelManager.downloadedModels.count) of \(WhisperModelType.allCases.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: openModelsFolder) {
                Label("Open Folder", systemImage: "folder")
            }
            .buttonStyle(.bordered)
        }
    }

    
    // MARK: - Actions
    
    private func downloadModel(_ model: WhisperModelType) {
        Task {
            do {
                try await modelManager.downloadModel(model)
            } catch {
                downloadError = error.localizedDescription
                showError = true
            }
        }
    }
    
    private func confirmDelete(_ model: WhisperModelType) {
        modelToDelete = model
        showDeleteConfirmation = true
    }
    
    private func deleteModel(_ model: WhisperModelType) {
        do {
            try modelManager.deleteModel(model)
        } catch {
            downloadError = error.localizedDescription
            showError = true
        }
        modelToDelete = nil
    }
    
    private func openModelsFolder() {
        NSWorkspace.shared.open(modelManager.modelsDirectory)
    }
}


// MARK: - Preview

#Preview {
    ModelSettingsView()
}
