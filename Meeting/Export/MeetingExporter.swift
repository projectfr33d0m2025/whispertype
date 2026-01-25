//
//  MeetingExporter.swift
//  WhisperType
//
//  Exports meeting data to various formats (Markdown, clipboard).
//

import Foundation
import AppKit

// MARK: - Meeting Exporter

class MeetingExporter {
    
    // MARK: - Singleton
    
    static let shared = MeetingExporter()
    
    // MARK: - Export to Markdown
    
    /// Export meeting to Markdown format
    func exportToMarkdown(meeting: MeetingRecord, summary: String, transcript: String) -> String {
        var content = """
        # \(meeting.title)
        
        **Date:** \(meeting.formattedDate)  
        **Duration:** \(meeting.formattedDuration)  
        **Audio Source:** \(meeting.audioSource.capitalized)
        """
        
        if meeting.speakerCount > 0 {
            content += """
              
            **Speakers:** \(meeting.speakerCount)
            """
        }
        
        if let template = meeting.templateUsed {
            content += """
              
            **Template:** \(template.capitalized)
            """
        }
        
        content += "\n\n---\n\n"
        
        // Summary section
        content += "## Summary\n\n"
        if summary.isEmpty || summary == "No summary available." {
            content += "_No summary generated._\n\n"
        } else {
            content += summary + "\n\n"
        }
        
        content += "---\n\n"
        
        // Transcript section
        content += "## Transcript\n\n"
        if transcript.isEmpty || transcript == "No transcript available." {
            content += "_No transcript available._\n\n"
        } else {
            content += transcript + "\n"
        }
        
        return content
    }
    
    /// Export meeting with action items
    func exportToMarkdownFull(
        meeting: MeetingRecord,
        summary: String,
        transcript: String,
        actionItems: [MeetingActionItem]
    ) -> String {
        var content = exportToMarkdown(meeting: meeting, summary: summary, transcript: transcript)
        
        // Insert action items before transcript
        if !actionItems.isEmpty {
            // Find where transcript section starts and insert before it
            if let transcriptRange = content.range(of: "---\n\n## Transcript") {
                var actionContent = "## Action Items\n\n"
                
                for item in actionItems {
                    let checkbox = item.completed ? "[x]" : "[ ]"
                    actionContent += "- \(checkbox) \(item.actionText)"
                    
                    if let assignee = item.assignee, !assignee.isEmpty {
                        actionContent += " (@\(assignee))"
                    }
                    
                    if let dueDate = item.dueDate, !dueDate.isEmpty {
                        actionContent += " - Due: \(dueDate)"
                    }
                    
                    actionContent += "\n"
                }
                
                actionContent += "\n---\n\n## Transcript"
                content.replaceSubrange(transcriptRange, with: actionContent)
            }
        }
        
        return content
    }
    
    // MARK: - Export to File
    
    /// Export meeting to a file at the specified URL
    func exportToFile(
        meeting: MeetingRecord,
        summary: String,
        transcript: String,
        actionItems: [MeetingActionItem] = [],
        to url: URL
    ) throws {
        let content = exportToMarkdownFull(
            meeting: meeting,
            summary: summary,
            transcript: transcript,
            actionItems: actionItems
        )
        
        try content.write(to: url, atomically: true, encoding: .utf8)
        print("MeetingExporter: Exported to \(url.path)")
    }
    
    // MARK: - Export to Clipboard
    
    /// Copy summary to clipboard
    func copySummaryToClipboard(_ summary: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(summary, forType: .string)
    }
    
    /// Copy transcript to clipboard
    func copyTranscriptToClipboard(_ transcript: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(transcript, forType: .string)
    }
    
    /// Copy full meeting to clipboard
    func copyFullMeetingToClipboard(
        meeting: MeetingRecord,
        summary: String,
        transcript: String,
        actionItems: [MeetingActionItem] = []
    ) {
        let content = exportToMarkdownFull(
            meeting: meeting,
            summary: summary,
            transcript: transcript,
            actionItems: actionItems
        )
        
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(content, forType: .string)
    }
    
    // MARK: - Suggested Filename
    
    /// Generate a suggested filename for export
    func suggestedFilename(for meeting: MeetingRecord) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: meeting.createdAt)
        
        // Sanitize title for filename
        let sanitizedTitle = meeting.title
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: "\\", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        return "\(dateString) - \(sanitizedTitle).md"
    }
}
