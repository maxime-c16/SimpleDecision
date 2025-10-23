//
//  TransportationRecommendationWidgetLiveActivity.swift
//  TransportationRecommendationWidget
//
//  Created by Tristan Aranda  on 30/09/2025.
//

import ActivityKit
import WidgetKit
import SwiftUI

// TransportationRecommendationWidgetAttributes is defined in SharedModels.swift

struct TransportationRecommendationWidgetLiveActivity: Widget {
    let kind: String = "TransportationRecommendationWidget"
    
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TransportationRecommendationWidgetAttributes.self) { context in
            // Lock Screen / Banner UI with Phase 2 enhancements
            RecommendationLockScreenView(context: context)
                .activityBackgroundTint(Color.clear)
                .activitySystemActionForegroundColor(Color.primary)
        } dynamicIsland: { context in
            // Dynamic Island UI with Phase 2 enhancements
            DynamicIsland {
                // MARK: - Expanded Regions
                
                DynamicIslandExpandedRegion(.leading) {
                    // Mode icon with safety badge overlay
                    ZStack(alignment: .topTrailing) {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        context.state.recommendation.mode.uiColor.opacity(0.3),
                                        context.state.recommendation.mode.uiColor.opacity(0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 36, height: 36)
                        
                        Image(systemName: context.state.recommendation.mode.iconName)
                            .foregroundColor(context.state.recommendation.mode.uiColor)
                            .font(.system(size: 16, weight: .semibold))
                        
                        // Phase 2: Safety badge
                        if let safetyLevel = context.state.recommendation.safetyLevel {
                            Text(safetyEmoji(for: safetyLevel))
                                .font(.system(size: 10))
                                .offset(x: 2, y: -2)
                        }
                    }
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    // Phase 2: ETA with urgency indicators
                    VStack(alignment: .trailing, spacing: 2) {
                        if let eta = context.state.recommendation.primaryETA {
                            HStack(alignment: .firstTextBaseline, spacing: 2) {
                                if let urgency = context.state.recommendation.urgencyScore {
                                    Text(urgencyEmoji(for: urgency))
                                        .font(.caption2)
                                }
                                Text("\(eta)")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(
                                        context.state.recommendation.urgencyScore.map { urgencyColor(for: $0) } ?? .primary
                                    )
                                Text("min")
                                    .font(.caption2)
                            }
                        }
                        
                        // Phase 2: Buffer with safety indicator
                        if let buffer = context.state.recommendation.bufferMinutes {
                            HStack(spacing: 3) {
                                if let safety = context.state.recommendation.safetyLevel {
                                    Text(safetyEmoji(for: safety))
                                        .font(.system(size: 9))
                                }
                                Text("⏱️\(buffer)m")
                                    .font(.caption2)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(buffer < 2 ? .red : buffer < 4 ? .orange : .green)
                        }
                    }
                }
                
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.recommendation.mode.displayName)
                        .font(.subheadline)
                        .fontWeight(.bold)
                }
                
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 6) {
                        // Transit details or walk/bus comparison
                        if let transit = context.state.recommendation.transitDetails {
                            HStack(spacing: 8) {
                                HStack(spacing: 4) {
                                    Image(systemName: "bus.fill")
                                        .font(.caption2)
                                        .foregroundColor(.blue)
                                    Text(transit.lineName)
                                        .font(.caption)
                                        .fontWeight(.bold)
                                }
                                
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 8))
                                
                                Text(transit.destinationName)
                                    .font(.caption2)
                                    .lineLimit(1)
                                
                                Spacer()
                                
                                HStack(spacing: 8) {
                                    Label("\(transit.walkToStopMinutes)m", systemImage: "figure.walk")
                                        .font(.caption2)
                                    Label("\(transit.minutesUntilDeparture)m", systemImage: "clock.fill")
                                        .font(.caption2)
                                }
                            }
                            .foregroundColor(.secondary)
                        } else if context.state.recommendation.walkETA != nil && 
                                  context.state.recommendation.busETA != nil {
                            HStack(spacing: 16) {
                                if let walkETA = context.state.recommendation.walkETA {
                                    HStack(spacing: 3) {
                                        Image(systemName: "figure.walk")
                                            .font(.caption)
                                        Text("\(walkETA)m")
                                            .font(.caption)
                                            .fontWeight(context.state.recommendation.mode == .walk ? .bold : .semibold)
                                    }
                                    .foregroundColor(context.state.recommendation.mode == .walk ? .primary : .secondary)
                                }
                                
                                if let busETA = context.state.recommendation.busETA {
                                    HStack(spacing: 3) {
                                        Image(systemName: "bus")
                                            .font(.caption)
                                        Text("\(busETA)m")
                                            .font(.caption)
                                            .fontWeight(context.state.recommendation.mode == .bus ? .bold : .semibold)
                                    }
                                    .foregroundColor(context.state.recommendation.mode == .bus ? .primary : .secondary)
                                }
                            }
                        }
                        
                        // Phase 2: Urgency progress bar
                        if let urgency = context.state.recommendation.urgencyScore {
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color.secondary.opacity(0.2))
                                        .frame(height: 3)
                                    
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(urgencyColor(for: urgency))
                                        .frame(width: geometry.size.width * urgency, height: 3)
                                }
                            }
                            .frame(height: 3)
                        }
                    }
                }
                
            } compactLeading: {
                // Compact: Show both route icons side-by-side
                HStack(spacing: 4) {
                    // Walk icon
                    ZStack {
                        Circle()
                            .fill(context.state.recommendation.mode == TransportationMode.walk ?
                                  Color.green : Color.gray.opacity(0.3))
                            .frame(width: 16, height: 16)
                        Image(systemName: "figure.walk")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    
                    // Bus icon
                    ZStack {
                        Circle()
                            .fill(context.state.recommendation.mode == TransportationMode.bus ?
                                  Color.blue : Color.gray.opacity(0.3))
                            .frame(width: 16, height: 16)
                        Image(systemName: "bus.fill")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                
            } compactTrailing: {
                // Compact: Show both ETAs
                HStack(spacing: 6) {
                    if let walkETA = context.state.recommendation.walkETA {
                        HStack(spacing: 1) {
                            if context.state.recommendation.mode == TransportationMode.walk,
                               let urgency = context.state.recommendation.urgencyScore {
                                Text(urgencyEmoji(for: urgency))
                                    .font(.system(size: 7))
                            }
                            Text("\(walkETA)")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(context.state.recommendation.mode == TransportationMode.walk ?
                                               urgencyColor(for: context.state.recommendation.urgencyScore ?? 0) : .secondary)
                        }
                    }
                    
                    Text("|")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    
                    if let busETA = context.state.recommendation.busETA {
                        HStack(spacing: 1) {
                            if context.state.recommendation.mode == TransportationMode.bus,
                               let urgency = context.state.recommendation.urgencyScore {
                                Text(urgencyEmoji(for: urgency))
                                    .font(.system(size: 7))
                            }
                            Text("\(busETA)")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(context.state.recommendation.mode == TransportationMode.bus ?
                                               urgencyColor(for: context.state.recommendation.urgencyScore ?? 0) : .secondary)
                        }
                    }
                }
                
            } minimal: {
                // Minimal: Show urgency emoji or mode icon
                if let urgency = context.state.recommendation.urgencyScore {
                    Text(urgencyEmoji(for: urgency))
                        .font(.system(size: 10))
                } else {
                    Image(systemName: context.state.recommendation.mode.iconName)
                        .foregroundColor(context.state.recommendation.mode.uiColor)
                        .font(.system(size: 10, weight: .semibold))
                }
            }
            .widgetURL(URL(string: "simpledecision://recommendation"))
            .keylineTint(
                context.state.recommendation.urgencyScore.map { urgencyColor(for: $0) } ?? 
                context.state.recommendation.mode.uiColor
            )
        }
    }
}

