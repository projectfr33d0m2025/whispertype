//
//  StubLLMEngine.swift
//  WhisperType
//
//  Stub implementation of LLMEngineProtocol for Phase 1.
//  Always returns .unavailable status and throws .notAvailable on process().
//  Will be replaced by real LLMEngine in Phase 2.
//

import Foundation

/// Stub LLM engine that always reports unavailable.
/// Used in Phase 1 before real LLM integration is implemented.
final class StubLLMEngine: LLMEngineProtocol {
    
    // MARK: - Singleton
    
    static let shared = StubLLMEngine()
    
    // MARK: - Properties
    
    private let unavailableReason = "AI enhancement not configured"
    
    // MARK: - Initialization
    
    private init() {
        print("StubLLMEngine: Initialized (AI enhancement not available)")
    }
    
    // MARK: - LLMEngineProtocol
    
    var status: LLMEngineStatus {
        get async {
            .unavailable(reason: unavailableReason)
        }
    }
    
    func process(
        _ text: String,
        mode: ProcessingMode,
        context: TranscriptionContext
    ) async throws -> String {
        print("StubLLMEngine: process() called but LLM not available")
        throw LLMError.notAvailable
    }
    
    func cancel() {
        // No-op for stub
        print("StubLLMEngine: cancel() called (no-op)")
    }
}
