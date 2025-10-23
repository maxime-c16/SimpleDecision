//
//  EnhancedRecommendationView.swift
//  simpleDecision
//
//  Created by Transportation Recommendation System on 22/10/2025.
//

import SwiftUI

/// Enhanced recommendation view with card-based layout
struct EnhancedRecommendationView: View {
    let recommendation: Recommendation
    @StateObject private var viewModel: RecommendationViewModel
    @State private var enhancedRecommendation: EnhancedRecommendation?
    
    init(recommendation: Recommendation, 
         locationService: LocationService = LocationService(),
         settingsManager: AppSettingsManager = AppSettingsManager()) {
        self.recommendation = recommendation
        
        // Create view model for enhanced logic
        let decisionEngine = DecisionEngine(locationService: locationService, settingsManager: settingsManager)
        let activityManager = ActivityManagerFactory.createActivityManager()
        
        _viewModel = StateObject(wrappedValue: RecommendationViewModel(
            decisionEngine: decisionEngine,
            locationService: locationService,
            activityManager: activityManager,
            settingsManager: settingsManager
        ))
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Show enhanced recommendation if available
                if let enhanced = enhancedRecommendation {
                    
                    // Primary recommendation card
                    PrimaryRecommendationCard(recommendation: enhanced)
                        .transition(.scale.combined(with: .opacity))
                    
                    // Alternative bus options (if any)
                    if !enhanced.alternativeBusOptions.isEmpty {
                        DestinationBusListCard(
                            title: enhanced.recommendationType == .walk ? "Alternative Bus Options" : "Other Departures",
                            busOptions: enhanced.alternativeBusOptions,
                            recommendedId: enhanced.primaryBusOption?.id
                        )
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    
                    // Refresh info
                    RefreshInfoCard(
                        lastUpdated: recommendation.timestamp,
                        nextRefreshText: "Updated from live data"
                    )
                    .transition(.opacity)
                }
            }
            .padding()
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: enhancedRecommendation?.id)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .onAppear {
            // Compute enhanced recommendation once when view appears
            if enhancedRecommendation == nil {
                enhancedRecommendation = viewModel.createEnhancedRecommendation(from: recommendation)
            }
        }
        .onChange(of: recommendation.id) {
            // Recompute when recommendation changes
            enhancedRecommendation = viewModel.createEnhancedRecommendation(from: recommendation)
        }
    }
}

// MARK: - Supporting Cards

/// Card showing refresh information
struct RefreshInfoCard: View {
    let lastUpdated: Date
    let nextRefreshText: String
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("Last updated: \(formatRelativeTime(lastUpdated))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(nextRefreshText)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
    
    private func formatRelativeTime(_ date: Date) -> String {
        let elapsed = Date().timeIntervalSince(date)
        
        if elapsed < 60 {
            return "Just now"
        } else if elapsed < 3600 {
            let minutes = Int(elapsed / 60)
            return "\(minutes)m ago"
        } else {
            let hours = Int(elapsed / 3600)
            return "\(hours)h ago"
        }
    }
}

/// Loading state card
struct LoadingCard: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Finding best option...")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Analyzing transit schedules")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
    }
}

/// No recommendation state card
struct NoRecommendationCard: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "location.slash")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text("No Recommendation")
                .font(.headline)
            
            Text("Select a destination to get started")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
    }
}

/// Error card
struct ErrorCard: View {
    let message: String
    let onDismiss: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title3)
                .foregroundColor(.red)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Error")
                    .font(.headline)
                    .foregroundColor(.red)
                
                Text(message)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.gray)
            }
        }
        .padding(16)
        .background(Color.red.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.red.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Preview Provider

#Preview("Walk Recommendation") {
    EnhancedRecommendationView(recommendation: Recommendation.mockWalk)
}

#Preview("Bus Recommendation") {
    EnhancedRecommendationView(recommendation: Recommendation.mockBus)
}
