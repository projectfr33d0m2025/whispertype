//
//  RecordingOverlayContentView.swift
//  WhisperType
//
//  The SwiftUI content view displayed inside the recording overlay panel.
//  A pill-shaped container with blur effect containing the waveform visualization
//  and optional mode/app indicator for app-aware context.
//

import SwiftUI

struct RecordingOverlayContentView: View {
    
    // MARK: - Properties
    
    @ObservedObject var state: RecordingOverlayState
    
    // MARK: - Constants
    
    private let waveformWidth: CGFloat = 120
    private let containerHeight: CGFloat = 32
    private let cornerRadius: CGFloat = 16
    private let backgroundColor = Color(red: 0.24, green: 0.26, blue: 0.29) // Dark gray ~#3D4249
    
    // MARK: - Computed Properties
    
    /// Whether to show the extended mode info section
    private var showModeInfo: Bool {
        !state.modeName.isEmpty
    }
    
    /// Total container width (dynamic based on mode info)
    private var containerWidth: CGFloat {
        if showModeInfo {
            return waveformWidth + modeInfoWidth + 8 // 8 for divider spacing
        }
        return waveformWidth
    }
    
    /// Width for mode info section
    private var modeInfoWidth: CGFloat {
        // Calculate based on content
        if state.isAppSpecificMode, let appName = state.appName {
            return min(CGFloat(appName.count + state.modeName.count) * 6 + 40, 160)
        }
        return min(CGFloat(state.modeName.count) * 7 + 24, 100)
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // Solid dark background
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(backgroundColor)
            
            HStack(spacing: 0) {
                // Mode info section (if enabled)
                if showModeInfo {
                    modeInfoSection
                    
                    // Divider
                    Rectangle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 1)
                        .padding(.vertical, 6)
                }
                
                // Waveform visualization
                WaveformView(
                    audioLevel: .constant(state.audioLevel),
                    barCount: 45,
                    isActive: state.isActive
                )
                .frame(width: waveformWidth)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
            }
        }
        .frame(width: containerWidth, height: containerHeight)
        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
        .animation(.easeInOut(duration: 0.2), value: showModeInfo)
    }
    
    // MARK: - Mode Info Section
    
    private var modeInfoSection: some View {
        HStack(spacing: 4) {
            if state.isAppSpecificMode, let appName = state.appName {
                // Show app-specific mode indicator
                VStack(alignment: .leading, spacing: 0) {
                    Text(state.modeName)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white)
                    Text("for \(appName)")
                        .font(.system(size: 8))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(1)
                }
            } else {
                // Just show mode name
                Text(state.modeName)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 10)
        .frame(width: modeInfoWidth, alignment: .leading)
    }
}

// MARK: - Preview

#if DEBUG
struct RecordingOverlayContentView_Previews: PreviewProvider {
    static var previews: some View {
        let simpleState = RecordingOverlayState()
        simpleState.audioLevel = 0.5
        
        let modeState = RecordingOverlayState()
        modeState.audioLevel = 0.5
        modeState.modeName = "Formatted"
        
        let appAwareState = RecordingOverlayState()
        appAwareState.audioLevel = 0.5
        appAwareState.modeName = "Clean"
        appAwareState.appName = "VS Code"
        appAwareState.isAppSpecificMode = true
        
        return VStack(spacing: 20) {
            // Simple overlay (no mode info)
            RecordingOverlayContentView(state: simpleState)
            
            // With mode name
            RecordingOverlayContentView(state: modeState)
            
            // App-aware mode
            RecordingOverlayContentView(state: appAwareState)
        }
        .padding(40)
        .background(Color.gray)
    }
}
#endif
