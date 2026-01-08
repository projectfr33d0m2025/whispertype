//
//  LiveSubtitleView.swift
//  WhisperType
//
//  SwiftUI view displaying scrollable live transcript during recording.
//

import SwiftUI
import Combine

/// State object for the live subtitle view
@MainActor
class LiveSubtitleViewState: ObservableObject {
    @Published var updates: [TranscriptUpdate] = []
    @Published var isRecording: Bool = true
    @Published var elapsedTime: TimeInterval = 0
    @Published var isAutoScrollEnabled: Bool = true
    
    var formattedElapsedTime: String {
        let hours = Int(elapsedTime) / 3600
        let minutes = (Int(elapsedTime) % 3600) / 60
        let seconds = Int(elapsedTime) % 60
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

/// Main view for displaying live subtitles
struct LiveSubtitleView: View {
    
    @ObservedObject var state: LiveSubtitleViewState
    
    /// Callback when close button is pressed
    var onClose: (() -> Void)?
    
    /// Callback when minimize button is pressed
    var onMinimize: (() -> Void)?
    
    @State private var scrollProxy: ScrollViewProxy?
    @State private var lastScrolledId: UUID?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            Divider()
            
            // Content
            if state.updates.isEmpty {
                emptyStateView
            } else {
                scrollableContentView
            }
        }
        .background(Color(.windowBackgroundColor).opacity(0.95))
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack(spacing: 12) {
            // Title
            HStack(spacing: 8) {
                Image(systemName: "text.bubble")
                    .font(.system(size: 14))
                Text("Live Transcript")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(.primary)
            
            Spacer()
            
            // Recording indicator
            if state.isRecording {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                        .opacity(pulsingOpacity())
                    
                    Text("REC")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.red)
                    
                    Text(state.formattedElapsedTime)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
            
            // Window controls
            HStack(spacing: 8) {
                Button(action: { onMinimize?() }) {
                    Image(systemName: "minus")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                
                Button(action: { onClose?() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(.windowBackgroundColor))
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "waveform")
                .font(.system(size: 32))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text("Listening...")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            
            Text("Speak clearly and the transcript will appear here.")
                .font(.system(size: 12))
                .foregroundColor(.secondary.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - Scrollable Content
    
    private var scrollableContentView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(state.updates) { update in
                        SubtitleEntryView(update: update)
                            .id(update.id)
                        
                        if update.id != state.updates.last?.id {
                            Divider()
                                .padding(.horizontal, 12)
                        }
                    }
                }
                .padding(.vertical, 8)
            }
            .onAppear {
                scrollProxy = proxy
            }
            .onChange(of: state.updates.count) { _ in
                autoScrollToBottom(proxy: proxy)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if !state.isAutoScrollEnabled {
                resumeScrollButton
            }
        }
    }
    
    // MARK: - Resume Scroll Button
    
    private var resumeScrollButton: some View {
        Button(action: {
            state.isAutoScrollEnabled = true
            if let lastId = state.updates.last?.id {
                withAnimation {
                    scrollProxy?.scrollTo(lastId, anchor: .bottom)
                }
            }
        }) {
            HStack(spacing: 4) {
                Image(systemName: "arrow.down")
                    .font(.system(size: 10, weight: .medium))
                Text("Resume")
                    .font(.system(size: 11, weight: .medium))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.accentColor.opacity(0.9))
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .padding(12)
    }
    
    // MARK: - Helpers
    
    private func autoScrollToBottom(proxy: ScrollViewProxy) {
        guard state.isAutoScrollEnabled else { return }
        guard let lastId = state.updates.last?.id else { return }
        
        withAnimation(.easeOut(duration: 0.2)) {
            proxy.scrollTo(lastId, anchor: .bottom)
        }
    }
    
    @State private var pulsePhase: CGFloat = 0
    
    private func pulsingOpacity() -> Double {
        let _ = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
        return 0.5 + 0.5 * sin(Date().timeIntervalSince1970 * 2)
    }
}

// MARK: - Preview

#if DEBUG
struct LiveSubtitleView_Previews: PreviewProvider {
    static var previews: some View {
        let state = LiveSubtitleViewState()
        state.updates = [
            TranscriptUpdate(text: "So I think we should proceed with the budget allocation as discussed in the previous meeting.", timestamp: 45),
            TranscriptUpdate(text: "The marketing team has confirmed they can work within those constraints for Q1.", timestamp: 52),
            TranscriptUpdate(text: "Great, let's move to the next agenda item then. Sarah, can you give us an update on the engineering timeline?", timestamp: 63)
        ]
        state.elapsedTime = 70
        
        return LiveSubtitleView(state: state)
            .frame(width: 500, height: 300)
    }
}
#endif
