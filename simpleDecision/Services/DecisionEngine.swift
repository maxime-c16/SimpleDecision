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
    private let settingsManager: AppSettingsManager
    private var cancellables = Set<AnyCancellable>()
    
    // Algorithm parameters (can be overridden by user settings)
    private let transitWaitPenaltyMinutes = 3.0 // Penalty for waiting at stops
    private let weatherDelayFactors: [String: Double] = [
        "rain": 1.3,
        "snow": 1.5,
        "clear": 1.0
    ]
    
    init(
        primClient: PRIMClient = PRIMClient.shared,
        locationService: LocationService,
        settingsManager: AppSettingsManager = AppSettingsManager()
    ) {
        self.primClient = primClient
        self.locationService = locationService
        self.settingsManager = settingsManager
    }
    
    // MARK: - Input Validation
    
    /// Validate coordinate values are within valid ranges
    private func validateCoordinates(_ coordinate: CLLocationCoordinate2D) -> Bool {
        // Latitude must be between -90 and 90 degrees
        guard coordinate.latitude >= -90.0 && coordinate.latitude <= 90.0 else {
            return false
        }
        
        // Longitude must be between -180 and 180 degrees
        guard coordinate.longitude >= -180.0 && coordinate.longitude <= 180.0 else {
            return false
        }
        
        // Check for invalid values (NaN, infinite)
        guard coordinate.latitude.isFinite && coordinate.longitude.isFinite else {
            return false
        }
        
        return true
    }
    
    /// Validate distance calculation result
    private func validateDistance(_ distance: Double) -> Bool {
        return distance >= 0 && distance.isFinite && distance < 100000 // Max 100km reasonable
    }
    
    /// Validate weather parameter
    private func validateWeather(_ weather: String) -> Bool {
        let validWeatherTypes = ["clear", "rain", "snow", "cloudy", "fog"]
        return validWeatherTypes.contains(weather.lowercased())
    }
    
    /// Validate PRIM API response
    private func validatePRIMResponse(_ response: PRIMResponse) -> Bool {
        // Check response has valid structure and recent timestamp
        guard response.isRecent else {
            return false
        }
        
        // Check if response has departures data
        guard !response.departures.isEmpty else {
            return false // Empty departures might be valid for some cases
        }
        
        // Validate departure data
        for departure in response.departures {
            // Check departure has valid time
            guard departure.minutesUntilDeparture >= 0 && departure.minutesUntilDeparture < 240 else {
                continue // Invalid departure time (skip but don't fail entire response)
            }
            
            // Check departure has valid line name
            guard !departure.lineName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                continue // Empty line name (skip but don't fail entire response)
            }
        }
        
        return true
    }
    
    /// Generate transportation recommendation based on current context
    func generateRecommendation(to destination: CLLocationCoordinate2D, weather: String = "clear") -> AnyPublisher<Recommendation, Error> {
        
        // Validate input coordinates
        guard validateCoordinates(destination) else {
            return Fail(error: DecisionError.invalidCoordinates)
                .eraseToAnyPublisher()
        }
        
        // Validate weather parameter
        guard validateWeather(weather) else {
            // Use default weather if invalid
            return generateRecommendation(to: destination, weather: "clear")
        }
        
        // Check location permission first
        guard locationService.authorizationStatus == .authorizedWhenInUse else {
            return Fail(error: DecisionError.locationPermissionDenied)
                .eraseToAnyPublisher()
        }
        
        guard let currentLocation = locationService.currentLocation else {
            // If we have permission but no location, try to get one
            locationService.requestLocation()
            return Fail(error: DecisionError.locationNotAvailable)
                .eraseToAnyPublisher()
        }
        
        isProcessing = true
        lastError = nil
        
        let distance = calculateDistance(from: currentLocation, to: destination)
        
        // Validate distance calculation
        guard distance >= 0 else {
            return Fail(error: DecisionError.invalidDistance)
                .eraseToAnyPublisher()
        }
        
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
            ) ?? Recommendation(
                mode: .walk,
                walkETA: Int(distance / 80), // Default: 80m/min walking speed
                busETA: nil,
                confidence: 0.3,
                timestamp: Date(),
                source: .localHeuristics
            )
            
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
        
        // Use user's max walking distance preference
        let maxWalkingDistance = settingsManager.settings.maxWalkingDistanceMeters
        
        // If very close, always recommend walking
        if distance < 300 {
            let walkingRec = createWalkingRecommendation(distance: distance, weather: weather)
            return Just(walkingRec)
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        }
        
        // If too far for user's walking preference, prefer transit
        if distance > maxWalkingDistance {
            return findBestTransitOption(from: origin, to: destination, distance: distance, weather: weather)
        }
        
        // Medium distance: compare walking vs transit
        return Publishers.CombineLatest(
            Just(createWalkingRecommendation(distance: distance, weather: weather))
                .setFailureType(to: Error.self),
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
                // Validate stops data
                let validStops = stops.compactMap { stop -> TransitStop? in
                    guard self.validateCoordinates(stop.coordinate),
                          stop.distance >= 0 && stop.distance < 5000, // Within 5km
                          !stop.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        return nil
                    }
                    return stop
                }
                
                guard let nearestStop = validStops.first else {
                    // No valid transit stops available, return walking
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
        // Validate input parameters
        let validatedDistance = max(0, min(distance, 50000)) // Cap at 50km
        let validatedWeather = validateWeather(weather) ? weather : "clear"
        
        // Use user's walking speed preference
        let walkingSpeed = settingsManager.settings.walkingSpeedMps
        let weatherFactor = weatherDelayFactors[validatedWeather] ?? 1.0
        let estimatedTimeMinutes = (validatedDistance / walkingSpeed / 60) * weatherFactor
        
        // Ensure reasonable time bounds (0-300 minutes)
        let cappedTimeMinutes = max(1, min(estimatedTimeMinutes, 300))
        
        return Recommendation(
            mode: .walk,
            walkETA: Int(cappedTimeMinutes),
            busETA: nil,
            confidence: calculateWalkingConfidence(distance: validatedDistance, weather: validatedWeather),
            timestamp: Date(),
            source: .localHeuristics
        )
    }
    
    /// Create transit recommendation based on PRIM data
    private func createTransitRecommendation(
        primResponse: PRIMResponse,
        nearestStop: TransitStop,
        totalDistance: Double,
        weather: String
    ) -> Recommendation {
        
        // Validate PRIM response
        guard validatePRIMResponse(primResponse) else {
            // Invalid response, fallback to walking
            return createWalkingRecommendation(distance: totalDistance, weather: weather)
        }
        
        guard let nextDeparture = primResponse.departures.first else {
            // No departures, fallback to walking
            return createWalkingRecommendation(distance: totalDistance, weather: weather)
        }
        
        // Validate departure data
        guard nextDeparture.minutesUntilDeparture >= 0 && nextDeparture.minutesUntilDeparture < 120 else {
            // Invalid departure time, fallback to walking
            return createWalkingRecommendation(distance: totalDistance, weather: weather)
        }
        
        let waitTimeMinutes = Double(nextDeparture.minutesUntilDeparture)
        let walkingSpeed = settingsManager.settings.walkingSpeedMps
        let walkToStopMinutes = nearestStop.distance / walkingSpeed / 60
        let estimatedTransitTimeMinutes = 15.0 // Assume 15min average transit ride
        let totalTimeMinutes = walkToStopMinutes + waitTimeMinutes + estimatedTransitTimeMinutes + transitWaitPenaltyMinutes
        
        let confidence = calculateTransitConfidence(
            waitTime: waitTimeMinutes,
            walkToStop: walkToStopMinutes,
            departureStatus: nextDeparture.departureStatus
        )
        
        return Recommendation(
            mode: .bus,
            walkETA: nil,
            busETA: Int(totalTimeMinutes),
            confidence: confidence,
            timestamp: Date(),
            source: .primAPI
        )
    }
    
    /// Select best option between walking and transit using enhanced confidence scoring
    private func selectBestOption(walking: Recommendation, transit: Recommendation) -> Recommendation {
        // If user prefers walking, boost walking score
        let walkingPreferenceBoost = settingsManager.settings.preferWalking ? 0.15 : 0.0
        
        // Enhanced selection algorithm considering confidence, time, and departure reliability
        let confidenceDiff = walking.confidence - transit.confidence
        let timeDiff = (walking.primaryETA ?? 0) - (transit.primaryETA ?? 0)
        
        // Calculate weighted score: confidence * 0.6 + time_efficiency * 0.4
        let walkingScore = calculateOptionScore(
            confidence: walking.confidence,
            timeMinutes: Double(walking.primaryETA ?? 0),
            isTransit: false
        ) + walkingPreferenceBoost
        
        let transitScore = calculateOptionScore(
            confidence: transit.confidence,
            timeMinutes: Double(transit.primaryETA ?? 0),
            isTransit: true
        )
        
        // If scores are very close (within 5%), prefer the option with higher confidence
        if abs(walkingScore - transitScore) < 0.05 {
            return confidenceDiff > 0 ? walking : transit
        }
        
        // Otherwise, choose the option with the higher weighted score
        return walkingScore > transitScore ? walking : transit
    }
    
    /// Calculate weighted score for transportation option
    private func calculateOptionScore(confidence: Double, timeMinutes: Double, isTransit: Bool) -> Double {
        // Normalize time score (shorter time = higher score)
        let maxReasonableTime = 60.0 // 60 minutes max
        let timeScore = max(0, (maxReasonableTime - timeMinutes) / maxReasonableTime)
        
        // Weight confidence more heavily for transit due to departure uncertainty
        let confidenceWeight = isTransit ? 0.7 : 0.5
        let timeWeight = isTransit ? 0.3 : 0.5
        
        return confidence * confidenceWeight + timeScore * timeWeight
    }
    
    /// Calculate distance between two coordinates
    private func calculateDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        // Validate input coordinates
        guard validateCoordinates(from) && validateCoordinates(to) else {
            return -1 // Invalid input
        }
        
        let fromLocation = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let toLocation = CLLocation(latitude: to.latitude, longitude: to.longitude)
        let distance = fromLocation.distance(from: toLocation)
        
        // Validate calculated distance
        guard validateDistance(distance) else {
            return -1 // Invalid distance calculation
        }
        
        return distance
    }
    
    /// Enhanced walking confidence calculation with distance, weather, and time factors
    private func calculateWalkingConfidence(distance: Double, weather: String) -> Double {
        var confidence = 1.0
        
        // Enhanced distance-based confidence scaling
        if distance <= 300 {
            // Very short walks get high confidence
            confidence = 0.95
        } else if distance <= 600 {
            // Comfortable walking distance
            confidence = 0.85
        } else if distance <= 1000 {
            // Moderate distance with gradual penalty
            confidence = 0.8 - (distance - 600) / 2000
        } else {
            // Longer distances with steeper penalty
            confidence = 0.6 - (distance - 1000) / 3000
        }
        
        // Enhanced weather impact
        let weatherMultiplier = calculateWeatherConfidenceMultiplier(weather)
        confidence *= weatherMultiplier
        
        // Time of day factor (could be enhanced with actual time)
        // For now, apply a small general reliability factor
        confidence *= 0.95 // Slight adjustment for real-world walking conditions
        
        return max(0.1, min(1.0, confidence))
    }
    
    /// Calculate weather impact on walking confidence
    private func calculateWeatherConfidenceMultiplier(_ weather: String) -> Double {
        switch weather.lowercased() {
        case "clear", "sunny":
            return 1.0
        case "cloudy", "overcast":
            return 0.95
        case "light_rain", "drizzle":
            return 0.8
        case "rain", "heavy_rain":
            return 0.7
        case "snow", "light_snow":
            return 0.6
        case "heavy_snow", "blizzard":
            return 0.4
        case "storm", "thunderstorm":
            return 0.5
        default:
            return 0.9 // Default for unknown weather
        }
    }
    
    /// Calculate transit confidence based on wait time and reliability
    private func calculateTransitConfidence(waitTime: Double, walkToStop: Double, departureStatus: String) -> Double {
        var confidence = 0.8 // Base transit confidence
        
        // Wait time penalty (enhanced with non-linear scaling)
        if waitTime > 10 {
            let waitPenalty = min((waitTime - 10) / 25, 0.3) // Cap wait penalty at 0.3
            confidence -= waitPenalty
        } else if waitTime < 2 {
            // Bonus for very short waits, but small to avoid over-optimization
            confidence += 0.05
        }
        
        // Walk to stop penalty (enhanced with distance-based scaling)
        if walkToStop > 5 {
            let walkPenalty = min((walkToStop - 5) / 15, 0.25) // Cap walk penalty at 0.25
            confidence -= walkPenalty
        }
        
        // Enhanced departure status confidence adjustment
        let departureConfidence = calculateDepartureStatusConfidence(
            status: departureStatus, 
            waitTime: waitTime,
            walkToStop: walkToStop
        )
        confidence *= departureConfidence
        
        return max(0.1, min(0.95, confidence))
    }
    
    /// Enhanced departure status confidence calculation
    private func calculateDepartureStatusConfidence(status: String, waitTime: Double, walkToStop: Double) -> Double {
        switch status.lowercased() {
        case "ontime", "on_time", "scheduled":
            // High confidence for on-time departures
            return 1.0
            
        case "delayed":
            // Confidence decreases with longer delays and walk times
            let delayImpact = max(0.6, 1.0 - (waitTime - 5) / 20) // More penalty for longer delays
            let walkImpact = walkToStop > 3 ? 0.9 : 1.0 // Additional penalty if walk is long
            return delayImpact * walkImpact
            
        case "cancelled":
            // Very low confidence, but not zero in case data is stale
            return 0.2
            
        case "approaching", "arriving":
            // High confidence if we can reach the stop quickly
            if walkToStop <= 2 {
                return 1.1 // Slight bonus for imminent departures we can catch
            } else {
                return 0.3 // Low confidence if we can't reach in time
            }
            
        case "departed":
            // Very low confidence for already departed vehicles
            return 0.1
            
        case "unknown", "":
            // Medium confidence when status is uncertain
            return 0.7
            
        default:
            // Default fallback for any other status
            return 0.8
        }
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
    case locationPermissionDenied
    case noTransitOptions
    case analysisTimeout
    case insufficientData
    case invalidCoordinates
    case invalidDistance
    case invalidAPIResponse
    case coordinateOutOfRange
    
    var errorDescription: String? {
        switch self {
        case .locationNotAvailable:
            return "Current location not available"
        case .locationPermissionDenied:
            return "Location permission required for recommendations"
        case .noTransitOptions:
            return "No transit options found"
        case .analysisTimeout:
            return "Decision analysis timed out"
        case .insufficientData:
            return "Insufficient data for recommendation"
        case .invalidCoordinates:
            return "Invalid coordinate values provided"
        case .invalidDistance:
            return "Invalid distance calculation"
        case .invalidAPIResponse:
            return "Invalid response from transit API"
        case .coordinateOutOfRange:
            return "Coordinates are outside valid range"
        }
    }
}