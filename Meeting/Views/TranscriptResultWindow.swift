//
//  TranscriptResultWindow.swift
//  WhisperType
//
//  Window to display the final transcript after meeting recording is complete.
//

import AppKit
import SwiftUI

/// Observable state for the transcript result window
/// Using ObservableObject allows us to update content without recreating the SwiftUI view,
/// which prevents autorelease pool crashes from zombie objects during view teardown.
@MainActor
class TranscriptResultState: ObservableObject {
    @Published var transcript: String = ""
    @Published var summary: String = ""
    @Published var sessionTitle: String = ""
    @Published var duration: String = ""
    @Published var transcriptPath: URL?
    @Published var showCopiedFeedback: Bool = false
    @Published var selectedTab: ResultTab = .summary
    
    enum ResultTab: String, CaseIterable {
        case summary = "Summary"
        case transcript = "Transcript"
    }
    
    func update(transcript: String, summary: String?, sessionTitle: String, duration: String, transcriptPath: URL?) {
        self.transcript = transcript
        self.summary = summary ?? ""
        self.sessionTitle = sessionTitle
        self.duration = duration
        self.transcriptPath = transcriptPath
        self.showCopiedFeedback = false
        // Default to summary tab if summary is available, otherwise transcript
        self.selectedTab = (summary != nil && !summary!.isEmpty) ? .summary : .transcript
    }
    
    func copyCurrentContent() {
        let content = selectedTab == .summary ? summary : transcript
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(content, forType: .string)
        showCopiedFeedback = true
        
        // Reset feedback after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.showCopiedFeedback = false
        }
        
        print("TranscriptResultWindow: Copied \(selectedTab.rawValue.lowercased()) to clipboard")
    }
    
    func openTranscriptFile() {
        guard let path = transcriptPath else { return }
        NSWorkspace.shared.open(path)
    }
    
    var wordCount: Int {
        transcript.split(separator: " ").count
    }
    
    var hasSummary: Bool {
        !summary.isEmpty
    }
}

/// Manages the transcript result window shown after recording
@MainActor
class TranscriptResultWindow {
    
    // MARK: - Properties
    
    private var window: NSWindow?
    
    /// Shared state object - survives across multiple show() calls
    /// This prevents SwiftUI view teardown which causes autorelease crashes
    private let state = TranscriptResultState()
    
    // MARK: - Singleton
    
    static let shared = TranscriptResultWindow()
    
    private init() {}
    
    // MARK: - Show Window
    
    /// Show the transcript result window with the final transcript and optional summary
    func show(
        transcript: String,
        summary: String? = nil,
        sessionTitle: String,
        duration: String,
        transcriptPath: URL?
    ) {
        // Update state (this triggers SwiftUI to re-render, not recreate)
        state.update(
            transcript: transcript,
            summary: summary,
            sessionTitle: sessionTitle,
            duration: duration,
            transcriptPath: transcriptPath
        )
        
        // Create window only if it doesn't exist
        if window == nil {
            createWindow()
        }
        
        // Show the window
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        print("TranscriptResultWindow: Showing transcript (\(transcript.count) characters)")
    }
    
    private func createWindow() {
        // Create SwiftUI view with persistent state
        let view = TranscriptResultView(
            state: state,
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
    }
    
    // MARK: - Actions
    
    func close() {
        // Just hide the window - it will be reused next time
        window?.orderOut(nil)
        print("TranscriptResultWindow: Closed (hidden)")
    }
    
    deinit {
        print("⚠️ DEINIT: TranscriptResultWindow - \(ObjectIdentifier(self))")
    }
}

// MARK: - SwiftUI View

struct TranscriptResultView: View {
    @ObservedObject var state: TranscriptResultState
    let onClose: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            Divider()
            
            // Tab picker (only show if we have a summary)
            if state.hasSummary {
                Picker("", selection: $state.selectedTab) {
                    ForEach(TranscriptResultState.ResultTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)
                
                Divider()
            }
            
            // Content based on selected tab
            ScrollView {
                if state.selectedTab == .summary && state.hasSummary {
                    Text(state.summary)
                        .font(.system(.body, design: .default))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                } else {
                    Text(state.transcript.isEmpty ? "No transcript available" : state.transcript)
                        .font(.system(.body, design: .default))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
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
                Text(state.sessionTitle.isEmpty ? "Meeting Transcript" : state.sessionTitle)
                    .font(.headline)
                
                HStack(spacing: 12) {
                    Label(state.duration, systemImage: "clock")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Label("\(state.wordCount) words", systemImage: "text.alignleft")
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
                state.copyCurrentContent()
            }) {
                Label(state.showCopiedFeedback ? "Copied!" : "Copy", systemImage: state.showCopiedFeedback ? "checkmark" : "doc.on.doc")
            }
            .buttonStyle(.bordered)
            
            Button(action: {
                state.openTranscriptFile()
            }) {
                Label("Open File", systemImage: "doc.text")
            }
            .buttonStyle(.bordered)
            
            Spacer()
            
            Button("Close", action: onClose)
                .keyboardShortcut(.escape)
        }
        .padding()
    }
}
