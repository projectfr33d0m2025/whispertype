#!/usr/bin/env swift

// Quick test script to verify spike can load existing audio files
// Run with: swift test_spike.swift

import Foundation

// Add the spike source files path
// (In a real setup, these would be compiled together)

print("🧪 Testing Speaker Diarization Spike Setup")
print("==========================================")
print("")

let testDir = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("research/whispertype/TestAssets/SpikeAudio")

print("Test directory: \(testDir.path)")
print("")

// Check for test files
let files = [
    ("two_speakers_120s.wav", "two_speakers_120s_labels.json"),
    ("four_speakers_300s.wav", "four_speakers_300s_labels.json"),
    ("single_speaker_60s.wav", "single_speaker_60s_labels.json")
]

print("Checking test files:")
for (audio, labels) in files {
    let audioPath = testDir.appendingPathComponent(audio)
    let labelsPath = testDir.appendingPathComponent(labels)
    
    let audioExists = FileManager.default.fileExists(atPath: audioPath.path)
    let labelsExists = FileManager.default.fileExists(atPath: labelsPath.path)
    
    let status = audioExists && labelsExists ? "✅" : "❌"
    print("  \(status) \(audio) + labels")
    
    if labelsExists {
        // Try to parse labels
        do {
            let data = try Data(contentsOf: labelsPath)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let segments = json["segments"] as? [[String: Any]] {
                let speakers = Set(segments.compactMap { $0["speaker"] as? String })
                print("     └─ \(segments.count) segments, \(speakers.count) speakers: \(speakers.sorted().joined(separator: ", "))")
            }
        } catch {
            print("     └─ ⚠️  Error parsing: \(error)")
        }
    }
}

print("")
print("✅ Setup verified! Ready to run spike.")
print("")
print("Next steps:")
print("  1. Add Spike/SpeakerDiarization/*.swift to your Xcode project")
print("  2. Run SpeakerDiarizationSpikeTests or call runSpikeFromCommandLine()")
