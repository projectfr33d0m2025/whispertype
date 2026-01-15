//
//  MeetingRecorder.swift
//  WhisperType
//
//  Main recording component for meeting transcription.
//  Implements ring buffer for memory-bounded recording with chunk emission.
//

import Foundation
import AVFoundation
import Combine

/// Errors specific to meeting recording
enum MeetingRecorderError: LocalizedError {
    case alreadyRecording
    case notRecording
    case microphonePermissionDenied
    case audioEngineSetupFailed(String)
    case recordingFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .alreadyRecording:
            return "Recording is already in progress"
        case .notRecording:
            return "No recording in progress"
        case .microphonePermissionDenied:
            return "Microphone permission denied"
        case .audioEngineSetupFailed(let message):
            return "Audio engine setup failed: \(message)"
        case .recordingFailed(let message):
            return "Recording failed: \(message)"
        }
    }
}

/// Main recording component for meeting transcription
@available(macOS 12.3, *)
@MainActor
class MeetingRecorder: ObservableObject, SystemAudioCaptureDelegate {
    
    // MARK: - Published Properties
    
    /// Whether recording is currently active
    @Published private(set) var isRecording = false
    
    /// Current audio level for UI display (microphone)
    @Published private(set) var audioLevel: Float = 0.0
    
    /// Current system audio level for UI display
    @Published private(set) var systemAudioLevel: Float = -60.0
    
    /// Recording duration in seconds
    @Published private(set) var duration: TimeInterval = 0
    
    /// Number of chunks emitted
    @Published private(set) var chunkCount: Int = 0
    
    /// Whether duration warning has been shown
    @Published private(set) var durationWarningShown = false
    
    /// Current audio source being used
    @Published private(set) var activeAudioSource: AudioSource = .microphone
    
    // MARK: - Dependencies
    
    private let streamBus: AudioStreamBus
    private let diskWriter: ChunkedDiskWriter
    private var systemAudioCapture: SystemAudioCapture?
    
    // MARK: - Audio Engine
    
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    
    // MARK: - Ring Buffer
    
    /// Ring buffer for accumulating microphone samples
    private var micRingBuffer: [Float] = []
    
    /// Ring buffer for accumulating system audio samples
    private var systemRingBuffer: [Float] = []
    
    /// Maximum samples in ring buffer (30 seconds at 16kHz)
    private let maxBufferSamples: Int
    
    /// Samples per chunk (30 seconds at 16kHz)
    private let samplesPerChunk: Int
    
    /// Sample rate for recording
    private let sampleRate: Double = Constants.Audio.meetingSampleRate
    
    // MARK: - Timing
    
    private var recordingStartTime: Date?
    private var durationTimer: Timer?
    private var chunkTimer: Timer?
    
    /// Current chunk index
    private var currentChunkIndex: Int = 0
    
    // MARK: - Subscriptions
    
    private var diskWriterSubscription: AnyCancellable?
    
    /// Pending session for recording
    private var pendingSession: MeetingSession?
    
    // MARK: - Initialization
    
    init(streamBus: AudioStreamBus = .shared, diskWriter: ChunkedDiskWriter = ChunkedDiskWriter()) {
        self.streamBus = streamBus
        self.diskWriter = diskWriter
        
        // Calculate buffer sizes
        let chunkDurationSeconds = Constants.Audio.chunkDurationSeconds
        self.samplesPerChunk = Int(sampleRate * chunkDurationSeconds)
        self.maxBufferSamples = samplesPerChunk // Only keep one chunk worth
        
        print("MeetingRecorder: Initialized - chunk size: \(samplesPerChunk) samples, \(chunkDurationSeconds)s")
    }
    
    // MARK: - Recording Control
    
