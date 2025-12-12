//
//  KeychainManager.swift
//  WhisperType
//
//  Secure storage for API keys using macOS Keychain.
//

import Foundation
import Security

/// Manages secure storage of API keys in macOS Keychain
class KeychainManager {
    
    // MARK: - Singleton
    
    static let shared = KeychainManager()
    
    // MARK: - Constants
    
    private let serviceName = "com.whispertype.app"
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Public API
    
    /// Save an API key to the keychain
    /// - Parameters:
    ///   - key: The API key to save
    ///   - account: The account identifier (e.g., "openai-api-key")
    /// - Returns: True if successful
    @discardableResult
    func saveAPIKey(_ key: String, for account: String) -> Bool {
        // Delete existing key first
        deleteAPIKey(for: account)
        
        guard let data = key.data(using: .utf8) else {
            print("KeychainManager: Failed to encode key for \(account)")
            return false
        }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status == errSecSuccess {
            print("KeychainManager: Saved API key for \(account)")
            return true
        } else {
            print("KeychainManager: Failed to save key for \(account), status: \(status)")
            return false
        }
    }
    
    /// Retrieve an API key from the keychain
    /// - Parameter account: The account identifier
    /// - Returns: The API key if found
    func getAPIKey(for account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess,
           let data = result as? Data,
           let key = String(data: data, encoding: .utf8) {
            return key
        }
        
        return nil
    }
    
    /// Delete an API key from the keychain
    /// - Parameter account: The account identifier
    /// - Returns: True if successful or key didn't exist
    @discardableResult
    func deleteAPIKey(for account: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        if status == errSecSuccess || status == errSecItemNotFound {
            print("KeychainManager: Deleted API key for \(account)")
            return true
        } else {
            print("KeychainManager: Failed to delete key for \(account), status: \(status)")
            return false
        }
    }
    
    /// Check if an API key exists
    /// - Parameter account: The account identifier
    /// - Returns: True if the key exists
    func hasAPIKey(for account: String) -> Bool {
        getAPIKey(for: account) != nil
    }
    
    /// Get a masked version of the API key for display
    /// - Parameter account: The account identifier
    /// - Returns: Masked key (e.g., "sk-...abc123") or nil
    func getMaskedAPIKey(for account: String) -> String? {
        guard let key = getAPIKey(for: account), key.count > 8 else {
            return nil
        }
        
        let prefix = String(key.prefix(3))
        let suffix = String(key.suffix(6))
        return "\(prefix)...\(suffix)"
    }
}

// MARK: - Convenience Extensions for Cloud Providers

extension KeychainManager {
    
    /// Save OpenAI API key
    @discardableResult
    func saveOpenAIKey(_ key: String) -> Bool {
        saveAPIKey(key, for: CloudProviderType.openAI.keychainAccount)
    }
    
    /// Get OpenAI API key
    func getOpenAIKey() -> String? {
        getAPIKey(for: CloudProviderType.openAI.keychainAccount)
    }
    
    /// Check if OpenAI key exists
    var hasOpenAIKey: Bool {
        hasAPIKey(for: CloudProviderType.openAI.keychainAccount)
    }
    
    /// Save OpenRouter API key
    @discardableResult
    func saveOpenRouterKey(_ key: String) -> Bool {
        saveAPIKey(key, for: CloudProviderType.openRouter.keychainAccount)
    }
    
    /// Get OpenRouter API key
    func getOpenRouterKey() -> String? {
        getAPIKey(for: CloudProviderType.openRouter.keychainAccount)
    }
    
    /// Check if OpenRouter key exists
    var hasOpenRouterKey: Bool {
        hasAPIKey(for: CloudProviderType.openRouter.keychainAccount)
    }
}
