//
//  UrgencyBadge.swift
//  simpleDecision
//
//  Created by Phase 2 - Visual Feedback System on 23/10/2025.
//

import SwiftUI

/// Animated urgency badge showing status and buffer time
struct UrgencyStatusBadge: View {
    let urgency: Double
    let safetyStatus: SafetyStatus
    let bufferMinutes: Int
    let routeType: String  // "walk" or "bus"
    let isSelected: Bool
    
    @State private var scale: CGFloat = 1.0
    @State private var rotation: Double = 0
    
    var body: some View {
        VStack(spacing: 8) {
            // Top emoji + status
            HStack(spacing: 8) {
                Text(UrgencyColorMapper.emojiForUrgency(urgency))
                    .font(.title2)
                    .scaleEffect(scale)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(routeType.capitalized)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.gray)
                    
                    Text(UrgencyColorMapper.descriptionForUrgency(urgency))
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(UrgencyColorMapper.colorForUrgency(urgency))
                }
                
                Spacer()
            }
            
            // Buffer time indicator
            HStack(spacing: 6) {
                Text("Buffer:")
                    .font(.caption2)
                    .foregroundColor(.gray)
                
                HStack(spacing: 4) {
                    Image(systemName: "hourglass.tophalf.fill")
                        .font(.caption2)
                        .foregroundColor(UrgencyColorMapper.colorForSafetyStatus(safetyStatus))
                    
                    Text("\(bufferMinutes) min")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(UrgencyColorMapper.colorForSafetyStatus(safetyStatus))
                }
                
                Spacer()
                
                // Safety badge
                HStack(spacing: 2) {
                    Text(safetyStatus.emoji)
                        .font(.caption)
                    
                    Text(safetyStatusLabel(safetyStatus))
                        .font(.caption2)
                        .fontWeight(.semibold)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(UrgencyColorMapper.backgroundColorForSafetyStatus(safetyStatus, opacity: 0.15))
                .cornerRadius(4)
            }
            
            // Progress mini-bar
            RoundedRectangle(cornerRadius: 3)
                .fill(UrgencyColorMapper.colorForUrgency(urgency))
                .frame(height: 4)
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(UrgencyColorMapper.colorForSafetyStatus(safetyStatus), lineWidth: 1)
                )
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(UIColor.systemBackground))
                .shadow(
                    color: UrgencyColorMapper.colorForUrgency(urgency).opacity(0.3),
                    radius: isSelected ? 8 : 4,
                    x: 0,
                    y: isSelected ? 4 : 2
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(
                    UrgencyColorMapper.colorForUrgency(urgency),
                    lineWidth: isSelected ? 2 : 1
                )
        )
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        .onAppear {
            startAnimations()
        }
    }
    
    private func safetyStatusLabel(_ status: SafetyStatus) -> String {
        switch status {
        case .comfortable:
            return "Comfortable"
        case .acceptable:
            return "Acceptable"
        case .tooRisky:
            return "Risky"
        }
    }
    
    private func startAnimations() {
        if UrgencyColorMapper.shouldPulseForUrgency(urgency) {
            let pulseDuration = UrgencyColorMapper.animationDurationForUrgency(urgency)
            let pulseAnimation = Animation
                .easeInOut(duration: pulseDuration)
                .repeatForever(autoreverses: true)
            
            withAnimation(pulseAnimation) {
                scale = 1.1
            }
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        // Comfortable
        UrgencyStatusBadge(
            urgency: 0.2,
            safetyStatus: .comfortable,
            bufferMinutes: 10,
            routeType: "walk",
            isSelected: false
        )
        
        // Acceptable
        UrgencyStatusBadge(
            urgency: 0.6,
            safetyStatus: .acceptable,
            bufferMinutes: 3,
            routeType: "bus",
            isSelected: true
        )
        
        // Too Risky
        UrgencyStatusBadge(
            urgency: 0.95,
            safetyStatus: .tooRisky,
            bufferMinutes: 1,
            routeType: "bus",
            isSelected: false
        )
    }
    .padding()
}
