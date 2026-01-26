//
//  LLMEngine.swift
//  WhisperType
//
//  Main LLM engine that orchestrates provider selection and fallback.
//

import Foundation
import Combine

/// Main LLM engine that orchestrates providers based on user preference
final class LLMEngine: LLMEngineProtocol, ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = LLMEngine()
    
    // MARK: - Published Properties
    
    @Published private(set) var currentStatus: LLMEngineStatus = .unavailable(reason: "Not initialized")
    @Published private(set) var lastProviderUsed: String?
    @Published private(set) var isProcessing = false
    
    // MARK: - Providers
    
    private var ollamaProvider: OllamaProvider
    private var cloudProvider: CloudProvider
    
    // MARK: - Settings Reference
    
    private var settings: AppSettings { AppSettings.shared }
    
    // MARK: - Initialization
    
    private init() {
        // Initialize providers with settings
        self.ollamaProvider = OllamaProvider(
            host: AppSettings.shared.ollamaHost,
            port: AppSettings.shared.ollamaPort,
            model: AppSettings.shared.ollamaModel
        )
        
        self.cloudProvider = CloudProvider(
            providerType: AppSettings.shared.cloudProviderType,
            model: AppSettings.shared.cloudModel
        )
        
        print("LLMEngine: Initialized")
        
        // Initial status check
        Task {
            await refreshStatus()
        }
    }
    
    // MARK: - Configuration
    
    /// Reconfigure the engine with current settings
    func reconfigure() {
        ollamaProvider.configure(
            host: settings.ollamaHost,
            port: settings.ollamaPort,
            model: settings.ollamaModel
        )
        
        cloudProvider.configure(
            providerType: settings.cloudProviderType,
            model: settings.cloudModel
        )
        
        print("LLMEngine: Reconfigured with current settings")
        
        Task {
            await refreshStatus()
        }
    }
    
    // MARK: - Status
    
    var status: LLMEngineStatus {
        get async {
            await refreshStatus()
            return currentStatus
        }
    }
    
    /// Refresh and return current status
    @MainActor
    @discardableResult
    func refreshStatus() async -> LLMEngineStatus {
        let preference = settings.llmPreference
        
        // If disabled, always unavailable
        if preference == .disabled {
            currentStatus = .unavailable(reason: "AI enhancement disabled")
            return currentStatus
        }
        
        // Check providers based on preference
        let localStatus = await ollamaProvider.status
        let cloudStatus = await cloudProvider.status
        
        switch preference {
        case .localOnly:
            if localStatus.isAvailable {
                currentStatus = .available(provider: ollamaProvider.displayName)
            } else {
                currentStatus = .unavailable(reason: "Ollama not available")
            }
            
        case .localFirst:
            if localStatus.isAvailable {
                currentStatus = .available(provider: ollamaProvider.displayName)
            } else if cloudStatus.isAvailable {
                currentStatus = .available(provider: "\(cloudProvider.displayName) (fallback)")
            } else {
                currentStatus = .unavailable(reason: "No providers available")
            }
            
        case .cloudFirst:
            if cloudStatus.isAvailable {
                currentStatus = .available(provider: cloudProvider.displayName)
            } else if localStatus.isAvailable {
                currentStatus = .available(provider: "\(ollamaProvider.displayName) (fallback)")
            } else {
                currentStatus = .unavailable(reason: "No providers available")
            }
            
        case .cloudOnly:
            if cloudStatus.isAvailable {
                currentStatus = .available(provider: cloudProvider.displayName)
            } else {
                currentStatus = .unavailable(reason: "Cloud API not configured")
            }
            
        case .disabled:
            currentStatus = .unavailable(reason: "AI enhancement disabled")
        }
        
        return currentStatus
    }
    
    /// Get status for a specific preference (used by MeetingSummarizer)
    func statusFor(preference: LLMPreference) async -> LLMEngineStatus {
        // If disabled, always unavailable
        if preference == .disabled {
            return .unavailable(reason: "AI enhancement disabled")
        }
        
        // Check providers based on preference
        let localStatus = await ollamaProvider.status
        let cloudStatus = await cloudProvider.status
        
        switch preference {
        case .localOnly:
            if localStatus.isAvailable {
                return .available(provider: ollamaProvider.displayName)
            } else {
                return .unavailable(reason: "Ollama not available")
            }
            
        case .localFirst:
            if localStatus.isAvailable {
                return .available(provider: ollamaProvider.displayName)
            } else if cloudStatus.isAvailable {
                return .available(provider: "\(cloudProvider.displayName) (fallback)")
            } else {
                return .unavailable(reason: "No providers available")
            }
            
        case .cloudFirst:
            if cloudStatus.isAvailable {
                return .available(provider: cloudProvider.displayName)
            } else if localStatus.isAvailable {
                return .available(provider: "\(ollamaProvider.displayName) (fallback)")
            } else {
                return .unavailable(reason: "No providers available")
            }
            
        case .cloudOnly:
            if cloudStatus.isAvailable {
                return .available(provider: cloudProvider.displayName)
            } else {
                return .unavailable(reason: "Cloud API not configured")
            }
            
        case .disabled:
            return .unavailable(reason: "AI enhancement disabled")
        }
    }
    
    // MARK: - Processing
    
    func process(
        _ text: String,
        mode: ProcessingMode,
        context: TranscriptionContext,
        preferenceOverride: LLMPreference? = nil
    ) async throws -> String {
        let preference = preferenceOverride ?? settings.llmPreference
        
        // Check if LLM is enabled
        guard preference.isEnabled else {
            throw LLMError.notAvailable
        }
        
        // Update status
        await MainActor.run {
            isProcessing = true
            currentStatus = .processing
        }
        
        defer {
            Task { @MainActor in
                isProcessing = false
                _ = await refreshStatus()
            }
        }
        
        // Build request
        let request = LLMRequest(
            text: text,
            mode: mode,
            context: context,
            timeout: preference.usesLocal ? 60.0 : 30.0
        )
        
        // Get provider order based on preference
        let providers = getProviderOrder(for: preference)
        
        var lastError: Error?
        
        // Try each provider in order
        for provider in providers {
            let providerStatus = await provider.status
            
            guard providerStatus.isAvailable else {
                print("LLMEngine: Skipping \(provider.displayName) - not available")
                continue
            }
            
            do {
                print("LLMEngine: Trying \(provider.displayName)...")
                let response = try await provider.process(request)
                
                await MainActor.run {
                    lastProviderUsed = provider.displayName
                }
                
                print("LLMEngine: Success with \(provider.displayName)")
                return response.processedText
                
            } catch let error as LLMError {
                print("LLMEngine: \(provider.displayName) failed - \(error.localizedDescription ?? "Unknown")")
                lastError = error
                
                // Don't retry on certain errors
                switch error {
                case .cancelled:
                    throw error
                case .invalidAPIKey:
                    print("LLMEngine: Invalid API key for \(provider.displayName)")
                    // Skip to next provider
                    continue
                case .rateLimited(let retryAfter):
                    print("LLMEngine: Rate limited by \(provider.displayName). Retry after: \(retryAfter ?? 0)s")
                    // Notify user about rate limiting (will be caught by PostProcessor)
                    // Skip to next provider
                    continue
                default:
                    continue
                }
                
            } catch {
                print("LLMEngine: \(provider.displayName) failed - \(error.localizedDescription)")
                lastError = error
            }
        }
        
        // All providers failed
        if let error = lastError {
            throw error
        }
        throw LLMError.notAvailable
    }
    
    private func getProviderOrder(for preference: LLMPreference) -> [LLMProvider] {
        switch preference {
        case .localOnly:
            return [ollamaProvider]
        case .localFirst:
            return [ollamaProvider, cloudProvider]
        case .cloudFirst:
            return [cloudProvider, ollamaProvider]
        case .cloudOnly:
            return [cloudProvider]
        case .disabled:
            return []
        }
    }
    
    // MARK: - Cancel
    
    func cancel() {
        print("LLMEngine: Cancelling all providers")
        ollamaProvider.cancel()
        cloudProvider.cancel()
    }
    
    // MARK: - Provider Access (for UI)
    
    /// Get Ollama provider status
    func getOllamaStatus() async -> LLMProviderStatus {
        await ollamaProvider.status
    }
    
    /// Get cloud provider status
    func getCloudStatus() async -> LLMProviderStatus {
        await cloudProvider.status
    }
    
    /// Force refresh Ollama status
    func refreshOllamaStatus() async -> LLMProviderStatus {
        await ollamaProvider.refreshStatus()
    }
}
