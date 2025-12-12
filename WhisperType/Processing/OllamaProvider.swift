//
//  OllamaProvider.swift
//  WhisperType
//
//  Ollama LLM provider for local, privacy-preserving text enhancement.
//  Communicates with Ollama via HTTP API at localhost.
//

import Foundation

/// Ollama LLM provider for local processing
final class OllamaProvider: LLMProvider {
    
    // MARK: - LLMProvider Properties
    
    let id = "ollama"
    let displayName = "Ollama (Local)"
    let isLocal = true
    
    // MARK: - Configuration
    
    private var host: String
    private var port: Int
    private var model: String
    private var connectionTimeout: TimeInterval = 5.0
    private var requestTimeout: TimeInterval = 60.0
    
    // MARK: - State
    
    private var currentTask: Task<LLMResponse, Error>?
    private var cachedStatus: LLMProviderStatus?
    private var statusCacheTime: Date?
    private let statusCacheDuration: TimeInterval = 30.0
    
    // MARK: - URL Session
    
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = requestTimeout
        config.timeoutIntervalForResource = requestTimeout + 10
        return URLSession(configuration: config)
    }()
    
    // MARK: - Initialization
    
    init(host: String = "localhost", port: Int = 11434, model: String = "llama3.2:3b") {
        self.host = host
        self.port = port
        self.model = model
        print("OllamaProvider: Initialized with \(host):\(port), model: \(model)")
    }
    
    // MARK: - Configuration Updates
    
    func configure(host: String, port: Int, model: String) {
        self.host = host
        self.port = port
        self.model = model
        // Invalidate cache when configuration changes
        self.cachedStatus = nil
        self.statusCacheTime = nil
        print("OllamaProvider: Reconfigured to \(host):\(port), model: \(model)")
    }
    
    // MARK: - Base URL
    
    private var baseURL: URL {
        URL(string: "http://\(host):\(port)")!
    }
    
    // MARK: - LLMProvider Status
    
    var status: LLMProviderStatus {
        get async {
            // Return cached status if still valid
            if let cached = cachedStatus,
               let cacheTime = statusCacheTime,
               Date().timeIntervalSince(cacheTime) < statusCacheDuration {
                return cached
            }
            
            // Check connection
            let newStatus = await checkConnection()
            cachedStatus = newStatus
            statusCacheTime = Date()
            return newStatus
        }
    }
    
    private func checkConnection() async -> LLMProviderStatus {
        let url = baseURL.appendingPathComponent("api/tags")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = connectionTimeout
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                return .unavailable(reason: "Invalid response")
            }
            
            guard httpResponse.statusCode == 200 else {
                return .unavailable(reason: "HTTP \(httpResponse.statusCode)")
            }
            
            // Parse response to check if our model is available
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let models = json["models"] as? [[String: Any]] {
                let modelNames = models.compactMap { $0["name"] as? String }
                
                if modelNames.contains(where: { $0.hasPrefix(model.split(separator: ":").first ?? "") }) {
                    print("OllamaProvider: Connected, model '\(model)' available")
                    return .available
                } else {
                    print("OllamaProvider: Connected but model '\(model)' not found. Available: \(modelNames)")
                    return .unavailable(reason: "Model '\(model)' not installed")
                }
            }
            
            // Connected but couldn't parse models - assume available
            print("OllamaProvider: Connected (couldn't verify model)")
            return .available
            
        } catch let error as URLError {
            switch error.code {
            case .cannotConnectToHost, .timedOut:
                print("OllamaProvider: Cannot connect - \(error.localizedDescription)")
                return .unavailable(reason: "Ollama not running")
            default:
                print("OllamaProvider: Connection error - \(error.localizedDescription)")
                return .unavailable(reason: error.localizedDescription)
            }
        } catch {
            print("OllamaProvider: Error - \(error.localizedDescription)")
            return .unavailable(reason: error.localizedDescription)
        }
    }
    
    /// Force refresh the status cache
    func refreshStatus() async -> LLMProviderStatus {
        cachedStatus = nil
        statusCacheTime = nil
        return await status
    }
    
    // MARK: - LLMProvider Process
    
    func process(_ request: LLMRequest) async throws -> LLMResponse {
        let startTime = Date()
        
        // Check status first
        let currentStatus = await status
        guard currentStatus.isAvailable else {
            if case .unavailable(let reason) = currentStatus {
                throw LLMError.processingFailed(reason: reason)
            }
            throw LLMError.notAvailable
        }
        
        // Build the prompt
        let promptBuilder = PromptBuilder.shared
        let prompt = promptBuilder.buildSinglePrompt(
            text: request.text,
            mode: request.mode,
            context: request.context
        )
        
        // Create the request
        let url = baseURL.appendingPathComponent("api/generate")
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = request.timeout
        
        // Build request body
        let requestBody: [String: Any] = [
            "model": model,
            "prompt": prompt,
            "stream": false,
            "options": [
                "temperature": 0.1,
                "top_p": 0.9,
                "num_predict": 500
            ]
        ]
        
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        print("OllamaProvider: Sending request to \(model)...")
        
        // Create task for cancellation support
        let task = Task<LLMResponse, Error> {
            let (data, response) = try await session.data(for: urlRequest)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw LLMError.processingFailed(reason: "Invalid response")
            }
            
            guard httpResponse.statusCode == 200 else {
                throw LLMError.processingFailed(reason: "HTTP \(httpResponse.statusCode)")
            }
            
            // Parse response
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let responseText = json["response"] as? String else {
                throw LLMError.processingFailed(reason: "Invalid response format")
            }
            
            let processingTime = Date().timeIntervalSince(startTime)
            let cleanedResponse = responseText.trimmingCharacters(in: .whitespacesAndNewlines)
            
            print("OllamaProvider: Response received in \(String(format: "%.2f", processingTime))s")
            
            return LLMResponse(
                processedText: cleanedResponse,
                processingTime: processingTime,
                tokensUsed: json["eval_count"] as? Int,
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
            
            if let urlError = error as? URLError, urlError.code == .timedOut {
                throw LLMError.timeout
            }
            
            throw error
        }
    }
    
    // MARK: - Cancel
    
    func cancel() {
        print("OllamaProvider: Cancelling current request")
        currentTask?.cancel()
        currentTask = nil
    }
}
