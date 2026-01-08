//
//  SubtitleEntryView.swift
//  WhisperType
//
//  Individual transcript entry view for live subtitles.
//

import SwiftUI

/// View for displaying a single transcript entry
struct SubtitleEntryView: View {
    
    let update: TranscriptUpdate
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Timestamp
            Text(update.formattedTimestamp)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(.secondary)
            
            // Transcript text
            Text(update.text)
                .font(.system(size: 14))
                .foregroundColor(.primary)
                .textSelection(.enabled)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Preview

#if DEBUG
struct SubtitleEntryView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 0) {
            SubtitleEntryView(update: TranscriptUpdate(
                text: "So I think we should proceed with the budget allocation as discussed in the previous meeting.",
                timestamp: 45
            ))
            
            Divider()
            
            SubtitleEntryView(update: TranscriptUpdate(
                text: "The marketing team has confirmed they can work within those constraints for Q1.",
                timestamp: 52
            ))
        }
        .frame(width: 450)
        .padding()
        .background(Color(.windowBackgroundColor))
    }
}
#endif
