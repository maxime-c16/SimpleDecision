//
//  SharedModels.swift
//  TransportationRecommendationWidget
//
//  Created by Transportation Recommendation System on 01/10/2025.
//

import Foundation
import ActivityKit
import SwiftUI

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

/// Detailed ETA breakdown for transit recommendations
public struct TransitETABreakdown: Codable, Equatable, Hashable {
    public let walkToStopMinutes: Int
    public let waitForBusMinutes: Int
    public let busRideMinutes: Int
    public let totalMinutes: Int
    
    public init(walkToStopMinutes: Int, waitForBusMinutes: Int, busRideMinutes: Int) {
        self.walkToStopMinutes = walkToStopMinutes
        self.waitForBusMinutes = waitForBusMinutes
        self.busRideMinutes = busRideMinutes
        self.totalMinutes = walkToStopMinutes + waitForBusMinutes + busRideMinutes
    }
    
    public var description: String {
        return "\(walkToStopMinutes)min walk + \(waitForBusMinutes)min wait + \(busRideMinutes)min ride = \(totalMinutes)min total"
    }
}

/// Alternative line information at the same stop
public struct AlternativeLine: Codable, Equatable, Hashable, Identifiable {
    public let id: String
    public let lineNumber: String
    public let lineRef: String
    public let destination: String
    public let nextDepartureTime: Date
    public let departureStatus: String
    public let isCatchable: Bool  // Can user walk to stop in time to catch this bus?
    
    public init(id: String, lineNumber: String, lineRef: String, destination: String, nextDepartureTime: Date, departureStatus: String, isCatchable: Bool = true) {
        self.id = id
        self.lineNumber = lineNumber
        self.lineRef = lineRef
        self.destination = destination
        self.nextDepartureTime = nextDepartureTime
        self.departureStatus = departureStatus
        self.isCatchable = isCatchable
    }
    
    public var minutesUntilDeparture: Int {
        let interval = nextDepartureTime.timeIntervalSinceNow
        return max(0, Int(interval / 60))
    }
}

/// Lightweight RER departure info for wait time calculation (minimal payload size)
public struct RERDeparture: Codable, Equatable, Hashable {
    public let lineName: String  // "RER A" or "RER E"
    public let departureTime: Date
    
    public init(lineName: String, departureTime: Date) {
        self.lineName = lineName
        self.departureTime = departureTime
    }
}

/// Bus departure schedule information from PRIM API
public struct BusDeparture: Codable, Equatable, Hashable, Identifiable {
    public let id: String
    public let departureTime: Date
    public let status: String
    public let minutesUntilDeparture: Int
    public let isCatchable: Bool
    
    public init(id: String, departureTime: Date, status: String, minutesUntilDeparture: Int, isCatchable: Bool) {
        self.id = id
        self.departureTime = departureTime
        self.status = status
        self.minutesUntilDeparture = minutesUntilDeparture
        self.isCatchable = isCatchable
    }
    
    public var displayTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: departureTime)
    }
}

/// Transit-specific details for bus/train recommendations (based on actual PRIM API structure)

public struct TransitDetails: Codable, Equatable, Hashable {
    public let lineName: String
    public let lineRef: String?
    public let destinationName: String
    public let stopName: String
    public let departureTime: Date
    public let departureStatus: String
    public let platformName: String
    public let walkToStopMinutes: Int
    public let operatorRef: String?
    public let direction: String?
    public let vehicleAtStop: Bool
    public let etaBreakdown: TransitETABreakdown?
    public let alternativeLines: [AlternativeLine]
    public let stopId: String?
    public let upcomingDepartures: [BusDeparture]  // Full schedule for the recommended line
    public let allRERDepartures: [RERDeparture]  // Lightweight RER schedule for wait time calculation
    
    public init(
        lineName: String,
        lineRef: String? = nil,
        destinationName: String,
        stopName: String,
        departureTime: Date,
        departureStatus: String,
        platformName: String,
        walkToStopMinutes: Int,
        operatorRef: String? = nil,
        direction: String? = nil,
        vehicleAtStop: Bool = false,
        etaBreakdown: TransitETABreakdown? = nil,
        alternativeLines: [AlternativeLine] = [],
        stopId: String? = nil,
        upcomingDepartures: [BusDeparture] = [],
        allRERDepartures: [RERDeparture] = []
    ) {
        self.lineName = lineName
        self.lineRef = lineRef
        self.destinationName = destinationName
        self.stopName = stopName
        self.departureTime = departureTime
        self.departureStatus = departureStatus
        self.platformName = platformName
        self.walkToStopMinutes = walkToStopMinutes
        self.operatorRef = operatorRef
        self.direction = direction
        self.vehicleAtStop = vehicleAtStop
        self.etaBreakdown = etaBreakdown
        self.alternativeLines = alternativeLines
        self.stopId = stopId
        self.upcomingDepartures = upcomingDepartures
        self.allRERDepartures = allRERDepartures
    }
    
