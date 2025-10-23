//
//  TimeFormatting.swift
//  simpleDecision
//
//  Created by Transportation Recommendation System on 22/10/2025.
//

import Foundation
import SwiftUI
import Combine

/// Utility for formatting time displays with countdown and urgency indicators
struct TimeFormatting {
    
    // MARK: - Countdown Formatting
    
    /// Format minutes until departure as countdown text
    /// - Returns: "Now", "1 min", "5 mins", "15 mins", etc.
    static func formatCountdown(minutes: Int) -> String {
        switch minutes {
        case ...0:
            return "Now"
        case 1:
            return "1 min"
        default:
            return "\(minutes) mins"
        }
    }
    
    /// Format time interval as countdown with urgency
    /// - Returns: ("Now", .red), ("2 mins", .orange), ("10 mins", .green)
    static func formatCountdownWithUrgency(minutes: Int) -> (text: String, color: Color) {
        let text = formatCountdown(minutes: minutes)
        let color = urgencyColor(for: minutes)
        return (text, color)
    }
    
    /// Calculate urgency color based on minutes until departure
    static func urgencyColor(for minutes: Int) -> Color {
        switch minutes {
        case ...1:
            return .red      // 0-1 min: CRITICAL! Run now!
        case 2:
            return .orange   // 2 min: Very urgent, hurry!
        case 3...4:
            return .yellow   // 3-4 min: Moderate urgency, leave soon
        default:
            return .green    // 5+ min: Comfortable timing
        }
    }
    
    // MARK: - Time Display
    
    /// Format Date as short time (e.g., "7:12 PM")
    static func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    /// Format Date as relative time (e.g., "in 5 mins", "now")
    static func formatRelativeTime(_ date: Date) -> String {
        let interval = date.timeIntervalSinceNow
        let minutes = Int(interval / 60)
        
        if minutes <= 0 {
            return "now"
        } else if minutes == 1 {
            return "in 1 min"
        } else {
            return "in \(minutes) mins"
        }
    }
    
    /// Format Date with both absolute and relative time
    /// - Returns: "7:12 PM (in 5 mins)"
    static func formatTimeWithCountdown(_ date: Date) -> String {
        let time = formatTime(date)
        let relative = formatRelativeTime(date)
        return "\(time) (\(relative))"
    }
    
    // MARK: - Duration Formatting
    
    /// Format duration in minutes as readable text
    /// - Returns: "5 min", "15 mins", "1 hour", "1h 30m"
    static func formatDuration(minutes: Int) -> String {
        if minutes < 60 {
            return minutes == 1 ? "1 min" : "\(minutes) mins"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            
            if remainingMinutes == 0 {
                return hours == 1 ? "1 hour" : "\(hours) hours"
            } else {
                return "\(hours)h \(remainingMinutes)m"
            }
        }
    }
    
    /// Format duration with icon for visual clarity
    static func formatDurationWithIcon(minutes: Int) -> String {
        let icon = minutes < 5 ? "⚡️" : minutes < 15 ? "🚶" : "🐢"
        return "\(icon) \(formatDuration(minutes: minutes))"
    }
    
    // MARK: - Status Text
    
    /// Generate status text based on time until departure
    /// - Returns: "Departing now!", "Run!", "Hurry!", "Leave soon", "Good timing"
    static func departureStatusText(minutesUntil: Int) -> String {
        switch minutesUntil {
        case ...0:
            return "Departing now!"
        case 1:
            return "Run! Leaving in 1 min"
        case 2:
            return "Hurry! 2 mins"
        case 3...4:
            return "Leave soon"
        default:
            return "Good timing"
        }
    }
    
    /// Generate waiting status text
    /// - Returns: "Critical!", "Hurry!", "Leave soon", "Good timing"
    static func waitStatusText(minutes: Int) -> String {
        switch minutes {
        case ...1:
            return "Critical!"
        case 2:
            return "Hurry!"
        case 3...4:
            return "Leave soon"
        default:
            return "Good timing"
        }
    }
}

// MARK: - SwiftUI Extensions

extension Date {
    /// Minutes from now (positive if future, negative if past)
    var minutesFromNow: Int {
        let interval = self.timeIntervalSinceNow
        return Int(interval / 60)
    }
    
    /// Seconds from now
    var secondsFromNow: Int {
        let interval = self.timeIntervalSinceNow
        return Int(interval)
    }
    
    /// Check if date is in the past
    var isPast: Bool {
        return self < Date()
    }
    
    /// Check if date is within next N minutes
    func isWithin(minutes: Int) -> Bool {
        let targetDate = Date().addingTimeInterval(TimeInterval(minutes * 60))
        return self <= targetDate && self >= Date()
    }
}

// MARK: - Countdown Timer View

/// A view that automatically updates countdown display
public struct CountdownText: View {
    let targetDate: Date
    let style: CountdownStyle
    
    @State private var currentTime = Date()
    @State private var previousMinutes: Int = 0
    
    let timer = Timer.publish(every: 10, on: .main, in: .common).autoconnect()
    
    public enum CountdownStyle {
        case simple          // "5 mins"
        case withUrgency     // "5 mins" with color
        case detailed        // "7:12 PM (in 5 mins)"
        case statusText      // "Good timing"
    }
    
