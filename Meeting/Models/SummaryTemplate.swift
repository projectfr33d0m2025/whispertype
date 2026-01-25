//
//  SummaryTemplate.swift
//  WhisperType
//
//  Model for meeting summary templates with built-in and custom templates.
//

import Foundation

// MARK: - Summary Template

/// A template for generating meeting summaries
struct SummaryTemplate: Identifiable, Codable, Equatable {
    
    /// Unique identifier
    let id: String
    
    /// Display name for the template
    var name: String
    
    /// Description of when to use this template
    var description: String
    
    /// The template content with {{variable}} placeholders
    var content: String
    
    /// Whether this is a built-in template (cannot be deleted)
    let isBuiltIn: Bool
    
    /// Icon name for display
    var icon: String
    
    /// Date created (for custom templates)
    let createdAt: Date
    
    /// Date last modified
    var modifiedAt: Date
    
    // MARK: - Initialization
    
    init(
        id: String = UUID().uuidString,
        name: String,
        description: String,
        content: String,
        isBuiltIn: Bool = false,
        icon: String = "doc.text",
        createdAt: Date = Date(),
        modifiedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.content = content
        self.isBuiltIn = isBuiltIn
        self.icon = icon
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }
    
    // MARK: - Variable Extraction
    
    /// Extract all variable names from the template content
    var variables: [String] {
        TemplateVariableExtractor.extractVariables(from: content)
    }
}

// MARK: - Built-in Templates

extension SummaryTemplate {
    
    /// Standard Meeting Notes template
    static let standardMeetingNotes = SummaryTemplate(
        id: "builtin-standard",
        name: "Standard Meeting Notes",
        description: "Comprehensive notes with summary, key points, decisions, and action items",
        content: """
        ## Summary
        {{summary}}
        
        ## Key Discussion Points
        {{key_points}}
        
        ## Decisions Made
        {{decisions}}
        
        ## Action Items
        {{action_items}}
        
        ## Participants
        {{participants}}
        """,
        isBuiltIn: true,
        icon: "doc.text.fill"
    )
    
    /// Action-Focused template
    static let actionFocused = SummaryTemplate(
        id: "builtin-action",
        name: "Action-Focused",
        description: "Emphasizes action items and next steps",
        content: """
        ## Action Items
        
        {{action_items}}
        
        ---
        Meeting: {{date}} | Duration: {{duration}}
        """,
        isBuiltIn: true,
        icon: "checklist"
    )
    
    /// Detailed Minutes template
    static let detailedMinutes = SummaryTemplate(
        id: "builtin-detailed",
        name: "Detailed Minutes",
        description: "Formal meeting minutes with full details",
        content: """
        # Meeting Minutes
        **Date:** {{date}}
        **Duration:** {{duration}}
        **Participants:** {{participants}}
        
        ## Summary
        {{summary}}
        
        ## Discussion Details
        {{key_points}}
        
        ## Decisions
        {{decisions}}
        
        ## Action Items
        {{action_items}}
        
        ## Transcript Preview
        {{transcript_short}}
        
        [Full transcript available in meeting history]
        """,
        isBuiltIn: true,
        icon: "doc.richtext"
    )
    
    /// Executive Brief template
    static let executiveBrief = SummaryTemplate(
        id: "builtin-executive",
        name: "Executive Brief",
        description: "High-level summary for executives",
        content: """
        ## {{date}} Meeting Brief
        
        {{summary}}
        
        **Key Decisions:** {{decisions}}
        
        **Critical Actions:** {{action_items}}
        """,
        isBuiltIn: true,
        icon: "briefcase.fill"
    )
    
    /// Stand-up/Scrum template
    static let standup = SummaryTemplate(
        id: "builtin-standup",
        name: "Stand-up/Scrum",
        description: "Daily stand-up format with updates and blockers",
        content: """
        ## Daily Stand-up - {{date}}
        
        ### Updates by Participant
        {{key_points}}
        
        ### Blockers Mentioned
        {{blockers}}
        
        ### Action Items
        {{action_items}}
        """,
        isBuiltIn: true,
        icon: "person.3.fill"
    )
    
