//
//  PRIMResponse.swift
//  simpleDecision
//
//  Created by Transportation Recommendation System on 30/09/2025.
//

import Foundation

// MARK: - Navitia API Models

/// Navitia places_nearby API response
struct NavitiaPlacesResponse: Codable {
    let places_nearby: [NavitiaPlace]
    let links: [NavitiaLink]?
}

/// Navitia place object (stop_area or stop_point)
struct NavitiaPlace: Codable {
    let id: String
    let name: String
    let embedded_type: String
    let quality: Int?
    let distance: Int?
    let stop_area: NavitiaStopArea?
    let stop_point: NavitiaStopPoint?
}

/// Navitia stop area object
struct NavitiaStopArea: Codable {
    let id: String
    let name: String
    let label: String?
    let coord: NavitiaCoord?
}

/// Navitia stop point object
struct NavitiaStopPoint: Codable {
    let id: String
    let name: String
    let label: String?
    let coord: NavitiaCoord?
}

/// Navitia coordinate object
struct NavitiaCoord: Codable {
    let lat: String
    let lon: String
}

/// Navitia link object
struct NavitiaLink: Codable {
    let href: String
    let rel: String?
    let type: String?
}

// MARK: - PRIM API Models

/// Request structure for PRIM API calls
struct PRIMRequest: Codable {
    let stopAreaId: String      // e.g., "STIF:StopPoint:Q:42016"
    let lineRef: String?        // Optional line filter
    let requestTime: Date
    
    /// Validate request parameters
    var isValid: Bool {
        // Stop area ID must follow PRIM format (removed trailing colon requirement)
        return stopAreaId.hasPrefix("STIF:") && !stopAreaId.isEmpty
    }
}

/// Response structure from PRIM API containing transit departure data
struct PRIMResponse: Codable {
    let departures: [Departure]
    let responseTimestamp: Date
    
    /// Filter departures by minimum time ahead
    func departures(minimumMinutesAhead: Int = 1) -> [Departure] {
        let cutoffTime = Date().addingTimeInterval(TimeInterval(minimumMinutesAhead * 60))
        return departures.filter { $0.expectedDepartureTime > cutoffTime }
    }
    
    /// Get next departure for specific line
    func nextDeparture(for lineName: String) -> Departure? {
        return departures
            .filter { $0.lineName.lowercased().contains(lineName.lowercased()) }
            .sorted { $0.expectedDepartureTime < $1.expectedDepartureTime }
            .first
    }
    
    /// Check if response is recent (within last 2 minutes)
    var isRecent: Bool {
        let twoMinutesAgo = Date().addingTimeInterval(-120)
        return responseTimestamp > twoMinutesAgo
    }
}

/// Individual transit departure information
struct Departure: Codable, Identifiable {
    let id: UUID
    let lineName: String              // e.g., "RER A", "Bus 122"
    let lineRef: String?              // STIF reference e.g., "STIF:Line::C01742:"
    let destinationName: String       // e.g., "Saint-Germain-en-Laye"
    let destinationRef: String?       // STIF destination reference
    let expectedDepartureTime: Date   // ISO 8601 format from API
    let departureStatus: String       // "onTime", "delayed", "early", "cancelled"
    let platformName: String          // Platform or stop designation
    let direction: String?            // Full direction description (DirectionName from API)
    let vehicleJourneyRef: String?    // Unique journey identifier
    let operatorRef: String?          // Transport operator reference (e.g., "MeC_Bus_PC:Operator::100:")
    let vehicleAtStop: Bool           // Whether vehicle is currently at stop
    
    enum CodingKeys: String, CodingKey {
        case lineName, lineRef, destinationName, destinationRef
        case expectedDepartureTime, departureStatus, platformName, direction
        case vehicleJourneyRef, operatorRef, vehicleAtStop
    }
    
