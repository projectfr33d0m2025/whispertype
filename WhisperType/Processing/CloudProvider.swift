//
//  CloudProvider.swift
//  WhisperType
//
//  Cloud LLM provider supporting OpenAI and OpenRouter APIs.
//  Both use compatible chat completion endpoints.
//

import Foundation

/// Cloud LLM provider for OpenAI and OpenRouter
final class CloudProvider: LLMProvider {
    
    // MARK: - LLMProvider Properties
    
    var id: String { providerType.rawValue }
    var displayName: String { providerType.displayName }
    let isLocal = false
    
    // MARK: - Configuration
    
    private var providerType: CloudProviderType
    private var model: String
    private var requestTimeout: TimeInterval = 30.0
    
    // MARK: - State
    
    private var currentTask: Task<LLMResponse, Error>?
    
    // MARK: - Dependencies
    
    private let keychainManager: KeychainManager
    
    // MARK: - URL Session
    
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = requestTimeout
        config.timeoutIntervalForResource = requestTimeout + 10
        return URLSession(configuration: config)
    }()
    
    // MARK: - Initialization
    
    init(
        providerType: CloudProviderType = .openAI,
        model: String? = nil,
        keychainManager: KeychainManager = .shared
    ) {
        self.providerType = providerType
        self.model = model ?? providerType.defaultModel
        self.keychainManager = keychainManager
        print("CloudProvider: Initialized for \(providerType.displayName), model: \(self.model)")
    }
    
    // MARK: - Configuration Updates
    
    func configure(providerType: CloudProviderType, model: String?) {
        self.providerType = providerType
        self.model = model ?? providerType.defaultModel
        print("CloudProvider: Reconfigured to \(providerType.displayName), model: \(self.model)")
    }
    
    // MARK: - API Key Access
    
    private var apiKey: String? {
        switch providerType {
        case .openAI:
            return keychainManager.getOpenAIKey()
        case .openRouter:
            return keychainManager.getOpenRouterKey()
        case .anthropic:
            return keychainManager.getAnthropicKey()
        }
    }
    
    private var hasAPIKey: Bool {
        apiKey != nil
    }
    
    // MARK: - LLMProvider Status
    
    var status: LLMProviderStatus {
        get async {
            guard hasAPIKey else {
                return .unavailable(reason: "API key not configured")
            }
            
            // For cloud providers, we assume available if key is set
            // Actual availability is checked during request
            return .available
        }
    }
    
    // MARK: - LLMProvider Process
    
    func process(_ request: LLMRequest) async throws -> LLMResponse {
        let startTime = Date()
        
        // Check API key
        guard let key = apiKey else {
            throw LLMError.invalidAPIKey
        }
        
        // Build the request
        let promptBuilder = PromptBuilder.shared
        let messages = promptBuilder.buildMessages(
            text: request.text,
            mode: request.mode,
            context: request.context
        )
        
        let url: URL
        var requestBody: [String: Any]
        
        // Construct basic request
        var urlRequest: URLRequest
        
        if providerType == .anthropic {
            // Anthropic Setup
            url = URL(string: "\(providerType.baseURL)/messages")!
            urlRequest = URLRequest(url: url)
            urlRequest.httpMethod = "POST"
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            urlRequest.setValue(key, forHTTPHeaderField: "x-api-key")
            urlRequest.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            
            // For Anthropic, system prompt must be separate if we were using it,
            // but promptBuilder currently puts everything in messages.
            // Anthropic accepts 'system' parameter but 'messages' is strictly user/assistant.
            // Ideally we separate system message, but for now we follow simple chat structure.
            // NOTE: Anthropic doesn't support 'system' role in 'messages'.
            // We need to filter out system messages or move them to top-level system param.
            
            var anthropicMessages = messages
            var systemPrompt: String? = nil
            
            if let first = messages.first, first["role"] as? String == "system" {
                systemPrompt = first["content"] as? String
                anthropicMessages.removeFirst()
            }
            
            requestBody = [
                "model": model,
                "messages": anthropicMessages,
                "max_tokens": 1024 // Anthropic requires max_tokens
            ]
            
            if let system = systemPrompt {
                requestBody["system"] = system
            }
            
        } else {
            // OpenAI / OpenRouter Setup
            url = URL(string: "\(providerType.baseURL)/chat/completions")!
            urlRequest = URLRequest(url: url)
            urlRequest.httpMethod = "POST"
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            urlRequest.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
            
            if providerType == .openRouter {
                urlRequest.setValue("WhisperType", forHTTPHeaderField: "X-Title")
                urlRequest.setValue("https://github.com/whispertype", forHTTPHeaderField: "HTTP-Referer")
            }
            
            requestBody = [
                "model": model,
                "messages": messages,
                "temperature": 0.1,
                "max_tokens": 500
            ]
        }
        
        urlRequest.timeoutInterval = request.timeout
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        print("CloudProvider: Sending request to \(providerType.displayName) (\(model))...")
        
        // Create task for cancellation support
        let task = Task<LLMResponse, Error> {
            let (data, response) = try await session.data(for: urlRequest)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw LLMError.processingFailed(reason: "Invalid response")
            }
            
            // Handle rate limiting
            if httpResponse.statusCode == 429 {
                let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After")
                    .flatMap { TimeInterval($0) }
                throw LLMError.rateLimited(retryAfter: retryAfter)
            }
            
            // Handle authentication errors
            if httpResponse.statusCode == 401 {
                throw LLMError.invalidAPIKey
            }
            
            // Handle other errors
            guard httpResponse.statusCode == 200 else {
                // Try to parse error message
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let error = json["error"] as? [String: Any],
                       let message = error["message"] as? String {
                        throw LLMError.processingFailed(reason: message)
                    }
                }
                throw LLMError.processingFailed(reason: "HTTP \(httpResponse.statusCode)")
            }
            
            // Parse successful response
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw LLMError.processingFailed(reason: "Invalid JSON response")
            }
            
            let content: String
            var tokens: Int?
            
            if self.providerType == .anthropic {
                // Parse Anthropic Response
                // Format: { "content": [ { "type": "text", "text": "..." } ], "usage": { "input_tokens": 10, "output_tokens": 20 } }
                guard let contentArray = json["content"] as? [[String: Any]],
                      let firstContent = contentArray.first,
                      let text = firstContent["text"] as? String else {
                    throw LLMError.processingFailed(reason: "Invalid Anthropic response format")
                }
                content = text
                
                if let usage = json["usage"] as? [String: Any],
                   let input = usage["input_tokens"] as? Int,
                   let output = usage["output_tokens"] as? Int {
                    tokens = input + output
                }
            } else {
                // Parse OpenAI/OpenRouter Response
                guard let choices = json["choices"] as? [[String: Any]],
                      let firstChoice = choices.first,
                      let message = firstChoice["message"] as? [String: Any],
                      let text = message["content"] as? String else {
                    throw LLMError.processingFailed(reason: "Invalid OpenAI response format")
                }
                content = text
                
                if let usage = json["usage"] as? [String: Any],
                   let total = usage["total_tokens"] as? Int {
                    tokens = total
                }
            }
            
            let processingTime = Date().timeIntervalSince(startTime)
            let cleanedResponse = content.trimmingCharacters(in: .whitespacesAndNewlines)
            
            print("CloudProvider: Response received in \(String(format: "%.2f", processingTime))s")
            
            return LLMResponse(
                processedText: cleanedResponse,
                processingTime: processingTime,
                tokensUsed: tokens,
                providerUsed: self.displayName,
                modelUsed: self.model
            )
        }
        
        currentTask = task
        
        do {
            let result = try await task.value
            currentTask = nil
            return result
        } catch {
            currentTask = nil
            
            if Task.isCancelled {
                throw LLMError.cancelled
            }
            
            if let urlError = error as? URLError {
                switch urlError.code {
                case .timedOut:
                    throw LLMError.timeout
                case .notConnectedToInternet, .networkConnectionLost:
                    throw LLMError.networkError(underlying: urlError)
                default:
                    throw LLMError.networkError(underlying: urlError)
                }
            }
            
            throw error
        }
    }
    
    // MARK: - Cancel
    
    func cancel() {
        print("CloudProvider: Cancelling current request")
        currentTask?.cancel()
        currentTask = nil
    }
}