    /// Start recording a meeting
    /// - Parameter session: The meeting session to record
    func startRecording(session: MeetingSession) async throws {
        guard !isRecording else {
            throw MeetingRecorderError.alreadyRecording
        }
        
        // Check microphone permission
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        if status == .denied || status == .restricted {
            throw MeetingRecorderError.microphonePermissionDenied
        }
        
        if status == .notDetermined {
            let granted = await AVCaptureDevice.requestAccess(for: .audio)
            if !granted {
                throw MeetingRecorderError.microphonePermissionDenied
            }
        }
        
        // Setup audio engine
        try setupAudioEngine()
        
        // Start disk writer session
        try diskWriter.startSession(sessionId: session.id)
        
        // Subscribe disk writer to stream bus
        diskWriterSubscription = streamBus.subscribe(diskWriter)
        
        // Reset state
        micRingBuffer = []
        systemRingBuffer = []
        currentChunkIndex = 0
        chunkCount = 0
        duration = 0
        durationWarningShown = false
        recordingStartTime = Date()
        activeAudioSource = session.audioSource
        pendingSession = session
        
        // Start stream bus
        streamBus.start()
        
        // Start audio engine
        guard let engine = audioEngine else {
            throw MeetingRecorderError.audioEngineSetupFailed("Audio engine not initialized")
        }
        
        try engine.start()
        
        // Install audio tap
        installAudioTap()
        
        // Start system audio capture if needed
        try await startSystemAudioCapture()
        
        // Start timers
        startDurationTimer()
        startChunkTimer()
        
        isRecording = true
        
        print("MeetingRecorder: Started recording for session \(session.id)")
        
        // Post notification
        NotificationCenter.default.post(name: .meetingRecordingStarted, object: session)
    }
    
    /// Stop recording and finalize chunks
    /// - Returns: Array of chunk file URLs
    func stopRecording() async throws -> [URL] {
        guard isRecording else {
            throw MeetingRecorderError.notRecording
        }
        
        print("MeetingRecorder: Stopping recording...")
        
        // Stop timers
        stopDurationTimer()
        stopChunkTimer()
        
        // Emit any remaining audio in buffer as final chunk
        if !micRingBuffer.isEmpty || !systemRingBuffer.isEmpty {
            emitCurrentChunk()
        }
        
        // Stop system audio capture if active
        systemAudioCapture?.stopCapture()
        
        // Stop audio engine
        removeAudioTap()
        audioEngine?.stop()
        
        // Stop stream bus
        streamBus.stop()
        
        // Wait briefly for async subscribers to receive final chunks
        // The subscription uses .receive(on: DispatchQueue.main) which is async
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // End disk writer session
        let chunkURLs = diskWriter.endSession()
        
        // Cancel subscription
        diskWriterSubscription?.cancel()
        diskWriterSubscription = nil
        
        // Reset state
        isRecording = false
        audioLevel = 0.0
        systemAudioLevel = -60.0
        
        print("MeetingRecorder: Stopped - \(chunkCount) chunks, \(String(format: "%.1f", duration)) seconds")
        
        // Post notification
        NotificationCenter.default.post(name: .meetingRecordingStopped, object: nil)
        
        return chunkURLs
    }
    
    /// Cancel recording and cleanup files
    func cancelRecording() {
        guard isRecording else { return }
        
        print("MeetingRecorder: Cancelling recording...")
        
        // Stop timers
        stopDurationTimer()
        stopChunkTimer()
        
        // Stop audio engine
        removeAudioTap()
        audioEngine?.stop()
        
        // Stop stream bus
        streamBus.stop()
        
        // Cancel disk writer (removes files)
        diskWriter.cancelSession()
        
        // Cancel subscription
        diskWriterSubscription?.cancel()
        diskWriterSubscription = nil
        
        // Reset state
        isRecording = false
        audioLevel = 0.0
        systemAudioLevel = -60.0
        micRingBuffer = []
        systemRingBuffer = []
        
        // Stop system audio capture
        systemAudioCapture?.stopCapture()
        
        print("MeetingRecorder: Cancelled")
        
        // Post notification
        NotificationCenter.default.post(name: .meetingRecordingCancelled, object: nil)
    }
    
    // MARK: - Audio Engine Setup
    
    private func setupAudioEngine() throws {
        let engine = AVAudioEngine()
        self.audioEngine = engine
        self.inputNode = engine.inputNode
        
        guard let inputNode = self.inputNode else {
            throw MeetingRecorderError.audioEngineSetupFailed("No input node available")
        }
        
        print("MeetingRecorder: Audio engine setup with format: \(inputNode.inputFormat(forBus: 0))")
    }
    
    private func installAudioTap() {
        guard let inputNode = inputNode else { return }
        
        let inputFormat = inputNode.inputFormat(forBus: 0)
        let outputFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: false
        )!
        
