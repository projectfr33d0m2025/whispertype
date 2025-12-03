//
//  WaveformView.swift
//  WhisperType
//
//  An enhanced SwiftUI view that displays a smooth, fluid waveform visualization
//  inspired by professional audio apps. Features mirrored bars, smooth decay,
//  and organic animation.
//

import SwiftUI

// MARK: - Waveform View

struct WaveformView: View {
    
    // MARK: - Properties
    
    /// Audio level from 0.0 to 1.0
    @Binding var audioLevel: Float
    
    /// Number of bars in the waveform
    let barCount: Int
    
    /// Whether the waveform is actively animating
    let isActive: Bool
    
    // MARK: - Animation State
    
    @StateObject private var animator = WaveformAnimator()
    
    // MARK: - Constants
    
    private let barSpacing: CGFloat = 1.2
    private let minBarHeight: CGFloat = 2.0
    private let maxBarHeight: CGFloat = 22.0
    private let idleBarHeight: CGFloat = 2.0
    
    // Animation timing
    private let frameRate: Double = 60.0
    
    // MARK: - Initialization
    
    init(audioLevel: Binding<Float>, barCount: Int = 45, isActive: Bool = true) {
        self._audioLevel = audioLevel
        self.barCount = barCount
        self.isActive = isActive
    }
    
    // MARK: - Body
    
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / frameRate)) { timeline in
            Canvas { context, size in
                drawWaveform(context: context, size: size, date: timeline.date)
            }
        }
        .onAppear {
            animator.initialize(barCount: barCount, idleHeight: idleBarHeight)
        }
        .onChange(of: barCount) { newCount in
            animator.initialize(barCount: newCount, idleHeight: idleBarHeight)
        }
    }
    
    // MARK: - Drawing
    
    private func drawWaveform(context: GraphicsContext, size: CGSize, date: Date) {
        let totalBarWidth = size.width / CGFloat(barCount)
        let barWidth = max(1.5, totalBarWidth - barSpacing)
        let centerY = size.height / 2
        
        // Time for animations
        let time = date.timeIntervalSinceReferenceDate
        
        // Update animator with current state
        animator.update(
            audioLevel: CGFloat(audioLevel),
            time: time,
            barCount: barCount,
            isActive: isActive,
            minHeight: minBarHeight,
            maxHeight: maxBarHeight,
            idleHeight: idleBarHeight
        )
        
        // Draw each bar
        for i in 0..<barCount {
            let barHeight = animator.getBarHeight(at: i)
            let halfHeight = barHeight / 2
            
            // Calculate bar position (centered)
            let x = CGFloat(i) * totalBarWidth + (totalBarWidth - barWidth) / 2
            
            // Calculate normalized position for color/opacity
            let normalizedPosition = abs(CGFloat(i) - CGFloat(barCount - 1) / 2) / (CGFloat(barCount - 1) / 2)
            
            // Calculate opacity based on bar height and position
            let heightRatio = (barHeight - minBarHeight) / (maxBarHeight - minBarHeight)
            let baseOpacity = 0.5 + 0.5 * (1 - normalizedPosition)
            let intensityOpacity = 0.3 + 0.7 * heightRatio
            let finalOpacity = baseOpacity * intensityOpacity
            
            // Create color based on intensity
            let color = barColor(intensity: heightRatio, opacity: finalOpacity)
            
            // Draw mirrored bar (extends both up and down from center)
            let barRect = CGRect(
                x: x,
                y: centerY - halfHeight,
                width: barWidth,
                height: barHeight
            )
            
            // Use pill shape (fully rounded ends)
            let cornerRadius = barWidth / 2
            let barPath = Path(roundedRect: barRect, cornerRadius: cornerRadius)
            
            // Fill with color
            context.fill(barPath, with: .color(color))
            
            // Add subtle glow for active bars
            if heightRatio > 0.5 {
                let glowOpacity = (heightRatio - 0.5) * 0.3
                let glowRect = barRect.insetBy(dx: -0.5, dy: -0.5)
                let glowPath = Path(roundedRect: glowRect, cornerRadius: cornerRadius + 0.5)
                context.fill(glowPath, with: .color(Color.white.opacity(glowOpacity * 0.2)))
            }
        }
    }
    
    // MARK: - Helper Functions
    
    /// Generate bar color based on intensity
    private func barColor(intensity: CGFloat, opacity: Double) -> Color {
        // Base white with slight warmth shift for active bars
        let warmth = intensity * 0.03
        return Color(
            red: 1.0,
            green: 1.0 - warmth * 0.3,
            blue: 1.0 - warmth * 0.6
        ).opacity(opacity)
    }
}


// MARK: - Waveform Animator

/// Manages the animation state for the waveform visualization
/// Uses a class to allow mutation during Canvas drawing
private class WaveformAnimator: ObservableObject {
    
    // Current smoothed bar heights
    private var barHeights: [CGFloat] = []
    
    // Smoothing parameters
    private let attackFactor: CGFloat = 0.45    // How fast bars rise (higher = faster)
    private let decayFactor: CGFloat = 0.06     // How fast bars fall (lower = slower, more fluid)
    
    /// Initialize with bar count
    func initialize(barCount: Int, idleHeight: CGFloat) {
        if barHeights.count != barCount {
            barHeights = Array(repeating: idleHeight, count: barCount)
        }
    }
    
