//
//  LiveActivityAttributes.swift
//  simpleDecision
//
//  Created by Copilot on 2025-09-30.
//

import ActivityKit
import Foundation

/// Attributes for Transportation Recommendation Live Activities
/// This struct defines the static information that doesn't change during the life of a Live Activity
public struct TransportationRecommendationWidgetAttributes: ActivityAttributes {
    
    /// Content state for the Live Activity that can be updated
    public struct ContentState: Codable, Hashable {
        /// The current transportation recommendation
        public let recommendation: Recommendation
        
        /// The current status of the recommendation
        public let status: RecommendationStatus
        
        /// Timestamp when this state was last updated
        public let lastUpdated: Date
        
        /// Whether the recommendation is still active
        public let isActive: Bool
        
        public init(
            recommendation: Recommendation,
            status: RecommendationStatus = .active,
            lastUpdated: Date = Date(),
            isActive: Bool = true
        ) {
            self.recommendation = recommendation
            self.status = status
            self.lastUpdated = lastUpdated
            self.isActive = isActive
        }
    }
    
    /// The user's destination name (static for the duration of the Live Activity)
    public let destinationName: String
    
    /// Whether this Live Activity should show detailed transit information
    public let showDetails: Bool
    
    /// The initial location name (static for the duration of the Live Activity)
    public let originName: String
    
    public init(
        destinationName: String,
        showDetails: Bool = true,
        originName: String = "Current Location"
    ) {
        self.destinationName = destinationName
        self.showDetails = showDetails
        self.originName = originName
    }
}

/// Status of a transportation recommendation
public enum RecommendationStatus: String, Codable, CaseIterable {
    case active = "active"
    case inProgress = "in_progress"
    case completed = "completed"
    case cancelled = "cancelled"
    case delayed = "delayed"
    case updated = "updated"
    
    public var displayName: String {
        switch self {
        case .active:
            return "Active"
        case .inProgress:
            return "In Progress"
        case .completed:
            return "Completed"
        case .cancelled:
            return "Cancelled"
        case .delayed:
            return "Delayed"
        case .updated:
            return "Updated"
        }
    }
    
    public var emoji: String {
        switch self {
        case .active:
            return "🟢"
        case .inProgress:
            return "🔵"
        case .completed:
            return "✅"
        case .cancelled:
            return "❌"
        case .delayed:
            return "⚠️"
        case .updated:
            return "🔄"
        }
    }
}