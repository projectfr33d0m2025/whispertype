//
//  LiveSubtitleWindow.swift
//  WhisperType
//
//  NSPanel wrapper for floating live subtitle window during meeting recording.
//  Uses singleton pattern to prevent autorelease pool crashes from SwiftUI view deallocation.
//

import AppKit
import SwiftUI
import Combine

/// Manages the floating live subtitle window
/// SINGLETON: This class is reused across sessions to prevent autorelease pool crashes.
/// When SwiftUI views with @Published state are deallocated, they create autoreleased
/// objects that can become zombies if the object graph is complex.
@MainActor
class LiveSubtitleWindow {
    
    // MARK: - Singleton
    
    /// Shared instance - window is reused across sessions
    static let shared = LiveSubtitleWindow()
    
    // MARK: - Constants
    
    private static let defaultWidth: CGFloat = 500
    private static let defaultHeight: CGFloat = 300
    private static let minWidth: CGFloat = 300
    private static let minHeight: CGFloat = 150
    
    private static let positionKey = "LiveSubtitleWindow.position"
    private static let sizeKey = "LiveSubtitleWindow.size"
    
    // MARK: - Properties
    
    private var panel: NSPanel?
    private var hostingView: NSHostingView<LiveSubtitleView>?
    
    /// State shared with SwiftUI view - persists across sessions
    let state = LiveSubtitleViewState()
    
    /// Whether the window is currently visible
    private(set) var isVisible = false
    
    /// Subscription to streaming processor updates
    private var processorSubscription: AnyCancellable?
    private var durationSubscription: AnyCancellable?
    
    /// Panel delegate - must be stored as strong reference to prevent deallocation
    private var panelDelegate: PanelDelegate?
    
    // MARK: - Initialization
    
    private init() {
        print("LiveSubtitleWindow: init (singleton)")
        setupPanel()
    }
    
    // MARK: - Panel Setup
    
    private func setupPanel() {
        // Load saved position and size
        let savedRect = loadSavedFrame() ?? defaultFrame()
        
        // Create the panel
        let panel = NSPanel(
            contentRect: savedRect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .nonactivatingPanel, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        
        // Configure panel properties
        panel.title = "Live Transcript"
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        
        // Set minimum size
        panel.minSize = NSSize(width: Self.minWidth, height: Self.minHeight)
        
        // Create SwiftUI view
        let view = LiveSubtitleView(
            state: state,
            onClose: { [weak self] in self?.hide() },
            onMinimize: { [weak self] in self?.minimize() }
        )
        
        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = panel.contentView?.bounds ?? .zero
        hostingView.autoresizingMask = [.width, .height]
        
        // Apply visual effect for translucency
        if let contentView = panel.contentView {
            let visualEffect = NSVisualEffectView(frame: contentView.bounds)
            visualEffect.autoresizingMask = [.width, .height]
            visualEffect.blendingMode = .behindWindow
            visualEffect.material = .popover
            visualEffect.state = .active
            
            contentView.addSubview(visualEffect)
            contentView.addSubview(hostingView)
        }
        
        // Handle window close - store delegate as property to prevent deallocation
        let delegate = PanelDelegate(onClose: { [weak self] in
            self?.saveFrame()
            self?.isVisible = false
        })
        self.panelDelegate = delegate
        panel.delegate = delegate
        
        self.panel = panel
        self.hostingView = hostingView
        
        print("LiveSubtitleWindow: Panel setup complete")
    }
    
    // MARK: - Frame Persistence
    
    private func defaultFrame() -> NSRect {
        guard let screen = NSScreen.main else {
            return NSRect(x: 100, y: 100, width: Self.defaultWidth, height: Self.defaultHeight)
        }
        
        // Position at bottom-right of screen
        let screenFrame = screen.visibleFrame
        let x = screenFrame.maxX - Self.defaultWidth - 20
        let y = screenFrame.minY + 20
        
        return NSRect(x: x, y: y, width: Self.defaultWidth, height: Self.defaultHeight)
    }
    
    private func loadSavedFrame() -> NSRect? {
        let defaults = UserDefaults.standard
        
        guard let positionData = defaults.data(forKey: Self.positionKey),
              let sizeData = defaults.data(forKey: Self.sizeKey),
              let position = try? JSONDecoder().decode(CGPoint.self, from: positionData),
              let size = try? JSONDecoder().decode(CGSize.self, from: sizeData) else {
            return nil
        }
        
        return NSRect(origin: position, size: size)
    }
    
    private func saveFrame() {
        guard let panel = panel else { return }
        
        let defaults = UserDefaults.standard
        let frame = panel.frame
        
        if let positionData = try? JSONEncoder().encode(frame.origin),
           let sizeData = try? JSONEncoder().encode(frame.size) {
            defaults.set(positionData, forKey: Self.positionKey)
            defaults.set(sizeData, forKey: Self.sizeKey)
        }
        
        print("LiveSubtitleWindow: Saved frame")
    }
    
    // MARK: - Show/Hide
    
    /// Show the subtitle window and reset state for new session
    func show() {
        guard let panel = panel else { return }
        guard !isVisible else { return }
        
        print("LiveSubtitleWindow: Showing")
        
        // Reset state for new session
        state.updates = []
        state.isRecording = true
        state.isAutoScrollEnabled = true
        state.elapsedTime = 0
        
        // Animate in
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }
        
        isVisible = true
    }
    