// MARK: - Lock Screen View (Dual-Route Design from spec 002)

struct RecommendationLockScreenView: View {
    let context: ActivityViewContext<TransportationRecommendationWidgetAttributes>
    
    var body: some View {
        VStack(spacing: 0) {
            // Dual-pane route comparison with improved spacing
            HStack(spacing: 0) {
                // 🏃 Walk Route (Left) - Shows walking time to destination
                RoutePane(
                    icon: "figure.walk",
                    title: "Walk",
                    eta: context.state.recommendation.walkETA,
                    urgency: context.state.recommendation.mode == TransportationMode.walk ? 
                             context.state.recommendation.urgencyScore : calculateWalkUrgency(recommendation: context.state.recommendation),
                    buffer: context.state.recommendation.walkETA,  // Display actual walking time
                    isRecommended: context.state.recommendation.mode == TransportationMode.walk,
                    safetyLevel: context.state.recommendation.mode == TransportationMode.walk ? 
                                 context.state.recommendation.safetyLevel : nil,
                    transitLine: nil,
                    walkToStop: nil,
                    waitTime: nil  // Walk route doesn't use this
                )
                
                // Elegant divider with gradient
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.1),
                                Color.white.opacity(0.35),
                                Color.white.opacity(0.1)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 1)
                
                // 🚌 Bus + RER Route (Right) - Shows bus wait time at stop
                RoutePane(
                    icon: "bus.fill",
                    title: "Bus",
                    eta: context.state.recommendation.busETA,
                    urgency: context.state.recommendation.mode == TransportationMode.bus ? 
                             context.state.recommendation.urgencyScore : calculateBusUrgency(recommendation: context.state.recommendation),
                    buffer: context.state.recommendation.mode == TransportationMode.bus ?
                            context.state.recommendation.bufferMinutes : nil,
                    isRecommended: context.state.recommendation.mode == TransportationMode.bus,
                    safetyLevel: context.state.recommendation.mode == TransportationMode.bus ? 
                                 context.state.recommendation.safetyLevel : nil,
                    transitLine: context.state.recommendation.transitDetails?.lineName,
                    walkToStop: context.state.recommendation.transitDetails?.walkToStopMinutes,
                    waitTime: calculateBusWaitAtStop(recommendation: context.state.recommendation)
                )
            }
            .frame(height: 140)  // Full height without bottom bar
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Route Pane Component

struct RoutePane: View {
    let icon: String
    let title: String
    let eta: Int?                // Not used - keeping for compatibility
    let urgency: Double?
    let buffer: Int?             // THIS IS THE KEY: wait time!
    let isRecommended: Bool
    let safetyLevel: String?
    var transitLine: String? = nil
    var walkToStop: Int? = nil
    var waitTime: Int? = nil     // For bus: wait at stop
    
