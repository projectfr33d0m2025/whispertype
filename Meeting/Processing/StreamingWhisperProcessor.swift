//
//  StreamingWhisperProcessor.swift
//  WhisperType
//
//  Streaming processor for live transcription during meeting recording.
//  Subscribes to AudioStreamBus, accumulates audio buffers, and produces
//  real-time transcript updates.
//

import Foundation
import Combine

/// Configuration for the streaming processor
struct StreamingProcessorConfig {
    /// Buffer accumulation time before processing (seconds)
    let bufferDuration: TimeInterval
    
    /// Processing interval (seconds)
    let processingInterval: TimeInterval
    
    /// Number of context words to pass to next transcription
    let contextWordCount: Int
    
    /// Default configuration optimized for accurate delayed subtitles
    /// Uses longer chunks (60s) for better Whisper accuracy, trading latency for quality
    static let `default` = StreamingProcessorConfig(
        bufferDuration: 60.0,       // 60 seconds for maximum accuracy
        processingInterval: 60.0,   // Match buffer duration
        contextWordCount: 0         // Clean slate each chunk for accuracy
    )
    
    /// Fast configuration for lower latency (less accuracy)
    static let fast = StreamingProcessorConfig(
        bufferDuration: 15.0,
        processingInterval: 10.0,
        contextWordCount: 30
    )
}

/// Streaming Whisper processor for live transcription
@MainActor
class StreamingWhisperProcessor: ObservableObject {
    
    // MARK: - Published Properties
    
    /// All transcript updates produced during this session
    @Published private(set) var transcriptUpdates: [TranscriptUpdate] = []
    
    /// Latest transcript update
    @Published private(set) var latestUpdate: TranscriptUpdate?
    
    /// Whether processing is currently active
    @Published private(set) var isProcessing: Bool = false
    
    /// Whether the processor is running (subscribed to audio)
    @Published private(set) var isRunning: Bool = false
    
    /// Current processing latency (time from audio capture to transcript)
    @Published private(set) var currentLatency: TimeInterval = 0
    
    // MARK: - Dependencies
    
    private let whisperWrapper: WhisperWrapper
    private let streamBus: AudioStreamBus
    private let config: StreamingProcessorConfig
    
    // MARK: - Private Properties
    
    /// Buffer for accumulating audio samples
    private var audioBuffer: [Float] = []
    
    /// Timestamp when buffer accumulation started
    private var bufferStartTimestamp: TimeInterval = 0
    
    /// Context from previous transcription (for continuity)
    private var contextPrompt: String = ""
    
    // MARK: - Silence-Triggered Transcription Properties
    
    /// Maximum chunk duration for transcription (Whisper works best with <30s)
    private let maxChunkDuration: TimeInterval = 25.0
    
    /// Minimum chunk duration before processing (need enough audio for accuracy)
    private let minChunkDuration: TimeInterval = 3.0
    
    /// The committed (finalized) transcript text from all completed chunks
    private var committedTranscript: String = ""
    
    /// Current pending audio buffer (cleared after each successful transcription)
    private var pendingAudioBuffer: [Float] = []
    
    /// Timestamp when current pending buffer started
    private var pendingBufferStartTime: TimeInterval = 0
    
    /// Timer for triggering processing
    private var processingTimer: Timer?
    
    /// Cancellables for Combine subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    /// Background queue for processing
    private let processingQueue = DispatchQueue(
        label: "com.whispertype.streaming-processor",
        qos: .userInitiated
    )
    
    /// Recording start time (for timestamp calculation)
    private var recordingStartTime: Date?
    
    // MARK: - VAD (Voice Activity Detection) Properties
    
    /// Silence threshold in dB (below this is considered silence)
    private let silenceThresholdDB: Float = -35.0
    
    /// Duration of silence required to trigger processing (seconds)
    /// Increased. for more natural sentence boundaries
    private let silenceDuration: TimeInterval = 0.8
    
    /// Minimum buffer duration before silence-triggered processing (seconds)
    private let minBufferForSilenceTrigger: TimeInterval = 2.0
    
    /// Last time speech was detected
    private var lastSpeechTime: Date?
    
