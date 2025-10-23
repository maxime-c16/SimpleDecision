//
//  RecommendationCards.swift
//  simpleDecision
//
//  Created by Transportation Recommendation System on 22/10/2025.
//

import SwiftUI

// MARK: - Primary Recommendation Card

/// Main card displaying the primary recommendation (Walk or Bus)
struct PrimaryRecommendationCard: View {
    let recommendation: EnhancedRecommendation
    @State private var selectedTab: RecommendationTab = .recommended
    
    enum RecommendationTab {
        case recommended
        case alternative
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with icon and recommendation type
            HStack(spacing: 16) {
                // Icon with gradient background
                ZStack {
                    LinearGradient(
                        colors: [recommendationColor.opacity(0.3), recommendationColor.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(width: 60, height: 60)
                    .cornerRadius(16)
                    
                    Image(systemName: recommendationIcon)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [recommendationColor, recommendationColor.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(recommendationTitle)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                // Total time - larger and more prominent, fixed width to prevent wrapping
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text("\(currentETA)")
                        .font(.system(size: 44, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.primary, .primary.opacity(0.7)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .fixedSize()
                    Text("min")
                        .font(.title3)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 4)
                        .fixedSize()
                }
                .fixedSize(horizontal: true, vertical: false)
            }
            
            // Tab picker for alternative option
            if hasAlternative {
                Picker("View", selection: $selectedTab) {
                    Text(recommendationTitle).tag(RecommendationTab.recommended)
                    Text(alternativeTitle).tag(RecommendationTab.alternative)
                }
                .pickerStyle(.segmented)
                .padding(.vertical, 4)
            }
            
            Divider()
            
            // Details based on selected tab
            if selectedTab == .recommended {
                if recommendation.recommendationType == .walk, let walkDetails = recommendation.walkDetails {
                    WalkDetailsSection(details: walkDetails)
                } else if recommendation.recommendationType == .bus, let busOption = recommendation.primaryBusOption {
                    BusDetailsSection(busOption: busOption)
                }
            } else {
                // Show alternative option
                if recommendation.recommendationType == .bus, let walkDetails = recommendation.walkDetails {
                    WalkDetailsSection(details: walkDetails)
                } else if recommendation.recommendationType == .walk, let busOption = recommendation.primaryBusOption {
                    BusDetailsSection(busOption: busOption)
                }
            }
            
            // Confidence indicator - more compact and modern
            HStack(spacing: 6) {
                Image(systemName: "chart.bar.fill")
                    .font(.caption2)
                Text("\(Int(recommendation.confidence * 100))%")
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            .foregroundStyle(
                LinearGradient(
                    colors: [confidenceColor, confidenceColor.opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(confidenceColor.opacity(0.12))
            )
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 6)
        )
    }
    
    // MARK: - Computed Properties
    
    private var hasAlternative: Bool {
        // Has alternative if both walk and bus options exist
        recommendation.walkDetails != nil && recommendation.primaryBusOption != nil
    }
    
    private var alternativeTitle: String {
        switch recommendation.recommendationType {
        case .walk: return "Take Bus"
        case .bus: return "Walk"
        case .tie: return "Other Option"
        }
    }
    
    private var currentETA: Int {
        if selectedTab == .recommended {
            return recommendation.primaryETA
        } else {
            // Return alternative ETA
            if recommendation.recommendationType == .walk {
                // If walk is recommended, show bus as alternative
                return recommendation.primaryBusOption?.totalMinutes ?? recommendation.primaryETA
            } else {
                // If bus is recommended, show walk as alternative
                return recommendation.walkDetails?.totalMinutes ?? recommendation.primaryETA
            }
        }
    }
    
    private var recommendationTitle: String {
        switch recommendation.recommendationType {
        case .walk: return "Walk"
        case .bus: return "Take Bus"
        case .tie: return "Either Option"
        }
    }
    
    private var recommendationIcon: String {
        switch recommendation.recommendationType {
        case .walk: return "figure.walk"
        case .bus: return "bus.fill"
        case .tie: return "arrow.left.arrow.right"
        }
    }
    
    private var recommendationColor: Color {
        switch recommendation.recommendationType {
        case .walk: return Color(red: 0.2, green: 0.78, blue: 0.35) // Modern green
        case .bus: return Color(red: 0.0, green: 0.48, blue: 1.0) // iOS blue
        case .tie: return Color(red: 1.0, green: 0.58, blue: 0.0) // Vibrant orange
        }
    }
    
    private var confidenceColor: Color {
        let confidence = recommendation.confidence
        if confidence >= 0.8 {
            return Color(red: 0.2, green: 0.78, blue: 0.35) // High confidence - green
        } else if confidence >= 0.6 {
            return Color(red: 1.0, green: 0.58, blue: 0.0) // Medium - orange
        } else {
            return Color(red: 1.0, green: 0.27, blue: 0.23) // Low - red
        }
    }
}

// MARK: - Walk Details Section

struct WalkDetailsSection: View {
    let details: WalkRecommendationDetails
    
    var body: some View {
        VStack(spacing: 12) {
            // Walk to station
            TimingRow(
                icon: "figure.walk",
                iconColor: .orange,
                label: "Walk to \(details.stationName)",
                time: details.walkToStationMinutes,
                unit: "min"
            )
            
            // RER Schedule with departure time
            HStack(spacing: 8) {
                Image(systemName: "tram.fill")
                    .foregroundColor(.purple)
                    .frame(width: 20)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Wait for RER")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    CountdownText(
                        targetDate: details.rerDepartureTime,
                        style: .detailed
                    )
                    .font(.caption)
                }
                
                Spacer()
                
                UrgencyBadge(minutes: details.rerDepartureTime.minutesFromNow)
            }
            
            // Next bus hint (if available)
            if let nextBusMinutes = details.nextBusOptionMinutes {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                    Text("Next bus option in \(nextBusMinutes) min")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }
}

// MARK: - Bus Details Section

struct BusDetailsSection: View {
    let busOption: BusOptionTiming
    
    var body: some View {
        VStack(spacing: 12) {
            // Bus line and destination
            HStack(spacing: 8) {
                Image(systemName: "bus.fill")
                    .foregroundColor(.blue)
                Text(busOption.lineName)
                    .font(.headline)
                    .fontWeight(.bold)
                Image(systemName: "arrow.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(busOption.destinationName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Timing breakdown
            VStack(spacing: 8) {
                TimingRow(
                    icon: "figure.walk",
                    iconColor: .orange,
                    label: "Walk to \(busOption.stopName)",
                    time: busOption.walkToStopMinutes,
                    unit: "min"
                )
                
                TimingRow(
                    icon: "clock.fill",
                    iconColor: .blue,
                    label: "Wait for bus",
                    time: busOption.waitAtStopMinutes,
                    unit: "min",
                    badge: UrgencyBadge(minutes: busOption.waitAtStopMinutes)
                )
                
                TimingRow(
                    icon: "bus.fill",
                    iconColor: .green,
                    label: "Bus ride",
                    time: busOption.busRideMinutes,
                    unit: "min"
                )
                
                if let rerSchedule = busOption.rerScheduleDisplay {
                    HStack(spacing: 8) {
                        Image(systemName: "tram.fill")
                            .foregroundColor(.purple)
                            .frame(width: 20)
                        
                        Text(rerSchedule)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                } else if let rerWait = busOption.rerWaitMinutes {
                    TimingRow(
                        icon: "tram.fill",
                        iconColor: .purple,
                        label: "Wait for RER",
                        time: rerWait,
                        unit: "min",
                        badge: UrgencyBadge(minutes: rerWait)
                    )
                }
            }
            
            // Departure status - simplified
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "clock.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatTime(busOption.departureTime))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                StatusBadge(status: busOption.departureStatus)
            }
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Timing Row Component

struct TimingRow: View {
    let icon: String
    let iconColor: Color
    let label: String
    let time: Int
    let unit: String
    var badge: UrgencyBadge? = nil
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon with subtle background
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 32, height: 32)
                
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(iconColor)
            }
            
            Text(label)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
            
            if let badge = badge {
                badge
            }
            
            Text("\(time) \(unit)")
                .font(.body)
                .fontWeight(.bold)
                .foregroundColor(.primary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Status Badge

struct StatusBadge: View {
    let status: String
    
    var body: some View {
        Text(statusText)
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor)
            .cornerRadius(6)
    }
    
    private var statusText: String {
        switch status.lowercased() {
        case "ontime": return "On Time"
        case "delayed": return "Delayed"
        case "early": return "Early"
        case "cancelled": return "Cancelled"
        default: return status
        }
    }
    
    private var statusColor: Color {
        switch status.lowercased() {
        case "ontime": return .green
        case "delayed": return .orange
        case "early": return .blue
        case "cancelled": return .red
        default: return .gray
        }
    }
}

// MARK: - Bus Schedule Card

/// Card showing a single bus option with all timing details
struct BusScheduleCard: View {
    let busOption: BusOptionTiming
    let isRecommended: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "bus.fill")
                        .foregroundColor(.blue)
                    Text(busOption.lineName)
                        .font(.headline)
                        .fontWeight(.bold)
                }
                
                Spacer()
                
                // Total time badge
                HStack(spacing: 4) {
                    Image(systemName: "clock.fill")
                        .font(.caption2)
                    Text("\(busOption.totalMinutes) min")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(isRecommended ? Color.blue : Color.gray)
                .cornerRadius(8)
            }
            
            // Destination
            HStack(spacing: 6) {
                Image(systemName: "arrow.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(busOption.destinationName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            // Timing breakdown
            VStack(spacing: 8) {
                CompactTimingRow(icon: "figure.walk", label: "Walk", time: busOption.walkToStopMinutes)
                CompactTimingRow(icon: "clock", label: "Wait", time: busOption.waitAtStopMinutes)
                CompactTimingRow(icon: "bus", label: "Ride", time: busOption.busRideMinutes)
                if let rerSchedule = busOption.rerScheduleDisplay {
                    HStack(spacing: 4) {
                        Image(systemName: "tram.fill")
                            .font(.caption2)
                            .foregroundColor(.purple)
                        Text(rerSchedule)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                } else if let rerWait = busOption.rerWaitMinutes {
                    CompactTimingRow(icon: "tram", label: "RER wait", time: rerWait)
                }
            }
            
            // Departure info
            HStack {
                CountdownText(
                    targetDate: busOption.departureTime,
                    style: .simple
                )
                .font(.caption)
                Spacer()
                UrgencyBadge(minutes: busOption.departureTime.minutesFromNow)
                StatusBadge(status: busOption.departureStatus)
            }
            
            // Recommended badge
            if isRecommended {
                HStack {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                    Text("Recommended")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundColor(.blue)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.15))
                .cornerRadius(8)
            }
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isRecommended ? Color.blue : Color.clear, lineWidth: 2)
        )
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Compact Timing Row

struct CompactTimingRow: View {
    let icon: String
    let label: String
    let time: Int
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 16)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text("\(time) min")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
    }
}

// MARK: - Destination Bus List Card

/// Card showing all available bus schedules with RER wait hints
struct DestinationBusListCard: View {
    let title: String
    let busOptions: [BusOptionTiming]
    let recommendedId: UUID?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text(title)
                    .font(.headline)
                    .fontWeight(.bold)
                
                Spacer()
                
                Text("\(busOptions.count) options")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(6)
            }
            
            // Bus options list
            if busOptions.isEmpty {
                EmptyBusListView()
            } else {
                VStack(spacing: 12) {
                    ForEach(busOptions) { option in
                        BusScheduleCard(
                            busOption: option,
                            isRecommended: option.id == recommendedId
                        )
                    }
                }
            }
        }
        .padding(20)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Empty Bus List View

struct EmptyBusListView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "bus.slash")
                .font(.system(size: 40))
                .foregroundColor(.gray)
            
            Text("No buses available")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text("Try walking or check back later")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
}

// MARK: - Preview Provider

#Preview("Primary - Walk") {
    PrimaryRecommendationCard(
        recommendation: EnhancedRecommendation(
            recommendationType: .walk,
            confidence: 0.85,
            walkDetails: WalkRecommendationDetails(
                walkToStationMinutes: 12,
                stationName: "Val de Fontenay",
                rerWaitMinutes: 5,
                nextBusOptionMinutes: 8
            )
        )
    )
    .padding()
}

#Preview("Primary - Bus") {
    PrimaryRecommendationCard(
        recommendation: EnhancedRecommendation(
            recommendationType: .bus,
            confidence: 0.92,
            primaryBusOption: BusOptionTiming(
                lineName: "Bus 122",
                destinationName: "Val de Fontenay",
                stopName: "Cimetière de Vincennes",
                departureTime: Date().addingTimeInterval(420),
                departureStatus: "onTime",
                walkToStopMinutes: 5,
                waitAtStopMinutes: 7,
                busRideMinutes: 8,
                rerWaitMinutes: 3
            )
        )
    )
    .padding()
}

#Preview("Bus Schedule Card") {
    BusScheduleCard(
        busOption: BusOptionTiming(
            lineName: "Bus 124",
            destinationName: "Château de Vincennes",
            stopName: "Cimetière",
            departureTime: Date().addingTimeInterval(600),
            departureStatus: "onTime",
            walkToStopMinutes: 5,
            waitAtStopMinutes: 10,
            busRideMinutes: 12,
            rerWaitMinutes: 4
        ),
        isRecommended: true
    )
    .padding()
}