    var body: some View {
        ZStack(alignment: .center) {
            // Background gradient - softer for Lock Screen
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: backgroundGradient,
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            
            // Subtle depth overlay
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.0),
                            Color.black.opacity(0.12)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            
            // Gloss overlay for polish
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.08),
                            Color.white.opacity(0.0)
                        ],
                        startPoint: .top,
                        endPoint: .center
                    )
                )
            
            // Main content - symmetrical layout
            HStack(spacing: 0) {
                // Left side - Icon OR spacer (symmetrical width)
                Group {
                    if icon == "figure.walk" {
                        Image(systemName: icon)
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                            .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                    } else {
                        Color.clear
                    }
                }
                .frame(width: 50)
                .frame(maxHeight: .infinity, alignment: .center)
                
                // Center - Main content (perfectly centered)
                VStack(spacing: 6) {
                    // Wait time number + label (grouped together)
                    VStack(spacing: 2) {
                        Text("\(displayWaitTime)")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.25), radius: 2, x: 0, y: 1.5)
                            .minimumScaleFactor(0.7)
                            .lineLimit(1)
                        
                        Text("min wait")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.85))
                            .lineLimit(1)
                    }
                    
                    // Urgency badge (compact)
                    if let urgency = urgency {
                        HStack(spacing: 3) {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 4, height: 4)
                            Text(statusText)
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(.white.opacity(0.92))
                                .tracking(0.2)
                        }
                        .padding(.vertical, 3)
                        .padding(.horizontal, 8)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.18))
                        )
                    }
                }
                .frame(maxWidth: .infinity)
                
                // Right side - Icon only
                Group {
                    if icon == "bus.fill" {
                        Image(systemName: icon)
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                            .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                    } else {
                        Color.clear
                    }
                }
                .frame(width: 50)
                .frame(maxHeight: .infinity, alignment: .center)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 10)
            
            // Bus line name at bottom (if present)
            if let line = transitLine, icon == "bus.fill" {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text(line)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white.opacity(0.9))
                            .lineLimit(1)
                        Spacer()
                    }
                    .padding(.bottom, 6)
                    .padding(.horizontal, 8)
                }
            }
            
            // Checkmark badge - top right (smaller, cleaner)
            if isRecommended {
                VStack {
                    HStack {
                        Spacer()
                        Circle()
                            .fill(Color.white)
                            .frame(width: 14, height: 14)
                            .overlay(
                                Image(systemName: "checkmark")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(.green)
                            )
                            .shadow(color: .black.opacity(0.12), radius: 1.5, x: 0, y: 1)
                    }
                    Spacer()
                }
                .padding(7)
            }
        }
    }
    
    // Computed property: Show wait time (buffer for walk, waitTime for bus)
    private var displayWaitTime: String {
        if let wait = waitTime {
            return "\(wait)"  // Bus: wait at stop
        } else if let buffer = buffer {
            return "\(buffer)"  // Walk: RER wait time
        } else {
            return "--"
        }
    }
    
    private var backgroundGradient: [Color] {
        guard let urgency = urgency else {
            // Subtle gray gradient for non-recommended routes
            return [
                Color(white: 0.35, opacity: 0.7),
                Color(white: 0.28, opacity: 0.8)
            ]
        }
        
        // Sophisticated gradients with proper saturation
        if urgency < 0.3 {
            // Green: Comfortable, plenty of time
            return [
                Color(red: 0.25, green: 0.7, blue: 0.4),   // Softer green
                Color(red: 0.18, green: 0.55, blue: 0.3)
            ]
        } else if urgency < 0.7 {
            // Yellow/Orange: Need to move, but manageable
            return [
                Color(red: 0.95, green: 0.7, blue: 0.15),  // Warmer, less neon
                Color(red: 0.85, green: 0.55, blue: 0.05)
            ]
        } else {
            // Red: Urgent, need to hurry
            return [
                Color(red: 0.95, green: 0.3, blue: 0.25),  // Less harsh red
                Color(red: 0.8, green: 0.2, blue: 0.15)
            ]
        }
    }
    
    private var statusText: String {
        guard let urgency = urgency else { return "" }
        
        if urgency < 0.3 {
            return "On Time"
        } else if urgency < 0.7 {
            return "Hurry"
        } else {
            return "Rush"
        }
    }
}

