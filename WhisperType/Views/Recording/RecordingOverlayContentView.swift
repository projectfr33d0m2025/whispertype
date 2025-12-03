//
//  RecordingOverlayContentView.swift
//  WhisperType
//
//  The SwiftUI content view displayed inside the recording overlay panel.
//  A pill-shaped container with blur effect containing the waveform visualization.
//

import SwiftUI

struct RecordingOverlayContentView: View {
    
    // MARK: - Properties
    
    @ObservedObject var state: RecordingOverlayState
    
    // MARK: - Constants
    
    private let containerWidth: CGFloat = 120
    private let containerHeight: CGFloat = 32
    private let cornerRadius: CGFloat = 16
    private let backgroundColor = Color(red: 0.24, green: 0.26, blue: 0.29) // Dark gray ~#3D4249
    private let backgroundOpacity: Double = 1.0
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // Solid dark background
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(backgroundColor)
            
            // Waveform visualization
            WaveformView(
                audioLevel: .constant(state.audioLevel),
                barCount: 45,
                isActive: state.isActive
            )
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
        }
        .frame(width: containerWidth, height: containerHeight)
        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Preview

#if DEBUG
struct RecordingOverlayContentView_Previews: PreviewProvider {
    static var previews: some View {
        let idleState = RecordingOverlayState()
        idleState.audioLevel = 0.0
        
        let activeState = RecordingOverlayState()
        activeState.audioLevel = 0.5
        
        let highState = RecordingOverlayState()
        highState.audioLevel = 0.9
        
        return VStack(spacing: 20) {
            // Idle state
            RecordingOverlayContentView(state: idleState)
            
            // Active recording
            RecordingOverlayContentView(state: activeState)
            
            // High audio
            RecordingOverlayContentView(state: highState)
        }
        .padding(40)
        .background(Color.gray)
    }
}
#endif
