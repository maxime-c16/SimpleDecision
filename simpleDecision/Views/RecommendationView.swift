//
//  RecommendationView.swift
//  simpleDecision
//
//  Created by Transportation Recommendation System on 30/09/2025.
//

import SwiftUI

/// SwiftUI view component for displaying transportation recommendations
struct RecommendationView: View {
    let recommendation: Recommendation
    @State private var showingDetails = false
    @State private var pulseAnimation = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Main recommendation card
            recommendationCard
            
            // Details section
            if showingDetails {
                detailsSection
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
            
            // Action buttons
            actionButtons
        }
        .padding()
        .background(cardBackground)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        .scaleEffect(pulseAnimation ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: pulseAnimation)
        .onAppear {
            startPulseAnimation()
        }
    }
    
    // MARK: - View Components
    
    private var recommendationCard: some View {
        HStack(spacing: 16) {
            // Transportation mode icon
            transportationIcon
            
            // Main content
            VStack(alignment: .leading, spacing: 8) {
                // Mode and time
                HStack {
                    Text(recommendation.mode.displayName)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(Color(recommendation.mode.colorName))
                    
                    Spacer()
                    
                    Text("\(recommendation.primaryETA ?? 0) min")
                        .font(.title)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
                
                // Transit quick info (when available)
                if let transit = recommendation.transitDetails {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: "bus.fill")
                                .font(.caption)
                                .foregroundColor(.blue)
                            Text(transit.lineName)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Image(systemName: "arrow.right")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(transit.destinationName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        
                        HStack(spacing: 8) {
                            Label("\(transit.walkToStopMinutes) min", systemImage: "figure.walk")
                                .font(.caption2)
                                .foregroundColor(.orange)
                            Label("\(transit.minutesUntilDeparture) min", systemImage: "clock")
                                .font(.caption2)
                                .foregroundColor(.blue)
                        }
                    }
                } else {
                    // Source info for non-transit
                    Text("Source: \(recommendation.source.displayName)")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                // Confidence and source
                HStack {
                    confidenceIndicator
                    
                    Spacer()
                    
                    sourceIndicator
                }
            }
        }
    }
    
    private var transportationIcon: some View {
        ZStack {
            Circle()
                .fill(Color(recommendation.mode.colorName).opacity(0.2))
                .frame(width: 60, height: 60)
            
            Image(systemName: recommendation.mode.iconName)
                .font(.system(size: 28, weight: .medium))
                .foregroundColor(Color(recommendation.mode.colorName))
        }
    }
    
    private var confidenceIndicator: some View {
        HStack(spacing: 4) {
            Image(systemName: "gauge.medium")
                .font(.caption)
                .foregroundColor(confidenceColor)
            
            Text("\(recommendation.confidencePercentage)%")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(confidenceColor)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(confidenceColor.opacity(0.2))
        .cornerRadius(6)
    }
    
    private var sourceIndicator: some View {
        HStack(spacing: 4) {
            Image(systemName: sourceIconName)
                .font(.caption2)
            
            Text(recommendation.source.displayName)
                .font(.caption2)
        }
        .foregroundColor(.secondary)
    }
    
    @ViewBuilder
    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
            
            // Transit-specific details (when available)
            if let transit = recommendation.transitDetails {
                VStack(alignment: .leading, spacing: 12) {
                    // Transit line and destination
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Line")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            HStack(spacing: 6) {
                                Image(systemName: "bus.fill")
                                    .foregroundColor(.blue)
                                Text(transit.lineName)
                                    .font(.headline)
                                    .fontWeight(.bold)
                            }
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Direction")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(transit.destinationName)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                    
                    // Stop information
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundColor(.red)
                            Text(transit.stopName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        
                        HStack(spacing: 16) {
                            HStack {
                                Image(systemName: "figure.walk")
                                    .foregroundColor(.orange)
                                Text("\(transit.walkToStopMinutes) min walk")
                                    .font(.caption)
                            }
                            
                            HStack {
                                Image(systemName: "clock.fill")
                                    .foregroundColor(Color(transit.statusColor))
                                Text("\(transit.minutesUntilDeparture) min")
                                    .font(.caption)
                            }
                            
                            Text(transit.departureStatus.capitalized)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(transit.statusColor).opacity(0.2))
                                .foregroundColor(Color(transit.statusColor))
                                .cornerRadius(6)
                        }
                        
                        if !transit.platformName.isEmpty {
                            HStack {
                                Image(systemName: "arrow.turn.up.right")
                                    .foregroundColor(.secondary)
                                Text("Platform: \(transit.platformName)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    Divider()
                }
            }
            
            // General information
            VStack(alignment: .leading, spacing: 8) {
                detailRow("Created", value: formattedTimestamp)
                detailRow("Weather", value: weatherDisplayText)
                
                if recommendation.mode == .bus {
                    detailRow("Data Source", value: "PRIM API (Real-time)")
                }
                
                if recommendation.mode == .walk {
                    detailRow("Walking Speed", value: "5 km/h average")
                }
            }
            
            // Tips section
            if !recommendationTips.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tips")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    
                    ForEach(recommendationTips, id: \.self) { tip in
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "lightbulb")
                                .font(.caption2)
                                .foregroundColor(.yellow)
                            
                            Text(tip)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
    }
    
    private func detailRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
    
    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button(action: {
                withAnimation(.spring()) {
                    showingDetails.toggle()
                }
            }) {
                HStack {
                    Image(systemName: showingDetails ? "chevron.up" : "info.circle")
                    Text(showingDetails ? "Less Info" : "More Info")
                }
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            // Alternative action based on mode
            alternativeActionButton
        }
    }
    
    @ViewBuilder
    private var alternativeActionButton: some View {
        if recommendation.mode == .bus {
            Button(action: {
                // Open Maps app or show transit directions
                openMapsForTransit()
            }) {
                HStack {
                    Image(systemName: "map")
                    Text("Directions")
                }
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.2))
                .foregroundColor(.blue)
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
        } else {
            Button(action: {
                // Open Maps app for walking directions
                openMapsForWalking()
            }) {
                HStack {
                    Image(systemName: "figure.walk")
                    Text("Navigate")
                }
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.green.opacity(0.2))
                .foregroundColor(.green)
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Computed Properties
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(.regularMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color(recommendation.mode.colorName).opacity(0.3), lineWidth: 1)
            )
    }
    
    private var confidenceColor: Color {
        if recommendation.confidence > 0.8 {
            return .green
        } else if recommendation.confidence > 0.6 {
            return .orange
        } else {
            return .red
        }
    }
    
    private var sourceIconName: String {
        switch recommendation.source {
        case .primAPI:
            return "globe"
        case .localHeuristics:
            return "brain"
        case .mock:
            return "hand.raised"
        }
    }
    
    private var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: recommendation.timestamp)
    }
    
    private var weatherDisplayText: String {
        return "�️ Clear"
    }
    
    private var recommendationTips: [String] {
        var tips: [String] = []
        
        switch recommendation.mode {
        case .walk:
            if let walkETA = recommendation.walkETA, walkETA > 15 {
                tips.append("Consider bringing water for longer walks")
            }
            tips.append("Don't forget an umbrella if it looks like rain!")
            
        case .bus:
            tips.append("Check for service alerts before departing")
            if recommendation.confidence < 0.7 {
                tips.append("Consider walking as backup if transit is delayed")
            }
            
        case .tie:
            tips.append("Both options are equally good - choose based on your preference")
        }
        
        return tips
    }
    
    // MARK: - Actions
    
    private func startPulseAnimation() {
        // Only pulse for high-confidence recommendations
        if recommendation.confidence > 0.8 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                pulseAnimation = true
            }
        }
    }
    
    private func openMapsForTransit() {
        // In a real app, this would open Maps with transit directions
        print("Opening Maps for transit directions")
    }
    
    private func openMapsForWalking() {
        // In a real app, this would open Maps with walking directions
        print("Opening Maps for walking directions")
    }
}

// MARK: - Preview

struct RecommendationView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Walking recommendation
            RecommendationView(recommendation: Recommendation.mockWalk)
                .padding()
                .previewDisplayName("Walking")
            
            // Transit recommendation
            RecommendationView(recommendation: Recommendation.mockBus)
                .padding()
                .previewDisplayName("Transit")
            
            // Tie recommendation
            RecommendationView(recommendation: Recommendation.mockTie)
                .padding()
                .previewDisplayName("Tie")
        }
        .previewLayout(.sizeThatFits)
    }
}