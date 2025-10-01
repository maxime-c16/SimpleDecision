//
//  SharedModels.swift
//  TransportationRecommendationWidget
//
//  Created by Transportation Recommendation System on 01/10/2025.
//

import Foundation
import ActivityKit

// MARK: - Live Activity Attributes

/// Shared ActivityAttributes for Live Activities - used by both main app and widget extension
@available(iOS 16.1, *)
public struct TransportationRecommendationWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public let recommendation: Recommendation
        public let lastUpdated: Date
        
        public init(recommendation: Recommendation, lastUpdated: Date) {
            self.recommendation = recommendation
            self.lastUpdated = lastUpdated
        }
    }
    
    public let sessionId: String
    
    public init(sessionId: String) {
        self.sessionId = sessionId
    }
}

// MARK: - Shared Models for Widget Extension

/// Transit-specific details for bus/train recommendations
public struct TransitDetails: Codable, Equatable, Hashable {
    public let lineName: String              // e.g., "RER A", "Bus 122"
    public let destinationName: String       // e.g., "Saint-Germain-en-Laye"
    public let stopName: String              // Name of the transit stop
    public let departureTime: Date           // Expected departure time
    public let departureStatus: String       // "onTime", "delayed", "early"
    public let platformName: String          // Platform or stop designation
    public let walkToStopMinutes: Int        // Walking time to reach the stop
    
    public init(
        lineName: String,
        destinationName: String,
        stopName: String,
        departureTime: Date,
        departureStatus: String,
        platformName: String,
        walkToStopMinutes: Int
    ) {
        self.lineName = lineName
        self.destinationName = destinationName
        self.stopName = stopName
        self.departureTime = departureTime
        self.departureStatus = departureStatus
        self.platformName = platformName
        self.walkToStopMinutes = walkToStopMinutes
    }
    
    /// Minutes until departure
    public var minutesUntilDeparture: Int {
        let interval = departureTime.timeIntervalSinceNow
        return max(0, Int(interval / 60))
    }
    
    /// Status color for UI
    public var statusColor: String {
        switch departureStatus.lowercased() {
        case "ontime": return "green"
        case "delayed": return "orange"
        case "early": return "blue"
        default: return "gray"
        }
    }
}

/// Core decision output with transportation mode and metadata
public struct Recommendation: Codable, Equatable, Identifiable, Hashable {
    public let id: UUID
    public let mode: TransportationMode
    public let walkETA: Int?           // minutes, nil if unavailable
    public let busETA: Int?            // minutes, nil if unavailable  
    public let confidence: Double      // 0.0 to 1.0
    public let timestamp: Date
    public let source: RecommendationSource
    
    // Transit-specific details (when mode is .bus)
    public let transitDetails: TransitDetails?
    
    enum CodingKeys: String, CodingKey {
        case mode, walkETA, busETA, confidence, timestamp, source, transitDetails
    }
    
    public init(
        mode: TransportationMode,
        walkETA: Int?,
        busETA: Int?,
        confidence: Double,
        timestamp: Date,
        source: RecommendationSource,
        transitDetails: TransitDetails? = nil
    ) {
        self.id = UUID()
        self.mode = mode
        self.walkETA = walkETA
        self.busETA = busETA
        self.confidence = confidence
        self.timestamp = timestamp
        self.source = source
        self.transitDetails = transitDetails
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID()
        self.mode = try container.decode(TransportationMode.self, forKey: .mode)
        self.walkETA = try container.decodeIfPresent(Int.self, forKey: .walkETA)
        self.busETA = try container.decodeIfPresent(Int.self, forKey: .busETA)
        self.confidence = try container.decode(Double.self, forKey: .confidence)
        self.timestamp = try container.decode(Date.self, forKey: .timestamp)
        self.source = try container.decode(RecommendationSource.self, forKey: .source)
        self.transitDetails = try container.decodeIfPresent(TransitDetails.self, forKey: .transitDetails)
    }
    
    /// Primary ETA based on recommended mode
    public var primaryETA: Int? {
        switch mode {
        case .walk:
            return walkETA
        case .bus:
            return busETA
        case .tie:
            return min(walkETA ?? Int.max, busETA ?? Int.max)
        }
    }
    
    /// Display-friendly confidence percentage
    public var confidencePercentage: Int {
        Int(confidence * 100)
    }
    
    // Mock data for development
    public static let mockWalk = Recommendation(
        mode: .walk,
        walkETA: 12,
        busETA: nil,
        confidence: 0.9,
        timestamp: Date(),
        source: .mock,
        transitDetails: nil
    )
    
    public static let mockBus = Recommendation(
        mode: .bus,
        walkETA: nil,
        busETA: 18,
        confidence: 0.8,
        timestamp: Date(),
        source: .mock,
        transitDetails: TransitDetails(
            lineName: "Bus 122",
            destinationName: "Gare du Nord",
            stopName: "Place de la République",
            departureTime: Date().addingTimeInterval(300), // 5 min from now
            departureStatus: "onTime",
            platformName: "Quai A",
            walkToStopMinutes: 3
        )
    )
    
    public static let mockTie = Recommendation(
        mode: .tie,
        walkETA: 15,
        busETA: 15,
        confidence: 0.5,
        timestamp: Date(),
        source: .mock,
        transitDetails: nil
    )
}

public enum TransportationMode: String, Codable, CaseIterable {
    case walk = "Walk"
    case bus = "Bus" 
    case tie = "Tie"
    
    /// Icon name for UI display
    public var iconName: String {
        switch self {
        case .walk: return "figure.walk"
        case .bus: return "bus"
        case .tie: return "arrow.left.arrow.right"
        }
    }
    
    /// Display name for UI
    public var displayName: String {
        switch self {
        case .walk: return "Walk"
        case .bus: return "Bus"
        case .tie: return "Tie"
        }
    }
    
    /// Color for UI display
    public var colorName: String {
        switch self {
        case .walk: return "green"
        case .bus: return "blue"
        case .tie: return "orange"
        }
    }
}

/// Source of recommendation data
public enum RecommendationSource: String, Codable {
    case localHeuristics = "Local"
    case primAPI = "PRIM"
    case mock = "Mock"
    
    /// Display name for UI
    public var displayName: String {
        switch self {
        case .localHeuristics: return "Local Calculation"
        case .primAPI: return "PRIM Real-time"
        case .mock: return "Mock Data"
        }
    }
}