//
//  WhisperWrapper.swift
//  WhisperType
//
//  Swift wrapper for whisper.cpp providing transcription functionality.
//  Uses a Swift actor for thread safety as whisper.cpp context must not be accessed
//  from multiple threads simultaneously.
//

import Foundation

// MARK: - Whisper Errors

enum WhisperError: LocalizedError {
    case contextNotInitialized
    case modelLoadFailed(path: String)
    case transcriptionFailed(reason: String)
    case invalidAudioData
    case noSegments
    
    var errorDescription: String? {
        switch self {
        case .contextNotInitialized:
            return "Whisper context is not initialized. Please load a model first."
        case .modelLoadFailed(let path):
            return "Failed to load Whisper model from: \(path)"
        case .transcriptionFailed(let reason):
            return "Transcription failed: \(reason)"
        case .invalidAudioData:
            return "Invalid audio data provided for transcription."
        case .noSegments:
            return "No transcription segments were produced."
        }
    }
}

// MARK: - Transcription Result

struct TranscriptionSegment: Identifiable {
    let id = UUID()
    let text: String
    let startTime: Int64  // milliseconds
    let endTime: Int64    // milliseconds
    
    var formattedTimeRange: String {
        let startSec = Double(startTime) / 1000.0
        let endSec = Double(endTime) / 1000.0
        return String(format: "%.2f - %.2f", startSec, endSec)
    }
}

// MARK: - Whisper Context Actor

