//
//  OllamaModelManager.swift
//  WhisperType
//
//  Manages Ollama model detection and recommendations.
//

import Foundation

/// Information about an Ollama model
struct OllamaModelInfo: Identifiable, Equatable {
    let id: String
    let name: String
    let size: Int64?
    let modifiedAt: Date?
    
    /// Speed rating (1-5, 5 being fastest)
    var speedRating: Int {
        OllamaModelManager.knownModelRatings[baseModelName]?.speed ?? 3
    }
    
    /// Quality rating (1-5, 5 being highest quality)
    var qualityRating: Int {
        OllamaModelManager.knownModelRatings[baseModelName]?.quality ?? 3
    }
    
    /// Estimated RAM required
    var estimatedRAM: String {
        OllamaModelManager.knownModelRatings[baseModelName]?.ram ?? "Unknown"
    }
    
    /// Base model name (without tag)
    var baseModelName: String {
        String(name.split(separator: ":").first ?? Substring(name))
    }
    
    /// Display name with ratings
    var displayName: String {
        let speedStars = String(repeating: "⚡", count: speedRating)
        let qualityStars = String(repeating: "★", count: qualityRating)
        return "\(name) - Speed: \(speedStars) Quality: \(qualityStars)"
    }
    
    /// Formatted size string
    var sizeString: String {
        guard let size = size else { return "Unknown size" }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}

/// Model rating information
struct ModelRating {
    let speed: Int      // 1-5
    let quality: Int    // 1-5
    let ram: String     // e.g., "4GB"
}

/// Manages Ollama model detection and recommendations
class OllamaModelManager: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = OllamaModelManager()
    
    // MARK: - Published Properties
    
    @Published var installedModels: [OllamaModelInfo] = []
    @Published var isLoading = false
    @Published var lastError: String?
    
    // MARK: - Configuration
    
    private var host: String = "localhost"
    private var port: Int = 11434
    
    // MARK: - Known Model Ratings
    
    static let knownModelRatings: [String: ModelRating] = [
        "llama3.2": ModelRating(speed: 4, quality: 3, ram: "4GB"),
        "llama3.1": ModelRating(speed: 3, quality: 4, ram: "8GB"),
        "llama3": ModelRating(speed: 3, quality: 4, ram: "8GB"),
        "mistral": ModelRating(speed: 3, quality: 4, ram: "8GB"),
        "phi3": ModelRating(speed: 4, quality: 3, ram: "4GB"),
        "phi": ModelRating(speed: 4, quality: 3, ram: "4GB"),
        "gemma2": ModelRating(speed: 4, quality: 3, ram: "4GB"),
        "gemma": ModelRating(speed: 4, quality: 3, ram: "4GB"),
        "qwen2.5": ModelRating(speed: 4, quality: 4, ram: "4GB"),
        "qwen2": ModelRating(speed: 4, quality: 3, ram: "4GB"),
        "deepseek-r1": ModelRating(speed: 2, quality: 5, ram: "16GB"),
    ]
    
    /// Recommended model for WhisperType
    static let recommendedModel = "llama3.2:3b"
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Configuration
    
    func configure(host: String, port: Int) {
        self.host = host
        self.port = port
        print("OllamaModelManager: Configured to \(host):\(port)")
    }
    
    // MARK: - Model Detection
    
    /// Detect installed Ollama models
    @MainActor
    func detectInstalledModels() async {
        isLoading = true
        lastError = nil
        
        let url = URL(string: "http://\(host):\(port)/api/tags")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 5.0
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                lastError = "Failed to connect to Ollama"
                installedModels = []
                isLoading = false
                return
            }
            
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let models = json["models"] as? [[String: Any]] else {
                lastError = "Invalid response from Ollama"
                installedModels = []
                isLoading = false
                return
            }
            
            installedModels = models.compactMap { modelDict -> OllamaModelInfo? in
                guard let name = modelDict["name"] as? String else { return nil }
                
                let size = modelDict["size"] as? Int64
                var modifiedAt: Date?
                if let dateString = modelDict["modified_at"] as? String {
                    let formatter = ISO8601DateFormatter()
                    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    modifiedAt = formatter.date(from: dateString)
                }
                
                return OllamaModelInfo(
                    id: name,
                    name: name,
                    size: size,
                    modifiedAt: modifiedAt
                )
            }
            
            print("OllamaModelManager: Found \(installedModels.count) models")
            isLoading = false
            
        } catch {
            print("OllamaModelManager: Error detecting models - \(error.localizedDescription)")
            lastError = error.localizedDescription
            installedModels = []
            isLoading = false
        }
    }
    
    // MARK: - Model Recommendation
    
    /// Get the recommended model from installed models
    func recommendModel() -> OllamaModelInfo? {
        // Priority 1: llama3.2:3b if installed
        if let recommended = installedModels.first(where: { $0.name == Self.recommendedModel }) {
            return recommended
        }
        
        // Priority 2: Any llama3.2 variant
        if let llama32 = installedModels.first(where: { $0.name.hasPrefix("llama3.2") }) {
            return llama32
        }
        
        // Priority 3: Any 3B model with speed >= 4
        let fastModels = installedModels.filter { $0.speedRating >= 4 }
        if let fast = fastModels.first {
            return fast
        }
        
        // Priority 4: Any 7-8B model
        if let medium = installedModels.first(where: { 
            $0.name.contains("7b") || $0.name.contains("8b") 
        }) {
            return medium
        }
        
        // Priority 5: First available
        return installedModels.first
    }
    
    /// Check if the recommended model is installed
    var hasRecommendedModel: Bool {
        installedModels.contains { $0.name == Self.recommendedModel }
    }
    
    /// Check if any models are installed
    var hasModels: Bool {
        !installedModels.isEmpty
    }
}
