//
//  PRIMClient.swift
//  simpleDecision
//
//  Created by Transportation Recommendation System on 30/09/2025.
//

import Foundation
import CoreLocation
import Combine

/// HTTP client for PRIM API - real transit data for Paris region
class PRIMClient: ObservableObject {
    static let shared = PRIMClient()
    
    private let baseURL = "https://prim.iledefrance-mobilites.fr/marketplace/stop-monitoring"
    private let apiKey = "r1NDADYoOpUH6qS5XkJoPhiRrNjPpee5"
    private let session = URLSession.shared
    private var cancellables = Set<AnyCancellable>()
    
    @Published var isLoading = false
    @Published var lastError: String?
    
    private init() {}
    
    /// Fetch real-time departures from PRIM API
    func fetchDepartures(for stopCode: String) -> AnyPublisher<PRIMResponse, Error> {
        guard !stopCode.isEmpty else {
            return Fail(error: PRIMError.invalidStopCode)
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
        
        return session.dataTaskPublisher(for: request)
            .map(\.data)
            .decode(type: PRIMResponse.self, decoder: JSONDecoder())
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
                return Just(self?.mockPRIMResponse(for: stopCode) ?? PRIMResponse.mockResponse)
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
                departureStatus: "onTime"
            ),
            Departure(
                lineName: "4",
                destinationName: "Porte de Clignancourt",
                expectedDepartureTime: Date().addingTimeInterval(7 * 60), // 7 minutes
                departureStatus: "onTime"
            ),
            Departure(
                lineName: "11",
                destinationName: "Mairie des Lilas",
                expectedDepartureTime: Date().addingTimeInterval(12 * 60), // 12 minutes
                departureStatus: "delayed"
            )
        ]
        
        return PRIMResponse(
            responseTimestamp: Date(),
            stopMonitoringDelivery: departures,
            isRealTime: false
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