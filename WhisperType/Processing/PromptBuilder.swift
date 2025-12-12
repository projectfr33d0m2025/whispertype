//
//  PromptBuilder.swift
//  WhisperType
//
//  Builds system and user prompts for LLM processing based on mode.
//

import Foundation

/// Builds prompts for LLM text enhancement
class PromptBuilder {
    
    // MARK: - Singleton
    
    static let shared = PromptBuilder()
    
    // MARK: - Vocabulary Terms (for Phase 3)
    
    private var vocabularyTerms: [String] = []
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Vocabulary Configuration
    
    /// Set vocabulary terms to include in prompts (Phase 3 integration)
    func setVocabularyTerms(_ terms: [String]) {
        self.vocabularyTerms = terms
        print("PromptBuilder: Set \(terms.count) vocabulary terms")
    }
    
    // MARK: - Prompt Building
    
    /// Build the system prompt for a given processing mode
    func buildSystemPrompt(mode: ProcessingMode) -> String {
        switch mode {
        case .raw:
            // Raw mode doesn't use LLM
            return ""
            
        case .clean:
            return """
            You are a text cleaning assistant. Your task is to clean voice transcriptions.
            
            Rules:
            - Remove filler words: um, uh, uhm, er, erm, ah, hmm, like (when used as filler), you know, I mean, basically, sort of, kind of
            - Remove false starts and repeated phrases
            - Keep the exact meaning and tone of the speaker
            - Do not add any new content or change the meaning
            - Output ONLY the cleaned text, nothing else
            """
            
        case .formatted:
            return """
            You are a text formatting assistant. Your task is to clean and format voice transcriptions.
            
            Rules:
            - Remove filler words: um, uh, uhm, er, erm, ah, hmm, like (when used as filler), you know, I mean, basically, sort of, kind of
            - Remove false starts and repeated phrases
            - Fix capitalization (sentence starts, proper nouns, "I")
            - Add or fix punctuation where clearly needed
            - Keep the speaker's voice and tone
            - Do not change the meaning or add content
            - Output ONLY the formatted text, nothing else
            """
            
        case .polished:
            return """
            You are a writing assistant. Your task is to improve voice transcriptions for clarity.
            
            Rules:
            - Remove all filler words and false starts
            - Fix grammar and punctuation
            - Improve clarity without changing the meaning
            - Preserve the speaker's tone and intent
            - Make sentences flow naturally
            - Do not add new ideas or change the message
            - Output ONLY the improved text, nothing else
            """
            
        case .professional:
            return """
            You are a professional writing assistant. Your task is to transform voice transcriptions into professional text.
            
            Rules:
            - Remove all filler words, informal patterns, and false starts
            - Use proper grammar and punctuation
            - Apply professional, formal tone
            - Complete sentence fragments into full sentences
            - Ensure the text is suitable for business communication
            - Preserve the core message and intent
            - Output ONLY the professional text, nothing else
            """
        }
    }
    
    /// Build the user prompt with the text to process
    func buildUserPrompt(text: String, context: TranscriptionContext) -> String {
        var prompt = text
        
        // Add context hints if available
        var contextHints: [String] = []
        
        if let appName = context.appName {
            contextHints.append("Context: Writing in \(appName).")
        }
        
        // Add vocabulary terms if set
        if !vocabularyTerms.isEmpty {
            let termsString = vocabularyTerms.prefix(50).joined(separator: ", ")
            contextHints.append("Important terms to spell correctly: \(termsString)")
        }
        
        if let additional = context.additionalContext, !additional.isEmpty {
            contextHints.append(additional)
        }
        
        // Prepend context if we have any
        if !contextHints.isEmpty {
            let contextString = contextHints.joined(separator: "\n")
            prompt = "\(contextString)\n\nText to process:\n\(text)"
        }
        
        return prompt
    }
    
    /// Build complete messages array for chat completion APIs
    func buildMessages(text: String, mode: ProcessingMode, context: TranscriptionContext) -> [[String: String]] {
        let systemPrompt = buildSystemPrompt(mode: mode)
        let userPrompt = buildUserPrompt(text: text, context: context)
        
        return [
            ["role": "system", "content": systemPrompt],
            ["role": "user", "content": userPrompt]
        ]
    }
    
    /// Build a single prompt for non-chat APIs (like Ollama generate)
    func buildSinglePrompt(text: String, mode: ProcessingMode, context: TranscriptionContext) -> String {
        let systemPrompt = buildSystemPrompt(mode: mode)
        let userPrompt = buildUserPrompt(text: text, context: context)
        
        return """
        \(systemPrompt)
        
        Input:
        \(userPrompt)
        
        Output:
        """
    }
}