// MARK: - Dynamic Island Component Views - Removed (now inline)

// MARK: - Phase 2 Helper Functions

/// Calculate urgency for non-recommended walk route (simple heuristic)
fileprivate func calculateWalkUrgency(recommendation: Recommendation) -> Double? {
    guard let walkETA = recommendation.walkETA else {
        print("📊 Live Activity: Walk ETA not available")
        return nil
    }
    
    // Simple urgency heuristic: longer walk = more urgent (need to leave earlier)
    // 8-10 min walk = low urgency (0.2-0.3)
    // 11-15 min walk = medium urgency (0.4-0.6)
    // 16+ min walk = high urgency (0.7+)
    let urgency: Double
    if walkETA <= 10 {
        urgency = 0.2
    } else if walkETA <= 15 {
        urgency = 0.5
    } else {
        urgency = 0.8
    }
    
    print("📊 Live Activity: Walk urgency calculated - ETA: \(walkETA)min → Urgency: \(String(format: "%.2f", urgency))")
    return urgency
}

/// Calculate urgency for non-recommended bus route (based on wait time)
fileprivate func calculateBusUrgency(recommendation: Recommendation) -> Double? {
    guard let transit = recommendation.transitDetails else {
        print("📊 Live Activity: Bus transit details not available")
        return nil
    }
    
    let waitTime = transit.minutesUntilDeparture
    
    // Urgency based on bus wait time
    // 0-2 min = high urgency (0.8-0.9) - need to hurry!
    // 3-5 min = medium urgency (0.4-0.6)
    // 6+ min = low urgency (0.1-0.3) - plenty of time
    let urgency: Double
    if waitTime <= 2 {
        urgency = 0.85
    } else if waitTime <= 5 {
        urgency = 0.5
    } else {
        urgency = 0.2
    }
    
    print("📊 Live Activity: Bus urgency calculated - Wait: \(waitTime)min → Urgency: \(String(format: "%.2f", urgency))")
    return urgency
}

