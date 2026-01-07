//
//  SystemAudioCapture.swift
//  WhisperType
//
//  Captures system audio using ScreenCaptureKit.
//  Requires macOS 12.3+ and Screen Recording permission.
//

import Foundation
import ScreenCaptureKit
import AVFoundation
import Combine

/// Errors specific to system audio capture
enum SystemAudioCaptureError: LocalizedError {
    case permissionDenied
    case permissionNotDetermined
    case screenCaptureNotAvailable
    case noContentToCapture
    case configurationFailed(String)
    case captureStartFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Screen Recording permission denied"
        case .permissionNotDetermined:
            return "Screen Recording permission not yet requested"
        case .screenCaptureNotAvailable:
            return "ScreenCaptureKit not available on this system"
        case .noContentToCapture:
            return "No content available to capture"
        case .configurationFailed(let message):
            return "Stream configuration failed: \(message)"
        case .captureStartFailed(let message):
            return "Capture start failed: \(message)"
        }
    }
}

/// Permission state for screen recording
enum ScreenRecordingPermission: Equatable {
    case notDetermined
    case granted
    case denied
}

/// Delegate protocol for receiving captured audio
protocol SystemAudioCaptureDelegate: AnyObject {
    func systemAudioCapture(_ capture: SystemAudioCapture, didReceiveSamples samples: [Float], timestamp: TimeInterval)
    func systemAudioCapture(_ capture: SystemAudioCapture, didReceiveLevel level: Float)
    func systemAudioCapture(_ capture: SystemAudioCapture, didFailWithError error: Error)
}

/// Captures system audio using ScreenCaptureKit
@available(macOS 12.3, *)
@MainActor
class SystemAudioCapture: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    
    /// Current permission state
    @Published private(set) var permissionState: ScreenRecordingPermission = .notDetermined
    
    /// Whether capture is currently active
    @Published private(set) var isCapturing = false
    
    /// Current audio level in dB
    @Published private(set) var audioLevel: Float = -60.0
    
    // MARK: - Delegate
    
    weak var delegate: SystemAudioCaptureDelegate?
    
    // MARK: - Private Properties
    
    private var stream: SCStream?
    private var streamOutput: SystemAudioStreamOutput?
    private var captureStartTime: Date?
    
    /// Target sample rate for output
    private let targetSampleRate: Double = Constants.Audio.meetingSampleRate
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        print("SystemAudioCapture: Initialized")
    }
    
    deinit {
        // Cleanup handled by stopCapture()
    }
    
    // MARK: - Permission Handling
    
    /// Check current permission state
    func checkPermission() async -> ScreenRecordingPermission {
        // ScreenCaptureKit doesn't have explicit permission check API
        // We detect permission by attempting to get shareable content
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            
            // If we get content, permission is granted
            if !content.displays.isEmpty || !content.windows.isEmpty {
                permissionState = .granted
                print("SystemAudioCapture: Permission granted")
                return .granted
            } else {
                // No content but no error - unusual state
                permissionState = .granted
                return .granted
            }
        } catch {
            // Permission denied or error
            let nsError = error as NSError
            if nsError.code == -3801 { // SCStreamErrorUserDeclined
                permissionState = .denied
                print("SystemAudioCapture: Permission denied")
                return .denied
            } else {
                // Could be first time - treat as not determined
                permissionState = .notDetermined
                print("SystemAudioCapture: Permission not determined - \(error)")
                return .notDetermined
            }
        }
    }
    
    /// Request permission by triggering the system prompt
    /// Returns true if permission is granted after the request
    func requestPermission() async -> Bool {
        // Trigger permission request by attempting to get content
        let state = await checkPermission()
        
        if state == .granted {
            return true
        }
        
        // If not determined, the system should show permission dialog
        // Try again after a short delay to see if user granted
        if state == .notDetermined {
            try? await Task.sleep(nanoseconds: 500_000_000)
            let newState = await checkPermission()
            return newState == .granted
        }
        
        return false
    }
    
    /// Open System Settings to Screen Recording permissions
    func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }
    
    // MARK: - Capture Control
    
    /// Start capturing system audio
    func startCapture() async throws {
        guard !isCapturing else {
            print("SystemAudioCapture: Already capturing")
            return
        }
        
        // Check permission first
        let permission = await checkPermission()
        guard permission == .granted else {
            throw SystemAudioCaptureError.permissionDenied
        }
        
        // Get shareable content
        let content: SCShareableContent
        do {
            content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
        } catch {
            throw SystemAudioCaptureError.noContentToCapture
        }
        
        // Use the first display for capture (audio is system-wide)
        guard let display = content.displays.first else {
            throw SystemAudioCaptureError.noContentToCapture
        }
        
        // Configure stream filter for audio-only
        let filter = SCContentFilter(display: display, excludingWindows: [])
        
        // Configure stream for audio only
        let configuration = SCStreamConfiguration()
        
        // Disable video capture (we only want audio)
        configuration.width = 2  // Minimum required
        configuration.height = 2
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: 1) // 1 FPS (minimum)
        configuration.showsCursor = false
        
        // Enable audio capture
        configuration.capturesAudio = true
        configuration.excludesCurrentProcessAudio = true // Don't capture our own app
        configuration.sampleRate = Int(targetSampleRate)
        configuration.channelCount = 1 // Mono
        
        // Create stream
        let stream = SCStream(filter: filter, configuration: configuration, delegate: nil)
        self.stream = stream
        
        // Create and add stream output
        let output = SystemAudioStreamOutput(targetSampleRate: targetSampleRate) { [weak self] samples, timestamp in
            self?.handleAudioSamples(samples, timestamp: timestamp)
        }
        self.streamOutput = output
        
        do {
            try stream.addStreamOutput(output, type: .audio, sampleHandlerQueue: .global(qos: .userInteractive))
        } catch {
            throw SystemAudioCaptureError.configurationFailed(error.localizedDescription)
        }
        
        // Start capture
        do {
            try await stream.startCapture()
            captureStartTime = Date()
            isCapturing = true
            print("SystemAudioCapture: Capture started")
        } catch {
            self.stream = nil
            self.streamOutput = nil
            throw SystemAudioCaptureError.captureStartFailed(error.localizedDescription)
        }
    }
    
    /// Stop capturing system audio
    func stopCapture() {
        guard isCapturing else { return }
        
        Task {
            do {
                try await stream?.stopCapture()
            } catch {
                print("SystemAudioCapture: Error stopping capture - \(error)")
            }
            
            stream = nil
            streamOutput = nil
            isCapturing = false
            captureStartTime = nil
            audioLevel = -60.0
            
            print("SystemAudioCapture: Capture stopped")
        }
    }
    
    // MARK: - Audio Processing
    
    private func handleAudioSamples(_ samples: [Float], timestamp: TimeInterval) {
        // Calculate audio level
        let rms = calculateRMS(samples)
        let dB = 20 * log10(max(rms, 1e-7))
        
        Task { @MainActor in
            self.audioLevel = dB
        }
        
        // Notify delegate
        delegate?.systemAudioCapture(self, didReceiveSamples: samples, timestamp: timestamp)
        delegate?.systemAudioCapture(self, didReceiveLevel: dB)
    }
    
    private func calculateRMS(_ samples: [Float]) -> Float {
        guard !samples.isEmpty else { return 0 }
        let sumOfSquares = samples.reduce(0) { $0 + $1 * $1 }
        return sqrt(sumOfSquares / Float(samples.count))
    }
}

