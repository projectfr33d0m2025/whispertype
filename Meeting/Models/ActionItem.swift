//
//  ActionItem.swift
//  WhisperType
//
//  Model for extracted action items from meeting transcripts.
//

import Foundation

/// An action item extracted from a meeting transcript
struct ActionItem: Identifiable, Codable, Equatable {
    
    /// Unique identifier
    let id: String
    
    /// The action item text
    var text: String
    
    /// Who is assigned to this action
    var assignee: String?
    
    /// Due date (if mentioned)
    var dueDate: String?
    
    /// Timestamp in the meeting when this was mentioned (in seconds)
    var timestamp: TimeInterval?
    
    /// Whether the action has been completed
    var isCompleted: Bool
    
    /// Confidence score from extraction (0-1)
    var confidence: Double
    
    // MARK: - Initialization
    
    init(
        id: String = UUID().uuidString,
        text: String,
        assignee: String? = nil,
        dueDate: String? = nil,
        timestamp: TimeInterval? = nil,
        isCompleted: Bool = false,
        confidence: Double = 1.0
    ) {
        self.id = id
        self.text = text
        self.assignee = assignee
        self.dueDate = dueDate
        self.timestamp = timestamp
        self.isCompleted = isCompleted
        self.confidence = confidence
    }
    
    // MARK: - Formatting
    
    /// Formatted string for display
    var formattedText: String {
        var result = "• "
        
        if let assignee = assignee, !assignee.isEmpty {
            result += "[\(assignee)] "
        }
        
        result += text
        
        if let dueDate = dueDate, !dueDate.isEmpty {
            result += " (Due: \(dueDate))"
        }
        
        return result
    }
    
    /// Markdown formatted string
    var markdownText: String {
        var result = "- [ ] "
        
        if let assignee = assignee, !assignee.isEmpty {
            result += "**\(assignee):** "
        }
        
        result += text
        
        if let dueDate = dueDate, !dueDate.isEmpty {
            result += " *(Due: \(dueDate))*"
        }
        
        return result
    }
}

// MARK: - Action Items Collection

extension Array where Element == ActionItem {
    
    /// Format all action items as markdown
    var asMarkdown: String {
        if isEmpty {
            return "*No action items identified*"
        }
        return map { $0.markdownText }.joined(separator: "\n")
    }
    
    /// Group action items by assignee
    var groupedByAssignee: [String: [ActionItem]] {
        var grouped: [String: [ActionItem]] = [:]
        
        for item in self {
            let key = item.assignee ?? "Unassigned"
            if grouped[key] == nil {
                grouped[key] = []
            }
            grouped[key]?.append(item)
        }
        
        return grouped
    }
    
    /// Filter by minimum confidence
    func filtered(minConfidence: Double) -> [ActionItem] {
        filter { $0.confidence >= minConfidence }
    }
}
