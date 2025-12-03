//
//  AudioRecorder.swift
//  WhisperType
//
//  Handles microphone audio recording using AVAudioEngine.
//  Records at device native sample rate, then converts to Whisper format (16kHz mono Float32).
//

import Foundation
import AVFoundation
import Accelerate

// MARK: - Audio Recorder Errors

enum AudioRecorderError: LocalizedError {
    case microphonePermissionDenied
    case microphonePermissionNotDetermined
    case audioEngineSetupFailed(String)
    case recordingFailed(String)
    case conversionFailed(String)
    case noAudioData
    case recordingInterrupted
    case microphoneNotAvailable
    
    var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            return "Microphone permission denied. Please enable in System Settings."
        case .microphonePermissionNotDetermined:
            return "Microphone permission not yet requested."
        case .audioEngineSetupFailed(let reason):
            return "Audio engine setup failed: \(reason)"
        case .recordingFailed(let reason):
            return "Recording failed: \(reason)"
        case .conversionFailed(let reason):
            return "Audio conversion failed: \(reason)"
        case .noAudioData:
            return "No audio data was recorded."
        case .recordingInterrupted:
            return "Recording was interrupted."
        case .microphoneNotAvailable:
            return "Selected microphone is not available."
        }
    }
}


// MARK: - Audio Recorder

