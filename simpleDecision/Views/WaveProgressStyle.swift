//
//  WaveProgressStyle.swift
//  simpleDecision
//
//  Created by Phase 2 - Visual Feedback System on 23/10/2025.
//

import SwiftUI

/// Animated wave-style progress bar with urgency feedback
struct WaveProgressStyle: View {
    let progress: Double
    let urgency: Double
    let safetyStatus: SafetyStatus
    let height: CGFloat
    let showLabel: Bool
    
    @State private var waveOffset: CGFloat = 0
    @State private var pulseScale: CGFloat = 1.0
    
    var body: some View {
        VStack(spacing: 8) {
            // Wave progress bar
            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: height)
                
                // Animated fill bar
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                UrgencyColorMapper.colorForUrgency(0.0),
                                UrgencyColorMapper.colorForUrgency(urgency),
                                UrgencyColorMapper.colorForUrgency(1.0)
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(width: CGFloat(progress) * 400)
                    .frame(height: height)
                    .offset(x: waveOffset * 0.3)
                
                // Shimmer overlay for accepted/risky states
                if safetyStatus != .comfortable {
                    shimmerOverlay(height: height)
                }
                
                // Pulse indicator at progress tip
                if UrgencyColorMapper.shouldPulseForUrgency(urgency) {
                    pulseIndicator(height: height)
                }
            }
            
            // Labels
            if showLabel {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Progress")
                            .font(.caption2)
                            .foregroundColor(.gray)
                        
                        HStack(spacing: 4) {
                            Text(UrgencyColorMapper.emojiForUrgency(urgency))
                                .font(.title3)
                            
                            Text(UrgencyColorMapper.descriptionForUrgency(urgency))
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(UrgencyColorMapper.colorForUrgency(urgency))
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(Int(progress * 100))%")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Text(safetyStatus.emoji)
                            .font(.title3)
                    }
                }
                .padding(.horizontal, 12)
            }
        }
        .onAppear {
            startAnimations()
        }
    }
    
    private func shimmerOverlay(height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: height / 2)
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [
                        .white.opacity(0),
                        .white.opacity(0.3),
                        .white.opacity(0)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: height)
            .offset(x: waveOffset * 2)
    }
    
    private func pulseIndicator(height: CGFloat) -> some View {
        HStack(spacing: 0) {
            Spacer()
            
            ZStack {
                // Outer pulse
                Circle()
                    .fill(UrgencyColorMapper.colorForUrgency(urgency))
                    .frame(width: height + 8, height: height + 8)
                    .scaleEffect(pulseScale)
                    .opacity(Double(1 - (pulseScale - 1) * 2))
                
                // Inner circle
                Circle()
                    .fill(UrgencyColorMapper.colorForUrgency(urgency))
                    .frame(width: height - 4, height: height - 4)
                    .shadow(color: UrgencyColorMapper.colorForUrgency(urgency).opacity(0.6), radius: 6)
            }
            .offset(x: -(height / 2 + 4))
        }
    }
    
    private func startAnimations() {
        // Wave animation
        let waveAnimation = Animation
            .linear(duration: 2.0)
            .repeatForever(autoreverses: false)
        
        withAnimation(waveAnimation) {
            waveOffset = 30
        }
        
        // Pulse animation (only if urgency is high)
        if UrgencyColorMapper.shouldPulseForUrgency(urgency) {
            let pulseAnimation = Animation
                .easeInOut(duration: UrgencyColorMapper.animationDurationForUrgency(urgency))
                .repeatForever(autoreverses: true)
            
            withAnimation(pulseAnimation) {
                pulseScale = 1.3
            }
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        // Comfortable
        WaveProgressStyle(
            progress: 0.3,
            urgency: 0.1,
            safetyStatus: .comfortable,
            height: 12,
            showLabel: true
        )
        
        // Acceptable
        WaveProgressStyle(
            progress: 0.6,
            urgency: 0.5,
            safetyStatus: .acceptable,
            height: 12,
            showLabel: true
        )
        
        // Too Risky
        WaveProgressStyle(
            progress: 0.9,
            urgency: 0.95,
            safetyStatus: .tooRisky,
            height: 12,
            showLabel: true
        )
    }
    .padding()
}
