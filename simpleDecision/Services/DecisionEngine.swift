//
//  DecisionEngine.swift
//  simpleDecision
//
//  Created by Transportation Recommendation System on 30/09/2025.
//

import Foundation
import CoreLocation
import Combine

/// Core business logic that analyzes data and generates transportation recommendations
class DecisionEngine: ObservableObject {
    @Published var currentRecommendation: Recommendation?
    @Published var isProcessing = false
    @Published var lastError: String?
    
    private let primClient: PRIMClient
    private let locationService: LocationService
    private var cancellables = Set<AnyCancellable>()
    
    // Algorithm parameters
    private let walkingSpeedMps = 1.4 // 1.4 m/s = ~5 km/h average walking speed
    private let maxWalkingDistanceMeters = 1200.0 // 12-minute walk maximum
    private let transitWaitPenaltyMinutes = 3.0 // Penalty for waiting at stops
    private let weatherDelayFactors: [String: Double] = [
        "rain": 1.3,
        "snow": 1.5,
        "clear": 1.0
    ]
    
    init(primClient: PRIMClient = PRIMClient.shared, locationService: LocationService) {
        self.primClient = primClient
        self.locationService = locationService
    }
    
    /// Generate transportation recommendation based on current context
    func generateRecommendation(to destination: CLLocationCoordinate2D, weather: String = "clear") -> AnyPublisher<Recommendation, Error> {
        
        guard let currentLocation = locationService.currentLocation else {
            return Fail(error: DecisionError.locationNotAvailable)
                .eraseToAnyPublisher()
        }
        
        isProcessing = true
        lastError = nil
        
        let distance = calculateDistance(from: currentLocation, to: destination)
        
        // Algorithm: Compare walking vs transit based on multiple factors
        return evaluateTransportationOptions(
            from: currentLocation,
            to: destination,
            distance: distance,
            weather: weather
        )
        .handleEvents(
            receiveCompletion: { [weak self] _ in DispatchQueue.main.async { self?.isProcessing = false } },
            receiveCancel: { [weak self] in DispatchQueue.main.async { self?.isProcessing = false } }
        )
        .catch { [weak self] error -> AnyPublisher<Recommendation, Error> in
            DispatchQueue.main.async {
                self?.lastError = error.localizedDescription
            }
            
            // Fallback to walking recommendation if analysis fails
            let walkingRecommendation = self?.createWalkingRecommendation(
                distance: distance,
                weather: weather
            ) ?? Recommendation.mockWalkingRecommendation
            
            return Just(walkingRecommendation)
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        }
        .eraseToAnyPublisher()
    }
    
    /// Evaluate and compare transportation options
    private func evaluateTransportationOptions(
        from origin: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D,
        distance: Double,
        weather: String
    ) -> AnyPublisher<Recommendation, Error> {
        
        // If very close, always recommend walking
        if distance < 300 {
            let walkingRec = createWalkingRecommendation(distance: distance, weather: weather)
            return Just(walkingRec)
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        }
        
        // If too far for reasonable walking, prefer transit
        if distance > maxWalkingDistanceMeters {
            return findBestTransitOption(from: origin, to: destination, distance: distance, weather: weather)
        }
        
        // Medium distance: compare walking vs transit
        return Publishers.CombineLatest(
            Just(createWalkingRecommendation(distance: distance, weather: weather)),
            findBestTransitOption(from: origin, to: destination, distance: distance, weather: weather)
        )
        .map { walkingOption, transitOption in
            return self.selectBestOption(walking: walkingOption, transit: transitOption)
        }
        .eraseToAnyPublisher()
    }
    
