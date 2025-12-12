//
//  PostProcessor.swift
//  WhisperType
//
//  Orchestrates the text processing pipeline.
//  Chains FillerRemover, FormattingRules, VocabularyCorrector, and LLM enhancement based on mode.
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
    private let vocabularyCorrector: VocabularyCorrector
    private var llmEngine: LLMEngineProtocol
    
    // MARK: - Settings Reference
    
    private var settings: AppSettings { AppSettings.shared }
    
    // MARK: - Initialization
    
    init(
        fillerRemover: FillerRemover = .shared,
        formattingRules: FormattingRules = .shared,
        vocabularyCorrector: VocabularyCorrector = .shared,
        llmEngine: LLMEngineProtocol = LLMEngine.shared
    ) {
        self.fillerRemover = fillerRemover
        self.formattingRules = formattingRules
        self.vocabularyCorrector = vocabularyCorrector
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
    @MainActor
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
        var wasRateLimited = false
        var provider: String? = nil
        var vocabularyCorrections: [VocabularyCorrection] = []
        
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
        
        // Step 2: Vocabulary correction (all modes except raw, before formatting)
        let vocabulary = VocabularyManager.shared.getAllForCorrection()
        if !vocabulary.isEmpty {
            let beforeVocab = processedText
            let correctionResult = vocabularyCorrector.correct(processedText, vocabulary: vocabulary)
            processedText = correctionResult.text
            vocabularyCorrections = correctionResult.corrections
            
            if correctionResult.hadCorrections {
                print("PostProcessor: Vocabulary correction made \(correctionResult.correctionCount) corrections:")
                print("  Before: \"\(beforeVocab)\"")
                print("  After:  \"\(processedText)\"")
                for correction in correctionResult.corrections {
                    print("    - '\(correction.original)' → '\(correction.corrected)' (\(correction.matchType.description))")
                    // Increment usage count for matched terms
                    VocabularyManager.shared.incrementUsage(correction.term)
                }
            } else {
                print("PostProcessor: Vocabulary correction - no matches found")
            }
        } else {
            print("PostProcessor: Vocabulary correction skipped (no vocabulary entries)")
        }
        
        // Step 3: Formatting rules (formatted and above)
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
        
        // Step 4: LLM enhancement (polished and professional only)
        if mode.requiresLLM {
            // Inject vocabulary terms into LLM prompt
            let llmVocabulary = VocabularyManager.shared.getLLMVocabulary()
            PromptBuilder.shared.setVocabularyTerms(llmVocabulary)
            
            // Check if LLM is available
            let llmStatus = await llmEngine.status
            
            if llmStatus.isAvailable {
                do {
                    processedText = try await llmEngine.process(processedText, mode: mode, context: context)
                    if case .available(let providerName) = llmStatus {
                        provider = providerName
                    }
                    print("PostProcessor: LLM enhancement complete")
                } catch let error as LLMError {
                    // LLM failed, fall back to formatted mode
                    print("PostProcessor: LLM enhancement failed (\(error.localizedDescription ?? "Unknown")), using fallback")
                    actualMode = mode.fallbackMode
                    usedFallback = true
                    
                    // Check if it was rate limited
                    if case .rateLimited = error {
                        wasRateLimited = true
                        print("PostProcessor: Rate limited, falling back")
                    }
                } catch {
                    // Other error, fall back
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
            provider: provider,
            wasRateLimited: wasRateLimited,
            vocabularyCorrections: vocabularyCorrections
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