// MARK: - Stream Output Handler

@available(macOS 12.3, *)
private class SystemAudioStreamOutput: NSObject, SCStreamOutput {
    
    private let targetSampleRate: Double
    private let onAudioReceived: ([Float], TimeInterval) -> Void
    private var converter: AVAudioConverter?
    private var startTime: Date?
    
    init(targetSampleRate: Double, onAudioReceived: @escaping ([Float], TimeInterval) -> Void) {
        self.targetSampleRate = targetSampleRate
        self.onAudioReceived = onAudioReceived
        super.init()
    }
    
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        // Only process audio
        guard type == .audio else { return }
        
        // Set start time on first sample
        if startTime == nil {
            startTime = Date()
        }
        
        // Extract audio samples
        guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { return }
        
        var length: Int = 0
        var dataPointer: UnsafeMutablePointer<Int8>?
        
        guard CMBlockBufferGetDataPointer(blockBuffer, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: &length, dataPointerOut: &dataPointer) == noErr,
              let dataPointer = dataPointer else {
            return
        }
        
        // Get format description
        guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer) else { return }
        let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription)?.pointee
        
        // Convert to Float samples based on format
        var samples: [Float] = []
        
        if let asbd = asbd {
            if asbd.mFormatFlags & kAudioFormatFlagIsFloat != 0 {
                // Already float
                let floatPointer = UnsafeRawPointer(dataPointer).bindMemory(to: Float.self, capacity: length / 4)
                samples = Array(UnsafeBufferPointer(start: floatPointer, count: length / MemoryLayout<Float>.size))
            } else if asbd.mBitsPerChannel == 16 {
                // Int16 format
                let int16Pointer = UnsafeRawPointer(dataPointer).bindMemory(to: Int16.self, capacity: length / 2)
                let int16Samples = Array(UnsafeBufferPointer(start: int16Pointer, count: length / MemoryLayout<Int16>.size))
                samples = int16Samples.map { Float($0) / Float(Int16.max) }
            } else if asbd.mBitsPerChannel == 32 {
                // Int32 format
                let int32Pointer = UnsafeRawPointer(dataPointer).bindMemory(to: Int32.self, capacity: length / 4)
                let int32Samples = Array(UnsafeBufferPointer(start: int32Pointer, count: length / MemoryLayout<Int32>.size))
                samples = int32Samples.map { Float($0) / Float(Int32.max) }
            }
        }
        
        guard !samples.isEmpty else { return }
        
        // Calculate timestamp
        let timestamp = startTime.map { Date().timeIntervalSince($0) } ?? 0
        
        // Deliver samples
        onAudioReceived(samples, timestamp)
    }
}
