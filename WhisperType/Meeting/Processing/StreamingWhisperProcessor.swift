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
    
    /// Default configuration optimized for live subtitles
    static let `default` = StreamingProcessorConfig(
        bufferDuration: 10.0,
        processingInterval: 5.0,
        contextWordCount: 50
    )
    
    /// Fast configuration for lower latency (less accuracy)
    static let fast = StreamingProcessorConfig(
        bufferDuration: 5.0,
        processingInterval: 3.0,
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
        
        // Subscribe to audio chunks
        streamBus.chunkPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] chunk in
                self?.handleAudioChunk(chunk)
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
    }
    
    /// Get combined transcript text
    var fullTranscript: String {
        transcriptUpdates
            .filter { !$0.isEmpty }
            .map { $0.text }
            .joined(separator: " ")
    }
    
    // MARK: - Audio Handling
    
    private func handleAudioChunk(_ chunk: AudioChunk) {
        // Set buffer start timestamp if this is the first chunk
        if audioBuffer.isEmpty {
            bufferStartTimestamp = chunk.timestamp
        }
        
        // Append samples to buffer
        audioBuffer.append(contentsOf: chunk.samples)
        
        // Check if we have enough audio to process
        let bufferDuration = Double(audioBuffer.count) / Constants.Audio.meetingSampleRate
        
        if bufferDuration >= config.bufferDuration {
            // Trigger immediate processing
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
        
        isProcessing = true
        
        // Capture buffer and timestamp
        let samplesToProcess = audioBuffer
        let timestamp = bufferStartTimestamp
        let captureTime = Date()
        let audioDuration = Double(samplesToProcess.count) / Constants.Audio.meetingSampleRate
        
        // Clear buffer (with overlap for continuity)
        let overlapSamples = Int(Constants.Audio.meetingSampleRate * 1.0) // 1 second overlap
        if audioBuffer.count > overlapSamples {
            audioBuffer = Array(audioBuffer.suffix(overlapSamples))
            bufferStartTimestamp = timestamp + audioDuration - 1.0
        } else {
            audioBuffer = []
        }
        
        print("StreamingWhisperProcessor: Processing \(String(format: "%.1f", audioDuration))s of audio at \(String(format: "%.1f", timestamp))s")
        
        // Process on background queue
        do {
            let transcriptionResult = try await whisperWrapper.transcribe(
                samples: samplesToProcess,
                language: "en",
                vocabulary: contextPrompt.isEmpty ? [] : contextPrompt.split(separator: " ").map(String.init)
            )
            
            // Create update
            let update = TranscriptUpdate(
                text: transcriptionResult,
                timestamp: timestamp,
                createdAt: Date(),
                audioDuration: audioDuration
            )
            
            // Calculate latency
            currentLatency = Date().timeIntervalSince(captureTime)
            
            // Update context for next transcription
            contextPrompt = update.lastWords(config.contextWordCount)
            
            // Add to updates (skip empty results)
            if !update.isEmpty {
                transcriptUpdates.append(update)
                latestUpdate = update
                
                print("StreamingWhisperProcessor: Produced update - \"\(update.text.prefix(50))...\" (latency: \(String(format: "%.2f", currentLatency))s)")
            }
            
        } catch {
            print("StreamingWhisperProcessor: Transcription error - \(error)")
        }
        
        isProcessing = false
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
