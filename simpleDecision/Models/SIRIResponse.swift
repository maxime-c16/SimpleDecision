//
//  SIRIResponse.swift
//  simpleDecision
//
//  Created by Transportation Recommendation System on 01/10/2025.
//  SIRI Lite 2.0 response models for PRIM API
//

import Foundation

// MARK: - SIRI Root Response

struct SIRIResponse: Codable {
    let siri: SIRIContainer
    
    enum CodingKeys: String, CodingKey {
        case siri = "Siri"
    }
}

struct SIRIContainer: Codable {
    let serviceDelivery: ServiceDelivery
    
    enum CodingKeys: String, CodingKey {
        case serviceDelivery = "ServiceDelivery"
    }
}

struct ServiceDelivery: Codable {
    let responseTimestamp: String
    let producerRef: String?
    let stopMonitoringDelivery: [StopMonitoringDelivery]
    
    enum CodingKeys: String, CodingKey {
        case responseTimestamp = "ResponseTimestamp"
        case producerRef = "ProducerRef"
        case stopMonitoringDelivery = "StopMonitoringDelivery"
    }
}

// MARK: - Stop Monitoring Delivery

struct StopMonitoringDelivery: Codable {
    let responseTimestamp: String?
    let version: String?
    let status: String?
    let monitoredStopVisit: [MonitoredStopVisit]
    
    enum CodingKeys: String, CodingKey {
        case responseTimestamp = "ResponseTimestamp"
        case version = "Version"
        case status = "Status"
        case monitoredStopVisit = "MonitoredStopVisit"
    }
}

struct MonitoredStopVisit: Codable {
    let recordedAtTime: String
    let itemIdentifier: String?
    let monitoringRef: RefValue
    let monitoredVehicleJourney: MonitoredVehicleJourney
    
    enum CodingKeys: String, CodingKey {
        case recordedAtTime = "RecordedAtTime"
        case itemIdentifier = "ItemIdentifier"
        case monitoringRef = "MonitoringRef"
        case monitoredVehicleJourney = "MonitoredVehicleJourney"
    }
}

// MARK: - Monitored Vehicle Journey

struct MonitoredVehicleJourney: Codable {
    let lineRef: RefValue  // Always has a value
    let operatorRef: OptionalRefValue?  // May be empty {} object
    let publishedLineName: [TextValue]?
    let directionName: [TextValue]?
    let directionRef: OptionalRefValue?  // May be empty
    let destinationName: [TextValue]?
    let destinationRef: OptionalRefValue?  // May be empty
    let destinationShortName: [TextValue]?
    let vehicleJourneyName: [TextValue]?
    let journeyNote: [TextValue]?
    let monitoredCall: MonitoredCall
    let framedVehicleJourneyRef: FramedVehicleJourneyRef?
    let trainNumbers: TrainNumbers?
    let vehicleFeatureRef: [String]?
    
    enum CodingKeys: String, CodingKey {
        case lineRef = "LineRef"
        case operatorRef = "OperatorRef"
        case publishedLineName = "PublishedLineName"
        case directionName = "DirectionName"
        case directionRef = "DirectionRef"
        case destinationName = "DestinationName"
        case destinationRef = "DestinationRef"
        case destinationShortName = "DestinationShortName"
        case vehicleJourneyName = "VehicleJourneyName"
        case journeyNote = "JourneyNote"
        case monitoredCall = "MonitoredCall"
        case framedVehicleJourneyRef = "FramedVehicleJourneyRef"
        case trainNumbers = "TrainNumbers"
        case vehicleFeatureRef = "VehicleFeatureRef"
    }
}

struct MonitoredCall: Codable {
    let stopPointName: [TextValue]?
    let vehicleAtStop: Bool?
    let destinationDisplay: [TextValue]?
    let expectedDepartureTime: String?
    let aimedDepartureTime: String?  // Fallback if expected is nil
    let departureStatus: String?
    let arrivalStatus: String?
    
    enum CodingKeys: String, CodingKey {
        case stopPointName = "StopPointName"
        case vehicleAtStop = "VehicleAtStop"
        case destinationDisplay = "DestinationDisplay"
        case expectedDepartureTime = "ExpectedDepartureTime"
        case aimedDepartureTime = "AimedDepartureTime"
        case departureStatus = "DepartureStatus"
        case arrivalStatus = "ArrivalStatus"
    }
}

// MARK: - Supporting Structures

/// Reference value that MUST have a value (like LineRef)
struct RefValue: Codable {
    let value: String
}

/// Optional reference value that MAY be empty {} (like OperatorRef for some lines)
struct OptionalRefValue: Codable {
    let value: String?
}

struct TextValue: Codable {
    let value: String
}

struct FramedVehicleJourneyRef: Codable {
    let dataFrameRef: OptionalRefValue?  // May be empty
    let datedVehicleJourneyRef: String?
    
    enum CodingKeys: String, CodingKey {
        case dataFrameRef = "DataFrameRef"
        case datedVehicleJourneyRef = "DatedVehicleJourneyRef"
    }
}

struct TrainNumbers: Codable {
    let trainNumberRef: [RefValue]?  // Array of {value: "train_number"}
    
    enum CodingKeys: String, CodingKey {
        case trainNumberRef = "TrainNumberRef"
    }
}

