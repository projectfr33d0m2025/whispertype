//
//  VocabularyEntryRow.swift
//  WhisperType
//
//  List row component for displaying a vocabulary entry.
//  Part of the v1.2 Vocabulary System feature.
//

import SwiftUI

struct VocabularyEntryRow: View {
    let entry: VocabularyEntry
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onTogglePin: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Pin indicator
            if entry.isPinned {
                Image(systemName: "pin.fill")
                    .foregroundColor(.orange)
                    .font(.caption)
            }
            
            // Main content
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    // Term
                    Text(entry.term)
                        .font(.body)
                        .fontWeight(.medium)
                    
                    // Phonetic (if exists)
                    if let phonetic = entry.phonetic, !phonetic.isEmpty {
                        Text("/\(phonetic)/")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // Source badge
                    SourceBadge(source: entry.source)
                }
                
                // Aliases
                if !entry.aliases.isEmpty {
                    Text("Aliases: \(entry.aliases.joined(separator: ", "))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Usage stats
            if entry.useCount > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "chart.bar.fill")
                        .font(.caption2)
                    Text("\(entry.useCount)")
                        .font(.caption)
                }
                .foregroundColor(.secondary)
            }
            
            // Action buttons (visible on hover)
            if isHovered {
                HStack(spacing: 4) {
                    // Pin/Unpin button
                    Button(action: onTogglePin) {
                        Image(systemName: entry.isPinned ? "pin.slash" : "pin")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                    .help(entry.isPinned ? "Unpin" : "Pin")
                    
                    // Edit button
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                    .help("Edit")
                    
                    // Delete button
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.borderless)
                    .help("Delete")
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
        .contextMenu {
            Button(action: onEdit) {
                Label("Edit", systemImage: "pencil")
            }
            
            Button(action: onTogglePin) {
                Label(entry.isPinned ? "Unpin" : "Pin", systemImage: entry.isPinned ? "pin.slash" : "pin")
            }
            
            Divider()
            
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

// MARK: - Source Badge

struct SourceBadge: View {
    let source: VocabularySource
    
    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: source.icon)
                .font(.caption2)
            Text(source.displayName)
                .font(.caption2)
        }
        .foregroundColor(.secondary)
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(
            Capsule()
                .fill(Color.secondary.opacity(0.1))
        )
    }
}

// MARK: - Preview

#Preview {
    List {
        VocabularyEntryRow(
            entry: VocabularyEntry(
                term: "Eng Leong",
                phonetic: "eng lee-ong",
                aliases: ["England", "English long"],
                source: .manual,
                isPinned: true,
                useCount: 15
            ),
            onEdit: {},
            onDelete: {},
            onTogglePin: {}
        )
        
        VocabularyEntryRow(
            entry: VocabularyEntry(
                term: "WhisperType",
                aliases: ["whisper type", "Whisper Type"],
                source: .imported,
                useCount: 5
            ),
            onEdit: {},
            onDelete: {},
            onTogglePin: {}
        )
        
        VocabularyEntryRow(
            entry: VocabularyEntry(
                term: "Anthropic",
                source: .manual
            ),
            onEdit: {},
            onDelete: {},
            onTogglePin: {}
        )
    }
    .frame(width: 500, height: 200)
}