    /// Find best transit option using PRIM data
    private func findBestTransitOption(
        from origin: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D,
        distance: Double,
        weather: String
    ) -> AnyPublisher<Recommendation, Error> {
        
        // Find nearby transit stops
        return primClient.findNearbyStops(coordinate: origin)
            .flatMap { stops -> AnyPublisher<Recommendation, Error> in
                guard let nearestStop = stops.first else {
                    // No transit available, return walking
                    return Just(self.createWalkingRecommendation(distance: distance, weather: weather))
                        .setFailureType(to: Error.self)
                        .eraseToAnyPublisher()
                }
                
                // Get departure times for nearest stop
                return self.primClient.fetchDepartures(for: nearestStop.id)
                    .map { primResponse in
                        return self.createTransitRecommendation(
                            primResponse: primResponse,
                            nearestStop: nearestStop,
                            totalDistance: distance,
                            weather: weather
                        )
                    }
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
    
    /// Create walking recommendation with weather adjustments
    private func createWalkingRecommendation(distance: Double, weather: String) -> Recommendation {
        let weatherFactor = weatherDelayFactors[weather] ?? 1.0
        let estimatedTimeMinutes = (distance / walkingSpeedMps / 60) * weatherFactor
        
        return Recommendation(
            id: UUID(),
            transportationMode: .walking,
            estimatedTimeMinutes: estimatedTimeMinutes,
            confidence: calculateWalkingConfidence(distance: distance, weather: weather),
            reasoning: generateWalkingReasoning(distance: distance, timeMinutes: estimatedTimeMinutes, weather: weather),
            source: .algorithm,
            timestamp: Date(),
            weatherCondition: weather
        )
    }
    
    /// Create transit recommendation based on PRIM data
    private func createTransitRecommendation(
        primResponse: PRIMResponse,
        nearestStop: TransitStop,
        totalDistance: Double,
        weather: String
    ) -> Recommendation {
        
        guard let nextDeparture = primResponse.stopMonitoringDelivery.first else {
            // No departures, fallback to walking
            return createWalkingRecommendation(distance: totalDistance, weather: weather)
        }
        
        let waitTimeMinutes = nextDeparture.minutesUntilDeparture
        let walkToStopMinutes = nearestStop.distance / walkingSpeedMps / 60
        let estimatedTransitTimeMinutes = 15.0 // Assume 15min average transit ride
        let totalTimeMinutes = walkToStopMinutes + waitTimeMinutes + estimatedTransitTimeMinutes + transitWaitPenaltyMinutes
        
        let confidence = calculateTransitConfidence(
            waitTime: waitTimeMinutes,
            walkToStop: walkToStopMinutes,
            departureStatus: nextDeparture.departureStatus
        )
        
        return Recommendation(
            id: UUID(),
            transportationMode: .publicTransit,
            estimatedTimeMinutes: totalTimeMinutes,
            confidence: confidence,
            reasoning: generateTransitReasoning(
                lineName: nextDeparture.lineName,
                waitMinutes: waitTimeMinutes,
                walkMinutes: walkToStopMinutes,
                stopName: nearestStop.name
            ),
            source: .primAPI,
            timestamp: Date(),
            weatherCondition: weather
        )
    }
    
    /// Select best option between walking and transit
    private func selectBestOption(walking: Recommendation, transit: Recommendation) -> Recommendation {
        // Prefer option with higher confidence score
        // If confidence is similar, prefer faster option
        let confidenceDiff = walking.confidence - transit.confidence
        let timeDiff = walking.estimatedTimeMinutes - transit.estimatedTimeMinutes
        
        if abs(confidenceDiff) < 0.1 {
            // Similar confidence, choose faster option
            return timeDiff > 0 ? transit : walking
        } else {
            // Choose higher confidence option
            return confidenceDiff > 0 ? walking : transit
        }
    }
    
    /// Calculate distance between two coordinates
    private func calculateDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let fromLocation = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let toLocation = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return fromLocation.distance(from: toLocation)
    }
    
    /// Calculate walking confidence based on distance and weather
    private func calculateWalkingConfidence(distance: Double, weather: String) -> Double {
        var confidence = 1.0
        
        // Distance penalty
        if distance > 800 {
            confidence -= (distance - 800) / 2000 // Decrease confidence for long walks
        }
        
        // Weather penalty
        switch weather {
        case "rain":
            confidence -= 0.2
        case "snow":
            confidence -= 0.3
        default:
            break
        }
        
        return max(0.1, min(1.0, confidence))
    }
    
    /// Calculate transit confidence based on wait time and reliability
    private func calculateTransitConfidence(waitTime: Double, walkToStop: Double, departureStatus: String) -> Double {
        var confidence = 0.8 // Base transit confidence
        
        // Wait time penalty
        if waitTime > 10 {
            confidence -= (waitTime - 10) / 30
        }
        
        // Walk to stop penalty
        if walkToStop > 5 {
            confidence -= (walkToStop - 5) / 20
        }
        
        // Departure status adjustment
        switch departureStatus {
        case "delayed":
            confidence -= 0.2
        case "cancelled":
            confidence -= 0.5
        default: // "onTime"
            break
        }
        
        return max(0.1, min(0.95, confidence))
    }
    
    /// Generate human-readable walking reasoning
    private func generateWalkingReasoning(distance: Double, timeMinutes: Double, weather: String) -> String {
        let distanceText = distance < 1000 ? "\(Int(distance))m" : String(format: "%.1fkm", distance / 1000)
        let timeText = String(format: "%.0f", timeMinutes)
        
        var reasoning = "\(timeText)-minute walk (\(distanceText))"
        
        if weather == "rain" {
            reasoning += " - consider umbrella"
        } else if weather == "snow" {
            reasoning += " - dress warmly"
        }
        
        return reasoning
    }
    
    /// Generate human-readable transit reasoning
    private func generateTransitReasoning(lineName: String, waitMinutes: Double, walkMinutes: Double, stopName: String) -> String {
        let waitText = String(format: "%.0f", waitMinutes)
        let walkText = String(format: "%.0f", walkMinutes)
        
        return "Line \(lineName) in \(waitText)min (\(walkText)min walk to \(stopName))"
    }
    
    /// Clear any stored errors
    func clearError() {
        lastError = nil
    }
}

// MARK: - Error Types
enum DecisionError: LocalizedError {
    case locationNotAvailable
    case noTransitOptions
    case analysisTimeout
    case insufficientData
    
    var errorDescription: String? {
        switch self {
        case .locationNotAvailable:
            return "Current location not available"
        case .noTransitOptions:
            return "No transit options found"
        case .analysisTimeout:
            return "Decision analysis timed out"
        case .insufficientData:
            return "Insufficient data for recommendation"
        }
    }
}