    init(
        lineName: String,
        lineRef: String? = nil,
        destinationName: String,
        destinationRef: String? = nil,
        expectedDepartureTime: Date,
        departureStatus: String,
        platformName: String,
        direction: String? = nil,
        vehicleJourneyRef: String? = nil,
        operatorRef: String? = nil,
        vehicleAtStop: Bool = false
    ) {
        self.id = UUID()
        self.lineName = lineName
        self.lineRef = lineRef
        self.destinationName = destinationName
        self.destinationRef = destinationRef
        self.expectedDepartureTime = expectedDepartureTime
        self.departureStatus = departureStatus
        self.platformName = platformName
        self.direction = direction
        self.vehicleJourneyRef = vehicleJourneyRef
        self.operatorRef = operatorRef
        self.vehicleAtStop = vehicleAtStop
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID()
        self.lineName = try container.decode(String.self, forKey: .lineName)
        self.lineRef = try container.decodeIfPresent(String.self, forKey: .lineRef)
        self.destinationName = try container.decode(String.self, forKey: .destinationName)
        self.destinationRef = try container.decodeIfPresent(String.self, forKey: .destinationRef)
        self.expectedDepartureTime = try container.decode(Date.self, forKey: .expectedDepartureTime)
        self.departureStatus = try container.decode(String.self, forKey: .departureStatus)
        self.platformName = try container.decode(String.self, forKey: .platformName)
        self.direction = try container.decodeIfPresent(String.self, forKey: .direction)
        self.vehicleJourneyRef = try container.decodeIfPresent(String.self, forKey: .vehicleJourneyRef)
        self.operatorRef = try container.decodeIfPresent(String.self, forKey: .operatorRef)
        self.vehicleAtStop = try container.decodeIfPresent(Bool.self, forKey: .vehicleAtStop) ?? false
    }
    
    /// Minutes until departure
    var minutesUntilDeparture: Int {
        let interval = expectedDepartureTime.timeIntervalSinceNow
        return max(0, Int(interval / 60))
    }
    
    /// Confidence score based on departure status (from actual API testing)
    var confidenceScore: Double {
        switch departureStatus.lowercased() {
        case "ontime", "on time":
            return 0.9
        case "delayed":
            return 0.6
        case "early":
            return 0.7
        case "cancelled":
            return 0.0
        default:
            return 0.7
        }
    }
    
    /// Check if departure is upcoming (not in the past)
    var isUpcoming: Bool {
        return expectedDepartureTime > Date()
    }
    
    /// Formatted time string for display
    var displayTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: expectedDepartureTime)
    }
    
    /// Status display text based on actual API values
    var statusDisplayText: String {
        switch departureStatus.lowercased() {
        case "ontime", "on time":
            return vehicleAtStop ? "At Stop" : "On Time"
        case "delayed":
            return "Delayed"
        case "early":
            return "Early"
        case "cancelled":
            return "Cancelled"
        default:
            return departureStatus
        }
    }
    
    /// Status emoji for UI display
    var statusEmoji: String {
        switch departureStatus.lowercased() {
        case "ontime", "on time":
            return vehicleAtStop ? "🚏" : "🟢"
        case "delayed":
            return "�"
        case "early":
            return "�"
        case "cancelled":
            return "🔴"
        default:
            return "⚪"
        }
    }

    
    /// Operator display name
    var operatorName: String {
        guard let op = operatorRef else { return "" }
        if op.contains("RATP") { return "RATP" }
        if op.contains("SNCF") { return "SNCF" }
        if op.contains("OPTILE") { return "Optile" }
        return op
    }
}

