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
        // CRITICAL FIX: Properly tear down previous window's SwiftUI view
        // Set contentView to nil FIRST to stop SwiftUI rendering and animations,
        // then close the window
        if let existingWindow = window {
            existingWindow.contentView = nil
            existingWindow.orderOut(nil)
            existingWindow.close()
            self.window = nil
        }
        
        let view = ProcessingIndicatorView(
            duration: duration,
            chunkCount: chunkCount
        )
        
        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 150),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        newWindow.title = "Processing Recording"
        newWindow.titlebarAppearsTransparent = true
        newWindow.isMovableByWindowBackground = true
        newWindow.contentView = NSHostingView(rootView: view)
        newWindow.center()
        newWindow.level = .floating
        
        self.window = newWindow
        
        newWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        print("ProcessingIndicatorWindow: Showing")
    }
    
    /// Hide the processing indicator (keeps window alive to avoid animation teardown crash)
    func hide() {
        guard let window = window else { return }
        
        // CRITICAL FIX for autorelease pool crash:
        // 
        // The ProcessingIndicatorView uses withAnimation(.repeatForever). Core Animation
        // continues running even after we set contentView = nil. When the animation
        // timer fires after the view is deallocated, it creates autoreleased objects
        // that become invalid, crashing during autorelease pool drain.
        //
        // SOLUTION: Don't close the window at all when hiding!
        // Just order it out (hide visually). The window stays alive with its animation
        // running harmlessly in the background. Close only when show() is called again
        // or when explicitly cleaned up.
        
        window.orderOut(nil)
        
        print("ProcessingIndicatorWindow: Hidden")
    }
    
    /// Clean up the window completely (call only when you know it's safe)
    func cleanup() {
        guard let window = window else { return }
        
        // Schedule cleanup on next run loop to avoid issues
        let windowToCleanup = window
        self.window = nil
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            windowToCleanup.contentView = nil
            windowToCleanup.close()
        }
        
        print("ProcessingIndicatorWindow: Cleaned up")
    }
    
    deinit {
        print("⚠️ DEINIT: ProcessingIndicatorWindow - \(ObjectIdentifier(self))")
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
