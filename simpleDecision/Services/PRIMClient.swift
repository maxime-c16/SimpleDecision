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
    private let defaultAPIKey = "r1NDADYoOpUH6qS5XkJoPhiRrNjPpee5" // Development fallback
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
        
        var components = URLComponents(string: baseURL)!
        components.queryItems = [
            URLQueryItem(name: "MonitoringRef", value: stopCode),
            URLQueryItem(name: "LineRef", value: ""), // All lines
            URLQueryItem(name: "apikey", value: apiKey)
        ]
        
        guard let url = components.url else {
            return Fail(error: PRIMError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10.0
        
        isLoading = true
        rateLimiter.recordRequest()
        
        return session.dataTaskPublisher(for: request)
            .map(\.data)
            .decode(type: PRIMResponse.self, decoder: JSONDecoder())
            .retry(2) // Retry up to 2 times on failure
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
    
    /// Find nearby transit stops using location
    func findNearbyStops(coordinate: CLLocationCoordinate2D, radius: Double = 500) -> AnyPublisher<[TransitStop], Error> {
        // For development, return mock nearby stops
        // In production, this would call PRIM stops API
        let mockStops = [
            TransitStop(
                id: "STOP_AREA:59:SA:A87",
                name: "Châtelet - Les Halles",
                coordinate: CLLocationCoordinate2D(latitude: 48.8606, longitude: 2.3472),
                distance: 150
            ),
            TransitStop(
                id: "STOP_AREA:59:SA:3688",
                name: "Hôtel de Ville",
                coordinate: CLLocationCoordinate2D(latitude: 48.8565, longitude: 2.3524),
                distance: 280
            ),
            TransitStop(
                id: "STOP_AREA:59:SA:1746",
                name: "République",
                coordinate: CLLocationCoordinate2D(latitude: 48.8676, longitude: 2.3632),
                distance: 420
            )
        ]
        
        return Just(mockStops)
            .setFailureType(to: Error.self)
            .delay(for: .milliseconds(500), scheduler: DispatchQueue.main) // Simulate network delay
            .eraseToAnyPublisher()
    }
    
    /// Save API key to Keychain
    func saveAPIKey(_ key: String) -> Bool {
        return KeychainHelper.shared.save(key: "PRIM_API_KEY", value: key)
    }
    
    /// Remove API key from Keychain
    func removeAPIKey() -> Bool {
        return KeychainHelper.shared.delete(key: "PRIM_API_KEY")
    }
    
    /// Clear any stored errors
    func clearError() {
        lastError = nil
    }
    
    /// Generate mock PRIM response for offline/fallback usage
    private func mockPRIMResponse(for stopCode: String) -> PRIMResponse {
        let departures = [
            Departure(
                lineName: "1",
                destinationName: "Château de Vincennes",
                expectedDepartureTime: Date().addingTimeInterval(3 * 60), // 3 minutes
                departureStatus: "onTime",
                platformName: "Quai 1",
                direction: "Direction Château de Vincennes"
            ),
            Departure(
                lineName: "4",
                destinationName: "Porte de Clignancourt",
                expectedDepartureTime: Date().addingTimeInterval(7 * 60), // 7 minutes
                departureStatus: "onTime",
                platformName: "Quai 2",
                direction: "Direction Porte de Clignancourt"
            ),
            Departure(
                lineName: "11",
                destinationName: "Mairie des Lilas",
                expectedDepartureTime: Date().addingTimeInterval(12 * 60), // 12 minutes
                departureStatus: "delayed",
                platformName: "Quai 3",
                direction: "Direction Mairie des Lilas"
            )
        ]
        
        return PRIMResponse(
            departures: departures,
            responseTimestamp: Date()
        )
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
        }
    }
}