    public init(targetDate: Date, style: CountdownStyle) {
        self.targetDate = targetDate
        self.style = style
    }
    
    public var body: some View {
        Group {
            switch style {
            case .simple:
                Text(TimeFormatting.formatCountdown(minutes: currentMinutes))
                    .foregroundColor(.secondary)
                
            case .withUrgency:
                let (text, color) = TimeFormatting.formatCountdownWithUrgency(minutes: currentMinutes)
                Text(text)
                    .foregroundColor(color)
                    .animation(.easeInOut(duration: 0.3), value: color)
                
            case .detailed:
                Text(TimeFormatting.formatTimeWithCountdown(targetDate))
                    .foregroundColor(.secondary)
                
            case .statusText:
                let statusText = TimeFormatting.departureStatusText(minutesUntil: currentMinutes)
                let statusColor = TimeFormatting.urgencyColor(for: currentMinutes)
                Text(statusText)
                    .foregroundColor(statusColor)
                    .animation(.easeInOut(duration: 0.3), value: statusColor)
            }
        }
        .onAppear {
            previousMinutes = targetDate.minutesFromNow
        }
        .onReceive(timer) { _ in
            let newMinutes = targetDate.minutesFromNow
            if newMinutes != previousMinutes {
                withAnimation(.easeInOut(duration: 0.3)) {
                    currentTime = Date()
                    previousMinutes = newMinutes
                }
            }
        }
    }
    
    private var currentMinutes: Int {
        targetDate.minutesFromNow
    }
}

// MARK: - Urgency Badge View

/// Visual badge showing urgency level with icon and color
public struct UrgencyBadge: View {
    let minutes: Int
    @State private var isPulsing = false
    @State private var hasTriggeredHaptic = false
    
    public init(minutes: Int) {
        self.minutes = minutes
    }
    
    public var body: some View {
        let badge = HStack(spacing: 4) {
            Image(systemName: iconName)
                .font(.caption2)
            Text(TimeFormatting.formatCountdown(minutes: minutes))
                .font(.caption2)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(backgroundColor)
        .foregroundColor(foregroundColor)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(foregroundColor.opacity(0.3), lineWidth: 1)
        )
        .scaleEffect(isPulsing && isUrgent ? 1.05 : 1.0)
        .opacity(isPulsing && isUrgent ? 0.9 : 1.0)
        .animation(
            isUrgent ? 
                Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true) : 
                .default,
            value: isPulsing
        )
        .onAppear {
            if isUrgent {
                isPulsing = true
                triggerHapticFeedback()
            }
        }
        .onChange(of: minutes) {
            if minutes <= 2 && !hasTriggeredHaptic {
                triggerHapticFeedback()
            }
        }
        
        return badge
    }
    
    private var isUrgent: Bool {
        minutes <= 2  // Red or orange = urgent
    }
    
    private var iconName: String {
        switch minutes {
        case ...1: return "exclamationmark.triangle.fill"  // Critical!
        case 2: return "exclamationmark.circle.fill"       // Very urgent
        case 3...4: return "clock.fill"                    // Moderate urgency
        default: return "checkmark.circle.fill"            // Good timing
        }
    }
    
    private var backgroundColor: Color {
        // More visible background - 25% opacity instead of 15%
        TimeFormatting.urgencyColor(for: minutes).opacity(0.25)
    }
    
    private var foregroundColor: Color {
        // Darker, more visible foreground
        let baseColor = TimeFormatting.urgencyColor(for: minutes)
        // For light colors like green, make them darker for better contrast
        switch minutes {
        case 6...: 
            return Color(red: 0.0, green: 0.5, blue: 0.0) // Darker green
        default:
            return baseColor
        }
    }
    
    private func triggerHapticFeedback() {
        guard !hasTriggeredHaptic else { return }
        
        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        
        // Different haptic patterns based on urgency
        switch minutes {
        case ...1:
            // Strong WARNING for critical timing (0-1 min)
            generator.notificationOccurred(.warning)
        case 2:
            // ERROR haptic for very urgent (2 min)
            generator.notificationOccurred(.error)
        case 3...4:
            // Light impact for moderate urgency
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        default:
            break
        }
        #endif
        
        hasTriggeredHaptic = true
    }
}

// MARK: - Preview Provider

struct TimeFormatting_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // Countdown examples
            VStack(alignment: .leading, spacing: 8) {
                Text("Countdown Examples")
                    .font(.headline)
                
                CountdownText(
                    targetDate: Date().addingTimeInterval(60),
                    style: .simple
                )
                
                CountdownText(
                    targetDate: Date().addingTimeInterval(180),
                    style: .withUrgency
                )
                
                CountdownText(
                    targetDate: Date().addingTimeInterval(600),
                    style: .detailed
                )
                
                CountdownText(
                    targetDate: Date().addingTimeInterval(120),
                    style: .statusText
                )
            }
            
            Divider()
            
            // Urgency badges
            VStack(alignment: .leading, spacing: 8) {
                Text("Urgency Badges")
                    .font(.headline)
                
                HStack(spacing: 8) {
                    UrgencyBadge(minutes: 0)
                    UrgencyBadge(minutes: 2)
                    UrgencyBadge(minutes: 5)
                    UrgencyBadge(minutes: 10)
                }
            }
        }
        .padding()
    }
}
