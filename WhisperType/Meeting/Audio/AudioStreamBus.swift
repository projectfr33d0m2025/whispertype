//
//  AudioStreamBus.swift
//  WhisperType
//
//  Combine-based publisher for distributing audio chunks to multiple subscribers.
//  Enables real-time streaming to disk writer, live subtitles, and level meter.
//

import Foundation
import Combine

/// Central bus for distributing audio chunks and levels to multiple subscribers
/// Uses Combine for reactive, efficient multicast publishing
@MainActor
class AudioStreamBus: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = AudioStreamBus()
    
    // MARK: - Published Properties
    
    /// Current audio level for UI display
    @Published private(set) var currentLevel: AudioLevel = .silent
    
    /// Whether the bus is currently active (receiving audio)
    @Published private(set) var isActive: Bool = false
    
    /// Total chunks published since start
    @Published private(set) var chunkCount: Int = 0
    
    // MARK: - Publishers
    
    /// Subject for audio chunks - multicast to all subscribers
    private let chunkSubject = PassthroughSubject<AudioChunk, Never>()
    
    /// Subject for audio levels - multicast to all subscribers
    private let levelSubject = PassthroughSubject<AudioLevel, Never>()
    
    /// Public publisher for audio chunks
    var chunkPublisher: AnyPublisher<AudioChunk, Never> {
        chunkSubject.eraseToAnyPublisher()
    }
    
    /// Public publisher for audio levels
    var levelPublisher: AnyPublisher<AudioLevel, Never> {
        levelSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    private init() {
        print("AudioStreamBus: Initialized")
        
        // Update current level when new levels are published
        levelSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] level in
                self?.currentLevel = level
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    /// Start the audio stream bus
    func start() {
        guard !isActive else { return }
        
        isActive = true
        chunkCount = 0
        currentLevel = .silent
        
        print("AudioStreamBus: Started")
    }
    
    /// Stop the audio stream bus
    func stop() {
        guard isActive else { return }
        
        isActive = false
        currentLevel = .silent
        
        print("AudioStreamBus: Stopped - Published \(chunkCount) chunks")
    }
    
    /// Publish an audio chunk to all subscribers
    /// - Parameter chunk: The audio chunk to publish
    func publish(chunk: AudioChunk) {
        guard isActive else {
            print("AudioStreamBus: Warning - Attempt to publish chunk while inactive")
            return
        }
        
        chunkCount += 1
        chunkSubject.send(chunk)
        
        print("AudioStreamBus: Published chunk \(chunkCount) - \(chunk.sampleCount) samples, duration: \(String(format: "%.2f", chunk.duration))s")
    }
    
    /// Publish an audio level to all subscribers
    /// - Parameter level: The audio level to publish
    func publish(level: AudioLevel) {
        guard isActive else { return }
        
        levelSubject.send(level)
    }
    
    /// Reset the bus state (for testing or fresh start)
    func reset() {
        stop()
        chunkCount = 0
        currentLevel = .silent
        print("AudioStreamBus: Reset")
    }
}

// MARK: - Subscriber Protocol

/// Protocol for objects that want to subscribe to audio chunks
protocol AudioChunkSubscriber: AnyObject {
    /// Handle an incoming audio chunk
    func handleChunk(_ chunk: AudioChunk)
    
    /// Called when the audio stream starts
    func audioStreamDidStart()
    
    /// Called when the audio stream stops
    func audioStreamDidStop()
}

/// Protocol for objects that want to subscribe to audio levels
protocol AudioLevelSubscriber: AnyObject {
    /// Handle an incoming audio level update
    func handleLevel(_ level: AudioLevel)
}

// MARK: - Default Implementations

extension AudioChunkSubscriber {
    func audioStreamDidStart() {}
    func audioStreamDidStop() {}
}

// MARK: - AudioStreamBus Extensions

extension AudioStreamBus {
    
    /// Subscribe to audio chunks with a handler closure
    /// - Parameter handler: Closure called for each chunk
    /// - Returns: AnyCancellable to manage the subscription
    func subscribeToChunks(handler: @escaping (AudioChunk) -> Void) -> AnyCancellable {
        chunkPublisher
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: handler)
    }
    
    /// Subscribe to audio levels with a handler closure
    /// - Parameter handler: Closure called for each level update
    /// - Returns: AnyCancellable to manage the subscription
    func subscribeToLevels(handler: @escaping (AudioLevel) -> Void) -> AnyCancellable {
        levelPublisher
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: handler)
    }
    
    /// Subscribe an AudioChunkSubscriber to receive chunks
    /// - Parameter subscriber: The subscriber to add
    /// - Returns: AnyCancellable to manage the subscription
    func subscribe(_ subscriber: AudioChunkSubscriber) -> AnyCancellable {
        let cancellable = chunkPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak subscriber] chunk in
                subscriber?.handleChunk(chunk)
            }
        
        if isActive {
            subscriber.audioStreamDidStart()
        }
        
        return cancellable
    }
    
    /// Subscribe an AudioLevelSubscriber to receive levels
    /// - Parameter subscriber: The subscriber to add
    /// - Returns: AnyCancellable to manage the subscription
    func subscribe(_ subscriber: AudioLevelSubscriber) -> AnyCancellable {
        levelPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak subscriber] level in
                subscriber?.handleLevel(level)
            }
    }
}