    /// Hide the subtitle window (synchronous - no animation to prevent race conditions)
    func hide() {
        guard let panel = panel else { return }
        guard isVisible else { return }
        
        print("LiveSubtitleWindow: Hiding")
        
        saveFrame()
        
        // Synchronous hide - no animation to prevent race conditions during cleanup
        panel.alphaValue = 0
        panel.orderOut(nil)
        
        isVisible = false
    }
    
    /// Minimize the window
    func minimize() {
        panel?.miniaturize(nil)
    }
    
    /// Toggle visibility
    func toggle() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }
    
    // MARK: - Streaming Processor Integration
    
    /// Connect to a streaming processor to receive updates
    func connectToProcessor(_ processor: StreamingWhisperProcessor) {
        print("LiveSubtitleWindow: Connecting to processor \(ObjectIdentifier(processor))")
        
        // Cancel any existing subscription first
        processorSubscription?.cancel()
        
        // Subscribe to transcript updates
        processorSubscription = processor.$transcriptUpdates
            .receive(on: DispatchQueue.main)
            .sink { [weak self] updates in
                self?.state.updates = updates
            }
        print("LiveSubtitleWindow: processorSubscription created")
    }
    
    /// Connect to meeting coordinator for duration updates
    func connectToCoordinator(_ coordinator: MeetingCoordinator) {
        print("LiveSubtitleWindow: Connecting to coordinator for duration")
        
        // Cancel any existing subscription first
        durationSubscription?.cancel()
        
        // Subscribe directly to coordinator's currentDuration
        durationSubscription = coordinator.$currentDuration
            .receive(on: DispatchQueue.main)
            .sink { [weak self] duration in
                self?.state.elapsedTime = duration
            }
        print("LiveSubtitleWindow: durationSubscription created")
    }
    
    /// Disconnect subscriptions (but don't deallocate - this is a singleton)
    func disconnect() {
        print("LiveSubtitleWindow: disconnect() - cancelling subscriptions")
        processorSubscription?.cancel()
        processorSubscription = nil
        durationSubscription?.cancel()
        durationSubscription = nil
        
        // Mark as not recording but DON'T clear the state completely
        // The window stays alive, just hidden
        state.isRecording = false
        
        print("LiveSubtitleWindow: subscriptions cancelled")
    }
    
    // MARK: - State Updates
    
    /// Add a transcript update
    func addUpdate(_ update: TranscriptUpdate) {
        state.updates.append(update)
    }
    
    /// Update elapsed time
    func updateElapsedTime(_ time: TimeInterval) {
        state.elapsedTime = time
    }
    
    /// Set recording state
    func setRecording(_ isRecording: Bool) {
        state.isRecording = isRecording
    }
    
    // NOTE: No deinit logging - this singleton should NEVER be deallocated
}

// MARK: - Panel Delegate

private class PanelDelegate: NSObject, NSWindowDelegate {
    let onClose: () -> Void
    
    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }
    
    func windowWillClose(_ notification: Notification) {
        onClose()
    }
}