@MainActor
class AudioRecorder: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = AudioRecorder()
    
    // MARK: - Published Properties
    
    @Published private(set) var isRecording = false
    @Published private(set) var audioLevel: Float = 0.0
    @Published private(set) var recordingDuration: TimeInterval = 0.0
    
    // MARK: - Private Properties
    
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var audioBuffer: [Float] = []
    private var recordingStartTime: Date?
    private var durationTimer: Timer?
    
    // Audio level metering (throttled to ~30 Hz for smooth animation)
    private var lastLevelUpdateTime: Date = .distantPast
    private let levelUpdateInterval: TimeInterval = 0.033 // ~30 Hz
    
    // Device sample rate (will be set from input node)
    private var deviceSampleRate: Double = 44100.0
    
    // MARK: - Initialization
    
    private init() {
        print("AudioRecorder: Initializing...")
        setupNotifications()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Setup
    
    private func setupNotifications() {
        // Listen for audio configuration changes (e.g., microphone unplugged)
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name.AVAudioEngineConfigurationChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleAudioConfigurationChange()
            }
        }
    }
    
    private func handleAudioConfigurationChange() {
        print("AudioRecorder: Audio configuration changed")
        
        // If recording, this is an interruption - stop and report error
        if isRecording {
            print("AudioRecorder: Configuration change during recording - stopping")
            // We'll handle this by stopping the engine; the error will be thrown on stopRecording
        }
    }
    
    // MARK: - Permission Handling
    
    /// Check if microphone permission is granted
    func checkMicrophonePermission() -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        return status == .authorized
    }
    
    /// Request microphone permission if needed
    func requestMicrophonePermissionIfNeeded() async throws {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        
        switch status {
        case .authorized:
            return // Already granted
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .audio)
            if !granted {
                throw AudioRecorderError.microphonePermissionDenied
            }
        case .denied, .restricted:
            throw AudioRecorderError.microphonePermissionDenied
        @unknown default:
            throw AudioRecorderError.microphonePermissionNotDetermined
        }
    }
    
    // MARK: - Audio Engine Setup
    
    /// Set up the audio engine with the appropriate input device
    private func setupAudioEngine() throws {
        // Create new engine
        let engine = AVAudioEngine()
        self.audioEngine = engine
        self.inputNode = engine.inputNode
        
        guard let inputNode = self.inputNode else {
            throw AudioRecorderError.audioEngineSetupFailed("Could not get input node")
        }
        
        // Get the input format from the input node
        let inputFormat = inputNode.outputFormat(forBus: 0)
        
        // Validate format
        guard inputFormat.sampleRate > 0 else {
            throw AudioRecorderError.audioEngineSetupFailed("Invalid sample rate")
        }
        
        guard inputFormat.channelCount > 0 else {
            throw AudioRecorderError.audioEngineSetupFailed("No audio channels available")
        }
        
        self.deviceSampleRate = inputFormat.sampleRate
        
        print("AudioRecorder: Input format - Sample rate: \(inputFormat.sampleRate), Channels: \(inputFormat.channelCount)")
        
        // Try to set selected microphone if specified
        if let selectedMicId = AppSettings.shared.selectedMicrophoneId {
            trySetInputDevice(deviceUID: selectedMicId)
        }
    }
    
    /// Attempt to set a specific input device by UID
    private func trySetInputDevice(deviceUID: String) {
        // Note: On macOS, setting specific input device requires CoreAudio
        // For simplicity, we'll use the system default for now
        // A full implementation would use AudioObjectSetPropertyData
        print("AudioRecorder: Requested input device: \(deviceUID) (using system default)")
    }
    
    // MARK: - Recording
    
    /// Start recording audio from the microphone
    func startRecording() async throws {
        // Check permission first
        try await requestMicrophonePermissionIfNeeded()
        
        // Don't start if already recording
        guard !isRecording else {
            print("AudioRecorder: Already recording")
            return
        }
        
        print("AudioRecorder: Starting recording...")
        
        // Clear previous buffer
        audioBuffer.removeAll()
        
        // Set up audio engine
        try setupAudioEngine()
        
        guard let engine = audioEngine, let inputNode = self.inputNode else {
            throw AudioRecorderError.audioEngineSetupFailed("Engine not initialized")
        }
        
        // Get input format
        let inputFormat = inputNode.outputFormat(forBus: 0)
        let bufferSize: AVAudioFrameCount = 1024
        
        // Install tap on input node
        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: inputFormat) { [weak self] buffer, time in
            self?.processAudioBuffer(buffer)
        }
        
        // Start the engine
        do {
            try engine.start()
        } catch {
            inputNode.removeTap(onBus: 0)
            throw AudioRecorderError.audioEngineSetupFailed(error.localizedDescription)
        }
        
        // Update state
        isRecording = true
        recordingStartTime = Date()
        recordingDuration = 0
        
        // Start duration timer
        startDurationTimer()
        
        print("AudioRecorder: Recording started")
        
        // Post notification
        NotificationCenter.default.post(name: .recordingStarted, object: nil)
    }
    
    /// Stop recording and return the audio data converted to Whisper format
    /// Returns: Array of Float32 samples at 16kHz mono
    func stopRecording() async throws -> [Float] {
        guard isRecording else {
            print("AudioRecorder: Not currently recording")
            throw AudioRecorderError.noAudioData
        }
        
        print("AudioRecorder: Stopping recording...")
        
        // Stop duration timer
        stopDurationTimer()
        
        // Remove tap and stop engine
        inputNode?.removeTap(onBus: 0)
        audioEngine?.stop()
        
        // Update state
        isRecording = false
        audioLevel = 0.0
        
        // Check if we have audio data
        guard !audioBuffer.isEmpty else {
            print("AudioRecorder: No audio data recorded")
            throw AudioRecorderError.noAudioData
        }
        
        let sampleCount = audioBuffer.count
        let duration = Double(sampleCount) / deviceSampleRate
        print("AudioRecorder: Recorded \(sampleCount) samples (\(String(format: "%.2f", duration))s) at \(deviceSampleRate)Hz")
        
        // Convert to Whisper format (16kHz mono Float32)
        let whisperAudio = try convertToWhisperFormat(audioBuffer, fromSampleRate: deviceSampleRate)
        
        print("AudioRecorder: Converted to \(whisperAudio.count) samples at 16kHz")
        
        // Clear buffer
        let recordedAudio = whisperAudio
        audioBuffer.removeAll()
        
        // Post notification
        NotificationCenter.default.post(name: .recordingStopped, object: nil)
        
        return recordedAudio
    }
    
    /// Cancel recording without returning data
    func cancelRecording() {
        guard isRecording else { return }
        
        print("AudioRecorder: Cancelling recording...")
        
        stopDurationTimer()
        inputNode?.removeTap(onBus: 0)
        audioEngine?.stop()
        
        isRecording = false
        audioLevel = 0.0
        audioBuffer.removeAll()
        
        NotificationCenter.default.post(name: .recordingCancelled, object: nil)
    }
    
    // MARK: - Audio Buffer Processing
    
    /// Process incoming audio buffer from the tap
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        
        let frameCount = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)
        
        // Convert to mono if stereo (average channels)
        var monoSamples = [Float](repeating: 0, count: frameCount)
        
        if channelCount == 1 {
            // Already mono
            monoSamples = Array(UnsafeBufferPointer(start: channelData[0], count: frameCount))
        } else {
            // Mix down to mono
            for i in 0..<frameCount {
                var sum: Float = 0
                for ch in 0..<channelCount {
                    sum += channelData[ch][i]
                }
                monoSamples[i] = sum / Float(channelCount)
            }
        }
        
        // Append to buffer (on main thread for thread safety)
        Task { @MainActor in
            self.audioBuffer.append(contentsOf: monoSamples)
            
            // Update audio level (throttled)
            self.updateAudioLevel(samples: monoSamples)
            
            // Check max duration
            let currentDuration = Double(self.audioBuffer.count) / self.deviceSampleRate
            if currentDuration >= Constants.Limits.maxRecordingDuration {
                print("AudioRecorder: Max duration reached, stopping")
                try? await self.stopRecording()
            }
        }
    }
    
    // MARK: - Audio Level Metering
    
    /// Update the audio level for visualization (throttled to ~30 Hz for smoother animation)
    private func updateAudioLevel(samples: [Float]) {
        let now = Date()
        guard now.timeIntervalSince(lastLevelUpdateTime) >= levelUpdateInterval else {
            return // Throttle updates
        }
        lastLevelUpdateTime = now
        
        // Calculate RMS (Root Mean Square) level
        var rms: Float = 0
        vDSP_measqv(samples, 1, &rms, vDSP_Length(samples.count))
        rms = sqrt(rms)
        
        // Also calculate peak level for more responsiveness
        var peak: Float = 0
        vDSP_maxv(samples, 1, &peak, vDSP_Length(samples.count))
        peak = abs(peak)
        
        // Blend RMS and peak for balanced responsiveness
        // RMS gives average loudness, peak catches transients
        let blendedLevel = rms * 0.6 + peak * 0.4
        
        // Convert to a 0-1 range with improved scaling
        // Use a slight logarithmic curve for more natural perception
        let scaled = min(1.0, blendedLevel * 4.5)
        let scaledLevel = pow(scaled, 0.9) // Slight compression for better visual range
        
        // Apply asymmetric smoothing: fast attack, slower decay
        let currentLevel = audioLevel
        if scaledLevel > currentLevel {
            // Fast attack for responsiveness
            let attackSmoothing: Float = 0.5
            audioLevel = currentLevel + (scaledLevel - currentLevel) * attackSmoothing
        } else {
            // Slower decay for fluid animation
            let decaySmoothing: Float = 0.15
            audioLevel = currentLevel + (scaledLevel - currentLevel) * decaySmoothing
        }
    }
    
    // MARK: - Duration Timer
    
    private func startDurationTimer() {
        durationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, let startTime = self.recordingStartTime else { return }
                self.recordingDuration = Date().timeIntervalSince(startTime)
            }
        }
    }
    
    private func stopDurationTimer() {
        durationTimer?.invalidate()
        durationTimer = nil
    }
    
    // MARK: - Audio Format Conversion
    
    /// Convert audio from device sample rate to Whisper format (16kHz mono Float32)
    private func convertToWhisperFormat(_ samples: [Float], fromSampleRate sourceSampleRate: Double) throws -> [Float] {
        let targetSampleRate = Constants.Audio.whisperSampleRate
        
        // If already at target rate, return as-is
        if abs(sourceSampleRate - targetSampleRate) < 1.0 {
            return samples
        }
        
        // Calculate conversion ratio and output size
        let ratio = targetSampleRate / sourceSampleRate
        let outputLength = Int(Double(samples.count) * ratio)
        
        guard outputLength > 0 else {
            throw AudioRecorderError.conversionFailed("Invalid output length")
        }
        
        // Use vDSP for high-quality resampling
        var outputSamples = [Float](repeating: 0, count: outputLength)
        
        // Simple linear interpolation resampling
        // For production, consider using AVAudioConverter for better quality
        resampleLinear(input: samples, output: &outputSamples, ratio: ratio)
        
        return outputSamples
    }
    
    /// Linear interpolation resampling
    private func resampleLinear(input: [Float], output: inout [Float], ratio: Double) {
        let inputCount = input.count
        let outputCount = output.count
        
        for i in 0..<outputCount {
            let srcIndex = Double(i) / ratio
            let srcIndexInt = Int(srcIndex)
            let fraction = Float(srcIndex - Double(srcIndexInt))
            
            if srcIndexInt + 1 < inputCount {
                // Linear interpolation between two samples
                output[i] = input[srcIndexInt] * (1 - fraction) + input[srcIndexInt + 1] * fraction
            } else if srcIndexInt < inputCount {
                output[i] = input[srcIndexInt]
            }
        }
    }
    
    // MARK: - Available Microphones
    
    /// Get list of available audio input devices
    func getAvailableMicrophones() -> [(id: String, name: String)] {
        var microphones: [(id: String, name: String)] = []
        
        // Get all audio input devices (compatible with macOS 13.0+)
        let devices = AVCaptureDevice.devices(for: .audio)
        
        for device in devices {
            microphones.append((id: device.uniqueID, name: device.localizedName))
        }
        
        // Add system default as first option
        if !microphones.isEmpty {
            microphones.insert((id: "default", name: "System Default"), at: 0)
        }
        
        return microphones
    }
    
    // MARK: - Utility
    
    /// Get formatted duration string
    var formattedDuration: String {
        let minutes = Int(recordingDuration) / 60
        let seconds = Int(recordingDuration) % 60
        let tenths = Int((recordingDuration.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%d:%02d.%d", minutes, seconds, tenths)
    }
    
    /// Check if recording is approaching max duration
    var isApproachingMaxDuration: Bool {
        recordingDuration >= Constants.Limits.maxRecordingDuration - 30 // 30 seconds warning
    }
}


// MARK: - Notification Names

extension Notification.Name {
    static let recordingStarted = Notification.Name("com.whispertype.recordingStarted")
    static let recordingStopped = Notification.Name("com.whispertype.recordingStopped")
    static let recordingCancelled = Notification.Name("com.whispertype.recordingCancelled")
}
