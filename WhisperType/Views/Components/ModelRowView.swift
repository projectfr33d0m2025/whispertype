//
//  ModelRowView.swift
//  WhisperType
//
//  A row view for displaying a single Whisper model in the model settings list.
//

import SwiftUI

struct ModelRowView: View {
    
    let model: WhisperModelType
    let downloadState: ModelDownloadState
    let isActive: Bool
    
    let onDownload: () -> Void
    let onCancel: () -> Void
    let onSetActive: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Model Info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(model.displayName)
                        .font(.headline)
                    
                    if isActive {
                        Text("Active")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.2))
                            .foregroundColor(.green)
                            .cornerRadius(4)
                    }
                    
                    if model.isEnglishOnly {
                        Text("EN")
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(3)
                    }
                }
                
                Text(model.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                // Rating indicators
                HStack(spacing: 12) {
                    ratingView(label: "Speed", rating: model.speedRating, color: .orange)
                    ratingView(label: "Accuracy", rating: model.accuracyRating, color: .purple)
                    Text("RAM: \(model.minimumRAM)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Actions
            actionButtons
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isActive ? Color.green.opacity(0.5) : Color.clear, lineWidth: 2)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityDescription)
    }
    
    /// Computed accessibility description for the model row
    private var accessibilityDescription: String {
        var parts: [String] = [model.displayName]
        
        if isActive {
            parts.append("Active")
        }
        
        if model.isEnglishOnly {
            parts.append("English only")
        } else {
            parts.append("Multilingual")
        }
        
        parts.append("Size: \(model.fileSizeFormatted)")
        parts.append("Speed rating: \(model.speedRating) out of 5")
        parts.append("Accuracy rating: \(model.accuracyRating) out of 5")
        
        switch downloadState {
        case .notDownloaded:
            parts.append("Not downloaded")
        case .downloading(let progress):
            parts.append("Downloading: \(Int(progress * 100)) percent")
        case .downloaded:
            parts.append("Downloaded")
        case .failed(let error):
            parts.append("Download failed: \(error)")
        }
        
        return parts.joined(separator: ". ")
    }

    
    // MARK: - Rating View
    
    private func ratingView(label: String, rating: Int, color: Color) -> some View {
        HStack(spacing: 2) {
            Text(label + ":")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            ForEach(1...5, id: \.self) { index in
                Image(systemName: index <= rating ? "circle.fill" : "circle")
                    .font(.system(size: 6))
                    .foregroundColor(index <= rating ? color : color.opacity(0.3))
            }
        }
    }
    
    // MARK: - Action Buttons
    
    @ViewBuilder
    private var actionButtons: some View {
        switch downloadState {
        case .notDownloaded:
            Button(action: onDownload) {
                Label("Download", systemImage: "arrow.down.circle")
            }
            .buttonStyle(.borderedProminent)
            .accessibilityLabel("Download \(model.displayName)")
            .accessibilityHint("Downloads the \(model.fileSizeFormatted) model file")
            
        case .downloading(let progress):
            VStack(spacing: 4) {
                ProgressView(value: progress)
                    .frame(width: 80)
                    .accessibilityLabel("Download progress")
                    .accessibilityValue("\(Int(progress * 100)) percent")
                
                HStack {
                    Text("\(Int(progress * 100))%")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Button(action: onCancel) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Cancel download")
                    .accessibilityLabel("Cancel download")
                }
            }
            
        case .downloaded:
            HStack(spacing: 8) {
                if !isActive {
                    Button("Set Active", action: onSetActive)
                        .buttonStyle(.bordered)
                        .accessibilityLabel("Set \(model.displayName) as active model")
                        .accessibilityHint("This model will be used for transcription")
                }
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(.bordered)
                .help("Delete model")
                .accessibilityLabel("Delete \(model.displayName)")
                .accessibilityHint("Removes the downloaded model file")
            }
            
        case .failed(let error):
            VStack(spacing: 4) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text("Failed")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                
                Button("Retry", action: onDownload)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .accessibilityLabel("Retry download")
                    .accessibilityHint("Download failed: \(error). Tap to try again.")
            }
            .help(error)
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 12) {
        ModelRowView(
            model: .tinyEn,
            downloadState: .notDownloaded,
            isActive: false,
            onDownload: {},
            onCancel: {},
            onSetActive: {},
            onDelete: {}
        )
        
        ModelRowView(
            model: .baseEn,
            downloadState: .downloading(progress: 0.45),
            isActive: false,
            onDownload: {},
            onCancel: {},
            onSetActive: {},
            onDelete: {}
        )
        
        ModelRowView(
            model: .smallEn,
            downloadState: .downloaded,
            isActive: true,
            onDownload: {},
            onCancel: {},
            onSetActive: {},
            onDelete: {}
        )
        
        ModelRowView(
            model: .medium,
            downloadState: .failed(error: "Network timeout"),
            isActive: false,
            onDownload: {},
            onCancel: {},
            onSetActive: {},
            onDelete: {}
        )
    }
    .padding()
    .frame(width: 500)
}
