//
//  ToastNotificationWindow.swift
//  WhisperType
//
//  A floating toast notification that appears briefly on screen.
//  Used for fallback notifications, rate limiting, and other transient messages.
//

import SwiftUI
import AppKit

// MARK: - Toast Type

enum ToastType {
    case info
    case success
    case warning
    case error
    
    var icon: String {
        switch self {
        case .info: return "info.circle.fill"
        case .success: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .info: return .blue
        case .success: return .green
        case .warning: return .orange
        case .error: return .red
        }
    }
    
    var backgroundColor: Color {
        switch self {
        case .info: return Color.blue.opacity(0.15)
        case .success: return Color.green.opacity(0.15)
        case .warning: return Color.orange.opacity(0.15)
        case .error: return Color.red.opacity(0.15)
        }
    }
}

// MARK: - Toast Content View

struct ToastContentView: View {
    let message: String
    let type: ToastType
    let onDismiss: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: type.icon)
                .font(.system(size: 20))
                .foregroundColor(type.color)
            
            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.primary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer(minLength: 8)
            
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .opacity(0.6)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(type.color.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 4)
    }
}

// MARK: - Toast Notification Window

class ToastNotificationWindow: NSObject {
    
    // MARK: - Singleton
    
    static let shared = ToastNotificationWindow()
    
    // MARK: - Properties
    
    private var window: NSPanel?
    private var dismissTask: Task<Void, Never>?
    private var isShowing = false
    
    // MARK: - Initialization
    
    private override init() {
        super.init()
    }
    
    // MARK: - Public API
    
    /// Show a toast notification
    func show(message: String, type: ToastType, duration: TimeInterval = 3.0) {
        Task { @MainActor in
            self.showOnMainThread(message: message, type: type, duration: duration)
        }
    }
    
    @MainActor
    private func showOnMainThread(message: String, type: ToastType, duration: TimeInterval) {
        // Cancel any existing dismiss task
        dismissTask?.cancel()
        
        // Dismiss existing toast first
        if isShowing {
            hideImmediately()
        }
        
        // Create the window
        createWindow(message: message, type: type)
        
        // Show with animation
        showWithAnimation()
        
        // Schedule auto-dismiss
        dismissTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            
            if !Task.isCancelled {
                self.hide()
            }
        }
    }
    
    /// Hide the toast with animation
    @MainActor
    func hide() {
        guard isShowing, let window = window else { return }
        
        dismissTask?.cancel()
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            window.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.window?.orderOut(nil)
            self?.window = nil
            self?.isShowing = false
        })
    }

    // MARK: - Private Methods
    
    @MainActor
    private func createWindow(message: String, type: ToastType) {
        // Calculate window size and position
        let contentView = ToastContentView(
            message: message,
            type: type,
            onDismiss: { [weak self] in
                self?.hide()
            }
        )
        
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.setFrameSize(NSSize(width: 320, height: 60))
        
        // Get the intrinsic size
        let fittingSize = hostingView.fittingSize
        let windowWidth = min(max(fittingSize.width, 280), 400)
        let windowHeight = max(fittingSize.height, 50)
        
        // Position at top center of main screen
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let windowX = screenFrame.midX - (windowWidth / 2)
        let windowY = screenFrame.maxY - windowHeight - 60
        
        let windowFrame = NSRect(
            x: windowX,
            y: windowY,
            width: windowWidth,
            height: windowHeight
        )
        
        // Create the panel
        let panel = NSPanel(
            contentRect: windowFrame,
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false
        
        hostingView.setFrameSize(NSSize(width: windowWidth, height: windowHeight))
        panel.contentView = hostingView
        
        self.window = panel
    }
    
    @MainActor
    private func showWithAnimation() {
        guard let window = window else { return }
        
        window.alphaValue = 0
        var frame = window.frame
        frame.origin.y += 20
        window.setFrame(frame, display: false)
        
        window.orderFront(nil)
        isShowing = true
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            
            window.animator().alphaValue = 1
            
            var finalFrame = window.frame
            finalFrame.origin.y -= 20
            window.animator().setFrame(finalFrame, display: true)
        }
    }
    
    @MainActor
    private func hideImmediately() {
        window?.orderOut(nil)
        window = nil
        isShowing = false
    }
    
    /// Clean up resources
    func cleanup() {
        Task { @MainActor in
            dismissTask?.cancel()
            hideImmediately()
        }
    }
}

// MARK: - Preview

#Preview {
    ToastContentView(
        message: "AI enhancement unavailable. Using Formatted mode.",
        type: .warning,
        onDismiss: {}
    )
    .padding()
    .frame(width: 350)
}
