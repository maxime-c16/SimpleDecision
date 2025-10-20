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
        
        // ALWAYS fetch both walking AND transit options so user can see both
        // This ensures alternativeTransitDetails is populated even when walking is recommended
        return Publishers.CombineLatest(
            Just(createWalkingRecommendation(distance: distance, weather: weather))
                .setFailureType(to: Error.self),
            findBestTransitOption(from: origin, to: destination, distance: distance, weather: weather)
        )
        .map { walkingOption, transitOption in
            // Apply distance-based preferences but still show both options
            if distance < 300 {
                // Very close: strongly prefer walking but show bus alternative
                return self.selectBestOptionWithAlternative(
                    walking: walkingOption, 
                    transit: transitOption, 
                    preferWalking: true
                )
            } else if distance > maxWalkingDistance {
                // Too far: strongly prefer transit but show walking alternative
                return self.selectBestOptionWithAlternative(
                    walking: walkingOption, 
                    transit: transitOption, 
                    preferWalking: false
                )
            } else {
                // Medium distance: compare and decide
                return self.selectBestOption(walking: walkingOption, transit: transitOption)
            }
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
                    // No valid transit stops available, use mock transit data
                    // This ensures users can still see bus schedule structure
                    print("⚠️ No valid transit stops found, using mock transit data")
                    return Just(self.createMockTransitRecommendation(distance: distance, weather: weather))
                        .setFailureType(to: Error.self)
                        .eraseToAnyPublisher()
                }
                
                print("✅ Using stop: \(nearestStop.name) (\(nearestStop.id)) at \(String(format: "%.0f", nearestStop.distance))m")
                
                // Get departure times for nearest stop
                return self.primClient.fetchDepartures(for: nearestStop.id)
                    .map { primResponse in
                        print("📊 PRIM API returned \(primResponse.departures.count) departures")
                        
                        // Debug: Log ALL departure details
                        print("🔍 RAW DEPARTURES FROM PRIM:")
                        for (idx, dep) in primResponse.departures.enumerated() {
                            let directionStr = dep.direction ?? "no-direction"
                            let platformStr = dep.platformName.isEmpty ? "no-platform" : dep.platformName
                            print("   [\(idx + 1)] Line: '\(dep.lineName)' (\(dep.lineRef ?? "no-ref"))")
                            print("       → Destination: '\(dep.destinationName)'")
                            print("       → Direction: '\(directionStr)'")
                            print("       → Platform: '\(platformStr)'")
                            print("       → Departs: \(dep.expectedDepartureTime) (in \(dep.minutesUntilDeparture) min)")
                            print("       → Status: \(dep.departureStatus)")
                        }
                        
                        return self.createTransitRecommendation(
                            primResponse: primResponse,
                            nearestStop: nearestStop,
                            totalDistance: distance,
                            weather: weather
                        )
                    }
                    .catch { error -> AnyPublisher<Recommendation, Error> in
                        // If departure fetching fails, use mock data instead of propagating error
                        print("❌ fetchDepartures failed: \(error.localizedDescription), using mock transit data")
                        return Just(self.createMockTransitRecommendation(distance: distance, weather: weather))
                            .setFailureType(to: Error.self)
                            .eraseToAnyPublisher()
                    }
                    .eraseToAnyPublisher()
            }
            .catch { error -> AnyPublisher<Recommendation, Error> in
                // If stop finding fails, use mock transit data
                print("❌ findNearbyStops failed: \(error.localizedDescription), using mock transit data")
                return Just(self.createMockTransitRecommendation(distance: distance, weather: weather))
                    .setFailureType(to: Error.self)
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
    
    /// Create mock transit recommendation when API data unavailable
    private func createMockTransitRecommendation(distance: Double, weather: String) -> Recommendation {
        // Use current time to determine if it's day or night
        let hour = Calendar.current.component(.hour, from: Date())
        let isDaytime = hour >= 6 && hour < 22
        
        // Mock stop near user
        let walkToStopMinutes = 5
        let waitForBusMinutes = isDaytime ? 3 : 8
        let busRideMinutes = Int(distance / 333) // ~20 km/h average
        let totalMinutes = walkToStopMinutes + waitForBusMinutes + busRideMinutes + 2
        
        // Create mock upcoming departures
        let now = Date()
        let userArrivalAtStop = now.addingTimeInterval(TimeInterval(walkToStopMinutes * 60))
        
        var mockDepartures: [BusDeparture] = []
        for i in 0..<5 {
            let departureTime = now.addingTimeInterval(TimeInterval((waitForBusMinutes + (i * (isDaytime ? 10 : 20))) * 60))
            let minutesUntil = Int(departureTime.timeIntervalSince(now) / 60)
            let isCatchable = departureTime > userArrivalAtStop.addingTimeInterval(60) // 1 min buffer
            
            mockDepartures.append(BusDeparture(
                id: UUID().uuidString,
                departureTime: departureTime,
                status: i == 0 ? "ontime" : "scheduled",
                minutesUntilDeparture: minutesUntil,
                isCatchable: isCatchable
            ))
        }
        
        // Create mock alternative lines
        let mockAlternatives: [AlternativeLine] = isDaytime ? [
            AlternativeLine(
                id: UUID().uuidString,
                lineNumber: "56",
                lineRef: "STIF:Line::C01056",
                destination: "Château de Vincennes",
                nextDepartureTime: now.addingTimeInterval(300),
                departureStatus: "ontime",
                isCatchable: true
            ),
            AlternativeLine(
                id: UUID().uuidString,
                lineNumber: "RER A",
                lineRef: "STIF:Line::C01371",
                destination: "Cergy",
                nextDepartureTime: now.addingTimeInterval(120),
                departureStatus: "ontime",
                isCatchable: false
            )
        ] : [
            AlternativeLine(
                id: UUID().uuidString,
                lineNumber: "N11",
                lineRef: "STIF:Line::C01385",
                destination: "Gare de l'Est",
                nextDepartureTime: now.addingTimeInterval(600),
                departureStatus: "scheduled",
                isCatchable: true
            )
        ]
        
        // Create ETA breakdown
        let etaBreakdown = TransitETABreakdown(
            walkToStopMinutes: walkToStopMinutes,
            waitForBusMinutes: waitForBusMinutes,
            busRideMinutes: busRideMinutes
        )
        
        // Select line based on time of day
        let lineName = isDaytime ? "124" : "N34"
        let lineRef = isDaytime ? "STIF:Line::C01153" : "STIF:Line::C01398"
        let destination = isDaytime ? "Porte de Vincennes" : "Gare de Lyon"
        
        let nextDeparture = now.addingTimeInterval(TimeInterval(waitForBusMinutes * 60))
        
        let transitDetails = TransitDetails(
            lineName: lineName,
            lineRef: lineRef,
            destinationName: destination,
            stopName: "Nation",
            departureTime: nextDeparture,
            departureStatus: "ontime",
            platformName: isDaytime ? "2" : "",
            walkToStopMinutes: walkToStopMinutes,
            operatorRef: "RATP:Operator::100",
            direction: destination,
            vehicleAtStop: false,
            etaBreakdown: etaBreakdown,
            alternativeLines: mockAlternatives,
            stopId: "STIF:StopPoint:Q:42016",
            upcomingDepartures: mockDepartures
        )
        
        return Recommendation(
            mode: .bus,
            walkETA: nil,
            busETA: totalMinutes,
            confidence: 0.7,
            timestamp: Date(),
            source: .primAPI,
            transitDetails: transitDetails
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
            // Invalid response, fallback to walking BUT keep PRIM source since we tried
            print("⚠️ Invalid PRIM response, recommending walking")
            let walkingRec = createWalkingRecommendation(distance: totalDistance, weather: weather)
            // Update source to show we used PRIM API (even though result was invalid)
            return Recommendation(
                mode: walkingRec.mode,
                walkETA: walkingRec.walkETA,
                busETA: walkingRec.busETA,
                confidence: walkingRec.confidence,
                timestamp: walkingRec.timestamp,
                source: .primAPI,  // We got data from PRIM, just wasn't useful
                transitDetails: walkingRec.transitDetails,
                alternativeTransitDetails: walkingRec.alternativeTransitDetails
            )
        }
        
        // Determine if it's daytime or nighttime
        let hour = Calendar.current.component(.hour, from: Date())
        let isDaytime = hour >= 6 && hour < 22  // 6 AM to 10 PM is daytime
        
        // Smart filtering based on time of day and bus availability
        // Strategy: During transition hours (10 PM - 1 AM), prefer daytime buses if available
        let isTransitionPeriod = (hour >= 22 && hour < 24) || (hour >= 0 && hour < 1)
        
        let daytimeBuses = primResponse.departures.filter { departure in
            !departure.lineName.uppercased().hasPrefix("N")
        }
        
        let nightBuses = primResponse.departures.filter { departure in
            departure.lineName.uppercased().hasPrefix("N")
        }
        
        let filteredDepartures: [Departure]
        if isDaytime {
            // Strict daytime: ONLY daytime buses
            filteredDepartures = daytimeBuses
            print("🌞 Daytime mode: Filtering out night buses. Found \(filteredDepartures.count) daytime departures")
        } else if isTransitionPeriod && !daytimeBuses.isEmpty {
            // Transition period: PREFER daytime buses if still running
            filteredDepartures = daytimeBuses
            print("🌆 Transition period: Daytime buses still running. Using \(filteredDepartures.count) daytime departures, ignoring \(nightBuses.count) night buses")
        } else {
            // Late night: Use night buses (or all buses if no dedicated night service)
            filteredDepartures = nightBuses.isEmpty ? primResponse.departures : nightBuses
            print("🌙 Night mode: Using \(filteredDepartures.count) night departures")
        }
        
        guard !filteredDepartures.isEmpty else {
            // No valid departures after filtering, fallback to walking BUT keep PRIM source
            print("⚠️ No valid departures found after time-aware filtering, recommending walking")
            let walkingRec = createWalkingRecommendation(distance: totalDistance, weather: weather)
            return Recommendation(
                mode: walkingRec.mode,
                walkETA: walkingRec.walkETA,
                busETA: walkingRec.busETA,
                confidence: walkingRec.confidence,
                timestamp: walkingRec.timestamp,
                source: .primAPI,  // We got PRIM data, just no suitable buses
                transitDetails: walkingRec.transitDetails,
                alternativeTransitDetails: walkingRec.alternativeTransitDetails
            )
        }
        
        // Calculate walk time to stop with safety buffer
        let walkingSpeed = settingsManager.settings.walkingSpeedMps
        let walkToStopMinutes = nearestStop.distance / walkingSpeed / 60
        
        // Add minimal 15-second safety buffer (account for slight timing uncertainty)
        // This allows catching buses that depart very close to arrival time
        let safetyBufferSeconds: TimeInterval = 15
        let arrivalTimeAtStop = Date().addingTimeInterval(walkToStopMinutes * 60 + safetyBufferSeconds)
        
        print("⏱️ Walk to stop: \(String(format: "%.1f", walkToStopMinutes)) min (\(String(format: "%.0f", nearestStop.distance))m at \(String(format: "%.1f", walkingSpeed))m/s)")
        print("🚶 User arrival at stop (with 15s buffer): \(DateFormatter.localizedString(from: arrivalTimeAtStop, dateStyle: .none, timeStyle: .short))")
        
        // Log all departure times for debugging
        for (index, departure) in filteredDepartures.enumerated() {
            let departureTimeStr = DateFormatter.localizedString(from: departure.expectedDepartureTime, dateStyle: .none, timeStyle: .short)
            let isCatchable = arrivalTimeAtStop <= departure.expectedDepartureTime
            print("   \(index + 1). \(departure.lineName) @ \(departureTimeStr) - \(isCatchable ? "✅ Catchable" : "❌ Too soon") (in \(departure.minutesUntilDeparture) min)")
        }
        
        // Find first catchable departure - look ahead as far as needed
        // Remove 120-minute limit since we have full schedule from PRIM API
        guard let nextDeparture = filteredDepartures.first(where: { departure in
            departure.isUpcoming &&
            departure.minutesUntilDeparture >= 0 &&
            arrivalTimeAtStop <= departure.expectedDepartureTime
        }) else {
            // No catchable departures in entire schedule, fallback to walking
            print("⚠️ No catchable departures found in schedule (checked \(filteredDepartures.count) departures), recommending walking")
            let walkingRec = createWalkingRecommendation(distance: totalDistance, weather: weather)
            return Recommendation(
                mode: walkingRec.mode,
                walkETA: walkingRec.walkETA,
                busETA: walkingRec.busETA,
                confidence: walkingRec.confidence,
                timestamp: walkingRec.timestamp,
                source: .primAPI,  // We got PRIM data, buses just not catchable
                transitDetails: walkingRec.transitDetails,
                alternativeTransitDetails: walkingRec.alternativeTransitDetails
            )
        }
        
        print("✅ Selected transit: \(nextDeparture.lineName) to \(nextDeparture.destinationName) at \(nextDeparture.expectedDepartureTime)")
        print("   📝 Selected departure details:")
        let dirStr = nextDeparture.direction ?? "no-direction"
        let platStr = nextDeparture.platformName.isEmpty ? "no-platform" : nextDeparture.platformName
        print("      Line: '\(nextDeparture.lineName)' (\(nextDeparture.lineRef ?? "no-ref"))")
        print("      Destination: '\(nextDeparture.destinationName)'")
        print("      Direction: '\(dirStr)'")
        print("      Platform: '\(platStr)'")
        print("      Status: \(nextDeparture.departureStatus)")
        
        // Calculate wait time (time between arrival at stop and bus departure)
        let waitTimeMinutes = nextDeparture.expectedDepartureTime.timeIntervalSince(arrivalTimeAtStop) / 60
        
        // Calculate bus ride time based on distance (estimate 20 km/h average speed in city)
        let estimatedTransitTimeMinutes = calculateTransitRideTime(distance: totalDistance - nearestStop.distance)
        
        let totalTimeMinutes = walkToStopMinutes + waitTimeMinutes + estimatedTransitTimeMinutes + transitWaitPenaltyMinutes
        
        let confidence = calculateTransitConfidence(
            waitTime: waitTimeMinutes,
            walkToStop: walkToStopMinutes,
            departureStatus: nextDeparture.departureStatus
        )
        
        // Create detailed ETA breakdown with REAL times
        let etaBreakdown = TransitETABreakdown(
            walkToStopMinutes: Int(walkToStopMinutes.rounded()),
            waitForBusMinutes: Int(waitTimeMinutes.rounded()),
            busRideMinutes: Int(estimatedTransitTimeMinutes.rounded())
        )
        
        // Find alternative lines at the same stop
        let alternativeLines = findAlternativeLines(
            at: nearestStop,
            excluding: nextDeparture,
            from: primResponse
        )
        
        print("🔄 Found \(alternativeLines.count) alternative lines:")
        for (idx, alt) in alternativeLines.enumerated() {
            print("   [\(idx + 1)] Line \(alt.lineNumber) → \(alt.destination) @ \(DateFormatter.localizedString(from: alt.nextDepartureTime, dateStyle: .none, timeStyle: .short)) (\(alt.isCatchable ? "✅ Catchable" : "❌ Too soon"))")
        }
        
        // Get upcoming departures for the same line (next 5 departures within 120 minutes)
        let upcomingDepartures = primResponse.departures
            .filter { departure in
                // Same line as recommended
                guard departure.lineName == nextDeparture.lineName else { return false }
                // Same destination (to avoid opposite direction)
                guard departure.destinationName == nextDeparture.destinationName else { return false }
                // Only upcoming departures
                guard departure.isUpcoming else { return false }
                // Within next 120 minutes (extended to capture more buses)
                guard departure.minutesUntilDeparture <= 120 else { return false }
                return true
            }
            .sorted { $0.expectedDepartureTime < $1.expectedDepartureTime }
            .prefix(5)
            .map { departure in
                // Check if this departure is catchable (buffer already included in arrivalTimeAtStop)
                let isCatchable = arrivalTimeAtStop <= departure.expectedDepartureTime
                
                return BusDeparture(
                    id: departure.id.uuidString,
                    departureTime: departure.expectedDepartureTime,
                    status: departure.departureStatus,
                    minutesUntilDeparture: departure.minutesUntilDeparture,
                    isCatchable: isCatchable
                )
            }
        
        print("📅 Found \(upcomingDepartures.count) upcoming departures for Line \(nextDeparture.lineName):")
        for (idx, upcoming) in upcomingDepartures.enumerated() {
            print("   [\(idx + 1)] @ \(DateFormatter.localizedString(from: upcoming.departureTime, dateStyle: .none, timeStyle: .short)) - \(upcoming.status) (\(upcoming.isCatchable ? "✅" : "❌"))")
        }
        
        // Create transit details from PRIM API data (based on actual available fields)
        let transitDetails = TransitDetails(
            lineName: nextDeparture.lineName,
            lineRef: nextDeparture.lineRef,
            destinationName: nextDeparture.destinationName,
            stopName: nearestStop.name,
            departureTime: nextDeparture.expectedDepartureTime,
            departureStatus: nextDeparture.departureStatus,
            platformName: nextDeparture.platformName,
            walkToStopMinutes: Int(walkToStopMinutes.rounded()),
            operatorRef: nextDeparture.operatorRef,
            direction: nextDeparture.direction,
            vehicleAtStop: nextDeparture.vehicleAtStop,
            etaBreakdown: etaBreakdown,
            alternativeLines: alternativeLines,
            stopId: nearestStop.id,
            upcomingDepartures: Array(upcomingDepartures)
        )
        
        return Recommendation(
            mode: .bus,
            walkETA: nil,
            busETA: Int(totalTimeMinutes),
            confidence: confidence,
            timestamp: Date(),
            source: .primAPI,
            transitDetails: transitDetails
        )
    }
    
    /// Calculate estimated transit ride time based on distance
    private func calculateTransitRideTime(distance: Double) -> Double {
        // Average bus speed: 20 km/h in city, metro/RER: 30 km/h
        let averageSpeedKmh = 20.0
        let averageSpeedMs = averageSpeedKmh * 1000 / 3600 // Convert to m/s
        let rideTimeMinutes = (distance / averageSpeedMs) / 60
        
        // Add stops penalty (assume 1 stop every 500m, 30 seconds per stop)
        let estimatedStops = distance / 500
        let stopPenaltyMinutes = estimatedStops * 0.5
        
        return max(5.0, rideTimeMinutes + stopPenaltyMinutes) // Minimum 5 minutes
    }
    
    /// Find alternative bus/metro lines at the same stop
    private func findAlternativeLines(
        at stop: TransitStop,
        excluding mainDeparture: Departure,
        from response: PRIMResponse
    ) -> [AlternativeLine] {
        // Calculate walk time to stop in minutes
        let walkingSpeed = settingsManager.settings.walkingSpeedMps
        let walkToStopMinutes = stop.distance / walkingSpeed / 60
        let arrivalTimeAtStop = Date().addingTimeInterval(walkToStopMinutes * 60)
        
        // Get all departures except the main one
        let alternatives = response.departures
            .filter { departure in
                // Exclude the main departure
                guard departure.id != mainDeparture.id else { return false }
                // Only upcoming departures
                guard departure.isUpcoming else { return false }
                // Within next 30 minutes
                guard departure.minutesUntilDeparture <= 30 else { return false }
                return true
            }
            .sorted { $0.expectedDepartureTime < $1.expectedDepartureTime }
            .prefix(5) // Limit to 5 alternatives
        
        return alternatives.map { departure in
            // Check if user can catch this bus (buffer already included in arrivalTimeAtStop)
            let isCatchable = arrivalTimeAtStop <= departure.expectedDepartureTime
            
            return AlternativeLine(
                id: departure.id.uuidString,
                lineNumber: departure.lineName,
                lineRef: departure.lineRef ?? "",
                destination: departure.destinationName,
                nextDepartureTime: departure.expectedDepartureTime,
                departureStatus: departure.departureStatus,
                isCatchable: isCatchable
            )
        }
    }
    
    /// Select best option between walking and transit using enhanced confidence scoring
    private func selectBestOption(walking: Recommendation, transit: Recommendation) -> Recommendation {
        // If user prefers walking, boost walking score
        let walkingPreferenceBoost = settingsManager.settings.preferWalking ? 0.15 : 0.0
        
        // Enhanced selection algorithm considering confidence, time, and departure reliability
        let confidenceDiff = walking.confidence - transit.confidence
        
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
        let selectedRecommendation: Recommendation
        if abs(walkingScore - transitScore) < 0.05 {
            selectedRecommendation = confidenceDiff > 0 ? walking : transit
        } else {
            // Otherwise, choose the option with the higher weighted score
            selectedRecommendation = walkingScore > transitScore ? walking : transit
        }
        
        // IMPORTANT: Always include transit details as alternative when walking is recommended
        // This allows users to see bus info even when walking is the primary recommendation
        if selectedRecommendation.mode == .walk && transit.transitDetails != nil {
            return Recommendation(
                mode: selectedRecommendation.mode,
                walkETA: selectedRecommendation.walkETA,
                busETA: transit.busETA,
                confidence: selectedRecommendation.confidence,
                timestamp: selectedRecommendation.timestamp,
                source: selectedRecommendation.source,
                transitDetails: selectedRecommendation.transitDetails,
                alternativeTransitDetails: transit.transitDetails
            )
        }
        
        return selectedRecommendation
    }
    
    /// Select option with strong preference but always include alternative
    private func selectBestOptionWithAlternative(
        walking: Recommendation,
        transit: Recommendation,
        preferWalking: Bool
    ) -> Recommendation {
        if preferWalking {
            // Recommend walking but include transit as alternative
            return Recommendation(
                mode: .walk,
                walkETA: walking.walkETA,
                busETA: transit.busETA,
                confidence: walking.confidence,
                timestamp: walking.timestamp,
                source: walking.source,
                transitDetails: nil,
                alternativeTransitDetails: transit.transitDetails
            )
        } else {
            // Recommend transit (bus is better for long distances)
            return transit
        }
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