    /// Whether we're currently in a speech segment
    private var isInSpeech: Bool = false
    
    // MARK: - Initialization
    
    init(
        whisperWrapper: WhisperWrapper = .shared,
        streamBus: AudioStreamBus = .shared,
        config: StreamingProcessorConfig = .default
    ) {
        self.whisperWrapper = whisperWrapper
        self.streamBus = streamBus
        self.config = config
        
        print("StreamingWhisperProcessor: Initialized with buffer=\(config.bufferDuration)s, interval=\(config.processingInterval)s")
    }
    
    // MARK: - Public API
    
    /// Start the streaming processor
    func start() {
        guard !isRunning else {
            print("StreamingWhisperProcessor: Already running")
            return
        }
        
        print("StreamingWhisperProcessor: Starting...")
        
        // Reset state
        audioBuffer = []
        transcriptUpdates = []
        latestUpdate = nil
        contextPrompt = ""
        bufferStartTimestamp = 0
        recordingStartTime = Date()
        
        // Subscribe to real-time audio samples (not chunks which are published every 30s)
        streamBus.samplePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] samples in
                self?.handleAudioSamples(samples)
            }
            .store(in: &cancellables)
        
        // Start processing timer
        startProcessingTimer()
        
        isRunning = true
        print("StreamingWhisperProcessor: Started")
    }
    
    /// Stop the streaming processor
    func stop() {
        guard isRunning else { return }
        
        print("StreamingWhisperProcessor: Stopping...")
        
        // Stop timer
        processingTimer?.invalidate()
        processingTimer = nil
        
        // Cancel subscriptions
        cancellables.removeAll()
        
        // Process any remaining audio
        if !audioBuffer.isEmpty {
            Task {
                await processCurrentBuffer()
            }
        }
        
        isRunning = false
        print("StreamingWhisperProcessor: Stopped with \(transcriptUpdates.count) updates")
    }
    
    /// Clear all transcript updates
    func clear() {
        transcriptUpdates = []
        latestUpdate = nil
        contextPrompt = ""
        audioBuffer = []
        pendingAudioBuffer = []
        pendingBufferStartTime = 0
        committedTranscript = ""
    }
    
    /// Get combined transcript text
    var fullTranscript: String {
        transcriptUpdates
            .filter { !$0.isEmpty }
            .map { $0.text }
            .joined(separator: " ")
    }
    
    // MARK: - Audio Handling
    
    private func handleAudioSamples(_ samples: [Float]) {
        // Set buffer start timestamp if this is the first batch of samples
        if audioBuffer.isEmpty, let startTime = recordingStartTime {
            bufferStartTimestamp = Date().timeIntervalSince(startTime)
        }
        
        // Append samples to buffer
        audioBuffer.append(contentsOf: samples)
        
        // VAD: Detect speech vs silence
        let rms = calculateRMS(samples)
        let dB = 20 * log10(max(rms, 1e-7))
        let isSpeechNow = dB > silenceThresholdDB
        
        if isSpeechNow {
            lastSpeechTime = Date()
            isInSpeech = true
        }
        
        // Check if we have enough audio to process
        let bufferDuration = Double(audioBuffer.count) / Constants.Audio.meetingSampleRate
        
        // Trigger processing in two cases:
        // 1. Buffer reached max duration (15s)
        // 2. Silence detected for 400ms after speech (natural boundary)
        let shouldProcessDueToMaxBuffer = bufferDuration >= config.bufferDuration
        let shouldProcessDueToSilence = isInSpeech && 
            !isSpeechNow && 
            bufferDuration >= minBufferForSilenceTrigger &&
            (lastSpeechTime.map { Date().timeIntervalSince($0) >= silenceDuration } ?? false)
        
        if shouldProcessDueToMaxBuffer || shouldProcessDueToSilence {
            if shouldProcessDueToSilence {
                print("StreamingWhisperProcessor: Silence detected, processing at natural boundary (\(String(format: "%.1f", bufferDuration))s)")
            }
            isInSpeech = false  // Reset for next speech segment
            Task {
                await processCurrentBuffer()
            }
        }
    }
    
    // MARK: - Processing Timer
    
    private func startProcessingTimer() {
        processingTimer = Timer.scheduledTimer(
            withTimeInterval: config.processingInterval,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.processCurrentBuffer()
            }
        }
    }
    
    // MARK: - Transcription Processing
    
    private func processCurrentBuffer() async {
        // Ensure we have audio to process
        guard !audioBuffer.isEmpty else { return }
        
        // Ensure Whisper model is loaded
        guard whisperWrapper.isModelLoaded else {
            print("StreamingWhisperProcessor: Whisper model not loaded, skipping")
            return
        }
        
        // Don't process if already processing
        guard !isProcessing else { return }
        
        // SILENCE-TRIGGERED TRANSCRIPTION:
        // Transcribe the full buffer, commit result, then clear buffer
        // This mimics option-space mode behavior
        
        let audioDuration = Double(audioBuffer.count) / Constants.Audio.meetingSampleRate
        
        // Wait for minimum audio duration
        guard audioDuration >= minChunkDuration else {
            return
        }
        
        isProcessing = true
        let captureTime = Date()
        
        // Capture the current buffer
        let samplesToProcess = audioBuffer
        let timestamp = bufferStartTimestamp
        
        // Check audio level
        let rms = calculateRMS(samplesToProcess)
        let dB = 20 * log10(max(rms, 1e-7))
        
        // Skip if too quiet (silence only)
        if dB < -40.0 {
            // Clear the buffer as it's just silence
            audioBuffer = []
            print("StreamingWhisperProcessor: Buffer is silence (\(String(format: "%.1f", dB)) dB), clearing")
            isProcessing = false
            return
        }
        
        print("StreamingWhisperProcessor: Processing \(String(format: "%.1f", audioDuration))s audio at \(String(format: "%.1f", timestamp))s (level: \(String(format: "%.1f", dB)) dB)")
        
        // Process transcription
        do {
            let transcriptionResult = try await whisperWrapper.transcribe(
                samples: samplesToProcess,
                language: "en",
                vocabulary: []  // No vocab hints - let Whisper work freely
            )
            
            let trimmedResult = transcriptionResult.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if !trimmedResult.isEmpty {
                // Append to committed transcript
                if committedTranscript.isEmpty {
                    committedTranscript = trimmedResult
                } else {
                    committedTranscript += " " + trimmedResult
                }
                
                print("StreamingWhisperProcessor: Transcribed chunk: \"\(trimmedResult.prefix(60))...\"")
            }
            
            // CLEAR the buffer after successful transcription
            // Next audio will be fresh, no overlap or re-processing
            audioBuffer = []
            bufferStartTimestamp += audioDuration
            
            // Calculate latency
            currentLatency = Date().timeIntervalSince(captureTime)
            
            // Create update with the FULL committed transcript
            let update = TranscriptUpdate(
                text: committedTranscript,
                timestamp: 0,
                createdAt: Date(),
                audioDuration: timestamp + audioDuration
            )
            
            // Single update with full transcript
            transcriptUpdates = [update]
            latestUpdate = update
            
            print("StreamingWhisperProcessor: Total transcript: \"...\(committedTranscript.suffix(60))\" (latency: \(String(format: "%.2f", currentLatency))s)")
            
        } catch {
            print("StreamingWhisperProcessor: Transcription error - \(error)")
        }
        
        isProcessing = false
    }
    
    // MARK: - Audio Analysis
    
    /// Calculate RMS (Root Mean Square) of audio samples for level detection
    private func calculateRMS(_ samples: [Float]) -> Float {
        guard !samples.isEmpty else { return 0 }
        let sumOfSquares = samples.reduce(0) { $0 + $1 * $1 }
        return sqrt(sumOfSquares / Float(samples.count))
    }
}

// MARK: - StreamingWhisperProcessor Extensions

extension StreamingWhisperProcessor {
    
    /// Subscribe to transcript updates
    func subscribeToUpdates(handler: @escaping (TranscriptUpdate) -> Void) -> AnyCancellable {
        $latestUpdate
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: handler)
    }
}
