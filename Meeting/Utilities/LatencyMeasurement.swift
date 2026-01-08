//
//  LatencyMeasurement.swift
//  WhisperType
//
//  Utility for measuring audio-to-transcript latency.
//

import Foundation

/// A single latency measurement record
struct LatencyRecord: Identifiable {
    let id: UUID
    let audioTimestamp: TimeInterval
    let audioCaptureTime: Date
    let transcriptReceiveTime: Date
    
    /// Time from audio capture to transcript production
    var latency: TimeInterval {
        transcriptReceiveTime.timeIntervalSince(audioCaptureTime)
    }
    
    init(
        id: UUID = UUID(),
        audioTimestamp: TimeInterval,
        audioCaptureTime: Date,
        transcriptReceiveTime: Date = Date()
    ) {
        self.id = id
        self.audioTimestamp = audioTimestamp
        self.audioCaptureTime = audioCaptureTime
        self.transcriptReceiveTime = transcriptReceiveTime
    }
}

/// Latency measurement collector and analyzer
class LatencyMeasurement: ObservableObject {
    
    // MARK: - Published Properties
    
    /// All recorded latency measurements
    @Published private(set) var records: [LatencyRecord] = []
    
    /// Current average latency
    @Published private(set) var averageLatency: TimeInterval = 0
    
    /// Maximum observed latency
    @Published private(set) var maxLatency: TimeInterval = 0
    
    /// Minimum observed latency
    @Published private(set) var minLatency: TimeInterval = .infinity
    
    // MARK: - Configuration
    
    /// Target latency threshold (default 5 seconds per PRD)
    let targetLatency: TimeInterval
    
    // MARK: - Initialization
    
    init(targetLatency: TimeInterval = 5.0) {
        self.targetLatency = targetLatency
    }
    
    // MARK: - Recording
    
    /// Record a new latency measurement
    /// - Parameters:
    ///   - audioTimestamp: Timestamp of the audio chunk being transcribed
    ///   - audioCaptureTime: When the audio was captured
    ///   - transcriptReceiveTime: When the transcript was received
    func record(
        audioTimestamp: TimeInterval,
        audioCaptureTime: Date,
        transcriptReceiveTime: Date = Date()
    ) {
        let record = LatencyRecord(
            audioTimestamp: audioTimestamp,
            audioCaptureTime: audioCaptureTime,
            transcriptReceiveTime: transcriptReceiveTime
        )
        
        records.append(record)
        updateStatistics()
        
        print("LatencyMeasurement: Recorded \(String(format: "%.2f", record.latency))s latency")
    }
    
    /// Record latency directly (for simpler use cases)
    func recordLatency(_ latency: TimeInterval, audioTimestamp: TimeInterval = 0) {
        let now = Date()
        let captureTime = now.addingTimeInterval(-latency)
        record(audioTimestamp: audioTimestamp, audioCaptureTime: captureTime, transcriptReceiveTime: now)
    }
    
    // MARK: - Statistics
    
    private func updateStatistics() {
        guard !records.isEmpty else {
            averageLatency = 0
            maxLatency = 0
            minLatency = .infinity
            return
        }
        
        let latencies = records.map { $0.latency }
        averageLatency = latencies.reduce(0, +) / Double(latencies.count)
        maxLatency = latencies.max() ?? 0
        minLatency = latencies.min() ?? .infinity
    }
    
    /// Check if average latency meets target
    var meetsTarget: Bool {
        averageLatency <= targetLatency
    }
    
    /// Percentage of measurements meeting target
    var targetComplianceRate: Double {
        guard !records.isEmpty else { return 1.0 }
        let passing = records.filter { $0.latency <= targetLatency }.count
        return Double(passing) / Double(records.count)
    }
    
    // MARK: - Reset
    
    /// Clear all measurements
    func reset() {
        records = []
        averageLatency = 0
        maxLatency = 0
        minLatency = .infinity
    }
    
    // MARK: - Summary
    
    /// Generate a summary report
    var summary: String {
        guard !records.isEmpty else {
            return "No latency measurements recorded"
        }
        
        return """
        Latency Summary:
        - Measurements: \(records.count)
        - Average: \(String(format: "%.2f", averageLatency))s
        - Min: \(String(format: "%.2f", minLatency))s
        - Max: \(String(format: "%.2f", maxLatency))s
        - Target (\(String(format: "%.1f", targetLatency))s): \(meetsTarget ? "✅ PASS" : "❌ FAIL")
        - Compliance: \(String(format: "%.1f", targetComplianceRate * 100))%
        """
    }
}