/// Calculate RER wait time for walk route (when bus is recommended)

/// Calculate actual bus wait time at stop (EXCLUDING walk time)
fileprivate func calculateBusWaitAtStop(recommendation: Recommendation) -> Int? {
    guard let transit = recommendation.transitDetails else {
        print("📊 Live Activity: Transit details not available")
        return nil
    }
    
    let minutesUntilDeparture = transit.minutesUntilDeparture
    let walkToStop = transit.walkToStopMinutes
    
    // Wait time = total time until departure - time to walk to stop
    let waitAtStop = max(0, minutesUntilDeparture - walkToStop)
    
    print("📊 Live Activity: Bus wait at stop - \(minutesUntilDeparture)min until departure - \(walkToStop)min walk = \(waitAtStop)min wait")
    return waitAtStop
}

/// Get safety emoji from string level
fileprivate func safetyEmoji(for level: String) -> String {
    switch level {
    case "comfortable":
        return "✅"
    case "acceptable":
        return "⚠️"
    case "tooRisky":
        return "🚫"
    default:
        return "⚠️"
    }
}

/// Get urgency color from score
fileprivate func urgencyColor(for score: Double) -> Color {
    switch score {
    case 0.0..<0.2:
        return Color(red: 0.2, green: 0.8, blue: 0.3)      // Green
    case 0.2..<0.4:
        return Color(red: 0.5, green: 0.85, blue: 0.1)     // Yellow-green
    case 0.4..<0.6:
        return Color(red: 0.8, green: 0.75, blue: 0.0)     // Yellow
    case 0.6..<0.8:
        return Color(red: 0.95, green: 0.4, blue: 0.1)     // Orange
    default:
        return Color(red: 0.9, green: 0.2, blue: 0.1)      // Red
    }
}

/// Get urgency emoji from score
fileprivate func urgencyEmoji(for score: Double) -> String {
    switch score {
    case 0.0..<0.4:
        return "🟢"
    case 0.4..<0.6:
        return "🟡"
    case 0.6..<0.8:
        return "🟠"
    default:
        return "🔴"
    }
}

extension TransportationRecommendationWidgetAttributes {
    fileprivate static var preview: TransportationRecommendationWidgetAttributes {
        TransportationRecommendationWidgetAttributes(sessionId: "preview-session")
    }
}

extension TransportationRecommendationWidgetAttributes.ContentState {
    fileprivate static var walkRecommendation: TransportationRecommendationWidgetAttributes.ContentState {
        TransportationRecommendationWidgetAttributes.ContentState(
            recommendation: Recommendation.mockWalk,
            lastUpdated: Date()
        )
     }
     
     fileprivate static var busRecommendation: TransportationRecommendationWidgetAttributes.ContentState {
         TransportationRecommendationWidgetAttributes.ContentState(
            recommendation: Recommendation.mockBus,
            lastUpdated: Date()
         )
     }
}

#Preview("Notification", as: .content, using: TransportationRecommendationWidgetAttributes.preview) {
   TransportationRecommendationWidgetLiveActivity()
} contentStates: {
    TransportationRecommendationWidgetAttributes.ContentState.walkRecommendation
    TransportationRecommendationWidgetAttributes.ContentState.busRecommendation
}