    /// 1-on-1 template
    static let oneOnOne = SummaryTemplate(
        id: "builtin-1on1",
        name: "1-on-1",
        description: "Personal meeting format for 1-on-1 conversations",
        content: """
        ## 1-on-1 Meeting - {{date}}
        
        ### Discussion Topics
        {{key_points}}
        
        ### Feedback & Notes
        {{feedback}}
        
        ### Follow-up Items
        {{action_items}}
        
        ### Next Meeting Topics
        {{next_topics}}
        """,
        isBuiltIn: true,
        icon: "person.2.fill"
    )
    
    /// All built-in templates
    static let allBuiltIn: [SummaryTemplate] = [
        .standardMeetingNotes,
        .actionFocused,
        .detailedMinutes,
        .executiveBrief,
        .standup,
        .oneOnOne
    ]
}

// MARK: - Template Variable

/// Known template variables and their descriptions
enum TemplateVariable: String, CaseIterable {
    case summary = "summary"
    case keyPoints = "key_points"
    case decisions = "decisions"
    case actionItems = "action_items"
    case participants = "participants"
    case duration = "duration"
    case date = "date"
    case transcript = "transcript"
    case transcriptShort = "transcript_short"
    case blockers = "blockers"
    case feedback = "feedback"
    case nextTopics = "next_topics"
    
    /// Display name for the variable
    var displayName: String {
        switch self {
        case .summary: return "Summary"
        case .keyPoints: return "Key Points"
        case .decisions: return "Decisions"
        case .actionItems: return "Action Items"
        case .participants: return "Participants"
        case .duration: return "Duration"
        case .date: return "Date"
        case .transcript: return "Full Transcript"
        case .transcriptShort: return "Transcript Preview"
        case .blockers: return "Blockers"
        case .feedback: return "Feedback"
        case .nextTopics: return "Next Topics"
        }
    }
    
    /// Description of what this variable contains
    var description: String {
        switch self {
        case .summary: return "2-3 paragraph summary of the meeting"
        case .keyPoints: return "Bullet list of main discussion points"
        case .decisions: return "Decisions that were made"
        case .actionItems: return "Tasks with assignees and due dates"
        case .participants: return "List of speakers"
        case .duration: return "Meeting length (e.g., 45 minutes)"
        case .date: return "Meeting date and time"
        case .transcript: return "Full transcript text"
        case .transcriptShort: return "First 500 words of transcript"
        case .blockers: return "Blockers mentioned (for stand-ups)"
        case .feedback: return "Feedback items (for 1-on-1s)"
        case .nextTopics: return "Topics for next meeting"
        }
    }
    
    /// Variable placeholder string
    var placeholder: String {
        "{{\(rawValue)}}"
    }
    
    /// Whether this variable requires LLM processing
    var requiresLLM: Bool {
        switch self {
        case .duration, .date, .transcript, .transcriptShort, .participants:
            return false
        default:
            return true
        }
    }
}

// MARK: - Template Variable Extractor

/// Utility for extracting variables from template content
enum TemplateVariableExtractor {
    
    /// Extract all variable names from template content
    /// - Parameter content: Template content with {{variable}} placeholders
    /// - Returns: Array of variable names
    static func extractVariables(from content: String) -> [String] {
        let pattern = "\\{\\{([a-zA-Z_][a-zA-Z0-9_]*)\\}\\}"
        
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return []
        }
        
        let range = NSRange(content.startIndex..., in: content)
        let matches = regex.matches(in: content, range: range)
        
        var variables: [String] = []
        for match in matches {
            if let varRange = Range(match.range(at: 1), in: content) {
                let variable = String(content[varRange])
                if !variables.contains(variable) {
                    variables.append(variable)
                }
            }
        }
        
        return variables
    }
    
    /// Check if all variables in template are known
    /// - Parameter content: Template content
    /// - Returns: Array of unknown variable names
    static func unknownVariables(in content: String) -> [String] {
        let extracted = extractVariables(from: content)
        let known = Set(TemplateVariable.allCases.map { $0.rawValue })
        return extracted.filter { !known.contains($0) }
    }
}
