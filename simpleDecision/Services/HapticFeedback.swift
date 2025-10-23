//
//  HapticFeedback.swift
//  simpleDecision
//
//  Created by Phase 2 - Visual Feedback System on 23/10/2025.
//

import UIKit
import Foundation

/// Manages haptic feedback based on safety status and urgency changes
class HapticFeedback {
    static let shared = HapticFeedback()
    
    private let impactGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let notificationGenerator = UINotificationFeedbackGenerator()
    private let selectionGenerator = UISelectionFeedbackGenerator()
    
    // MARK: - Haptic Feedback Triggers
    
    /// Trigger haptic for safety status change
    func triggerForSafetyStatusChange(from oldStatus: SafetyStatus?, to newStatus: SafetyStatus) {
        DispatchQueue.main.async {
            switch newStatus {
            case .comfortable:
                // Light positive feedback
                self.triggerLightSuccess()
                
            case .acceptable:
                // Medium warning feedback
                self.triggerWarning()
                
            case .tooRisky:
                // Strong warning feedback
                self.triggerCriticalWarning()
            }
        }
    }
    
    /// Trigger haptic for urgency threshold crossing
    func triggerForUrgencyThreshold(urgency: Double) {
        DispatchQueue.main.async {
            switch urgency {
            case 0.0..<0.2:
                // Relaxed - no feedback needed
                break
                
            case 0.2..<0.4:
                // Comfortable - subtle feedback
                self.triggerSubtle()
                
            case 0.4..<0.6:
                // On time - medium feedback
                self.triggerMedium()
                
            case 0.6..<0.8:
                // Hurry up - increasing urgency
                self.triggerIncreasingUrgency()
                
            case 0.8...1.0:
                // RUSH - strong feedback
                self.triggerCriticalUrgency()
                
            default:
                break
            }
        }
    }
    
    /// Trigger haptic for route recommendation
    func triggerForRouteRecommendation(safetyStatus: SafetyStatus) {
        DispatchQueue.main.async {
            switch safetyStatus {
            case .comfortable:
                self.triggerPositiveConfirmation()
                
            case .acceptable:
                self.triggerNeutralConfirmation()
                
            case .tooRisky:
                self.triggerWarningConfirmation()
            }
        }
    }
    
    /// Trigger haptic when buffer time is running out
    func triggerBufferRunningOut(secondsRemaining: Int) {
        DispatchQueue.main.async {
            if secondsRemaining < 30 {
                // Less than 30 seconds - rapid pulses
                self.triggerRapidPulses(count: 3)
            } else if secondsRemaining < 60 {
                // Less than 1 minute - double pulse
                self.triggerDoublePulse()
            }
        }
    }
    
    // MARK: - Individual Haptic Types
    
    private func triggerLightSuccess() {
        print("🔔 Haptic: Light success")
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
    
    private func triggerMedium() {
        print("🔔 Haptic: Medium impact")
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    private func triggerSubtle() {
        print("🔔 Haptic: Subtle selection")
        selectionGenerator.selectionChanged()
    }
    
    private func triggerWarning() {
        print("🔔 Haptic: Warning")
        notificationGenerator.notificationOccurred(.warning)
    }
    
    private func triggerIncreasingUrgency() {
        print("🔔 Haptic: Increasing urgency")
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
    }
    
    private func triggerCriticalUrgency() {
        print("🔔 Haptic: Critical urgency (rapid)")
        triggerRapidPulses(count: 4)
    }
    
    private func triggerCriticalWarning() {
        print("🔔 Haptic: Critical warning")
        notificationGenerator.notificationOccurred(.error)
    }
    
    private func triggerPositiveConfirmation() {
        print("🔔 Haptic: Positive confirmation")
        notificationGenerator.notificationOccurred(.success)
    }
    
    private func triggerNeutralConfirmation() {
        print("🔔 Haptic: Neutral confirmation")
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    private func triggerWarningConfirmation() {
        print("🔔 Haptic: Warning confirmation")
        notificationGenerator.notificationOccurred(.warning)
    }
    
    private func triggerDoublePulse() {
        print("🔔 Haptic: Double pulse")
        let generator = UIImpactFeedbackGenerator(style: .medium)
        
        generator.impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            generator.impactOccurred()
        }
    }
    
    private func triggerRapidPulses(count: Int) {
        print("🔔 Haptic: Rapid pulses (\(count)x)")
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        
        for i in 0..<count {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.1) {
                generator.impactOccurred()
            }
        }
    }
}

// MARK: - Convenience Extensions

extension SafetyStatus {
    /// Trigger haptic feedback when status is reached
    func triggerHapticFeedback() {
        HapticFeedback.shared.triggerForSafetyStatusChange(from: nil, to: self)
    }
}
