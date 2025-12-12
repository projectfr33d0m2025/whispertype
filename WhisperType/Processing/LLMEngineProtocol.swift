//
//  LLMEngineProtocol.swift
//  WhisperType
//
//  Protocol defining the interface for LLM-based text enhancement.
//  Implementations include StubLLMEngine (Phase 1) and real LLMEngine (Phase 2).
//

import Foundation

// MARK: - LLM Engine Status

/// Status of the LLM engine
enum LLMEngineStatus: Equatable {
    /// LLM is available and ready
    case available(provider: String)
    
    /// LLM is unavailable with a reason
    case unavailable(reason: String)
    
    /// LLM is currently processing a request
    case processing
    
    /// Connection is being established
    case connecting
    
    // MARK: - Computed Properties
    
    var isAvailable: Bool {
        if case .available = self { return true }
        return false
    }
    
    var isProcessing: Bool {
        if case .processing = self { return true }
        return false
    }
    
    var displayText: String {
        switch self {
        case .available(let provider):
            return "Connected (\(provider))"
        case .unavailable(let reason):
            return reason
        case .processing:
            return "Processing..."
        case .connecting:
            return "Connecting..."
        }
    }
    
    var icon: String {
        switch self {
        case .available:
            return "checkmark.circle.fill"
        case .unavailable:
            return "xmark.circle.fill"
        case .processing:
            return "ellipsis.circle"
        case .connecting:
            return "arrow.triangle.2.circlepath"
        }
    }
}

// MARK: - LLM Error

/// Errors that can occur during LLM processing
enum LLMError: LocalizedError {
    case notAvailable
    case rateLimited(retryAfter: TimeInterval?)
    case invalidAPIKey
    case networkError(underlying: Error)
    case timeout
    case modelNotFound(name: String)
    case processingFailed(reason: String)
    case cancelled
    
    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "AI enhancement is not available"
        case .rateLimited(let retryAfter):
            if let seconds = retryAfter {
                return "Rate limited. Try again in \(Int(seconds)) seconds"
            }
            return "Rate limited. Please try again later"
        case .invalidAPIKey:
            return "Invalid API key"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .timeout:
            return "Request timed out"
        case .modelNotFound(let name):
            return "Model '\(name)' not found"
        case .processingFailed(let reason):
            return "Processing failed: \(reason)"
        case .cancelled:
            return "Request was cancelled"
        }
    }
}

// MARK: - Transcription Context

/// Context information passed to the LLM for better processing
struct TranscriptionContext {
    /// Name of the app where text will be injected
    var appName: String?
    
    /// Bundle identifier of the target app
    var appBundleId: String?
    
    /// Custom vocabulary terms to preserve
    var vocabularyTerms: [String]
    
    /// Any additional context hints
    var additionalContext: String?
    
    init(
        appName: String? = nil,
        appBundleId: String? = nil,
        vocabularyTerms: [String] = [],
        additionalContext: String? = nil
    ) {
        self.appName = appName
        self.appBundleId = appBundleId
        self.vocabularyTerms = vocabularyTerms
        self.additionalContext = additionalContext
    }
    
    /// Default context with no special configuration
    static let `default` = TranscriptionContext()
}

// MARK: - Processing Result

/// Result of LLM processing
struct ProcessingResult {
    /// The processed text
    let text: String
    
    /// The mode that was actually used (may differ from requested if fallback occurred)
    let modeUsed: ProcessingMode
    
    /// Whether fallback was used
    let usedFallback: Bool
    
    /// Processing time in seconds
    let processingTime: TimeInterval
    
    /// Which provider was used (if any)
    let provider: String?
    
    /// Whether rate limiting caused the fallback
    let wasRateLimited: Bool
    
    /// Vocabulary corrections that were applied
    let vocabularyCorrections: [VocabularyCorrection]
    
    init(
        text: String,
        modeUsed: ProcessingMode,
        usedFallback: Bool,
        processingTime: TimeInterval,
        provider: String?,
        wasRateLimited: Bool = false,
        vocabularyCorrections: [VocabularyCorrection] = []
    ) {
        self.text = text
        self.modeUsed = modeUsed
        self.usedFallback = usedFallback
        self.processingTime = processingTime
        self.provider = provider
        self.wasRateLimited = wasRateLimited
        self.vocabularyCorrections = vocabularyCorrections
    }
}

// MARK: - LLM Engine Protocol

/// Protocol for LLM-based text enhancement engines
protocol LLMEngineProtocol: AnyObject {
    
    /// Current status of the engine
    var status: LLMEngineStatus { get async }
    
    /// Process text using LLM enhancement
    /// - Parameters:
    ///   - text: The text to process
    ///   - mode: The processing mode to use
    ///   - context: Additional context for processing
    /// - Returns: Processed text
    /// - Throws: LLMError if processing fails
    func process(
        _ text: String,
        mode: ProcessingMode,
        context: TranscriptionContext
    ) async throws -> String
    
    /// Cancel any ongoing processing
    func cancel()
}
