//
//  LiveSubtitleWindow.swift
//  WhisperType
//
//  NSPanel wrapper for floating live subtitle window during meeting recording.
//

import AppKit
import SwiftUI
import Combine

/// Manages the floating live subtitle window
@MainActor
class LiveSubtitleWindow {
    
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
    
    /// State shared with SwiftUI view
    let state = LiveSubtitleViewState()
    
    /// Whether the window is currently visible
    private(set) var isVisible = false
    
    /// Subscription to streaming processor updates
    private var processorSubscription: AnyCancellable?
    private var durationSubscription: AnyCancellable?
    
    /// Panel delegate - must be stored as strong reference to prevent deallocation
    private var panelDelegate: PanelDelegate?
    
    // MARK: - Initialization
    
    init() {
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
    
    /// Show the subtitle window
    func show() {
        guard let panel = panel else { return }
        guard !isVisible else { return }
        
        print("LiveSubtitleWindow: Showing")
        
        // Reset state
        state.updates = []
        state.isRecording = true
        state.isAutoScrollEnabled = true
        
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
    
    /// Prepare for shutdown - clears state safely before disconnect
    func prepareForShutdown() {
        // Clear state first while subscriptions are still valid
        state.updates = []
        state.isRecording = false
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
        // Subscribe to transcript updates
        processorSubscription = processor.$transcriptUpdates
            .receive(on: DispatchQueue.main)
            .sink { [weak self] updates in
                self?.state.updates = updates
            }
    }
    
    /// Connect to meeting coordinator for duration updates
    func connectToCoordinator(_ coordinator: MeetingCoordinator) {
        // Subscribe to the current session's duration property
        // Use flatMap to follow the session and then its duration changes
        durationSubscription = coordinator.$currentSession
            .compactMap { $0 }  // Only non-nil sessions
            .flatMap { $0.$duration }  // Subscribe to the session's duration publisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] duration in
                self?.state.elapsedTime = duration
            }
    }
    
    /// Disconnect from processor
    func disconnect() {
        processorSubscription?.cancel()
        processorSubscription = nil
        durationSubscription?.cancel()
        durationSubscription = nil
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
    
    // MARK: - Cleanup
    
    func cleanup() {
        saveFrame()
        disconnect()
        
        // CRITICAL FIX for autorelease pool crash:
        // The SwiftUI view observes 'state' via @ObservedObject. If we deallocate
        // the hostingView while it's still observing state, the Combine observers
        // create autoreleased objects that become invalid. This causes a crash
        // when the autorelease pool drains at the end of the run loop cycle.
        //
        // Fix: Properly tear down the view hierarchy BEFORE releasing references,
        // then defer the final nil-out to the NEXT run loop cycle.
        
        // 1. Clear state's @Published properties to disconnect Combine observers
        state.updates = []
        state.isRecording = false
        state.elapsedTime = 0
        
        // 2. Remove hosting view from superview to break SwiftUI observation
        hostingView?.removeFromSuperview()
        
        // 3. Clear delegate references
        panel?.delegate = nil
        panelDelegate = nil
        
        // 4. Close and order out the panel
        panel?.orderOut(nil)
        
        // 5. CRITICAL: Defer the final reference cleanup to the NEXT run loop cycle
        //    This allows the current autorelease pool to drain completely before
        //    our references are released, preventing use-after-free during drain.
        let hostingViewToRelease = hostingView
        let panelToRelease = panel
        hostingView = nil
        panel = nil
        
        DispatchQueue.main.async {
            // These references are now released on the next run loop cycle
            _ = hostingViewToRelease
            _ = panelToRelease
        }
    }
    
    deinit {
        print("LiveSubtitleWindow: Deinit")
    }
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