// MARK: - Conversion to App Models

extension SIRIResponse {
    /// Convert SIRI response to PRIMResponse for app use
    func toPRIMResponse() -> PRIMResponse {
        guard let delivery = siri.serviceDelivery.stopMonitoringDelivery.first else {
            print("❌ No StopMonitoringDelivery found in response!")
            return PRIMResponse(departures: [], responseTimestamp: Date())
        }
        
        var parseFailures: [String: Int] = [:]
        
        let departures = delivery.monitoredStopVisit.compactMap { visit -> Departure? in
            let journey = visit.monitoredVehicleJourney
            
            // Try to get published line name first, fallback to extraction
            let lineNumber: String
            if let publishedName = journey.publishedLineName?.first?.value {
                lineNumber = publishedName
            } else {
                lineNumber = extractLineNumber(from: journey.lineRef.value)
            }
            
            // Parse ISO 8601 timestamp - try expected first, then aimed
            let departureTimeString = journey.monitoredCall.expectedDepartureTime 
                ?? journey.monitoredCall.aimedDepartureTime
            
            guard let departureTimeStr = departureTimeString else {
                parseFailures["no_time"] = (parseFailures["no_time"] ?? 0) + 1
                return nil
            }
            
            // Configure ISO8601DateFormatter to handle fractional seconds
            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            
            guard let departureTime = dateFormatter.date(from: departureTimeStr) else {
                parseFailures["invalid_time_format"] = (parseFailures["invalid_time_format"] ?? 0) + 1
                return nil
            }
            
            // Get stop name and platform info
            let stopName = journey.monitoredCall.stopPointName?.first?.value ?? "Unknown"
            // PRIM API doesn't provide platform information in stop-monitoring endpoint
            let platformName = ""
            
            // Get destination - try multiple fields
            let destinationName = journey.destinationName?.first?.value 
                ?? journey.destinationShortName?.first?.value
                ?? journey.monitoredCall.destinationDisplay?.first?.value 
                ?? "Unknown"
            
            // Get direction - try directionName or fall back to destination
            var direction = journey.directionName?.first?.value ?? destinationName
            
            // Clean up direction string (remove common prefixes)
            if direction.hasPrefix("Direction ") {
                direction = String(direction.dropFirst("Direction ".count))
            }
            
            return Departure(
                lineName: lineNumber,
                lineRef: journey.lineRef.value,
                destinationName: destinationName,
                destinationRef: journey.destinationRef?.value,
                expectedDepartureTime: departureTime,
                departureStatus: journey.monitoredCall.departureStatus ?? "unknown",
                platformName: platformName,
                direction: direction,
                vehicleJourneyRef: journey.framedVehicleJourneyRef?.datedVehicleJourneyRef,
                operatorRef: journey.operatorRef?.value,
                vehicleAtStop: journey.monitoredCall.vehicleAtStop ?? false
            )
        }
        
        // Parse response timestamp
        let timestamp = ISO8601DateFormatter().date(from: siri.serviceDelivery.responseTimestamp) ?? Date()
        
        print("✅ SIRI Parsing complete: \(departures.count)/\(delivery.monitoredStopVisit.count) valid departures")
        if !parseFailures.isEmpty {
            print("❌ Parse failures:")
            for (reason, count) in parseFailures.sorted(by: { $0.value > $1.value }) {
                print("   • \(reason): \(count) departures")
            }
        }
        return PRIMResponse(departures: departures, responseTimestamp: timestamp)
    }
    
    /// Extract readable line number from STIF line reference
    /// Examples:
    /// - "STIF:Line::C01151:" -> "122" (bus 122)
    /// - "STIF:Line::C01398:" -> "N34" (night bus N34)
    /// - "STIF:Line::C01742:" -> "A" (RER A)
    /// - "STIF:Line::C01729:" -> "E" (RER E)
    private func extractLineNumber(from lineRef: String) -> String {
        // Remove STIF prefix and colons
        let code = lineRef.replacingOccurrences(of: "STIF:Line::", with: "")
            .replacingOccurrences(of: ":", with: "")
        
        // Map ONLY the required lines (VERIFIED from PRIM API requete-ligne endpoint)
        let lineMapping: [String: String] = [
            // RER Lines (VERIFIED)
            "C01742": "A",     // RER A ✅
            "C01729": "E",     // RER E ✅
            
            // Bus Lines (VERIFIED)
            "C01151": "122",   // Bus 122 ✅
            "C01153": "124",   // Bus 124 ✅
            "C01398": "N34",   // N34 Night bus (Noctilien)
        ]
        
        // Try mapping first
        if let mapped = lineMapping[code] {
            return mapped
        }
        
        // For unmapped codes, try to extract a meaningful number
        // Bus lines often have format C0XXXX where XXXX contains the line number
        if code.hasPrefix("C") && code.count > 2 {
            // Try to find the last 3 digits as the line number
            let digits = code.filter { $0.isNumber }
            if digits.count >= 3 {
                let lineNum = String(digits.suffix(3))
                // Remove leading zeros
                if let num = Int(lineNum) {
                    return String(num)
                }
            }
        }
        
        // Fallback to showing the code itself
        return "Line \(code)"
    }
}