    /// Minutes until departure
    public var minutesUntilDeparture: Int {
        let interval = departureTime.timeIntervalSinceNow
        return max(0, Int(interval / 60))
    }
    
    /// Status color for UI
    public var statusUIColor: Color {
        switch departureStatus.lowercased() {
        case "ontime": return .green
        case "delayed": return .orange
        case "early": return .blue
        case "cancelled": return .red
        default: return .gray
        }
    }
    
    /// Status display text
    public var statusText: String {
        switch departureStatus.lowercased() {
        case "ontime": return vehicleAtStop ? "At Stop" : "On Time"
        case "delayed": return "Delayed"
        case "early": return "Early"
        case "cancelled": return "Cancelled"
        default: return departureStatus
        }
    }
    
    /// Operator name from reference (simplified mapping)
    public var operatorName: String? {
        guard let ref = operatorRef else { return nil }
        // Extract operator code from format like "MeC_Bus_PC:Operator::100:"
        if ref.contains("100") { return "RATP" }
        if ref.contains("200") { return "SNCF" }
        return nil
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
    
    // Alternative option info (e.g., bus info when walking is recommended)
    public let alternativeTransitDetails: TransitDetails?
    
    // Phase 2: Urgency and Safety tracking
    public let urgencyScore: Double?    // 0.0-1.0, from DualRouteCalculator
    public let bufferMinutes: Int?      // Safety buffer before departure
    public let safetyLevel: String?     // "comfortable", "acceptable", "tooRisky"
    
    enum CodingKeys: String, CodingKey {
        case mode, walkETA, busETA, confidence, timestamp, source, transitDetails, alternativeTransitDetails
        case urgencyScore, bufferMinutes, safetyLevel
    }
    
    public init(
        mode: TransportationMode,
        walkETA: Int?,
        busETA: Int?,
        confidence: Double,
        timestamp: Date,
        source: RecommendationSource,
        transitDetails: TransitDetails? = nil,
        alternativeTransitDetails: TransitDetails? = nil,
        urgencyScore: Double? = nil,
        bufferMinutes: Int? = nil,
        safetyLevel: String? = nil
    ) {
        self.id = UUID()
        self.mode = mode
        self.walkETA = walkETA
        self.busETA = busETA
        self.confidence = confidence
        self.timestamp = timestamp
        self.source = source
        self.transitDetails = transitDetails
        self.alternativeTransitDetails = alternativeTransitDetails
        self.urgencyScore = urgencyScore
        self.bufferMinutes = bufferMinutes
        self.safetyLevel = safetyLevel
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
        self.alternativeTransitDetails = try container.decodeIfPresent(TransitDetails.self, forKey: .alternativeTransitDetails)
        self.urgencyScore = try container.decodeIfPresent(Double.self, forKey: .urgencyScore)
        self.bufferMinutes = try container.decodeIfPresent(Int.self, forKey: .bufferMinutes)
        self.safetyLevel = try container.decodeIfPresent(String.self, forKey: .safetyLevel)
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
            lineName: "N34",
            destinationName: "Gare de Lyon",
            stopName: "Cimetière de Vincennes",
            departureTime: Date().addingTimeInterval(300), // 5 min from now
            departureStatus: "onTime",
            platformName: "Quai A",
            walkToStopMinutes: 3,
            upcomingDepartures: [
                BusDeparture(id: "1", departureTime: Date().addingTimeInterval(300), status: "onTime", minutesUntilDeparture: 5, isCatchable: true),
                BusDeparture(id: "2", departureTime: Date().addingTimeInterval(900), status: "onTime", minutesUntilDeparture: 15, isCatchable: true),
                BusDeparture(id: "3", departureTime: Date().addingTimeInterval(1500), status: "onTime", minutesUntilDeparture: 25, isCatchable: true),
                BusDeparture(id: "4", departureTime: Date().addingTimeInterval(2100), status: "onTime", minutesUntilDeparture: 35, isCatchable: true)
            ]
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
    public var uiColor: Color {
        switch self {
        case .walk: return .green
        case .bus: return .blue
        case .tie: return .orange
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

// MARK: - Enhanced Recommendation Data Models

/// Detailed timing breakdown for a bus option
public struct BusOptionTiming: Codable, Equatable, Hashable, Identifiable {
    public let id: UUID
    public let lineName: String
    public let lineRef: String?
    public let destinationName: String
    public let stopName: String
    public let departureTime: Date
    public let departureStatus: String
    
    // Timing breakdown
    public let walkToStopMinutes: Int
    public let waitAtStopMinutes: Int
    public let busRideMinutes: Int
    public let rerWaitMinutes: Int?  // Wait time for RER at destination
    
    // Total journey time
    public var totalMinutes: Int {
        return walkToStopMinutes + waitAtStopMinutes + busRideMinutes + (rerWaitMinutes ?? 0)
    }
    
    // Whether this bus is catchable given current time
    public var isCatchable: Bool {
        let arrivalTime = Date().addingTimeInterval(TimeInterval(walkToStopMinutes * 60))
        return arrivalTime < departureTime
    }
    
    // RER arrival time and display (when RER wait is available)
    public var rerArrivalTime: Date? {
        guard rerWaitMinutes != nil else { return nil }
        // Calculate when bus arrives at Val de Fontenay
        let busArrivalSeconds = TimeInterval((walkToStopMinutes + waitAtStopMinutes + busRideMinutes) * 60)
        return Date().addingTimeInterval(busArrivalSeconds)
    }
    
    public var rerDepartureTime: Date? {
        guard let rerWait = rerWaitMinutes, let arrival = rerArrivalTime else { return nil }
        return arrival.addingTimeInterval(TimeInterval(rerWait * 60))
    }
    
    public var rerScheduleDisplay: String? {
        guard let rerDep = rerDepartureTime, let rerWait = rerWaitMinutes else { return nil }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        let timeString = formatter.string(from: rerDep)
        return "\(rerWait)min wait (RER at \(timeString))"
    }
    
    public init(
        lineName: String,
        lineRef: String? = nil,
        destinationName: String,
        stopName: String,
        departureTime: Date,
        departureStatus: String,
        walkToStopMinutes: Int,
        waitAtStopMinutes: Int,
        busRideMinutes: Int,
        rerWaitMinutes: Int? = nil
    ) {
        self.id = UUID()
        self.lineName = lineName
        self.lineRef = lineRef
        self.destinationName = destinationName
        self.stopName = stopName
        self.departureTime = departureTime
        self.departureStatus = departureStatus
        self.walkToStopMinutes = walkToStopMinutes
        self.waitAtStopMinutes = waitAtStopMinutes
        self.busRideMinutes = busRideMinutes
        self.rerWaitMinutes = rerWaitMinutes
    }
}

/// Walk recommendation with RER station details
public struct WalkRecommendationDetails: Codable, Equatable, Hashable {
    public let walkToStationMinutes: Int
    public let stationName: String
    public let rerWaitMinutes: Int
    public let nextBusOptionMinutes: Int?  // Minutes until next bus becomes viable
    public let totalMinutes: Int
    
    public init(
        walkToStationMinutes: Int,
        stationName: String,
        rerWaitMinutes: Int,
        nextBusOptionMinutes: Int? = nil
    ) {
        self.walkToStationMinutes = walkToStationMinutes
        self.stationName = stationName
        self.rerWaitMinutes = rerWaitMinutes
        self.nextBusOptionMinutes = nextBusOptionMinutes
        self.totalMinutes = walkToStationMinutes + rerWaitMinutes
    }
    
    // RER arrival and departure times for display
    public var stationArrivalTime: Date {
        return Date().addingTimeInterval(TimeInterval(walkToStationMinutes * 60))
    }
    
    public var rerDepartureTime: Date {
        return stationArrivalTime.addingTimeInterval(TimeInterval(rerWaitMinutes * 60))
    }
    
    public var rerScheduleDisplay: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        let timeString = formatter.string(from: rerDepartureTime)
        return "\(rerWaitMinutes)min wait (RER at \(timeString))"
    }
}

/// Complete recommendation data with all timing details
public struct EnhancedRecommendation: Codable, Equatable, Hashable, Identifiable {
    public let id: UUID
    public let recommendationType: RecommendationType
    public let timestamp: Date
    public let confidence: Double
    
    // Walk-specific details
    public let walkDetails: WalkRecommendationDetails?
    
    // Bus-specific details
    public let primaryBusOption: BusOptionTiming?
    public let alternativeBusOptions: [BusOptionTiming]
    
    public enum RecommendationType: String, Codable {
        case walk
        case bus
        case tie
    }
    
    public init(
        recommendationType: RecommendationType,
        timestamp: Date = Date(),
        confidence: Double,
        walkDetails: WalkRecommendationDetails? = nil,
        primaryBusOption: BusOptionTiming? = nil,
        alternativeBusOptions: [BusOptionTiming] = []
    ) {
        self.id = UUID()
        self.recommendationType = recommendationType
        self.timestamp = timestamp
        self.confidence = confidence
        self.walkDetails = walkDetails
        self.primaryBusOption = primaryBusOption
        self.alternativeBusOptions = alternativeBusOptions
    }
    
    /// Primary ETA based on recommendation type
    public var primaryETA: Int {
        switch recommendationType {
        case .walk:
            return walkDetails?.totalMinutes ?? 0
        case .bus:
            return primaryBusOption?.totalMinutes ?? 0
        case .tie:
            let walkTime = walkDetails?.totalMinutes ?? Int.max
            let busTime = primaryBusOption?.totalMinutes ?? Int.max
            return min(walkTime, busTime)
        }
    }
}