//
//  PRIMResponse.swift
//  simpleDecision
//
//  Created by Transportation Recommendation System on 30/09/2025.
//

import Foundation

/// Request structure for PRIM API calls
struct PRIMRequest: Codable {
    let stopAreaId: String      // e.g., "STIF:StopArea:SP:47900:"
    let lineRef: String?        // Optional line filter
    let requestTime: Date
    
    /// Validate request parameters
    var isValid: Bool {
        // Stop area ID must follow PRIM format
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
    let destinationName: String       // e.g., "Saint-Germain-en-Laye"
    let expectedDepartureTime: Date   // ISO 8601 format from API
    let departureStatus: String       // "onTime", "delayed", "early"
    let platformName: String          // Platform or stop designation
    let direction: String?            // Full direction description
    
    enum CodingKeys: String, CodingKey {
        case lineName, destinationName, expectedDepartureTime, departureStatus, platformName, direction
    }
    
    init(lineName: String, destinationName: String, expectedDepartureTime: Date, departureStatus: String, platformName: String, direction: String? = nil) {
        self.id = UUID()
        self.lineName = lineName
        self.destinationName = destinationName
        self.expectedDepartureTime = expectedDepartureTime
        self.departureStatus = departureStatus
        self.platformName = platformName
        self.direction = direction
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID()
        self.lineName = try container.decode(String.self, forKey: .lineName)
        self.destinationName = try container.decode(String.self, forKey: .destinationName)
        self.expectedDepartureTime = try container.decode(Date.self, forKey: .expectedDepartureTime)
        self.departureStatus = try container.decode(String.self, forKey: .departureStatus)
        self.platformName = try container.decode(String.self, forKey: .platformName)
        self.direction = try container.decodeIfPresent(String.self, forKey: .direction)
    }
    
    /// Minutes until departure
    var minutesUntilDeparture: Int {
        let interval = expectedDepartureTime.timeIntervalSinceNow
        return max(0, Int(interval / 60))
    }
    
    /// Confidence score based on departure status (from API testing)
    var confidenceScore: Double {
        switch departureStatus.lowercased() {
        case "ontime", "on time":
            return 0.9
        case "delayed":
            return 0.6
        case "early":
            return 0.7
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
    
    /// Status emoji for UI display
    var statusEmoji: String {
        switch departureStatus.lowercased() {
        case "ontime", "on time":
            return "🟢"
        case "delayed":
            return "🟡"
        case "early":
            return "🔵"
        default:
            return "⚪"
        }
    }
}

// MARK: - Mock Data for Development (Based on Real API Testing)
extension PRIMResponse {
    /// Mock PRIM response with RER A departures (based on real API data)
    static let mockRERResponse = PRIMResponse(
        departures: [
            Departure(
                lineName: "RER A",
                destinationName: "Saint-Germain-en-Laye",
                expectedDepartureTime: Date().addingTimeInterval(180), // 3 minutes
                departureStatus: "onTime",
                platformName: "1",
                direction: "Cergy le Haut • Poissy • Saint-Germain-en-Laye"
            ),
            Departure(
                lineName: "RER A",
                destinationName: "Le Vésinet - Le Pecq",
                expectedDepartureTime: Date().addingTimeInterval(300), // 5 minutes
                departureStatus: "onTime",
                platformName: "1",
                direction: "Cergy le Haut • Poissy • Saint-Germain-en-Laye"
            ),
            Departure(
                lineName: "RER A",
                destinationName: "Rueil-Malmaison",
                expectedDepartureTime: Date().addingTimeInterval(420), // 7 minutes
                departureStatus: "onTime",
                platformName: "1",
                direction: "Cergy le Haut • Poissy • Saint-Germain-en-Laye"
            )
        ],
        responseTimestamp: Date()
    )
    
    /// Mock PRIM response with bus departures (based on real API data)
    static let mockBusResponse = PRIMResponse(
        departures: [
            Departure(
                lineName: "Bus 122",
                destinationName: "Gallieni",
                expectedDepartureTime: Date().addingTimeInterval(420), // 7 minutes
                departureStatus: "onTime",
                platformName: "A",
                direction: nil
            ),
            Departure(
                lineName: "Bus 122",
                destinationName: "Val-de-Fontenay <RER>",
                expectedDepartureTime: Date().addingTimeInterval(660), // 11 minutes
                departureStatus: "onTime",
                platformName: "A",
                direction: nil
            ),
            Departure(
                lineName: "Bus C01156",
                destinationName: "Place de la Résistance",
                expectedDepartureTime: Date().addingTimeInterval(540), // 9 minutes
                departureStatus: "onTime",
                platformName: "B",
                direction: nil
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