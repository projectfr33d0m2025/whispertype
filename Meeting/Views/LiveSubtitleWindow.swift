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
        
        // Handle window close
        panel.delegate = PanelDelegate(onClose: { [weak self] in
            self?.saveFrame()
            self?.isVisible = false
        })
        
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
    
    /// Hide the subtitle window (recording continues)
    func hide() {
        guard let panel = panel else { return }
        guard isVisible else { return }
        
        print("LiveSubtitleWindow: Hiding")
        
        saveFrame()
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            Task { @MainActor [weak self] in
                self?.panel?.orderOut(nil)
            }
        }
        
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
        durationSubscription = coordinator.$currentSession
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] session in
                self?.state.elapsedTime = session.duration
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
        panel?.orderOut(nil)
        panel = nil
        hostingView = nil
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
