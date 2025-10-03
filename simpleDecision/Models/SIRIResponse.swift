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
    let lineRef: RefValue
    let operatorRef: RefValue?
    let publishedLineName: [TextValue]?
    let directionName: [TextValue]?
    let directionRef: RefValue?
    let destinationName: [TextValue]?
    let destinationRef: RefValue?
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
    let departureStatus: String?
    let arrivalStatus: String?
    
    enum CodingKeys: String, CodingKey {
        case stopPointName = "StopPointName"
        case vehicleAtStop = "VehicleAtStop"
        case destinationDisplay = "DestinationDisplay"
        case expectedDepartureTime = "ExpectedDepartureTime"
        case departureStatus = "DepartureStatus"
        case arrivalStatus = "ArrivalStatus"
    }
}

// MARK: - Supporting Structures

struct RefValue: Codable {
    let value: String
}

struct TextValue: Codable {
    let value: String
}

struct FramedVehicleJourneyRef: Codable {
    let dataFrameRef: RefValue?
    let datedVehicleJourneyRef: String?
    
    enum CodingKeys: String, CodingKey {
        case dataFrameRef = "DataFrameRef"
        case datedVehicleJourneyRef = "DatedVehicleJourneyRef"
    }
}

struct TrainNumbers: Codable {
    let trainNumberRef: [String]?
    
    enum CodingKeys: String, CodingKey {
        case trainNumberRef = "TrainNumberRef"
    }
}

// MARK: - Conversion to App Models

extension SIRIResponse {
    /// Convert SIRI response to PRIMResponse for app use
    func toPRIMResponse() -> PRIMResponse {
        guard let delivery = siri.serviceDelivery.stopMonitoringDelivery.first else {
            return PRIMResponse(departures: [], responseTimestamp: Date())
        }
        
        let departures = delivery.monitoredStopVisit.compactMap { visit -> Departure? in
            let journey = visit.monitoredVehicleJourney
            
            // Try to get published line name first, fallback to extraction
            let lineNumber: String
            if let publishedName = journey.publishedLineName?.first?.value {
                lineNumber = publishedName
            } else {
                lineNumber = extractLineNumber(from: journey.lineRef.value)
            }
            
            // Parse ISO 8601 timestamp
            guard let departureTime = ISO8601DateFormatter().date(from: journey.monitoredCall.expectedDepartureTime ?? "") else {
                return nil
            }
            
            let stopName = journey.monitoredCall.stopPointName?.first?.value ?? "Unknown"
            let destinationName = journey.destinationName?.first?.value 
                ?? journey.monitoredCall.destinationDisplay?.first?.value 
                ?? "Unknown"
            
            return Departure(
                lineName: lineNumber,
                lineRef: journey.lineRef.value,
                destinationName: destinationName,
                destinationRef: journey.destinationRef?.value,
                expectedDepartureTime: departureTime,
                departureStatus: journey.monitoredCall.departureStatus ?? "unknown",
                platformName: stopName,
                direction: journey.directionName?.first?.value,
                vehicleJourneyRef: journey.framedVehicleJourneyRef?.datedVehicleJourneyRef,
                operatorRef: journey.operatorRef?.value,
                vehicleAtStop: journey.monitoredCall.vehicleAtStop ?? false
            )
        }
        
        // Parse response timestamp
        let timestamp = ISO8601DateFormatter().date(from: siri.serviceDelivery.responseTimestamp) ?? Date()
        
        return PRIMResponse(departures: departures, responseTimestamp: timestamp)
    }
    
    /// Extract readable line number from STIF line reference
    /// Examples:
    /// - "STIF:Line::C01151:" -> "122" (bus 122 day service)
    /// - "STIF:Line::C01398:" -> "N34" (night bus via fallback or PublishedLineName)
    /// - "STIF:Line::C01742:" -> "A" (RER A)
    /// - "STIF:Line::C01729:" -> "E" (RER E)
    /// - "STIF:Line::C01371:" -> "1" (metro)
    private func extractLineNumber(from lineRef: String) -> String {
        // Remove STIF prefix and colons
        let code = lineRef.replacingOccurrences(of: "STIF:Line::", with: "")
            .replacingOccurrences(of: ":", with: "")
        
        // Map known codes to line numbers (comprehensive mapping based on real API data)
        let lineMapping: [String: String] = [
            // RER Lines (using short published names as they appear in API)
            "C01742": "A",     // RER A
            "C01743": "B",     // RER B
            "C01727": "C",     // RER C
            "C01728": "D",     // RER D
            "C01729": "E",     // RER E
            "C01730": "P",     // RER P (Paris-only service)
            
            // Metro Lines
            "C01371": "M1",
            "C01372": "M2",
            "C01373": "M3",
            "C01374": "M3bis",
            "C01375": "M4",
            "C01376": "M5",
            "C01377": "M6",
            "C01378": "M7",
            "C01379": "M7bis",
            "C01380": "M8",
            "C01381": "M9",
            "C01382": "M10",
            "C01383": "M11",
            "C01384": "M12",
            "C01385": "M13",
            "C01386": "M14",
            
            // Bus Lines (confirmed from API)
            "C01151": "122",  // Bus 122 (day service)
            "C01153": "124",  // Bus 124
            "C01398": "N34",  // N34 Night bus (Noctilien)
            
            // Tramway Lines
            "C01774": "T1",
            "C01775": "T2",
            "C01776": "T3a",
            "C01777": "T3b",
            "C01778": "T4",
            "C01779": "T5",
            "C01780": "T6",
            "C01781": "T7",
            "C01782": "T8",
            "C01783": "T9",
            "C01784": "T10",
            "C01785": "T11",
            "C01786": "T12",
            "C01787": "T13"
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