/// Thread-safe Whisper context wrapper using Swift actor.
/// whisper.cpp requires that the context is not accessed from multiple threads simultaneously.
actor WhisperContext {
    
    private var context: OpaquePointer?
    private let modelPath: String
    
    // MARK: - Initialization
    
    init(modelPath: String) throws {
        self.modelPath = modelPath
        
        // Configure context parameters
        var params = whisper_context_default_params()
        params.use_gpu = true  // Enable Metal GPU acceleration
        params.flash_attn = true  // Enable flash attention for better performance
        
        // Load the model
        guard let ctx = whisper_init_from_file_with_params(modelPath, params) else {
            throw WhisperError.modelLoadFailed(path: modelPath)
        }
        
        self.context = ctx
        print("WhisperContext: Loaded model from \(modelPath)")
    }
    
    deinit {
        if let ctx = context {
            whisper_free(ctx)
            print("WhisperContext: Freed context")
        }
    }
    
    // MARK: - Transcription
    
    /// Transcribe audio samples to text
    /// - Parameters:
    ///   - samples: Float32 audio samples at 16kHz mono
    ///   - language: Language code (e.g., "en", nil for auto-detect)
    ///   - vocabulary: Optional vocabulary words for initial prompt
    ///   - verbatimMode: If true, attempts to preserve filler words and speech patterns
    /// - Returns: Array of transcription segments
    func transcribe(
        samples: [Float],
        language: String? = "en",
        vocabulary: [String] = [],
        verbatimMode: Bool = false
    ) throws -> [TranscriptionSegment] {
        guard let ctx = context else {
            throw WhisperError.contextNotInitialized
        }
        
        guard !samples.isEmpty else {
            throw WhisperError.invalidAudioData
        }
        
        // Calculate optimal thread count
        let threadCount = Self.optimalThreadCount()
        print("WhisperContext: Transcribing \(samples.count) samples with \(threadCount) threads, verbatim: \(verbatimMode)")

        // Configure transcription parameters
        var params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY)
        
        // Build initial prompt from vocabulary words
        // For verbatim mode, add a prompt that encourages preserving speech patterns
        var promptParts: [String] = []
        
        if verbatimMode {
            // This prompt tells Whisper to preserve filler words
            promptParts.append("Transcribe exactly as spoken, including um, uh, like, you know, and other filler words.")
        }
        
        if !vocabulary.isEmpty {
            promptParts.append(vocabulary.joined(separator: ", "))
        }
        
        let initialPrompt = promptParts.isEmpty ? nil : promptParts.joined(separator: " ")
        
        // Set common parameters
        params.print_realtime = false
        params.print_progress = false
        params.print_timestamps = false
        params.print_special = false
        params.translate = false
        params.n_threads = threadCount
        params.offset_ms = 0
        params.no_context = true
        params.single_segment = false
        params.suppress_blank = true
        params.suppress_nst = true
        
        // Handle language parameter - nil means auto-detect
        if let language = language {
            return try language.withCString { langPtr in
                params.language = langPtr
                return try performTranscriptionWithPrompt(ctx: ctx, samples: samples, params: params, initialPrompt: initialPrompt)
            }
        } else {
            // Auto-detect: set language to nil (Whisper will detect)
            params.language = nil
            return try performTranscriptionWithPrompt(ctx: ctx, samples: samples, params: params, initialPrompt: initialPrompt)
        }
    }
    
    private func performTranscriptionWithPrompt(
        ctx: OpaquePointer,
        samples: [Float],
        params: whisper_full_params,
        initialPrompt: String?
    ) throws -> [TranscriptionSegment] {
        var mutableParams = params
        
        // Set initial prompt if vocabulary is provided
        if let prompt = initialPrompt {
            return try prompt.withCString { promptPtr in
                mutableParams.initial_prompt = promptPtr
                return try performTranscription(ctx: ctx, samples: samples, params: mutableParams)
            }
        } else {
            return try performTranscription(ctx: ctx, samples: samples, params: mutableParams)
        }
    }
    
    private func performTranscription(
        ctx: OpaquePointer,
        samples: [Float],
        params: whisper_full_params
    ) throws -> [TranscriptionSegment] {
        // Reset timings for performance measurement
        whisper_reset_timings(ctx)
        
        // Perform transcription
        let result = samples.withUnsafeBufferPointer { samplesPtr in
            whisper_full(ctx, params, samplesPtr.baseAddress, Int32(samples.count))
        }
        
        if result != 0 {
            throw WhisperError.transcriptionFailed(reason: "whisper_full returned \(result)")
        }
        
        // Print timing information for debugging
        whisper_print_timings(ctx)

        // Extract segments
        let segmentCount = whisper_full_n_segments(ctx)
        print("WhisperContext: Got \(segmentCount) segments")
        
        var segments: [TranscriptionSegment] = []
        
        for i in 0..<segmentCount {
            guard let textPtr = whisper_full_get_segment_text(ctx, i) else {
                continue
            }
            
            let text = String(cString: textPtr)
            let startTime = whisper_full_get_segment_t0(ctx, i) * 10  // Convert to ms
            let endTime = whisper_full_get_segment_t1(ctx, i) * 10    // Convert to ms
            
            let segment = TranscriptionSegment(
                text: text,
                startTime: startTime,
                endTime: endTime
            )
            segments.append(segment)
        }
        
        return segments
    }
    
    /// Get the full transcription text from segments
    func getFullTranscription(segments: [TranscriptionSegment]) -> String {
        segments.map { $0.text }.joined().trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Thread Count
    
    /// Calculate optimal thread count for transcription
    /// Uses half of available cores, bounded between 4-8
    static func optimalThreadCount() -> Int32 {
        let processorCount = ProcessInfo.processInfo.processorCount
        // Use half of cores, bounded between 4-8
        // - Minimum 4: ensures good parallelism
        // - Maximum 8: prevents thermal throttling on Apple Silicon
        let optimal = min(max(4, processorCount / 2), 8)
        return Int32(optimal)
    }
}


// MARK: - Whisper Wrapper (Main Interface)

