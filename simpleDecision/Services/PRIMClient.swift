//
//  PRIMClient.swift
//  simpleDecision
//
//  Created by Transportation Recommendation System on 30/09/2025.
//

import Foundation
import CoreLocation
import Combine
import Security

/// HTTP client for PRIM API - real transit data for Paris region
class PRIMClient: ObservableObject {
    static let shared = PRIMClient()
    
    private let baseURL = "https://prim.iledefrance-mobilites.fr/marketplace/stop-monitoring"
    private let defaultAPIKey = "GTMvVD9BG8KTIRabGaEE3R65hkGe1N8D" // User's API key
    private let session = URLSession.shared
    private var cancellables = Set<AnyCancellable>()
    
    // Rate limiting - 5 requests per second max
    private let rateLimiter = RateLimiter(maxRequests: 5, timeWindow: 1.0)
    
    @Published var isLoading = false
    @Published var lastError: String?
    
    private init() {}
    
    /// Get API key from Keychain or fallback to default
    private var apiKey: String {
        if let storedKey = KeychainHelper.shared.get(key: "PRIM_API_KEY") {
            return storedKey
        }
        return defaultAPIKey
    }
    
    /// Fetch real-time departures from PRIM API with rate limiting and retry logic
    func fetchDepartures(for stopCode: String) -> AnyPublisher<PRIMResponse, Error> {
        guard !stopCode.isEmpty else {
            return Fail(error: PRIMError.invalidStopCode)
                .eraseToAnyPublisher()
        }
        
        // Check rate limit
        guard rateLimiter.canMakeRequest() else {
            return Fail(error: PRIMError.rateLimitExceeded)
                .eraseToAnyPublisher()
        }
        
        // Ensure stop code has trailing colon (REQUIRED by PRIM API)
        let cleanStopCode = stopCode.hasSuffix(":") ? stopCode : "\(stopCode):"
        
        var components = URLComponents(string: baseURL)!
        components.queryItems = [
            URLQueryItem(name: "MonitoringRef", value: cleanStopCode)
            // API key goes in header, not query params
        ]
        
        guard let url = components.url else {
            return Fail(error: PRIMError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(apiKey, forHTTPHeaderField: "apikey")  // ✅ API key in header
        request.timeoutInterval = 10.0
        
        print("🚌 PRIM API Request: \(url.absoluteString)")
        print("🔑 API Key: \(apiKey.prefix(10))...")
        
        isLoading = true
        rateLimiter.recordRequest()
        
        return session.dataTaskPublisher(for: request)
            .tryMap { data, response -> Data in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw PRIMError.networkError(NSError(domain: "Invalid response", code: -1))
                }
                
                // Log response for debugging
                if let responseString = String(data: data, encoding: .utf8) {
                    print("🚌 PRIM API Response (\(httpResponse.statusCode)): \(responseString.prefix(200))...")
                }
                
                guard httpResponse.statusCode == 200 else {
                    throw PRIMError.networkError(NSError(domain: "HTTP \(httpResponse.statusCode)", code: httpResponse.statusCode))
                }
                
                return data
            }
            .decode(type: SIRIResponse.self, decoder: JSONDecoder())
            .map { siriResponse in
                // Map stop code to stop name for filtering
                let stopName = self.mapStopCodeToName(stopCode)
                return siriResponse.toPRIMResponse(stopName: stopName)
            }
            .flatMap { primResponse -> AnyPublisher<PRIMResponse, Error> in
                // Enrich departures with published line names from requete-ligne endpoint
                self.enrichWithPublishedNames(primResponse)
            }
            .retry(1) // Retry once on failure
            .handleEvents(
                receiveCompletion: { [weak self] _ in
                    DispatchQueue.main.async {
                        self?.isLoading = false
                    }
                },
                receiveCancel: { [weak self] in
                    DispatchQueue.main.async {
                        self?.isLoading = false
                    }
                }
            )
            .catch { [weak self] error -> AnyPublisher<PRIMResponse, Error> in
                print("❌❌❌ PRIM API PIPELINE ERROR: \(error)")
                print("❌❌❌ Error details: \(error.localizedDescription)")
                if let decodingError = error as? DecodingError {
                    print("❌❌❌ DECODING ERROR DETECTED:")
                    switch decodingError {
                    case .keyNotFound(let key, let context):
                        print("   Key '\(key.stringValue)' not found: \(context.debugDescription)")
                        print("   codingPath: \(context.codingPath)")
                    case .valueNotFound(let type, let context):
                        print("   Value of type '\(type)' not found: \(context.debugDescription)")
                        print("   codingPath: \(context.codingPath)")
                    case .typeMismatch(let type, let context):
                        print("   Type mismatch for '\(type)': \(context.debugDescription)")
                        print("   codingPath: \(context.codingPath)")
                    case .dataCorrupted(let context):
                        print("   Data corrupted: \(context.debugDescription)")
                        print("   codingPath: \(context.codingPath)")
                    @unknown default:
                        print("   Unknown decoding error")
                    }
                }
                print("❌❌❌ FALLING BACK TO MOCK DATA")
                
                DispatchQueue.main.async {
                    self?.lastError = error.localizedDescription
                }
                
                // Return mock data on API failure for graceful degradation
                return Just(self?.mockPRIMResponse(for: stopCode) ?? PRIMResponse(
                    departures: [],
                    responseTimestamp: Date()
                ))
                    .setFailureType(to: Error.self)
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
    
    /// Find nearby transit stops using Navitia API (real dynamic discovery)
    func findNearbyStops(coordinate: CLLocationCoordinate2D, radius: Double = 500) -> AnyPublisher<[TransitStop], Error> {
        // Use Navitia places_nearby endpoint for real stop discovery
        let navitiaBaseURL = "https://api.navitia.io/v1/coverage/fr-idf"
        let lon = coordinate.longitude
        let lat = coordinate.latitude
        
        print("📍 DEBUG findNearbyStops:")
        print("   Input coordinate: lat=\(lat), lon=\(lon)")
        print("   (raw: \(coordinate))")
        
        var components = URLComponents(string: "\(navitiaBaseURL)/coords/\(lon);\(lat)/places_nearby")!
        components.queryItems = [
            URLQueryItem(name: "distance", value: String(Int(radius))),
            URLQueryItem(name: "type[]", value: "stop_area"),
            URLQueryItem(name: "type[]", value: "stop_point"),
            URLQueryItem(name: "count", value: "10"),
            URLQueryItem(name: "disable_geojson", value: "true")
        ]
        
        guard let url = components.url else {
            return Fail(error: PRIMError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        // Use API key for Navitia authentication
        request.setValue(apiKey, forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10.0
        
        return session.dataTaskPublisher(for: request)
            .tryMap { data, response -> [TransitStop] in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw PRIMError.networkError(NSError(domain: "Invalid response", code: -1))
                }
                
                guard httpResponse.statusCode == 200 else {
                    throw PRIMError.networkError(NSError(domain: "HTTP Error", code: httpResponse.statusCode))
                }
                
                let decoder = JSONDecoder()
                let navitiaResponse = try decoder.decode(NavitiaPlacesResponse.self, from: data)
                
                return navitiaResponse.places_nearby.compactMap { place -> TransitStop? in
                    guard let coord = place.stop_area?.coord else {
                        return nil
                    }
                    
                    // Convert Navitia ID format to PRIM MonitoringRef format
                    // Navitia uses "stop_area:xxx" format, PRIM uses "STIF:StopPoint:Q:xxx" format
                    let primId = self.convertNavitiaIDToPRIM(place.id)
                    
                    return TransitStop(
                        id: primId,
                        name: place.name,
                        coordinate: CLLocationCoordinate2D(
                            latitude: Double(coord.lat) ?? coordinate.latitude,
                            longitude: Double(coord.lon) ?? coordinate.longitude
                        ),
                        distance: Double(place.distance ?? 0)
                    )
                }
            }
            .catch { error -> AnyPublisher<[TransitStop], Error> in
                print("⚠️ Navitia API error: \(error). Falling back to known working stops.")
                
                // Fallback to essential stops only
                // Verified working with PRIM API on 2025-10-04
                // Coordinates from official RATP/STIF data (arrets.json)
                let valdeFontenayCoord = CLLocationCoordinate2D(latitude: 48.85316, longitude: 2.48711)
                let cimetierCoord = CLLocationCoordinate2D(latitude: 48.86095, longitude: 2.48124)
                
                let valdeFontenayDist = self.calculateDistance(from: coordinate, to: valdeFontenayCoord)
                let cimetierDist = self.calculateDistance(from: coordinate, to: cimetierCoord)
                
                print("🔍 DEBUG Distance Calculations:")
                print("   From user (lat=\(coordinate.latitude), lon=\(coordinate.longitude)):")
                print("   → Val de Fontenay (48.85316, 2.48711): \(String(format: "%.0f", valdeFontenayDist))m")
                print("   → Cimetière (48.86095, 2.48124): \(String(format: "%.0f", cimetierDist))m")
                print("   Cimetière is closer by: \(String(format: "%.0f", abs(valdeFontenayDist - cimetierDist)))m")
                
                let fallbackStops = [
                    TransitStop(
                        id: "STIF:StopArea:SP:47900:",  // Val de Fontenay RER A Station (towards Paris)
                        name: "Val de Fontenay RER",
                        coordinate: valdeFontenayCoord,
                        distance: valdeFontenayDist
                    ),
                    TransitStop(
                        id: "STIF:StopArea:SP:46543:",  // Cimetière de Vincennes (Bus 122 to VDF, 124 to Château)
                        name: "Cimetière de Vincennes",
                        coordinate: cimetierCoord,
                        distance: cimetierDist
                    )
                ].sorted { $0.distance < $1.distance }  // Sort by distance to user
                
                print("🔍 DEBUG Fallback stops (sorted):")
                for (idx, stop) in fallbackStops.enumerated() {
                    print("   [\(idx + 1)] \(stop.name): \(String(format: "%.0f", stop.distance))m")
                }
                
                return Just(fallbackStops)
                    .setFailureType(to: Error.self)
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
    
    /// Convert Navitia stop ID to PRIM MonitoringRef format
    private func convertNavitiaIDToPRIM(_ navitiaID: String) -> String {
        // Navitia format: "stop_area:STIF:XXXXX" or "stop_point:STIF:XXXXX"
        // PRIM format: "STIF:StopPoint:Q:XXXXX" (without trailing colon)
        
        // Extract the numeric/alphanumeric part after "STIF:"
        let components = navitiaID.components(separatedBy: ":")
        if components.count >= 3, components[1] == "STIF" {
            let stopCode = components[2]
            return "STIF:StopPoint:Q:\(stopCode)"
        }
        
        // If already in correct format, return as-is
        return navitiaID
    }
    
    /// Calculate distance between two coordinates in meters
    private func calculateDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let fromLocation = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let toLocation = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return fromLocation.distance(from: toLocation)
    }
    
    /// Save API key to Keychain
    func saveAPIKey(_ key: String) -> Bool {
        return KeychainHelper.shared.save(key: "PRIM_API_KEY", value: key)
    }
    
    /// Remove API key from Keychain
    func removeAPIKey() -> Bool {
        return KeychainHelper.shared.delete(key: "PRIM_API_KEY")
    }
    
    /// Get current API key (stored or default)
    func getAPIKey() -> String {
        return apiKey
    }
    
    /// Clear any stored errors
    func clearError() {
        lastError = nil
    }
    
    /// Generate mock PRIM response for offline/fallback usage
    private func mockPRIMResponse(for stopCode: String) -> PRIMResponse {
        // Get current hour to determine if it's day or night
        let hour = Calendar.current.component(.hour, from: Date())
        let isDaytime = hour >= 6 && hour < 22  // Daytime: 6 AM to 10 PM
        
        // Determine stop name from stop code
        // SP:47900 = Val de Fontenay RER, SP:46543 = Cimetière de Vincennes
        let stopName: String
        if stopCode.contains("47900") {
            stopName = "Val de Fontenay RER"
        } else if stopCode.contains("46543") {
            stopName = "Cimetière de Vincennes"
        } else {
            stopName = "Unknown Stop"
        }
        
        // Use realistic data based on which stop is requested
        let departures: [Departure]
        
        if stopCode.contains("47900") {
            // Val de Fontenay RER - RER A and E trains only
            if isDaytime {
                // Generate realistic RER schedule with trains every 3-6 minutes for next 30 minutes
                var rerDepartures: [Departure] = []
                let now = Date()
                
                // RER A trains (every 3-6 minutes, alternating destinations)
                let rerADestinations = ["Cergy le Haut", "Poissy", "Marne-la-Vallée"]
                for i in 0..<10 { // 10 trains over ~30 minutes
                    let offset = 3 + (i * 3) // 3, 6, 9, 12, 15, 18, 21, 24, 27, 30 minutes
                    rerDepartures.append(Departure(
                        lineName: "RER A",
                        lineRef: "STIF:Line::C01742:",
                        destinationName: rerADestinations[i % rerADestinations.count],
                        destinationRef: nil,
                        expectedDepartureTime: now.addingTimeInterval(TimeInterval(offset * 60)),
                        departureStatus: i < 3 ? "onTime" : "scheduled",
                        platformName: "Val de Fontenay",
                        direction: rerADestinations[i % rerADestinations.count],
                        vehicleJourneyRef: nil,
                        operatorRef: "STIF:Operator::RATP:",
                        vehicleAtStop: i == 0,
                        stopName: stopName
                    ))
                }
                
                // RER E trains (every 4-8 minutes)
                let rerEDestinations = ["Haussmann-St-Lazare", "Chelles-Gournay"]
                for i in 0..<6 { // 6 trains over ~30 minutes
                    let offset = 5 + (i * 5) // 5, 10, 15, 20, 25, 30 minutes
                    rerDepartures.append(Departure(
                        lineName: "RER E",
                        lineRef: "STIF:Line::C01729:",
                        destinationName: rerEDestinations[i % rerEDestinations.count],
                        destinationRef: nil,
                        expectedDepartureTime: now.addingTimeInterval(TimeInterval(offset * 60)),
                        departureStatus: i < 2 ? "onTime" : "scheduled",
                        platformName: "Val de Fontenay",
                        direction: rerEDestinations[i % rerEDestinations.count],
                        vehicleJourneyRef: nil,
                        operatorRef: "STIF:Operator::SNCF:",
                        vehicleAtStop: false,
                        stopName: stopName
                    ))
                }
                
                departures = rerDepartures.sorted { $0.expectedDepartureTime < $1.expectedDepartureTime }
                print("🚆 Generated \(departures.count) RER mock departures for Val de Fontenay")
            
            } else {
                departures = []  // No RER at night
            }
        } else if stopCode.contains("46543") {
            // Cimetière de Vincennes - Bus 122 only
            if isDaytime {
                departures = [
                    Departure(
                        lineName: "Bus 122",  // Match user preferences format
                        lineRef: "STIF:Line::C01152:",
                        destinationName: "Nogent-Chalamet",
                        destinationRef: nil,
                        expectedDepartureTime: Date().addingTimeInterval(4 * 60),
                        departureStatus: "onTime",
                        platformName: "Cimetière de Vincennes",
                        direction: "Direction Nogent",
                        vehicleJourneyRef: nil,
                        operatorRef: "RATP:Operator::100:",
                        vehicleAtStop: false,
                        stopName: stopName
                    ),
                    Departure(
                        lineName: "Bus 122",  // Match user preferences format
                        lineRef: "STIF:Line::C01152:",
                        destinationName: "Nogent-Chalamet",
                        destinationRef: nil,
                        expectedDepartureTime: Date().addingTimeInterval(10 * 60),
                        departureStatus: "onTime",
                        platformName: "Cimetière de Vincennes",
                        direction: "Direction Nogent",
                        vehicleJourneyRef: nil,
                        operatorRef: "RATP:Operator::100:",
                        vehicleAtStop: false,
                        stopName: stopName
                    )
                ]
            } else {
                // Night bus from Cimetière
                departures = [
                    Departure(
                        lineName: "N34",
                        lineRef: "STIF:Line::C01398:",
                        destinationName: "Gare de Lyon",
                        destinationRef: "STIF:StopPoint:Q:421409:",
                        expectedDepartureTime: Date().addingTimeInterval(15 * 60),
                        departureStatus: "onTime",
                        platformName: "Cimetière de Vincennes",
                        direction: "Direction Gare de Lyon",
                        vehicleJourneyRef: nil,
                        operatorRef: "RATP:Operator::100:",
                        vehicleAtStop: false,
                        stopName: stopName
                    )
                ]
            }
        } else {
            // Unknown stop - return generic departures
            if isDaytime {
                departures = [
                    Departure(
                        lineName: "Bus 122",  // Match user preferences format
                        lineRef: "STIF:Line::C01152:",
                        destinationName: "Nogent-Chalamet",
                        destinationRef: nil,
                        expectedDepartureTime: Date().addingTimeInterval(8 * 60),
                        departureStatus: "onTime",
                        platformName: "Unknown",
                        direction: "Direction Nogent",
                        vehicleJourneyRef: nil,
                        operatorRef: "RATP:Operator::100:",
                        vehicleAtStop: false,
                        stopName: stopName
                    )
                ]
            } else {
                departures = [
                    Departure(
                        lineName: "N34",  // Already correct format
                        lineRef: "STIF:Line::C01398:",
                        destinationName: "Gare de Lyon",
                        destinationRef: "STIF:StopPoint:Q:421409:",
                        expectedDepartureTime: Date().addingTimeInterval(15 * 60),
                        departureStatus: "onTime",
                        platformName: "Unknown",
                        direction: "Direction Gare de Lyon",
                        vehicleJourneyRef: nil,
                        operatorRef: "RATP:Operator::100:",
                        vehicleAtStop: false,
                        stopName: stopName
                    )
                ]
            }
        }
        
        return PRIMResponse(
            departures: departures,
            responseTimestamp: Date()
        )
    }
    
    /// Enrich PRIMResponse with published line names from requete-ligne endpoint
    /// This is called after initial SIRI parsing to get accurate line names (e.g., "N34" for night buses)
    private func enrichWithPublishedNames(_ response: PRIMResponse) -> AnyPublisher<PRIMResponse, Error> {
        // Collect all unique line refs that need enrichment (filter out nil lineRefs)
        let lineRefsToFetch = Set(response.departures.compactMap { $0.lineRef })
        
        if lineRefsToFetch.isEmpty {
            return Just(response)
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        }
        
        // Fetch published names for all unique line refs in parallel
        let publishers = lineRefsToFetch.map { lineRef -> AnyPublisher<(String, String?), Never> in
            LineInfoService.shared.fetchPublishedLineName(for: lineRef)
                .replaceError(with: nil)
                .map { publishedName in (lineRef, publishedName) }
                .eraseToAnyPublisher()
        }
        
        return Publishers.MergeMany(publishers)
            .collect()
            .map { (fetchedNames: [(String, String?)]) -> PRIMResponse in
                // Create a mapping of lineRef -> publishedName
                var nameMap: [String: String?] = [:]
                for (lineRef, publishedName) in fetchedNames {
                    nameMap[lineRef] = publishedName
                }
                
                // Update departures with published names where available
                let enrichedDepartures = response.departures.map { departure -> Departure in
                    guard let lineRef = departure.lineRef,
                          let publishedName = nameMap[lineRef],
                          let name = publishedName,
                          !name.isEmpty else {
                        return departure
                    }
                    
                    return Departure(
                        lineName: name,
                        lineRef: departure.lineRef,
                        destinationName: departure.destinationName,
                        destinationRef: departure.destinationRef,
                        expectedDepartureTime: departure.expectedDepartureTime,
                        departureStatus: departure.departureStatus,
                        platformName: departure.platformName,
                        direction: departure.direction,
                        vehicleJourneyRef: departure.vehicleJourneyRef,
                        operatorRef: departure.operatorRef,
                        vehicleAtStop: departure.vehicleAtStop,
                        stopName: departure.stopName
                    )
                }
                
                // Now refine bus destinations for better catchability analysis
                let refinedDepartures = self.refineDestinations(enrichedDepartures)
                
                return PRIMResponse(
                    departures: refinedDepartures,
                    responseTimestamp: response.responseTimestamp
                )
            }
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    /// Refine bus destinations for better catchability calculation
    /// Maps bus routes to their primary destinations
    private func refineDestinations(_ departures: [Departure]) -> [Departure] {
        // Destination refinement mapping: for specific bus lines and API destinations,
        // map to the refined destination for better user guidance
        let destinationRefinements: [String: [String: String]] = [
            "Bus 122": [
                // Bus 122 destinations mapping
                "Gallieni": "Val de Fontenay",
                "Val-de-Fontenay <RER>": "Val de Fontenay",
            ],
            "Bus 124": [
                // Bus 124 destinations mapping
                "Montreuil-Boissière-Acacia": "Chateau de Vincennes",
                "Château de Vincennes": "Chateau de Vincennes",
            ],
        ]
        
        let refinedDepartures = departures.map { departure -> Departure in
            var refinedDestination = departure.destinationName
            
            // Check if this is a bus line that needs destination refinement
            if let mappings = destinationRefinements[departure.lineName] {
                // Look for a matching original destination
                if let refined = mappings[departure.destinationName] {
                    refinedDestination = refined
                }
            }
            
            return Departure(
                lineName: departure.lineName,
                lineRef: departure.lineRef,
                destinationName: refinedDestination,
                destinationRef: departure.destinationRef,
                expectedDepartureTime: departure.expectedDepartureTime,
                departureStatus: departure.departureStatus,
                platformName: departure.platformName,
                direction: departure.direction,
                vehicleJourneyRef: departure.vehicleJourneyRef,
                operatorRef: departure.operatorRef,
                vehicleAtStop: departure.vehicleAtStop,
                stopName: departure.stopName
            )
        }
        
        return refinedDepartures
    }
    
    /// Map stop code to stop name for filtering purposes
    private func mapStopCodeToName(_ stopCode: String) -> String {
        // Extract the numeric ID from stop code like "STIF:StopArea:SP:46543:"
        if stopCode.contains("46543") {
            return "Cimetière de Vincennes"
        } else if stopCode.contains("47900") {
            return "Val de Fontenay RER"
        } else if stopCode.contains("473595") {
            return "Val de Fontenay Bus"
        }
        return "Unknown Stop"
    }
}

// MARK: - Supporting Models
struct TransitStop: Codable, Identifiable {
    let id: String
    let name: String
    let coordinate: CLLocationCoordinate2D
    let distance: Double // meters from user location
    
    var formattedDistance: String {
        if distance < 1000 {
            return "\(Int(distance))m"
        } else {
            return String(format: "%.1fkm", distance / 1000)
        }
    }
    
    /// Map stop code to stop name for filtering purposes
    private func mapStopCodeToName(_ stopCode: String) -> String {
        // Extract the numeric ID from stop code like "STIF:StopArea:SP:46543:"
        if stopCode.contains("46543") {
            return "Cimetière de Vincennes"
        } else if stopCode.contains("47900") {
            return "Val de Fontenay RER"
        } else if stopCode.contains("473595") {
            return "Val de Fontenay Bus"
        }
        return "Unknown Stop"
    }
}

// MARK: - Rate Limiter
class RateLimiter {
    private let maxRequests: Int
    private let timeWindow: TimeInterval
    private var requestTimes: [Date] = []
    private let queue = DispatchQueue(label: "rate.limiter", attributes: .concurrent)
    
    init(maxRequests: Int, timeWindow: TimeInterval) {
        self.maxRequests = maxRequests
        self.timeWindow = timeWindow
    }
    
    func canMakeRequest() -> Bool {
        return queue.sync {
            let now = Date()
            let cutoff = now.addingTimeInterval(-timeWindow)
            
            // Remove old requests outside the time window
            requestTimes.removeAll { $0 < cutoff }
            
            return requestTimes.count < maxRequests
        }
    }
    
    func recordRequest() {
        queue.async(flags: .barrier) {
            self.requestTimes.append(Date())
        }
    }
}

// MARK: - Keychain Helper
class KeychainHelper {
    static let shared = KeychainHelper()
    private let service = "simpleDecision.keychain"
    
    private init() {}
    
    func save(key: String, value: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        // Delete existing item first
        SecItemDelete(query as CFDictionary)
        
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    func get(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return string
    }
    
    func delete(key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess
    }
}

// MARK: - Error Types
enum PRIMError: LocalizedError {
    case invalidStopCode
    case invalidURL
    case noData
    case apiKeyMissing
    case rateLimitExceeded
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidStopCode:
            return "Invalid stop code provided"
        case .invalidURL:
            return "Could not construct valid API URL"
        case .noData:
            return "No transit data available"
        case .apiKeyMissing:
            return "API key not configured"
        case .rateLimitExceeded:
            return "Too many requests - please wait"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}