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
    private let session = URLSession.shared
    
    // Hardcoded fallback mapping for transit lines used in the app
    // Verified from PRIM API on 2025-10-04
    private let knownLines: [String: String] = [
        // Val de Fontenay RER Station (SP:47900)
        "STIF:Line::C01742:": "RER A",        // RER A (towards Paris: Cergy/Poissy/Saint-Germain-en-Laye)
        "STIF:Line::C01729:": "RER E",        // RER E (Tournan/Villiers-sur-Marne ↔ Nanterre-La Folie)
        
        // Cimetière de Vincennes Bus Stop (SP:46543)
        "STIF:Line::C01151:": "Bus 122",      // Bus 122 (to Val-de-Fontenay)
        "STIF:Line::C01153:": "Bus 124",      // Bus 124 (to Château de Vincennes)
    ]
    
    // Cache for published line names to avoid repeated API calls
    private var lineNameCache: [String: String] = [:]
    private let cacheQueue = DispatchQueue(label: "com.simpleDecision.lineNameCache")
    
    private init() {}
    
    /// Get API key from PRIMClient (uses same key)
    private var apiKey: String {
        return PRIMClient.shared.getAPIKey()
    }
    
    /// Fetch published line name for a given line reference
    func fetchPublishedLineName(for lineRef: String) -> AnyPublisher<String?, Error> {
        // Check hardcoded mapping first
        if let knownName = knownLines[lineRef] {
            print("📖 Known line: \(lineRef) = \(knownName)")
            cacheName(knownName, for: lineRef)
            return Just(knownName)
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        }
        
        // Check cache second
        if let cached = getCachedName(for: lineRef) {
            print("💾 Cache HIT for \(lineRef): \(cached)")
            return Just(cached)
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        }
        
        print("🌐 Fetching published name for \(lineRef) from PRIM API...")
        
        var components = URLComponents(string: baseURL)!
        components.queryItems = [
            URLQueryItem(name: "LineRef", value: lineRef)
        ]
        
        guard let url = components.url else {
            print("❌ Invalid URL for LineRef: \(lineRef)")
            return Fail(error: URLError(.badURL))
                .eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.timeoutInterval = 10.0
        
        print("📡 LineInfo API Request: \(url.absoluteString)")
        
        return session.dataTaskPublisher(for: request)
            .map(\.data)
            .decode(type: LineDiscoveryResponse.self, decoder: JSONDecoder())
            .map { [weak self] response in
                let publishedName = response.extractPublishedLineName()
                print("✅ LineInfo API Response for \(lineRef): \(publishedName ?? "nil")")
                self?.cacheName(publishedName, for: lineRef)
                return publishedName
            }
            .catch { error -> AnyPublisher<String?, Error> in
                print("❌ LineInfo API Error for \(lineRef): \(error.localizedDescription)")
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
