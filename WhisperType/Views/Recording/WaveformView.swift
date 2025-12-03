//
//  WaveformView.swift
//  WhisperType
//
//  A SwiftUI view that displays an animated waveform visualization
//  based on real-time audio input levels.
//

import SwiftUI

struct WaveformView: View {
    
    // MARK: - Properties
    
    /// Audio level from 0.0 to 1.0
    @Binding var audioLevel: Float
    
    /// Number of bars in the waveform
    let barCount: Int
    
    /// Whether the waveform is actively animating
    let isActive: Bool
    
    // MARK: - Animation State
    
    @State private var idlePhase: Double = 0
    
    // MARK: - Constants
    
    private let barSpacing: CGFloat = 1.5
    private let minBarHeight: CGFloat = 2
    private let maxBarHeight: CGFloat = 20
    private let idleBarHeight: CGFloat = 1.5  // Very short bars when idle
    private let idleAnimationAmplitude: CGFloat = 0.8  // Subtle movement when idle
    private let idleAnimationFrequency: Double = 1.2 // Hz
    
    // MARK: - Initialization
    
    init(audioLevel: Binding<Float>, barCount: Int = 45, isActive: Bool = true) {
        self._audioLevel = audioLevel
        self.barCount = barCount
        self.isActive = isActive
    }
    
    // MARK: - Body
    
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            Canvas { context, size in
                drawWaveform(context: context, size: size, date: timeline.date)
            }
        }
        .onChange(of: isActive) { newValue in
            if newValue {
                idlePhase = 0
            }
        }
    }
    
    // MARK: - Drawing
    
    private func drawWaveform(context: GraphicsContext, size: CGSize, date: Date) {
        let totalBarWidth = size.width / CGFloat(barCount)
        let barWidth = totalBarWidth - barSpacing
        
        // Calculate idle animation offset based on time
        let timeInterval = date.timeIntervalSinceReferenceDate
        let idleOffset = sin(timeInterval * 2 * .pi * idleAnimationFrequency) * idleAnimationAmplitude
        
        // Determine if we should show idle animation
        let effectiveAudioLevel = CGFloat(audioLevel)
        let isIdle = effectiveAudioLevel < 0.05
        
        for i in 0..<barCount {
            // Calculate normalized position (-1 to 1, center = 0)
            let normalizedPosition = (CGFloat(i) - CGFloat(barCount - 1) / 2) / (CGFloat(barCount - 1) / 2)
            
            // Calculate waveform envelope (bell curve shape)
            // Center bars are taller, edges taper off
            let envelope = gaussianEnvelope(x: normalizedPosition, sigma: 0.4)
            
            // Add some variation to make it look more natural
            let variation = pseudoRandomVariation(index: i, time: timeInterval)
            
            // Calculate bar height based on audio level
            var barHeight: CGFloat
            
            if isIdle && isActive {
                // Idle: very short bars with subtle breathing animation
                let idleEnvelope = gaussianEnvelope(x: normalizedPosition, sigma: 0.6)
                barHeight = idleBarHeight + (idleOffset + idleAnimationAmplitude) * idleEnvelope * 0.5
            } else {
                // Active audio visualization
                let audioContribution = effectiveAudioLevel * (maxBarHeight - minBarHeight) * envelope
                let variationContribution = variation * effectiveAudioLevel * 3
                barHeight = minBarHeight + audioContribution + variationContribution
            }
            
            // Clamp height
            barHeight = max(idleBarHeight, min(maxBarHeight, barHeight))
            
            // Calculate bar position
            let x = CGFloat(i) * totalBarWidth + barSpacing / 2
            let y = (size.height - barHeight) / 2
            
            // Create rounded rectangle for the bar
            let barRect = CGRect(x: x, y: y, width: barWidth, height: barHeight)
            let barPath = Path(roundedRect: barRect, cornerRadius: barWidth / 2)
            
            // Draw with gradient opacity based on position
            let opacity = 0.6 + 0.4 * envelope
            context.fill(barPath, with: .color(.white.opacity(opacity)))
        }
    }
    
    // MARK: - Helpers
    
    /// Gaussian bell curve for envelope shaping
    private func gaussianEnvelope(x: CGFloat, sigma: CGFloat) -> CGFloat {
        return exp(-(x * x) / (2 * sigma * sigma))
    }
    
    /// Pseudo-random variation for natural look
    private func pseudoRandomVariation(index: Int, time: TimeInterval) -> CGFloat {
        // Use sine functions with prime-based frequencies for pseudo-random variation
        let freq1 = Double(index) * 0.7 + time * 8
        let freq2 = Double(index) * 1.3 + time * 5
        return CGFloat(sin(freq1) * 0.3 + sin(freq2) * 0.2)
    }
}

// MARK: - Preview

#if DEBUG
struct WaveformView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // Idle state
            WaveformView(audioLevel: .constant(0.0), isActive: true)
                .frame(width: 100, height: 24)
                .background(Color.black.opacity(0.8))
                .cornerRadius(12)
            
            // Low audio
            WaveformView(audioLevel: .constant(0.2), isActive: true)
                .frame(width: 100, height: 24)
                .background(Color.black.opacity(0.8))
                .cornerRadius(12)
            
            // Medium audio
            WaveformView(audioLevel: .constant(0.5), isActive: true)
                .frame(width: 100, height: 24)
                .background(Color.black.opacity(0.8))
                .cornerRadius(12)
            
            // High audio
            WaveformView(audioLevel: .constant(0.8), isActive: true)
                .frame(width: 100, height: 24)
                .background(Color.black.opacity(0.8))
                .cornerRadius(12)
        }
        .padding()
        .background(Color.gray)
    }
}
#endif
