import ActivityKit
import Foundation

// MARK: - Live Activity Attributes & Content State
// Using the existing structure from SharedModels.swift for consistency

/// Alias for the main Live Activity attributes defined in SharedModels.swift
@available(iOS 16.1, *)
public typealias TransportationRecommendationAttributes = TransportationRecommendationWidgetAttributes

// MARK: - Activity Content Helpers

@available(iOS 16.1, *)
extension ActivityContent where State == TransportationRecommendationWidgetAttributes.ContentState {
    /// Create activity content with automatic stale date (2 minutes from now)
    public static func withStaleDate(
        state: TransportationRecommendationWidgetAttributes.ContentState
    ) -> ActivityContent<TransportationRecommendationWidgetAttributes.ContentState> {
        return ActivityContent(
            state: state,
            staleDate: Date().addingTimeInterval(120) // 2 minutes staleness
        )
    }
}

// MARK: - Convenience Extensions

@available(iOS 16.1, *)
extension TransportationRecommendationWidgetAttributes.ContentState {
    /// Create content state from Recommendation model
    public init(from recommendation: Recommendation) {
        self.init(
            recommendation: recommendation,
            lastUpdated: Date()
        )
    }
    
    /// Create content state with custom timestamp
    public init(from recommendation: Recommendation, lastUpdated: Date) {
        self.init(
            recommendation: recommendation,
            lastUpdated: lastUpdated
        )
    }
}

@available(iOS 16.1, *)
extension TransportationRecommendationWidgetAttributes {
    /// Create attributes with destination information
    public init(destinationName: String, startLocationName: String) {
        // Use a composite session ID that includes destination for uniqueness
        let sessionId = "\(startLocationName)-to-\(destinationName)-\(Date().timeIntervalSince1970)"
        self.init(sessionId: sessionId)
    }
}