/// Main interface for Whisper transcription.
/// Observable class that can be used from SwiftUI views.
@MainActor
class WhisperWrapper: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = WhisperWrapper()
    
    // MARK: - Published Properties
    
    @Published private(set) var isModelLoaded = false
    @Published private(set) var isTranscribing = false
    @Published private(set) var loadedModelType: WhisperModelType?
    @Published private(set) var lastError: String?
    
    // MARK: - Private Properties
    
    private var whisperContext: WhisperContext?
    
    // MARK: - Initialization
    
    private init() {
        print("WhisperWrapper: Initializing...")
        setupNotifications()
    }
    
    private func setupNotifications() {
        // Listen for model changes
        NotificationCenter.default.addObserver(
            forName: .activeModelChanged,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                if let model = notification.object as? WhisperModelType {
                    print("WhisperWrapper: Active model changed to \(model.rawValue)")
                    try? await self?.loadModel(model)
                }
            }
        }
    }

    // MARK: - Model Management
    
    /// Load a Whisper model
    func loadModel(_ model: WhisperModelType) async throws {
        let modelPath = ModelManager.shared.modelPath(for: model)
        
        guard ModelManager.shared.isModelDownloaded(model) else {
            throw WhisperError.modelLoadFailed(path: modelPath.path)
        }
        
        print("WhisperWrapper: Loading model \(model.rawValue) from \(modelPath.path)")
        
        // Free existing context
        whisperContext = nil
        isModelLoaded = false
        loadedModelType = nil
        
        do {
            whisperContext = try WhisperContext(modelPath: modelPath.path)
            isModelLoaded = true
            loadedModelType = model
            lastError = nil
            print("WhisperWrapper: Model \(model.rawValue) loaded successfully")
        } catch {
            lastError = error.localizedDescription
            throw error
        }
    }
    
    /// Load the currently active model from ModelManager
    func loadActiveModel() async throws {
        guard let activeModel = ModelManager.shared.activeModel else {
            print("WhisperWrapper: No active model set")
            return
        }
        
        try await loadModel(activeModel)
    }
    
    /// Reload the current model (e.g., after app becomes active)
    func reloadModel() async throws {
        if let model = loadedModelType {
            try await loadModel(model)
        } else if let activeModel = ModelManager.shared.activeModel {
            try await loadModel(activeModel)
        }
    }

    // MARK: - Transcription
    
    /// Transcribe audio samples to text
    /// - Parameters:
    ///   - samples: Float32 audio samples at 16kHz mono
    ///   - language: Language code (nil for auto-detect, default: "en")
    ///   - vocabulary: Optional vocabulary words to improve recognition
    ///   - verbatimMode: If true, attempts to preserve filler words (for Raw mode)
    /// - Returns: Transcribed text
    func transcribe(
        samples: [Float],
        language: String? = "en",
        vocabulary: [String] = [],
        verbatimMode: Bool = false
    ) async throws -> String {
        guard let context = whisperContext else {
            throw WhisperError.contextNotInitialized
        }
        
        guard !samples.isEmpty else {
            throw WhisperError.invalidAudioData
        }
        
        isTranscribing = true
        lastError = nil
        
        defer {
            Task { @MainActor in
                self.isTranscribing = false
            }
        }
        
        do {
            let segments = try await context.transcribe(
                samples: samples,
                language: language,
                vocabulary: vocabulary,
                verbatimMode: verbatimMode
            )
            
            let fullText = await context.getFullTranscription(segments: segments)
            print("WhisperWrapper: Transcription complete: \"\(fullText.prefix(50))...\"")
            return fullText
        } catch {
            lastError = error.localizedDescription
            throw error
        }
    }

    /// Transcribe audio samples and return detailed segments
    /// - Parameters:
    ///   - samples: Float32 audio samples at 16kHz mono
    ///   - language: Language code (nil for auto-detect, default: "en")
    ///   - vocabulary: Optional vocabulary words to improve recognition
    /// - Returns: Array of transcription segments with timing info
    func transcribeWithSegments(
        samples: [Float],
        language: String? = "en",
        vocabulary: [String] = []
    ) async throws -> [TranscriptionSegment] {
        guard let context = whisperContext else {
            throw WhisperError.contextNotInitialized
        }
        
        guard !samples.isEmpty else {
            throw WhisperError.invalidAudioData
        }
        
        isTranscribing = true
        lastError = nil
        
        defer {
            Task { @MainActor in
                self.isTranscribing = false
            }
        }
        
        do {
            let segments = try await context.transcribe(
                samples: samples,
                language: language,
                vocabulary: vocabulary
            )
            print("WhisperWrapper: Transcription complete with \(segments.count) segments")
            return segments
        } catch {
            lastError = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - Cleanup
    
    /// Free the Whisper context and release memory
    func unloadModel() {
        whisperContext = nil
        isModelLoaded = false
        loadedModelType = nil
        print("WhisperWrapper: Model unloaded")
    }
}
