//
//  ActionItemExtractor.swift
//  WhisperType
//
//  Extracts action items from meeting transcripts using LLM.
//

import Foundation

/// Extracts action items from meeting transcripts
class ActionItemExtractor {
    
    // MARK: - Singleton
    
    static let shared = ActionItemExtractor()
    
    // MARK: - Private Properties
    
    private let llmEngine = LLMEngine.shared
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Extraction
    
    /// Extract action items from a transcript
    /// - Parameter transcript: The meeting transcript text
    /// - Returns: Array of extracted action items
    func extractActionItems(from transcript: String) async throws -> [ActionItem] {
        // Check if LLM is available
        let status = await llmEngine.status
        guard status.isAvailable else {
            print("ActionItemExtractor: LLM not available, returning empty")
            return []
        }
        
        // Build the extraction prompt
        let prompt = buildExtractionPrompt(transcript: transcript)
        
        // Process with LLM
        let response = try await llmEngine.process(
            prompt,
            mode: .polished,  // Use improve mode for extraction
            context: .default
        )
        
        // Parse the response
        return parseActionItems(from: response)
    }
    
    // MARK: - Prompt Building
    
    private func buildExtractionPrompt(transcript: String) -> String {
        """
        Extract all action items from the following meeting transcript. For each action item, identify:
        1. The task to be done
        2. Who is assigned (if mentioned)
        3. Due date or deadline (if mentioned)
        
        Format each action item as:
        ACTION: [task description]
        ASSIGNEE: [name or "unassigned"]
        DUE: [date/time or "none"]
        ---
        
        If there are no action items, respond with:
        NO_ACTION_ITEMS
        
        TRANSCRIPT:
        \(transcript.prefix(8000))
        
        ACTION ITEMS:
        """
    }
    
    // MARK: - Response Parsing
    
    private func parseActionItems(from response: String) -> [ActionItem] {
        // Check for no action items
        if response.contains("NO_ACTION_ITEMS") {
            return []
        }
        
        var actionItems: [ActionItem] = []
        
        // Split by delimiter
        let blocks = response.components(separatedBy: "---")
        
        for block in blocks {
            let trimmed = block.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            
            // Parse each field
            var text: String?
            var assignee: String?
            var dueDate: String?
            
            let lines = trimmed.components(separatedBy: .newlines)
            for line in lines {
                let lineTrimmed = line.trimmingCharacters(in: .whitespaces)
                
                if lineTrimmed.hasPrefix("ACTION:") {
                    text = lineTrimmed
                        .replacingOccurrences(of: "ACTION:", with: "")
                        .trimmingCharacters(in: .whitespaces)
                } else if lineTrimmed.hasPrefix("ASSIGNEE:") {
                    let value = lineTrimmed
                        .replacingOccurrences(of: "ASSIGNEE:", with: "")
                        .trimmingCharacters(in: .whitespaces)
                    if value.lowercased() != "unassigned" && value.lowercased() != "none" && !value.isEmpty {
                        assignee = value
                    }
                } else if lineTrimmed.hasPrefix("DUE:") {
                    let value = lineTrimmed
                        .replacingOccurrences(of: "DUE:", with: "")
                        .trimmingCharacters(in: .whitespaces)
                    if value.lowercased() != "none" && !value.isEmpty {
                        dueDate = value
                    }
                }
            }
            
            // Create action item if we have text
            if let actionText = text, !actionText.isEmpty {
                let item = ActionItem(
                    text: actionText,
                    assignee: assignee,
                    dueDate: dueDate,
                    confidence: 0.9  // High confidence for LLM extraction
                )
                actionItems.append(item)
            }
        }
        
        return actionItems
    }
    
    // MARK: - Simple Extraction (Fallback)
    
    /// Simple regex-based extraction as fallback when LLM is unavailable
    func extractActionItemsSimple(from transcript: String) -> [ActionItem] {
        var actionItems: [ActionItem] = []
        
        // Common action item patterns
        let patterns = [
            "(?:please|can you|could you|will you|should)\\s+(.{10,100})",
            "(?:need to|have to|must|should)\\s+(.{10,100})",
            "(?:action item|todo|task)[:\\s]+(.{10,100})",
            "(?:by|before|due)\\s+(?:monday|tuesday|wednesday|thursday|friday|saturday|sunday|tomorrow|next week|end of day|eod|end of week|eow)[,\\s]*(.{5,100})?",
        ]
        
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
                continue
            }
            
            let range = NSRange(transcript.startIndex..., in: transcript)
            let matches = regex.matches(in: transcript, range: range)
            
            for match in matches.prefix(10) {  // Limit to 10 per pattern
                if let textRange = Range(match.range(at: 1), in: transcript) {
                    let text = String(transcript[textRange])
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    if !text.isEmpty && text.count > 10 {
                        let item = ActionItem(
                            text: text,
                            confidence: 0.5  // Lower confidence for regex
                        )
                        actionItems.append(item)
                    }
                }
            }
        }
        
        // Remove duplicates based on similar text
        return removeDuplicates(from: actionItems)
    }
    
    private func removeDuplicates(from items: [ActionItem]) -> [ActionItem] {
        var unique: [ActionItem] = []
        
        for item in items {
            let isDuplicate = unique.contains { existing in
                let similarity = calculateSimilarity(existing.text, item.text)
                return similarity > 0.8
            }
            
            if !isDuplicate {
                unique.append(item)
            }
        }
        
        return unique
    }
    
    private func calculateSimilarity(_ s1: String, _ s2: String) -> Double {
        let set1 = Set(s1.lowercased().components(separatedBy: .whitespaces))
        let set2 = Set(s2.lowercased().components(separatedBy: .whitespaces))
        
        let intersection = set1.intersection(set2).count
        let union = set1.union(set2).count
        
        return union > 0 ? Double(intersection) / Double(union) : 0
    }
}
