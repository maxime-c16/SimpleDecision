//
//  UrgencyColorMapper.swift
//  simpleDecision
//
//  Created by Phase 2 - Visual Feedback System on 23/10/2025.
//

import SwiftUI

/// Maps urgency scores and safety status to visual properties
struct UrgencyColorMapper {
    
    // MARK: - Color Palettes
    
    /// Primary colors for each urgency level (smooth gradient)
    static let urgencyGradient: [Color] = [
        Color(red: 0.2, green: 0.8, blue: 0.3),    // 🟢 Comfortable: Green
        Color(red: 0.3, green: 0.85, blue: 0.2),   // 🟢 Green-yellow
        Color(red: 0.5, green: 0.85, blue: 0.1),   // 🟡 Yellow-green
        Color(red: 0.8, green: 0.75, blue: 0.0),   // 🟡 Yellow
        Color(red: 0.9, green: 0.6, blue: 0.1),    // 🟠 Orange
        Color(red: 0.95, green: 0.4, blue: 0.1),   // 🟠 Red-orange
        Color(red: 0.9, green: 0.2, blue: 0.1),    // 🔴 Red
        Color(red: 1.0, green: 0.1, blue: 0.1)     // 🔴 Bright red
    ]
    
    // MARK: - Color Mapping from Urgency Score
    
    /// Get color based on urgency score (0.0-1.0)
    /// Uses smooth interpolation across gradient
    static func colorForUrgency(_ urgency: Double) -> Color {
        let clamped = max(0.0, min(urgency, 1.0))
        let index = clamped * Double(urgencyGradient.count - 1)
        let lowerIndex = Int(floor(index))
        let upperIndex = Int(ceil(index))
        let fraction = index - Double(lowerIndex)
        
        if lowerIndex == upperIndex {
            return urgencyGradient[lowerIndex]
        }
        
        let lowerColor = urgencyGradient[lowerIndex]
        let upperColor = urgencyGradient[upperIndex]
        
        // Simple interpolation - return approximate between two colors
        if fraction > 0.5 {
            return upperColor
        } else {
            return lowerColor
        }
    }
    
    // MARK: - Safety Status Colors
    
    /// Get primary color for safety status
    static func colorForSafetyStatus(_ status: SafetyStatus) -> Color {
        switch status {
        case .comfortable:
            return Color(red: 0.2, green: 0.8, blue: 0.3)      // 🟢 Green
        case .acceptable:
            return Color(red: 0.95, green: 0.6, blue: 0.1)     // 🟡 Orange
        case .tooRisky:
            return Color(red: 0.9, green: 0.2, blue: 0.1)      // 🔴 Red
        }
    }
    
    /// Get secondary/accent color for safety status
    static func accentColorForSafetyStatus(_ status: SafetyStatus) -> Color {
        switch status {
        case .comfortable:
            return Color(red: 0.1, green: 0.6, blue: 0.2)      // Darker green
        case .acceptable:
            return Color(red: 0.8, green: 0.4, blue: 0.0)      // Darker orange
        case .tooRisky:
            return Color(red: 0.7, green: 0.1, blue: 0.0)      // Darker red
        }
    }
    
    /// Get background color for safety status (subtle)
    static func backgroundColorForSafetyStatus(_ status: SafetyStatus, opacity: Double = 0.1) -> Color {
        colorForSafetyStatus(status).opacity(opacity)
    }
    
    // MARK: - Gradient Builders
    
    /// Create a linear gradient for progress indicators
    static func progressGradient(urgency: Double) -> LinearGradient {
        let color1 = colorForUrgency(0.0)              // Green (start)
        let color2 = colorForUrgency(urgency)          // Current urgency
        let color3 = colorForUrgency(1.0)              // Red (end)
        
        return LinearGradient(
            gradient: Gradient(colors: [color1, color2, color3]),
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    /// Create a radial gradient for badge backgrounds
    static func radialGradient(urgency: Double) -> RadialGradient {
        let primaryColor = colorForUrgency(urgency)
        let accentColor = colorForUrgency(max(0.0, urgency - 0.2))
        
        return RadialGradient(
            gradient: Gradient(colors: [primaryColor, accentColor]),
            center: .topLeading,
            startRadius: 5,
            endRadius: 50
        )
    }
    
    // MARK: - Status Information
    
    /// Get descriptive text for urgency level
    static func descriptionForUrgency(_ urgency: Double) -> String {
        switch urgency {
        case 0.0..<0.2:
            return "Relaxed - plenty of time"
        case 0.2..<0.4:
            return "Comfortable - good pace"
        case 0.4..<0.6:
            return "On time - normal pace"
        case 0.6..<0.8:
            return "Hurry up! - increase pace"
        case 0.8..<1.0:
            return "Rush! - walk fast"
        default:
            return "Critical - don't miss it!"
        }
    }
    
    /// Get emoji for urgency level
    static func emojiForUrgency(_ urgency: Double) -> String {
        switch urgency {
        case 0.0..<0.2:
            return "🟢"
        case 0.2..<0.4:
            return "🟢"
        case 0.4..<0.6:
            return "🟡"
        case 0.6..<0.8:
            return "🟠"
        case 0.8..<1.0:
            return "🔴"
        default:
            return "⚠️"
        }
    }
    
    // MARK: - Animation Intensity
    
    /// Get animation speed based on urgency (higher urgency = faster animation)
    static func animationDurationForUrgency(_ urgency: Double) -> Double {
        let clamped = max(0.0, min(urgency, 1.0))
        // Range: 2.0 seconds (relaxed) to 0.3 seconds (critical)
        return 2.0 - (clamped * 1.7)
    }
    
    /// Whether to apply pulsing animation based on urgency
    static func shouldPulseForUrgency(_ urgency: Double) -> Bool {
        return urgency > 0.6  // Pulse when urgency is high
    }
    
    /// Get pulse intensity (0.0-1.0) based on urgency
    static func pulseIntensityForUrgency(_ urgency: Double) -> Double {
        if urgency < 0.6 { return 0.0 }
        return (urgency - 0.6) / 0.4  // Map 0.6-1.0 to 0.0-1.0
    }
}


