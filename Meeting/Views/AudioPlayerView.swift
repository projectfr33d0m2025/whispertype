//
//  AudioPlayerView.swift
//  WhisperType
//
//  Audio player component for playing WAV meeting recordings.
//

import SwiftUI
import AVFoundation

// MARK: - Audio Player View Model

@MainActor
class AudioPlayerViewModel: ObservableObject {
    @Published var isPlaying: Bool = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var errorMessage: String?
    @Published var currentlyPlayingURL: URL?
    
    private var audioPlayer: AVAudioPlayer?
    private var timer: Timer?
    
    deinit {
        stop()
    }
    
    func loadAudio(url: URL) {
        stop()
        errorMessage = nil
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.prepareToPlay()
            duration = audioPlayer?.duration ?? 0
            currentlyPlayingURL = url
        } catch {
            errorMessage = "Unable to load audio file: \(error.localizedDescription)"
            print("AudioPlayerViewModel: Failed to load audio - \(error)")
        }
    }
    
    func play() {
        guard let player = audioPlayer else { return }
        
        player.play()
        isPlaying = true
        startTimer()
    }
    
    func pause() {
        audioPlayer?.pause()
        isPlaying = false
        stopTimer()
    }
    
    func stop() {
        audioPlayer?.stop()
        audioPlayer?.currentTime = 0
        isPlaying = false
        currentTime = 0
        currentlyPlayingURL = nil
        stopTimer()
    }
    
    func seek(to time: TimeInterval) {
        audioPlayer?.currentTime = time
        currentTime = time
    }
    
    // MARK: - Private Methods
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let player = self.audioPlayer else { return }
            
            self.currentTime = player.currentTime
            
            // Auto-stop when finished
            if !player.isPlaying && self.isPlaying {
                self.stop()
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

// MARK: - Audio Player View

struct AudioPlayerView: View {
    @StateObject private var viewModel: AudioPlayerViewModel
    let audioURL: URL
    let chunkName: String
    
    init(audioURL: URL, chunkName: String, viewModel: AudioPlayerViewModel? = nil) {
        self.audioURL = audioURL
        self.chunkName = chunkName
        _viewModel = StateObject(wrappedValue: viewModel ?? AudioPlayerViewModel())
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Play/Pause button
            Button {
                if viewModel.currentlyPlayingURL != audioURL {
                    viewModel.loadAudio(url: audioURL)
                    viewModel.play()
                } else {
                    if viewModel.isPlaying {
                        viewModel.pause()
                    } else {
                        viewModel.play()
                    }
                }
            } label: {
                Image(systemName: (viewModel.currentlyPlayingURL == audioURL && viewModel.isPlaying) ? "pause.circle.fill" : "play.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.tint)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.errorMessage != nil)
            
            // Stop button
            Button {
                if viewModel.currentlyPlayingURL == audioURL {
                    viewModel.stop()
                }
            } label: {
                Image(systemName: "stop.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.currentlyPlayingURL != audioURL)
            
            VStack(alignment: .leading, spacing: 4) {
                // Chunk name
                Text(chunkName)
                    .font(.body)
                
                // Progress and time
                if viewModel.currentlyPlayingURL == audioURL {
                    HStack(spacing: 8) {
                        Text(formatTime(viewModel.currentTime))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                        
                        Slider(
                            value: Binding(
                                get: { viewModel.currentTime },
                                set: { viewModel.seek(to: $0) }
                            ),
                            in: 0...max(viewModel.duration, 1)
                        )
                        .controlSize(.small)
                        
                        Text(formatTime(viewModel.duration))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                } else {
                    // Show duration when not playing
                    if let duration = getAudioDuration(url: audioURL) {
                        Text(formatTime(duration))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(viewModel.currentlyPlayingURL == audioURL ? Color.accentColor.opacity(0.1) : Color.secondary.opacity(0.05))
        )
        .overlay(
            Group {
                if let error = viewModel.errorMessage {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                }
            }
        )
    }
    
    // MARK: - Helpers
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func getAudioDuration(url: URL) -> TimeInterval? {
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            return player.duration
        } catch {
            return nil
        }
    }
}

// MARK: - Preview

#Preview {
    VStack {
        AudioPlayerView(
            audioURL: URL(fileURLWithPath: "/tmp/test.wav"),
            chunkName: "Chunk 1: 00:00 - 00:30"
        )
        
        AudioPlayerView(
            audioURL: URL(fileURLWithPath: "/tmp/test2.wav"),
            chunkName: "Chunk 2: 00:30 - 01:00"
        )
    }
    .padding()
    .frame(width: 500)
}