// MARK: - Mock Data for Development (Based on Real API Testing)
extension PRIMResponse {
    /// Mock PRIM response with RER E departures (based on real API data from Val de Fontenay)
    static let mockRERResponse = PRIMResponse(
        departures: [
            Departure(
                lineName: "E",
                lineRef: "STIF:Line::C01729:",
                destinationName: "Nanterre-La-Folie",
                destinationRef: nil,
                expectedDepartureTime: Date().addingTimeInterval(180), // 3 minutes
                departureStatus: "onTime",
                platformName: "Val de Fontenay",
                direction: nil,
                vehicleJourneyRef: nil,
                operatorRef: nil,
                vehicleAtStop: false
            ),
            Departure(
                lineName: "E",
                lineRef: "STIF:Line::C01729:",
                destinationName: "Nanterre-La-Folie",
                destinationRef: nil,
                expectedDepartureTime: Date().addingTimeInterval(480), // 8 minutes
                departureStatus: "onTime",
                platformName: "Val de Fontenay",
                direction: nil,
                vehicleJourneyRef: nil,
                operatorRef: nil,
                vehicleAtStop: false
            ),
            Departure(
                lineName: "E",
                lineRef: "STIF:Line::C01729:",
                destinationName: "Nanterre-La-Folie",
                destinationRef: nil,
                expectedDepartureTime: Date().addingTimeInterval(720), // 12 minutes
                departureStatus: "onTime",
                platformName: "Val de Fontenay",
                direction: nil,
                vehicleJourneyRef: nil,
                operatorRef: nil,
                vehicleAtStop: false
            )
        ],
        responseTimestamp: Date()
    )
    
    /// Mock PRIM response with bus departures (based on real API data from Cimetière de Vincennes)
    static let mockBusResponse = PRIMResponse(
        departures: [
            Departure(
                lineName: "N34",
                lineRef: "STIF:Line::C01398:",
                destinationName: "Gare de Lyon",
                destinationRef: "STIF:StopPoint:Q:421409:",
                expectedDepartureTime: Date().addingTimeInterval(420), // 7 minutes
                departureStatus: "onTime",
                platformName: "Cimetière de Vincennes",
                direction: "Direction Gare de Lyon",
                vehicleJourneyRef: nil,
                operatorRef: "MeC_Bus_PC:Operator::100:",
                vehicleAtStop: false
            ),
            Departure(
                lineName: "N34",
                lineRef: "STIF:Line::C01398:",
                destinationName: "Torcy RER",
                destinationRef: "STIF:StopPoint:Q:41446:",
                expectedDepartureTime: Date().addingTimeInterval(660), // 11 minutes
                departureStatus: "onTime",
                platformName: "Cimetière de Vincennes",
                direction: "Direction Gare de Torcy RER",
                vehicleJourneyRef: nil,
                operatorRef: "MeC_Bus_PC:Operator::100:",
                vehicleAtStop: false
            ),
            Departure(
                lineName: "124",
                lineRef: "STIF:Line::C01153:",
                destinationName: "Gare de Lyon",
                destinationRef: nil,
                expectedDepartureTime: Date().addingTimeInterval(540), // 9 minutes
                departureStatus: "onTime",
                platformName: "Cimetière de Vincennes",
                direction: "Direction Gare de Lyon",
                vehicleJourneyRef: nil,
                operatorRef: "MeC_Bus_PC:Operator::100:",
                vehicleAtStop: false
            )
        ],
        responseTimestamp: Date()
    )
    
    /// Empty response for error testing
    static let mockEmptyResponse = PRIMResponse(
        departures: [],
        responseTimestamp: Date()
    )
}

extension PRIMRequest {
    /// Mock requests based on validated API endpoints
    static let mockValDeFontenayRER = PRIMRequest(
        stopAreaId: "STIF:StopArea:SP:47900:",
        lineRef: "STIF:Line::C01742:",
        requestTime: Date()
    )
    
    static let mockCimetiereVincennesBus = PRIMRequest(
        stopAreaId: "STIF:StopArea:SP:46543:",
        lineRef: "STIF:Line::C01151:",
        requestTime: Date()
    )
    
    static let mockAllDepartures = PRIMRequest(
        stopAreaId: "STIF:StopArea:SP:47900:",
        lineRef: nil, // Get all lines
        requestTime: Date()
    )
}