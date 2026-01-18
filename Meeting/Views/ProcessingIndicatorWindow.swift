//
//  ProcessingIndicatorWindow.swift
//  WhisperType
//
//  Shows a processing indicator while the final transcript is being generated.
//

import AppKit
import SwiftUI

/// Manages the processing indicator window shown during final transcription
@MainActor
class ProcessingIndicatorWindow {
    
    // MARK: - Properties
    
    private var window: NSWindow?
    private var progressValue: Double = 0
    private var statusMessage: String = "Processing..."
    
    // MARK: - Singleton
    
    static let shared = ProcessingIndicatorWindow()
    
    private init() {}
    
    // MARK: - Show/Hide
    
    /// Show the processing indicator
    func show(duration: String, chunkCount: Int) {
        // Close existing window if any
        window?.close()
        
        let view = ProcessingIndicatorView(
            duration: duration,
            chunkCount: chunkCount
        )
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 150),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        window.title = "Processing Recording"
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.contentView = NSHostingView(rootView: view)
        window.center()
        window.level = .floating
        
        self.window = window
        
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        print("ProcessingIndicatorWindow: Showing")
    }
    
    /// Hide and close the processing indicator
    func hide() {
        window?.close()
        window = nil
        print("ProcessingIndicatorWindow: Hidden")
    }
}

// MARK: - SwiftUI View

struct ProcessingIndicatorView: View {
    let duration: String
    let chunkCount: Int
    
    @State private var animationPhase = 0.0
    
    var body: some View {
        VStack(spacing: 16) {
            // Animated processing icon
            ZStack {
                Circle()
                    .stroke(Color.blue.opacity(0.2), lineWidth: 4)
                    .frame(width: 50, height: 50)
                
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 50, height: 50)
                    .rotationEffect(.degrees(animationPhase))
            }
            .onAppear {
                withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                    animationPhase = 360
                }
            }
            
            VStack(spacing: 4) {
                Text("Generating Final Transcript")
                    .font(.headline)
                
                Text("Processing \(duration) of audio...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if chunkCount > 0 {
                    Text("\(chunkCount) audio chunks")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(24)
        .frame(width: 320)
    }
}
