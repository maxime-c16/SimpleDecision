//
//  SafetyIndicator.swift
//  simpleDecision
//
//  Created by Phase 2 - Visual Feedback System on 23/10/2025.
//

import SwiftUI

/// Comprehensive safety indicator with visual warnings and detailed information
struct SafetyIndicator: View {
    let safetyStatus: SafetyStatus
    let bufferMinutes: Int
    let urgency: Double
    let routeDescription: String
    
    @State private var isExpanded: Bool = false
    @State private var showWarningAnimation: Bool = false
    
    var body: some View {
        VStack(spacing: 12) {
            // Header - tap to expand
            Button(action: { withAnimation(.easeInOut(duration: 0.3)) { isExpanded.toggle() } }) {
                HStack(spacing: 12) {
                    // Status icon with animation
                    ZStack {
                        Circle()
                            .fill(UrgencyColorMapper.backgroundColorForSafetyStatus(safetyStatus, opacity: 0.2))
                            .frame(width: 44, height: 44)
                        
                        Text(safetyStatus.emoji)
                            .font(.title)
                            .scaleEffect(showWarningAnimation && safetyStatus != .comfortable ? 1.15 : 1.0)
                    }
                    
                    // Status text
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Text(titleForSafetyStatus(safetyStatus))
                                .font(.headline)
                                .foregroundColor(UrgencyColorMapper.colorForSafetyStatus(safetyStatus))
                            
                            if safetyStatus != .comfortable {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(UrgencyColorMapper.colorForSafetyStatus(safetyStatus))
                                    .scaleEffect(showWarningAnimation ? 1.2 : 1.0)
                            }
                        }
                        
                        Text(subtitleForSafetyStatus(safetyStatus))
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    // Expand chevron
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .animation(.easeInOut(duration: 0.3), value: isExpanded)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(UrgencyColorMapper.backgroundColorForSafetyStatus(safetyStatus, opacity: 0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(
                                    UrgencyColorMapper.colorForSafetyStatus(safetyStatus).opacity(0.3),
                                    lineWidth: 1
                                )
                        )
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            // Expanded details
            if isExpanded {
                VStack(spacing: 12) {
                    Divider()
                        .opacity(0.5)
                    
                    // Buffer information
                    HStack(spacing: 12) {
                        Image(systemName: "hourglass.tophalf.fill")
                            .font(.title3)
                            .foregroundColor(UrgencyColorMapper.colorForSafetyStatus(safetyStatus))
                            .frame(width: 32)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Time Buffer")
                                .font(.caption)
                                .foregroundColor(.gray)
                            
                            HStack(spacing: 8) {
                                Text("\(bufferMinutes)")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(UrgencyColorMapper.colorForSafetyStatus(safetyStatus))
                                
                                Text("minutes")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Urgency")
                                .font(.caption)
                                .foregroundColor(.gray)
                            
                            Text("\(Int(urgency * 100))%")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(UrgencyColorMapper.colorForUrgency(urgency))
                        }
                    }
                    .padding(12)
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(8)
                    
                    // Route description
                    HStack(spacing: 12) {
                        Image(systemName: "route.fill")
                            .font(.title3)
                            .foregroundColor(.blue)
                            .frame(width: 32)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Route")
                                .font(.caption)
                                .foregroundColor(.gray)
                            
                            Text(routeDescription)
                                .font(.caption)
                                .lineLimit(2)
                                .foregroundColor(.primary)
                        }
                        
                        Spacer()
                    }
                    .padding(12)
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(8)
                    
                    // Recommendation based on safety
                    HStack(spacing: 12) {
                        Image(systemName: recommendationIconForSafetyStatus(safetyStatus))
                            .font(.title3)
                            .foregroundColor(UrgencyColorMapper.colorForSafetyStatus(safetyStatus))
                            .frame(width: 32)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Recommendation")
                                .font(.caption)
                                .foregroundColor(.gray)
                            
                            Text(recommendationForSafetyStatus(safetyStatus))
                                .font(.caption)
                                .lineLimit(3)
                                .foregroundColor(.primary)
                        }
                        
                        Spacer()
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(UrgencyColorMapper.backgroundColorForSafetyStatus(safetyStatus, opacity: 0.1))
                    )
                    .cornerRadius(8)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .onAppear {
            startAnimations()
        }
    }
    
    // MARK: - Helper Functions
    
    private func titleForSafetyStatus(_ status: SafetyStatus) -> String {
        switch status {
        case .comfortable:
            return "Comfortable Timing"
        case .acceptable:
            return "Acceptable Timing"
        case .tooRisky:
            return "High Risk"
        }
    }
    
    private func subtitleForSafetyStatus(_ status: SafetyStatus) -> String {
        switch status {
        case .comfortable:
            return "5+ minutes buffer - safe margin"
        case .acceptable:
            return "2-5 minutes buffer - tight but manageable"
        case .tooRisky:
            return "< 2 minutes - very tight timing"
        }
    }
    
    private func recommendationIconForSafetyStatus(_ status: SafetyStatus) -> String {
        switch status {
        case .comfortable:
            return "checkmark.circle.fill"
        case .acceptable:
            return "exclamationmark.triangle.fill"
        case .tooRisky:
            return "xmark.circle.fill"
        }
    }
    
    private func recommendationForSafetyStatus(_ status: SafetyStatus) -> String {
        switch status {
        case .comfortable:
            return "You have plenty of time. No need to rush."
        case .acceptable:
            return "Timing is tight. Walk at a normal pace but don't linger."
        case .tooRisky:
            return "Very tight timing. Any delay could cause you to miss this. Use with caution."
        }
    }
    
    private func startAnimations() {
        if safetyStatus != .comfortable {
            let pulseAnimation = Animation
                .easeInOut(duration: 1.5)
                .repeatForever(autoreverses: true)
            
            withAnimation(pulseAnimation) {
                showWarningAnimation = true
            }
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        SafetyIndicator(
            safetyStatus: .comfortable,
            bufferMinutes: 10,
            urgency: 0.1,
            routeDescription: "Walk 1.2 km to Val de Fontenay RER"
        )
        
        SafetyIndicator(
            safetyStatus: .acceptable,
            bufferMinutes: 3,
            urgency: 0.5,
            routeDescription: "Bus 124 to Chateau de Vincennes"
        )
        
        SafetyIndicator(
            safetyStatus: .tooRisky,
            bufferMinutes: 1,
            urgency: 0.9,
            routeDescription: "Bus 124 → RER A to La Défense"
        )
    }
    .padding()
}
