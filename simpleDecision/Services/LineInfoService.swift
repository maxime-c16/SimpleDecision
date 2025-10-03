//
//  LineInfoService.swift
//  simpleDecision
//
//  Created by Transportation Recommendation System on 01/10/2025.
//  Service to fetch and cache published line names from PRIM API
//

import Foundation
import Combine

/// Service to fetch published line names and metadata
class LineInfoService {
    static let shared = LineInfoService()
    
    private let baseURL = "https://prim.iledefrance-mobilites.fr/marketplace/requete-ligne"
    private let apiKey = "r1NDADYoOpUH6qS5XkJoPhiRrNjPpee5"
    private let session = URLSession.shared
    
    // Cache for published line names to avoid repeated API calls
    private var lineNameCache: [String: String] = [:]
    private let cacheQueue = DispatchQueue(label: "com.simpleDecision.lineNameCache")
    
    private init() {}
    
    /// Fetch published line name for a given line reference
    func fetchPublishedLineName(for lineRef: String) -> AnyPublisher<String?, Error> {
        // Check cache first
        if let cached = getCachedName(for: lineRef) {
            return Just(cached)
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        }
        
        var components = URLComponents(string: baseURL)!
        components.queryItems = [
            URLQueryItem(name: "LineRef", value: lineRef)
        ]
        
        guard let url = components.url else {
            return Fail(error: URLError(.badURL))
                .eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.timeoutInterval = 10.0
        
        return session.dataTaskPublisher(for: request)
            .map(\.data)
            .decode(type: LineDiscoveryResponse.self, decoder: JSONDecoder())
            .map { [weak self] response in
                let publishedName = response.extractPublishedLineName()
                self?.cacheName(publishedName, for: lineRef)
                return publishedName
            }
            .catch { _ -> AnyPublisher<String?, Error> in
                // Return nil on error, fallback to line ref extraction
                return Just(nil)
                    .setFailureType(to: Error.self)
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
    
    /// Get published line name synchronously from cache
    func getCachedName(for lineRef: String) -> String? {
        cacheQueue.sync {
            lineNameCache[lineRef]
        }
    }
    
    /// Cache a line name
    private func cacheName(_ name: String?, for lineRef: String) {
        guard let name = name else { return }
        cacheQueue.async { [weak self] in
            self?.lineNameCache[lineRef] = name
        }
    }
}

// MARK: - Line Discovery Response Models

struct LineDiscoveryResponse: Codable {
    let siri: LineDiscoverySiri
    
    enum CodingKeys: String, CodingKey {
        case siri = "Siri"
    }
    
    func extractPublishedLineName() -> String? {
        guard let delivery = siri.serviceDelivery.estimatedTimetableDelivery?.first,
              let frame = delivery.estimatedJourneyVersionFrame?.first,
              let journey = frame.estimatedVehicleJourney?.first,
              let publishedName = journey.publishedLineName?.first?.value else {
            return nil
        }
        return publishedName
    }
}

struct LineDiscoverySiri: Codable {
    let serviceDelivery: LineServiceDelivery
    
    enum CodingKeys: String, CodingKey {
        case serviceDelivery = "ServiceDelivery"
    }
}

struct LineServiceDelivery: Codable {
    let responseTimestamp: String
    let estimatedTimetableDelivery: [EstimatedTimetableDelivery]?
    
    enum CodingKeys: String, CodingKey {
        case responseTimestamp = "ResponseTimestamp"
        case estimatedTimetableDelivery = "EstimatedTimetableDelivery"
    }
}

struct EstimatedTimetableDelivery: Codable {
    let responseTimestamp: String?
    let version: String?
    let status: String?
    let estimatedJourneyVersionFrame: [EstimatedJourneyVersionFrame]?
    
    enum CodingKeys: String, CodingKey {
        case responseTimestamp = "ResponseTimestamp"
        case version = "Version"
        case status = "Status"
        case estimatedJourneyVersionFrame = "EstimatedJourneyVersionFrame"
    }
}

struct EstimatedJourneyVersionFrame: Codable {
    let estimatedVehicleJourney: [EstimatedVehicleJourney]?
    
    enum CodingKeys: String, CodingKey {
        case estimatedVehicleJourney = "EstimatedVehicleJourney"
    }
}

struct EstimatedVehicleJourney: Codable {
    let lineRef: RefValue?
    let publishedLineName: [TextValue]?
    let directionName: [TextValue]?
    let operatorRef: RefValue?
    
    enum CodingKeys: String, CodingKey {
        case lineRef = "LineRef"
        case publishedLineName = "PublishedLineName"
        case directionName = "DirectionName"
        case operatorRef = "OperatorRef"
    }
}