    /// Update animation state
    func update(
        audioLevel: CGFloat,
        time: TimeInterval,
        barCount: Int,
        isActive: Bool,
        minHeight: CGFloat,
        maxHeight: CGFloat,
        idleHeight: CGFloat
    ) {
        // Ensure correct array size
        if barHeights.count != barCount {
            barHeights = Array(repeating: idleHeight, count: barCount)
        }
        
        // Calculate targets and update heights
        let targets = calculateTargets(
            audioLevel: audioLevel,
            time: time,
            barCount: barCount,
            isActive: isActive,
            minHeight: minHeight,
            maxHeight: maxHeight,
            idleHeight: idleHeight
        )
        
        // Apply attack/decay smoothing
        for i in 0..<barCount {
            let current = barHeights[i]
            let target = targets[i]
            
            if target > current {
                // Attack: rise quickly
                barHeights[i] = current + (target - current) * attackFactor
            } else {
                // Decay: fall slowly with smooth easing
                barHeights[i] = current + (target - current) * decayFactor
            }
        }
    }
    
    /// Get the current height for a bar
    func getBarHeight(at index: Int) -> CGFloat {
        guard index >= 0 && index < barHeights.count else { return 2.0 }
        return barHeights[index]
    }
    
    /// Calculate target heights for each bar
    private func calculateTargets(
        audioLevel: CGFloat,
        time: TimeInterval,
        barCount: Int,
        isActive: Bool,
        minHeight: CGFloat,
        maxHeight: CGFloat,
        idleHeight: CGFloat
    ) -> [CGFloat] {
        var targets = [CGFloat](repeating: idleHeight, count: barCount)
        
        // Determine if we're in idle state
        let isIdle = audioLevel < 0.03
        
        for i in 0..<barCount {
            // Calculate normalized position (-1 to 1, center = 0)
            let normalizedPosition = (CGFloat(i) - CGFloat(barCount - 1) / 2) / (CGFloat(barCount - 1) / 2)
            
            if isIdle && isActive {
                // Idle state: subtle breathing animation
                let idleEnvelope = gaussianEnvelope(x: normalizedPosition, sigma: 0.5)
                let breathingOffset = sin(time * 2.0 * .pi * 0.7) * 0.5 + 0.5
                let waveOffset = sin(time * 2.5 + Double(i) * 0.12) * 0.25
                targets[i] = idleHeight + CGFloat(breathingOffset + waveOffset) * idleEnvelope * 1.2
            } else if audioLevel > 0 {
                // Active audio: responsive visualization
                
                // Primary envelope (bell curve - tighter for more center focus)
                let primaryEnvelope = gaussianEnvelope(x: normalizedPosition, sigma: 0.32)
                
                // Secondary envelope for variety (wider spread)
                let secondaryEnvelope = gaussianEnvelope(x: normalizedPosition, sigma: 0.55)
                
                // Time-varying modulation for organic movement
                let modulation1 = sin(time * 8.0 + Double(i) * 0.35) * 0.12
                let modulation2 = sin(time * 12.0 + Double(i) * 0.55) * 0.08
                let modulation3 = sin(time * 6.0 - Double(i) * 0.25) * 0.10
                
                // Combine envelopes with modulation
                let envelope = primaryEnvelope * 0.65 + secondaryEnvelope * 0.35
                let variation = 1.0 + CGFloat(modulation1 + modulation2 + modulation3)
                
                // Calculate height based on audio level with some non-linearity
                let adjustedLevel = pow(audioLevel, 0.85) // Slight compression
                let audioContribution = adjustedLevel * (maxHeight - minHeight) * envelope * variation
                
                targets[i] = max(minHeight, minHeight + audioContribution)
            } else {
                targets[i] = minHeight
            }
            
            // Clamp to valid range
            targets[i] = max(minHeight, min(maxHeight, targets[i]))
        }
        
        return targets
    }
    
    /// Gaussian bell curve for envelope shaping
    private func gaussianEnvelope(x: CGFloat, sigma: CGFloat) -> CGFloat {
        return exp(-(x * x) / (2 * sigma * sigma))
    }
}


// MARK: - Preview

#if DEBUG
struct WaveformView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            // Idle state
            Text("Idle (0.0)")
                .foregroundColor(.white)
                .font(.caption)
            WaveformView(audioLevel: .constant(0.0), isActive: true)
                .frame(width: 120, height: 28)
                .background(Color(red: 0.24, green: 0.26, blue: 0.29))
                .cornerRadius(14)
            
            // Low audio
            Text("Low (0.15)")
                .foregroundColor(.white)
                .font(.caption)
            WaveformView(audioLevel: .constant(0.15), isActive: true)
                .frame(width: 120, height: 28)
                .background(Color(red: 0.24, green: 0.26, blue: 0.29))
                .cornerRadius(14)
            
            // Medium audio
            Text("Medium (0.4)")
                .foregroundColor(.white)
                .font(.caption)
            WaveformView(audioLevel: .constant(0.4), isActive: true)
                .frame(width: 120, height: 28)
                .background(Color(red: 0.24, green: 0.26, blue: 0.29))
                .cornerRadius(14)
            
            // High audio
            Text("High (0.7)")
                .foregroundColor(.white)
                .font(.caption)
            WaveformView(audioLevel: .constant(0.7), isActive: true)
                .frame(width: 120, height: 28)
                .background(Color(red: 0.24, green: 0.26, blue: 0.29))
                .cornerRadius(14)
            
            // Very high audio
            Text("Very High (0.95)")
                .foregroundColor(.white)
                .font(.caption)
            WaveformView(audioLevel: .constant(0.95), isActive: true)
                .frame(width: 120, height: 28)
                .background(Color(red: 0.24, green: 0.26, blue: 0.29))
                .cornerRadius(14)
        }
        .padding(30)
        .background(Color.gray.opacity(0.7))
    }
}
#endif
