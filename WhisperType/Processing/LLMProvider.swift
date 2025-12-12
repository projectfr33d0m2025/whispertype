//
//  LLMProvider.swift
//  WhisperType
//
//  Protocol defining the interface for LLM providers (Ollama, OpenAI, OpenRouter).
//  Each provider implements this protocol for unified access.
//

import Foundation

// MARK: - LLM Provider Protocol

/// Protocol for LLM providers that can process text
protocol LLMProvider: AnyObject {
    /// Unique identifier for this provider
    var id: String { get }
    
    /// Display name for UI
    var displayName: String { get }
    
    /// Whether this provider runs locally (no data sent to cloud)
    var isLocal: Bool { get }
    
    /// Current status of the provider
    var status: LLMProviderStatus { get async }
    
    /// Process a text enhancement request
    /// - Parameter request: The request containing text and configuration
    /// - Returns: The processed response
    /// - Throws: LLMError if processing fails
    func process(_ request: LLMRequest) async throws -> LLMResponse
    
    /// Cancel any ongoing request
    func cancel()
}

// MARK: - LLM Provider Status

/// Status of an individual LLM provider
enum LLMProviderStatus: Equatable {
    /// Provider is available and ready
    case available
    
    /// Provider is unavailable with a reason
    case unavailable(reason: String)
    
    /// Provider is connecting/checking status
    case connecting
    
    /// Provider is rate limited
    case rateLimited(retryAfter: TimeInterval?)
    
    // MARK: - Computed Properties
    
    var isAvailable: Bool {
        if case .available = self { return true }
        return false
    }
    
    var displayText: String {
        switch self {
        case .available:
            return "Available"
        case .unavailable(let reason):
            return reason
        case .connecting:
            return "Connecting..."
        case .rateLimited(let retryAfter):
            if let seconds = retryAfter {
                return "Rate limited (\(Int(seconds))s)"
            }
            return "Rate limited"
        }
    }
    
    var icon: String {
        switch self {
        case .available:
            return "checkmark.circle.fill"
        case .unavailable:
            return "xmark.circle.fill"
        case .connecting:
            return "arrow.triangle.2.circlepath"
        case .rateLimited:
            return "clock.fill"
        }
    }
    
    var color: String {
        switch self {
        case .available:
            return "green"
        case .unavailable:
            return "red"
        case .connecting:
            return "orange"
        case .rateLimited:
            return "yellow"
        }
    }
}

// MARK: - LLM Request

/// Request structure for LLM processing
struct LLMRequest {
    /// The text to process
    let text: String
    
    /// Processing mode to apply
    let mode: ProcessingMode
    
    /// Additional context for processing
    let context: TranscriptionContext
    
    /// Timeout for the request in seconds
    let timeout: TimeInterval
    
    init(
        text: String,
        mode: ProcessingMode,
        context: TranscriptionContext = .default,
        timeout: TimeInterval = 30.0
    ) {
        self.text = text
        self.mode = mode
        self.context = context
        self.timeout = timeout
    }
}

// MARK: - LLM Response

/// Response structure from LLM processing
struct LLMResponse {
    /// The processed text
    let processedText: String
    
    /// Processing time in seconds
    let processingTime: TimeInterval
    
    /// Number of tokens used (if available)
    let tokensUsed: Int?
    
    /// Which provider was used
    let providerUsed: String
    
    /// Model name that was used
    let modelUsed: String?
    
    init(
        processedText: String,
        processingTime: TimeInterval,
        tokensUsed: Int? = nil,
        providerUsed: String,
        modelUsed: String? = nil
    ) {
        self.processedText = processedText
        self.processingTime = processingTime
        self.tokensUsed = tokensUsed
        self.providerUsed = providerUsed
        self.modelUsed = modelUsed
    }
}

// MARK: - Cloud Provider Type

/// Enum for cloud provider selection
enum CloudProviderType: String, Codable, CaseIterable, Identifiable {
    case openAI = "openai"
    case openRouter = "openrouter"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .openAI: return "OpenAI"
        case .openRouter: return "OpenRouter"
        }
    }
    
    var description: String {
        switch self {
        case .openAI:
            return "Direct OpenAI API access. Requires API key."
        case .openRouter:
            return "Access multiple models via OpenRouter. Requires API key."
        }
    }
    
    var icon: String {
        switch self {
        case .openAI: return "brain"
        case .openRouter: return "arrow.triangle.branch"
        }
    }
    
    var baseURL: String {
        switch self {
        case .openAI:
            return "https://api.openai.com/v1"
        case .openRouter:
            return "https://openrouter.ai/api/v1"
        }
    }
    
    var defaultModel: String {
        switch self {
        case .openAI:
            return "gpt-4o-mini"
        case .openRouter:
            return "openai/gpt-4o-mini"
        }
    }
    
    var keychainAccount: String {
        switch self {
        case .openAI:
            return "openai-api-key"
        case .openRouter:
            return "openrouter-api-key"
        }
    }
}
