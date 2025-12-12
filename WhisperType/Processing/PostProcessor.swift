//
//  PostProcessor.swift
//  WhisperType
//
//  Orchestrates the text processing pipeline.
//  Chains FillerRemover, FormattingRules, and LLM enhancement based on mode.
//

import Foundation

/// Orchestrates text processing through the enhancement pipeline.
/// Handles fallback when LLM is unavailable.
class PostProcessor {
    
    // MARK: - Singleton
    
    static let shared = PostProcessor()
    
    // MARK: - Dependencies
    
    private let fillerRemover: FillerRemover
    private let formattingRules: FormattingRules
    private var llmEngine: LLMEngineProtocol
    
    // MARK: - Settings Reference
    
    private var settings: AppSettings { AppSettings.shared }
    
    // MARK: - Initialization
    
    init(
        fillerRemover: FillerRemover = .shared,
        formattingRules: FormattingRules = .shared,
        llmEngine: LLMEngineProtocol = StubLLMEngine.shared
    ) {
        self.fillerRemover = fillerRemover
        self.formattingRules = formattingRules
        self.llmEngine = llmEngine
        
        print("PostProcessor: Initialized with LLM engine: \(type(of: llmEngine))")
    }
    
    // MARK: - Configuration
    
    /// Update the LLM engine (called when Phase 2 is implemented)
    func setLLMEngine(_ engine: LLMEngineProtocol) {
        self.llmEngine = engine
        print("PostProcessor: LLM engine updated to \(type(of: engine))")
    }
    
    // MARK: - Public API
    
    /// Process text according to the specified mode
    /// - Parameters:
    ///   - text: Raw transcription text
    ///   - mode: Processing mode to apply
    ///   - context: Additional context for LLM processing
    /// - Returns: ProcessingResult with processed text and metadata
    func process(
        _ text: String,
        mode: ProcessingMode,
        context: TranscriptionContext = .default
    ) async -> ProcessingResult {
        let startTime = Date()
        
        print("PostProcessor: Processing text (\(text.count) chars) with mode: \(mode.displayName)")
        
        // Handle raw mode - no processing
        if mode == .raw {
            print("PostProcessor: Raw mode - returning unchanged text")
            return ProcessingResult(
                text: text,
                modeUsed: .raw,
                usedFallback: false,
                processingTime: Date().timeIntervalSince(startTime),
                provider: nil
            )
        }
        
        // Apply basic processing chain
        var processedText = text
        var actualMode = mode
        var usedFallback = false
        var provider: String? = nil
        
        // Step 1: Filler removal (all modes except raw)
        if mode.removesFiller && settings.fillerRemovalEnabled {
            let beforeFiller = processedText
            processedText = fillerRemover.remove(processedText)
            if beforeFiller != processedText {
                print("PostProcessor: Filler removal changed text:")
                print("  Before: \"\(beforeFiller)\"")
                print("  After:  \"\(processedText)\"")
            } else {
                print("PostProcessor: Filler removal - no fillers found")
            }
        } else {
            print("PostProcessor: Filler removal skipped (mode: \(mode.removesFiller), enabled: \(settings.fillerRemovalEnabled))")
        }
        
        // Step 2: Formatting rules (formatted and above)
        if mode.appliesFormatting {
            let beforeFormat = processedText
            processedText = formattingRules.apply(processedText)
            if beforeFormat != processedText {
                print("PostProcessor: Formatting rules changed text:")
                print("  Before: \"\(beforeFormat)\"")
                print("  After:  \"\(processedText)\"")
            } else {
                print("PostProcessor: Formatting rules - no changes needed")
            }
        } else {
            print("PostProcessor: Formatting rules skipped (mode doesn't apply formatting)")
        }
        
        // Step 3: LLM enhancement (polished and professional only)
        if mode.requiresLLM {
            // Check if LLM is available
            let llmStatus = await llmEngine.status
            
            if llmStatus.isAvailable {
                do {
                    processedText = try await llmEngine.process(processedText, mode: mode, context: context)
                    if case .available(let providerName) = llmStatus {
                        provider = providerName
                    }
                    print("PostProcessor: LLM enhancement complete")
                } catch {
                    // LLM failed, fall back to formatted mode
                    print("PostProcessor: LLM enhancement failed (\(error.localizedDescription)), using fallback")
                    actualMode = mode.fallbackMode
                    usedFallback = true
                }
            } else {
                // LLM not available, use fallback mode
                print("PostProcessor: LLM not available, using fallback mode: \(mode.fallbackMode.displayName)")
                actualMode = mode.fallbackMode
                usedFallback = true
            }
        }
        
        let processingTime = Date().timeIntervalSince(startTime)
        print("PostProcessor: Complete in \(String(format: "%.3f", processingTime))s")
        
        return ProcessingResult(
            text: processedText,
            modeUsed: actualMode,
            usedFallback: usedFallback,
            processingTime: processingTime,
            provider: provider
        )
    }
    
    /// Quick check if LLM is currently available
    var isLLMAvailable: Bool {
        get async {
            let status = await llmEngine.status
            return status.isAvailable
        }
    }
    
    /// Get current LLM status
    var llmStatus: LLMEngineStatus {
        get async {
            await llmEngine.status
        }
    }
}
