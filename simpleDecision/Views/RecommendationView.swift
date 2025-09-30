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
                    Text(recommendation.transportationMode.displayName)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(Color(recommendation.transportationMode.colorName))
                    
                    Spacer()
                    
                    Text(recommendation.primaryETA)
                        .font(.title)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
                
                // Reasoning
                Text(recommendation.reasoning)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
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
                .fill(Color(recommendation.transportationMode.colorName).opacity(0.2))
                .frame(width: 60, height: 60)
            
            Image(systemName: recommendation.transportationMode.iconName)
                .font(.system(size: 28, weight: .medium))
                .foregroundColor(Color(recommendation.transportationMode.colorName))
        }
    }
    
    private var confidenceIndicator: some View {
        HStack(spacing: 4) {
            Image(systemName: "gauge.medium")
                .font(.caption)
                .foregroundColor(confidenceColor)
            
            Text(recommendation.confidencePercentage)
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
        .foregroundColor(.tertiary)
    }
    
    @ViewBuilder
    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
            
            // Detailed information
            VStack(alignment: .leading, spacing: 8) {
                detailRow("Created", value: formattedTimestamp)
                detailRow("Weather", value: weatherDisplayText)
                
                if recommendation.transportationMode == .publicTransit {
                    detailRow("Data Source", value: "PRIM API (Île-de-France)")
                }
                
                if recommendation.transportationMode == .walking {
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
        if recommendation.transportationMode == .publicTransit {
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
                    .stroke(Color(recommendation.transportationMode.colorName).opacity(0.3), lineWidth: 1)
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
        case .algorithm:
            return "brain"
        case .manual:
            return "hand.raised"
        }
    }
    
    private var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: recommendation.timestamp)
    }
    
    private var weatherDisplayText: String {
        switch recommendation.weatherCondition {
        case "rain":
            return "🌧️ Rainy"
        case "snow":
            return "❄️ Snowy"
        case "clear":
            return "☀️ Clear"
        default:
            return "🌤️ \(recommendation.weatherCondition?.capitalized ?? "Unknown")"
        }
    }
    
    private var recommendationTips: [String] {
        var tips: [String] = []
        
        switch recommendation.transportationMode {
        case .walking:
            if recommendation.estimatedTimeMinutes > 15 {
                tips.append("Consider bringing water for longer walks")
            }
            if recommendation.weatherCondition == "rain" {
                tips.append("Don't forget an umbrella!")
            }
            if recommendation.weatherCondition == "snow" {
                tips.append("Wear appropriate footwear for icy conditions")
            }
            
        case .publicTransit:
            tips.append("Check for service alerts before departing")
            if recommendation.confidence < 0.7 {
                tips.append("Consider walking as backup if transit is delayed")
            }
            
        case .bicycle:
            tips.append("Check bike availability at nearby stations")
            
        case .car:
            tips.append("Check traffic conditions before departing")
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
            RecommendationView(recommendation: Recommendation.mockWalkingRecommendation)
                .padding()
                .previewDisplayName("Walking")
            
            // Transit recommendation
            RecommendationView(recommendation: Recommendation.mockTransitRecommendation)
                .padding()
                .previewDisplayName("Transit")
            
            // Low confidence recommendation
            RecommendationView(recommendation: Recommendation(
                id: UUID(),
                transportationMode: .walking,
                estimatedTimeMinutes: 25,
                confidence: 0.4,
                reasoning: "Long walk with potential delays",
                source: .algorithm,
                timestamp: Date(),
                weatherCondition: "rain"
            ))
            .padding()
            .previewDisplayName("Low Confidence")
        }
        .previewLayout(.sizeThatFits)
    }
}