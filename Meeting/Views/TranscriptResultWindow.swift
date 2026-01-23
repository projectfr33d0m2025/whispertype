//
//  TranscriptResultWindow.swift
//  WhisperType
//
//  Window to display the final transcript after meeting recording is complete.
//

import AppKit
import SwiftUI

/// Manages the transcript result window shown after recording
@MainActor
class TranscriptResultWindow {
    
    // MARK: - Properties
    
    private var window: NSWindow?
    private var transcript: String = ""
    private var sessionTitle: String = ""
    private var duration: String = ""
    private var transcriptPath: URL?
    
    // MARK: - Singleton
    
    static let shared = TranscriptResultWindow()
    
    private init() {}
    
    // MARK: - Show Window
    
    /// Show the transcript result window with the final transcript
    func show(
        transcript: String,
        sessionTitle: String,
        duration: String,
        transcriptPath: URL?
    ) {
        self.transcript = transcript
        self.sessionTitle = sessionTitle
        self.duration = duration
        self.transcriptPath = transcriptPath
        
        createAndShowWindow()
    }
    
    private func createAndShowWindow() {
        // CRITICAL FIX: Properly tear down previous window's SwiftUI view
        // before closing to prevent autorelease pool crash
        if let existingWindow = window {
            if let hostingView = existingWindow.contentView as? NSHostingView<TranscriptResultView> {
                hostingView.removeFromSuperview()
            }
            existingWindow.close()
            self.window = nil
        }
        
        // Create SwiftUI view
        let view = TranscriptResultView(
            transcript: transcript,
            sessionTitle: sessionTitle,
            duration: duration,
            onCopy: { [weak self] in self?.copyTranscript() },
            onOpenFile: { [weak self] in self?.openTranscriptFile() },
            onClose: { [weak self] in self?.close() }
        )
        
        // Create window
        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 500),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        
        newWindow.title = "Meeting Transcript"
        newWindow.contentView = NSHostingView(rootView: view)
        newWindow.minSize = NSSize(width: 400, height: 300)
        newWindow.center()
        
        self.window = newWindow
        
        newWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        print("TranscriptResultWindow: Showing transcript (\(transcript.count) characters)")
    }
    
    // MARK: - Actions
    
    private func copyTranscript() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(transcript, forType: .string)
        print("TranscriptResultWindow: Copied transcript to clipboard")
    }
    
    private func openTranscriptFile() {
        guard let path = transcriptPath else { return }
        NSWorkspace.shared.open(path)
    }
    
    func close() {
        // CRITICAL FIX for autorelease pool crash:
        // Same issue as ProcessingIndicatorWindow - SwiftUI views with animations
        // cause crashes when closed during animation. Just hide the window.
        window?.orderOut(nil)
        
        // Don't close or nil the window - let it be reused/closed when show() is called
        print("TranscriptResultWindow: Closed (hidden)")
    }
    
    deinit {
        print("⚠️ DEINIT: TranscriptResultWindow - \(ObjectIdentifier(self))")
    }
}

// MARK: - SwiftUI View

struct TranscriptResultView: View {
    let transcript: String
    let sessionTitle: String
    let duration: String
    let onCopy: () -> Void
    let onOpenFile: () -> Void
    let onClose: () -> Void
    
    @State private var showCopiedFeedback = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            Divider()
            
            // Transcript content
            ScrollView {
                Text(transcript.isEmpty ? "No transcript available" : transcript)
                    .font(.system(.body, design: .default))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .background(Color(NSColor.textBackgroundColor))
            
            Divider()
            
            // Footer with actions
            footerView
        }
        .frame(minWidth: 400, minHeight: 300)
    }
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(sessionTitle.isEmpty ? "Meeting Transcript" : sessionTitle)
                    .font(.headline)
                
                HStack(spacing: 12) {
                    Label(duration, systemImage: "clock")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Label("\(wordCount) words", systemImage: "text.alignleft")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Text("✓ Transcription Complete")
                .font(.caption)
                .foregroundColor(.green)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.green.opacity(0.1))
                .cornerRadius(4)
        }
        .padding()
    }
    
    private var footerView: some View {
        HStack {
            Button(action: {
                onCopy()
                showCopiedFeedback = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    showCopiedFeedback = false
                }
            }) {
                Label(showCopiedFeedback ? "Copied!" : "Copy", systemImage: showCopiedFeedback ? "checkmark" : "doc.on.doc")
            }
            .buttonStyle(.bordered)
            
            Button(action: onOpenFile) {
                Label("Open File", systemImage: "doc.text")
            }
            .buttonStyle(.bordered)
            
            Spacer()
            
            Button("Close", action: onClose)
                .keyboardShortcut(.escape)
        }
        .padding()
    }
    
    private var wordCount: Int {
        transcript.split(separator: " ").count
    }
}