        // Create format converter if needed
        let converter: AVAudioConverter?
        if inputFormat.sampleRate != sampleRate || inputFormat.channelCount != 1 {
            converter = AVAudioConverter(from: inputFormat, to: outputFormat)
        } else {
            converter = nil
        }
        
        // Install tap
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            Task { @MainActor in
                self?.processAudioBuffer(buffer, converter: converter, outputFormat: outputFormat)
            }
        }
        
        print("MeetingRecorder: Audio tap installed")
    }
    
    private func removeAudioTap() {
        inputNode?.removeTap(onBus: 0)
        print("MeetingRecorder: Audio tap removed")
    }
    
    // MARK: - Audio Processing
    
    private func processAudioBuffer(
        _ buffer: AVAudioPCMBuffer,
        converter: AVAudioConverter?,
        outputFormat: AVAudioFormat
    ) {
        var samples: [Float] = []
        
        if let converter = converter {
            // Convert to target format
            let frameCapacity = AVAudioFrameCount(Double(buffer.frameLength) * sampleRate / buffer.format.sampleRate)
            guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: frameCapacity) else {
                return
            }
            
            var error: NSError?
            let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
                outStatus.pointee = .haveData
                return buffer
            }
            
            converter.convert(to: convertedBuffer, error: &error, withInputFrom: inputBlock)
            
            if error == nil, let channelData = convertedBuffer.floatChannelData?[0] {
                samples = Array(UnsafeBufferPointer(start: channelData, count: Int(convertedBuffer.frameLength)))
            }
        } else {
            // Already in correct format
            if let channelData = buffer.floatChannelData?[0] {
                samples = Array(UnsafeBufferPointer(start: channelData, count: Int(buffer.frameLength)))
            }
        }
        
        guard !samples.isEmpty else { return }
        
        // Boost microphone volume (1.5x gain) - helps with clarity after downsampling to 16kHz
        let microphoneGain: Float = 1.5
        let boostedSamples = samples.map { min(max($0 * microphoneGain, -1.0), 1.0) } // Clamp to prevent clipping
        
        // Add to microphone ring buffer
        micRingBuffer.append(contentsOf: boostedSamples)
        
        // Publish samples for live transcription
        streamBus.publish(samples: boostedSamples)
        
        // Calculate audio level (RMS)
        let rms = calculateRMS(samples)
        let dB = 20 * log10(max(rms, 1e-7))
        audioLevel = dB
        
        // Publish audio level
        let level = AudioLevel.microphone(dB)
        streamBus.publish(level: level)
        
        // Trim mic ring buffer if exceeds max size
        if micRingBuffer.count > maxBufferSamples * 2 {
            micRingBuffer = Array(micRingBuffer.suffix(maxBufferSamples * 2))
        }
    }
    
    private func calculateRMS(_ samples: [Float]) -> Float {
        guard !samples.isEmpty else { return 0 }
        let sumOfSquares = samples.reduce(0) { $0 + $1 * $1 }
        return sqrt(sumOfSquares / Float(samples.count))
    }
    
    // MARK: - Chunk Emission
    
    /// Emit the current buffer contents as a chunk
    private func emitCurrentChunk() {
        // Get samples based on audio source
        let samples: [Float]
        
        switch activeAudioSource {
        case .microphone:
            guard !micRingBuffer.isEmpty else { return }
            samples = micRingBuffer
            micRingBuffer = []
            
        case .system:
            guard !systemRingBuffer.isEmpty else { return }
            samples = systemRingBuffer
            systemRingBuffer = []
            
        case .both:
            // Mix microphone and system audio
            let mic = micRingBuffer
            let system = systemRingBuffer
            micRingBuffer = []
            systemRingBuffer = []
            
            guard !mic.isEmpty || !system.isEmpty else { return }
            samples = AudioMixer.mixMicAndSystem(mic: mic, system: system, normalize: true)
        }
        
        let timestamp = TimeInterval(currentChunkIndex) * Constants.Audio.chunkDurationSeconds
        let chunkDuration = Double(samples.count) / sampleRate
        
        let chunk = AudioChunk(
            samples: samples,
            timestamp: timestamp,
            duration: chunkDuration,
            sampleRate: sampleRate,
            chunkIndex: currentChunkIndex
        )
        
        currentChunkIndex += 1
        chunkCount = currentChunkIndex
        
        // Publish to stream bus
        streamBus.publish(chunk: chunk)
        
        print("MeetingRecorder: Emitted chunk \(currentChunkIndex) - \(samples.count) samples, \(String(format: "%.2f", chunkDuration))s")
    }
    
    // MARK: - Timers
    
    private func startDurationTimer() {
        durationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateDuration()
            }
        }
    }
    
    private func stopDurationTimer() {
        durationTimer?.invalidate()
        durationTimer = nil
    }
    
    private func startChunkTimer() {
        let chunkInterval = Constants.Audio.chunkDurationSeconds
        chunkTimer = Timer.scheduledTimer(withTimeInterval: chunkInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.emitCurrentChunk()
            }
        }
    }
    
    private func stopChunkTimer() {
        chunkTimer?.invalidate()
        chunkTimer = nil
    }
    
    private func updateDuration() {
        guard let startTime = recordingStartTime else { return }
        duration = Date().timeIntervalSince(startTime)
        
        // Check for duration warning
        if duration >= Constants.Limits.meetingWarningDuration && !durationWarningShown {
            durationWarningShown = true
            NotificationCenter.default.post(name: .meetingDurationWarning, object: nil)
            print("MeetingRecorder: Duration warning - 5 minutes remaining")
        }
        
        // Check for auto-stop at max duration
        if duration >= Constants.Limits.maxMeetingDuration {
            print("MeetingRecorder: Max duration reached, stopping")
            Task {
                do {
                    _ = try await stopRecording()
                } catch {
                    print("MeetingRecorder: Error auto-stopping: \(error)")
                }
            }
        }
    }
    
    // MARK: - Utility
    
    /// Get formatted duration string
    var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    /// Get session directory URL
    var sessionDirectory: URL? {
        diskWriter.sessionDirectory
    }
    
    /// Get all chunk URLs written so far
    var chunkURLs: [URL] {
        diskWriter.chunkURLs
    }
    
    // MARK: - System Audio Capture
    
    /// Start system audio capture
    private func startSystemAudioCapture() async throws {
        guard activeAudioSource == .system || activeAudioSource == .both else {
            return
        }
        
        let capture = SystemAudioCapture()
        capture.delegate = self
        systemAudioCapture = capture
        
        // Check permission
        let permission = await capture.checkPermission()
        if permission == .denied {
            print("MeetingRecorder: Screen Recording permission denied")
            // Don't throw - just fall back to microphone only
            if activeAudioSource == .both {
                print("MeetingRecorder: Falling back to microphone only")
            }
            return
        }
        
        do {
            try await capture.startCapture()
            print("MeetingRecorder: System audio capture started")
        } catch {
            print("MeetingRecorder: Failed to start system audio capture - \(error)")
            // Fall back to microphone only
            if activeAudioSource == .both {
                print("MeetingRecorder: Falling back to microphone only")
            }
        }
    }
    
    // MARK: - SystemAudioCaptureDelegate
    
    nonisolated func systemAudioCapture(_ capture: SystemAudioCapture, didReceiveSamples samples: [Float], timestamp: TimeInterval) {
        Task { @MainActor in
            // Boost system audio volume (2.5x gain) - system audio is often quieter than microphone
            let systemAudioGain: Float = 2.5
            let boostedSamples = samples.map { min(max($0 * systemAudioGain, -1.0), 1.0) } // Clamp to prevent clipping
            
            // Add to system ring buffer
            systemRingBuffer.append(contentsOf: boostedSamples)
            
            // Publish samples for live transcription
            streamBus.publish(samples: boostedSamples)
            
            // Trim if exceeds max size
            if systemRingBuffer.count > maxBufferSamples * 2 {
                systemRingBuffer = Array(systemRingBuffer.suffix(maxBufferSamples * 2))
            }
        }
    }
    
    nonisolated func systemAudioCapture(_ capture: SystemAudioCapture, didReceiveLevel level: Float) {
        Task { @MainActor in
            systemAudioLevel = level
            
            // Publish system audio level
            let audioLevelValue = AudioLevel.system(level)
            streamBus.publish(level: audioLevelValue)
        }
    }
    
    nonisolated func systemAudioCapture(_ capture: SystemAudioCapture, didFailWithError error: Error) {
        Task { @MainActor in
            print("MeetingRecorder: System audio capture error - \(error)")
        }
    }
}
