//
//  MeetingSummarizer.swift
//  WhisperType
//
//  Main summarization engine for meeting transcripts.
//

import Foundation

/// Result of meeting summarization
struct SummarizationResult {
    /// The generated summary text
    let summary: String
    
    /// Extracted action items
    let actionItems: [ActionItem]
    
    /// Template used
    let template: SummaryTemplate
    
    /// Whether LLM was available for generation
    let usedLLM: Bool
    
    /// Validation result
    let validation: SummaryValidationResult?
    
    /// Processing time in seconds
    let processingTime: TimeInterval
}

/// Main summarization engine for meeting transcripts
@MainActor
class MeetingSummarizer: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = MeetingSummarizer()
    
    // MARK: - Published Properties
    
    @Published private(set) var isProcessing: Bool = false
    @Published private(set) var currentStage: String = ""
    
    // MARK: - Dependencies
    
    private let llmEngine = LLMEngine.shared
    private let templateStore = SummaryTemplateStore.shared
    private let actionExtractor = ActionItemExtractor.shared
    
    // MARK: - Configuration
    
    /// Maximum characters per chunk for hierarchical summarization
    private let chunkSize = 4000
    
    /// Chunk overlap to maintain context
    private let chunkOverlap = 200
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Summarization
    
    /// Summarize a meeting transcript
    /// - Parameters:
    ///   - transcript: The full transcript text
    ///   - duration: Meeting duration string (e.g., "45 minutes")
    ///   - date: Meeting date
    ///   - template: Template to use (nil = use selected template)
    /// - Returns: Summarization result
    func summarize(
        transcript: String,
        duration: String,
        date: Date,
        template: SummaryTemplate? = nil
    ) async -> SummarizationResult {
        let startTime = Date()
        isProcessing = true
        
        defer {
            isProcessing = false
            currentStage = ""
        }
        
        // Get template
        let selectedTemplate = template ?? templateStore.selectedTemplate ?? templateStore.defaultTemplate
        
        // Check LLM availability
        let llmStatus = await llmEngine.status
        let llmAvailable = llmStatus.isAvailable
        
        // Extract variables needed
        let variables = selectedTemplate.variables
        
        // Prepare variable values
        var variableValues: [String: String] = [:]
        
        // Fill metadata variables (no LLM needed)
        variableValues["duration"] = duration
        variableValues["date"] = formatDate(date)
        variableValues["transcript"] = transcript
        variableValues["transcript_short"] = String(transcript.prefix(2000))
        variableValues["participants"] = extractParticipants(from: transcript)
        
        // Process LLM-dependent variables
        if llmAvailable {
            currentStage = "Analyzing transcript..."
            
            // Use hierarchical summarization for long transcripts
            let processedTranscript: String
            if transcript.count > chunkSize * 2 {
                currentStage = "Processing long meeting..."
                processedTranscript = await summarizeHierarchically(transcript)
            } else {
                processedTranscript = transcript
            }
            
            // Generate each LLM variable
            for variable in variables {
                guard let templateVar = TemplateVariable(rawValue: variable),
                      templateVar.requiresLLM else {
                    continue
                }
                
                currentStage = "Generating \(templateVar.displayName.lowercased())..."
                
                if let value = await generateVariable(templateVar, from: processedTranscript) {
                    variableValues[variable] = value
                } else {
                    variableValues[variable] = "*Unable to generate*"
                }
            }
        } else {
            // Fallback: provide basic structure
            for variable in variables {
                if variableValues[variable] == nil {
                    variableValues[variable] = "*Summary generation requires AI. Please configure Ollama or cloud LLM in Settings.*"
                }
            }
        }
        
        // Extract action items
        currentStage = "Extracting action items..."
        let actionItems: [ActionItem]
        if llmAvailable {
            actionItems = (try? await actionExtractor.extractActionItems(from: transcript)) ?? []
        } else {
            actionItems = actionExtractor.extractActionItemsSimple(from: transcript)
        }
        
        // Override action_items variable with extracted items
        if !actionItems.isEmpty {
            variableValues["action_items"] = actionItems.asMarkdown
        }
        
        // Render template
        currentStage = "Generating summary..."
        let summary = renderTemplate(selectedTemplate, with: variableValues)
        
        // Validate
        let validation = SummaryValidator.validate(
            summary: summary,
            template: selectedTemplate,
            transcript: transcript
        )
        
        let processingTime = Date().timeIntervalSince(startTime)
        
        return SummarizationResult(
            summary: summary,
            actionItems: actionItems,
            template: selectedTemplate,
            usedLLM: llmAvailable,
            validation: validation,
            processingTime: processingTime
        )
    }
    
    // MARK: - Hierarchical Summarization
    
    /// Summarize a long transcript in chunks
    private func summarizeHierarchically(_ transcript: String) async -> String {
        // Split into chunks
        let chunks = splitIntoChunks(transcript)
        
        // Summarize each chunk
        var chunkSummaries: [String] = []
        
        for (index, chunk) in chunks.enumerated() {
            currentStage = "Summarizing part \(index + 1) of \(chunks.count)..."
            
            let prompt = """
            Summarize this portion of a meeting transcript concisely, focusing on key points and decisions:
            
            \(chunk)
            
            Summary:
            """
            
            do {
                let response = try await llmEngine.process(prompt, mode: .polished, context: .default)
                chunkSummaries.append(response)
            } catch {
                print("MeetingSummarizer: Failed to summarize chunk \(index) - \(error)")
            }
        }
        
        // If we have multiple chunk summaries, combine them
        if chunkSummaries.count > 1 {
            return chunkSummaries.joined(separator: "\n\n---\n\n")
        }
        
        return chunkSummaries.first ?? transcript
    }
    
    /// Split transcript into overlapping chunks
    private func splitIntoChunks(_ text: String) -> [String] {
        var chunks: [String] = []
        var startIndex = text.startIndex
        
        while startIndex < text.endIndex {
            let endDistance = min(chunkSize, text.distance(from: startIndex, to: text.endIndex))
            let endIndex = text.index(startIndex, offsetBy: endDistance)
            
            // Try to break at a sentence boundary
            var adjustedEnd = endIndex
            if endIndex < text.endIndex {
                // Look for sentence ending
                let searchRange = text.index(endIndex, offsetBy: -100, limitedBy: startIndex) ?? startIndex
                if let periodIndex = text[searchRange..<endIndex].lastIndex(of: ".") {
                    adjustedEnd = text.index(after: periodIndex)
                }
            }
            
            let chunk = String(text[startIndex..<adjustedEnd])
            chunks.append(chunk)
            
            // Move start with overlap
            let overlapOffset = max(0, chunk.count - chunkOverlap)
            startIndex = text.index(startIndex, offsetBy: overlapOffset, limitedBy: text.endIndex) ?? text.endIndex
        }
        
        return chunks
    }
    
    // MARK: - Variable Generation
    
    /// Generate a specific template variable value using LLM
    private func generateVariable(_ variable: TemplateVariable, from transcript: String) async -> String? {
        let prompt: String
        
        switch variable {
        case .summary:
            prompt = """
            Write a 2-3 paragraph summary of this meeting. Focus on the main topics discussed and key outcomes:
            
            \(transcript.prefix(6000))
            
            Summary:
            """
            
        case .keyPoints:
            prompt = """
            List the key discussion points from this meeting as bullet points (use - for each point):
            
            \(transcript.prefix(6000))
            
            Key Points:
            """
            
        case .decisions:
            prompt = """
            List any decisions that were made during this meeting. If no clear decisions were made, write "No explicit decisions recorded."
            
            \(transcript.prefix(6000))
            
            Decisions:
            """
            
        case .actionItems:
            prompt = """
            List all action items, tasks, or follow-ups mentioned. Format as "- [Assignee]: Task" if assignee is known:
            
            \(transcript.prefix(6000))
            
            Action Items:
            """
            
        case .blockers:
            prompt = """
            List any blockers or obstacles mentioned during this meeting:
            
            \(transcript.prefix(6000))
            
            Blockers:
            """
            
        case .feedback:
            prompt = """
            Summarize any feedback, praise, or concerns shared during this 1-on-1 meeting:
            
            \(transcript.prefix(6000))
            
            Feedback & Notes:
            """
            
        case .nextTopics:
            prompt = """
            List any topics mentioned for the next meeting or future discussion:
            
            \(transcript.prefix(6000))
            
            Next Meeting Topics:
            """
            
        default:
            return nil
        }
        
        do {
            let response = try await llmEngine.process(prompt, mode: .polished, context: .default)
            return response.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            print("MeetingSummarizer: Failed to generate \(variable) - \(error)")
            return nil
        }
    }
    
    // MARK: - Template Rendering
    
    /// Render a template with variable values
    private func renderTemplate(_ template: SummaryTemplate, with values: [String: String]) -> String {
        var result = template.content
        
        for (variable, value) in values {
            result = result.replacingOccurrences(of: "{{\(variable)}}", with: value)
        }
        
        return result
    }
    
    // MARK: - Utilities
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func extractParticipants(from transcript: String) -> String {
        // Look for speaker labels in transcript
        let pattern = "\\[?Speaker\\s*([A-Z])\\]?:|([A-Z][a-z]+)\\s*:"
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return "*Participants not identified*"
        }
        
        let range = NSRange(transcript.startIndex..., in: transcript)
        let matches = regex.matches(in: transcript, range: range)
        
        var speakers: Set<String> = []
        for match in matches {
            if let labelRange = Range(match.range(at: 1), in: transcript) {
                speakers.insert("Speaker \(transcript[labelRange])")
            } else if let nameRange = Range(match.range(at: 2), in: transcript) {
                speakers.insert(String(transcript[nameRange]))
            }
        }
        
        if speakers.isEmpty {
            return "*Participants not identified*"
        }
        
        return speakers.sorted().joined(separator: ", ")
    }
}
