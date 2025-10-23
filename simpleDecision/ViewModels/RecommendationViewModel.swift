//
//  RecommendationViewModel.swift
//  simpleDecision
//
//  Created by Transportation Recommendation System on 30/09/2025.
//

import Foundation
import SwiftUI
import Combine
import CoreLocation

/// View model for displaying and managing transportation recommendations
@MainActor
class RecommendationViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var recommendation: Recommendation?
    @Published var isRefreshing = false
    @Published var showingDetails = false
    @Published var showingAlternatives = false
    @Published var alternativeRecommendations: [Recommendation] = []
    @Published var errorMessage: String?
    @Published var timeUntilRefresh: Int = 0
    @Published var weatherCondition = "clear"
    
    // Animation and UI state
    @Published var showingAnimation = false
    @Published var pulseAnimation = false
    
    // MARK: - Services
    private let decisionEngine: DecisionEngine
    private let locationService: LocationService
    private let activityManager: ActivityManagerProtocol
    private let settingsManager: AppSettingsManager
    private let rerEstimator = RERWaitTimeEstimator()
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private var refreshTimer: Timer?
    private var countdownTimer: Timer?
    private let refreshInterval: TimeInterval = 30
    
    // MARK: - Initialization
    @MainActor
    init(
        decisionEngine: DecisionEngine,
        locationService: LocationService,
        activityManager: ActivityManagerProtocol,
        settingsManager: AppSettingsManager
    ) {
        self.decisionEngine = decisionEngine
        self.locationService = locationService
        self.activityManager = activityManager
        self.settingsManager = settingsManager
        
        setupBindings()
    }
    
    // MARK: - Setup
    private func setupBindings() {
        // Monitor decision engine recommendation updates
        decisionEngine.$currentRecommendation
            .sink { [weak self] recommendation in
                self?.handleRecommendationUpdate(recommendation)
            }
            .store(in: &cancellables)
        
        // Monitor decision engine loading state
        decisionEngine.$isProcessing
            .assign(to: \.isRefreshing, on: self)
            .store(in: &cancellables)
        
        // Monitor decision engine errors
        decisionEngine.$lastError
            .compactMap { $0 }
            .sink { [weak self] error in
                self?.errorMessage = error
            }
            .store(in: &cancellables)
        
        // Start pulse animation when loading
        $isRefreshing
            .sink { [weak self] isRefreshing in
                if isRefreshing {
                    self?.startPulseAnimation()
                } else {
                    self?.stopPulseAnimation()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    /// Set the current recommendation and start refresh cycle
    func setRecommendation(_ recommendation: Recommendation) {
        self.recommendation = recommendation
        startRefreshCycle()
        triggerShowAnimation()
    }
    
    /// Manually refresh the recommendation
    func refreshRecommendation(destination: Destination) async {
        guard !isRefreshing else { return }
        
        do {
            let newRecommendation = try await decisionEngine
                .generateRecommendation(to: destination.coordinate, weather: weatherCondition)
                .async()
            
            recommendation = newRecommendation
            startRefreshCycle()
            
        // Update Live Activity if active
        if #available(iOS 16.1, *), activityManager.hasActiveActivities() {
            _ = await activityManager.updateActivity(with: newRecommendation)
        }        } catch {
            errorMessage = "Failed to refresh: \(error.localizedDescription)"
        }
    }
    
    /// Generate alternative recommendations
    func generateAlternatives(destination: Destination) async {
        guard let currentRec = recommendation else { return }
        
        // Generate alternatives by modifying weather conditions and parameters
        var alternatives: [Recommendation] = []
        
        // Weather alternatives
        let weatherConditions = ["clear", "rain", "snow"]
        for weather in weatherConditions where weather != weatherCondition {
            do {
                let altRec = try await decisionEngine
                    .generateRecommendation(to: destination.coordinate, weather: weather)
                    .async()
                alternatives.append(altRec)
            } catch {
                // Continue with other alternatives if one fails
                continue
            }
        }
        
        // Add walking alternative if current is transit
        if currentRec.mode == .bus {
            let walkingRec = createWalkingAlternative(destination: destination)
            alternatives.append(walkingRec)
        }
        
        // Add transit alternative if current is walking
        if currentRec.mode == .walk {
            // This would be a simplified transit option
            let transitRec = createTransitAlternative(destination: destination)
            alternatives.append(transitRec)
        }
        
        alternativeRecommendations = alternatives.filter { $0.mode != currentRec.mode }
        showingAlternatives = true
    }
    
    /// Select an alternative recommendation
    func selectAlternative(_ alternative: Recommendation) {
        recommendation = alternative
        showingAlternatives = false
        triggerShowAnimation()
        
        // Update Live Activity
        if #available(iOS 16.1, *), activityManager.hasActiveActivities() {
            Task {
                await activityManager.updateActivity(with: alternative)
            }
        }
    }
    
    /// Show recommendation details
    func showDetails() {
        showingDetails = true
    }
    
    /// Hide recommendation details
    func hideDetails() {
        showingDetails = false
    }
    
    /// Mark journey as started (begin Live Activity tracking)
    func startJourney(destination: Destination) {
        guard let rec = recommendation else { return }
        
        if #available(iOS 16.1, *) {
            Task {
                await activityManager.startActivity(
                    destinationName: destination.name, 
                    startLocationName: "Current Location",
                    recommendation: rec
                )
            }
        }
        
        startRefreshCycle()
    }
    
    /// Mark journey as completed
    func completeJourney() {
        if #available(iOS 16.1, *) {
            Task {
                await activityManager.markActivityCompleted()
            }
        }
        
        stopRefreshCycle()
        recommendation = nil
    }
    
    /// Clear current recommendation
    func clearRecommendation() {
        recommendation = nil
        alternativeRecommendations = []
        stopRefreshCycle()
        
        if #available(iOS 16.1, *) {
            Task {
                await activityManager.endAllActivities()
            }
        }
    }
    
    /// Update weather condition
    func updateWeather(_ weather: String) {
        weatherCondition = weather
    }
    
    /// Clear error message
    func clearError() {
        errorMessage = nil
        decisionEngine.clearError()
    }
    
    // MARK: - Private Methods
    
    private func handleRecommendationUpdate(_ recommendation: Recommendation?) {
        self.recommendation = recommendation
        
        if recommendation != nil {
            triggerShowAnimation()
        }
    }
    
    private func startRefreshCycle() {
        stopRefreshCycle()
        
        timeUntilRefresh = Int(refreshInterval)
        
        // Countdown timer
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            Task { @MainActor in
                if self.timeUntilRefresh > 0 {
                    self.timeUntilRefresh -= 1
                } else {
                    // Timer reached zero, will be reset by refresh timer
                    self.timeUntilRefresh = Int(self.refreshInterval)
                }
            }
        }
        
        // Refresh timer
        refreshTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                // Auto-refresh would happen here in a real implementation
                // For now, we just reset the countdown
                self.timeUntilRefresh = Int(self.refreshInterval)
            }
        }
    }
    
    private func stopRefreshCycle() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        countdownTimer?.invalidate()
        countdownTimer = nil
        timeUntilRefresh = 0
    }
    
    private func triggerShowAnimation() {
        showingAnimation = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.showingAnimation = false
        }
    }
    
    private func startPulseAnimation() {
        pulseAnimation = true
    }
    
    private func stopPulseAnimation() {
        pulseAnimation = false
    }
    
    private func createWalkingAlternative(destination: Destination) -> Recommendation {
        guard locationService.currentLocation != nil else {
            return Recommendation.mockWalk
        }
        
        let distance = locationService.distanceToDestination(destination.coordinate) ?? 1000
        let walkingSpeedMps = 1.4
        let timeMinutes = distance / walkingSpeedMps / 60
        
        return Recommendation(
            mode: .walk,
            walkETA: Int(timeMinutes),
            busETA: nil,
            confidence: max(0.3, 1.0 - (distance / 2000)), // Lower confidence for longer walks
            timestamp: Date(),
            source: .localHeuristics
        )
    }
    
    private func createTransitAlternative(destination: Destination) -> Recommendation {
        // Simplified transit alternative
        return Recommendation(
            mode: .bus,
            walkETA: nil,
            busETA: 20,
            confidence: 0.7,
            timestamp: Date(),
            source: .localHeuristics
        )
    }
    
    // MARK: - Computed Properties
    
    var hasRecommendation: Bool {
        recommendation != nil
    }
    
    var hasAlternatives: Bool {
        !alternativeRecommendations.isEmpty
    }
    
    var isJourneyActive: Bool {
        if #available(iOS 16.1, *) {
            return activityManager.hasActiveActivities()
        } else {
            return recommendation != nil && refreshTimer != nil
        }
    }
    
    var recommendationAge: String {
        guard let rec = recommendation else { return "" }
        
        let elapsed = Date().timeIntervalSince(rec.timestamp)
        
        if elapsed < 60 {
            return "Just now"
        } else if elapsed < 3600 {
            let minutes = Int(elapsed / 60)
            return "\(minutes)m ago"
        } else {
            let hours = Int(elapsed / 3600)
            return "\(hours)h ago"
        }
    }
    
    var nextRefreshText: String {
        if timeUntilRefresh > 0 {
            return "Next update in \(timeUntilRefresh)s"
        } else {
            return "Updating..."
        }
    }
    
    var weatherDisplayText: String {
        switch weatherCondition {
        case "rain":
            return "🌧️ Rainy"
        case "snow":
            return "❄️ Snowy"
        case "clear":
            return "☀️ Clear"
        default:
            return "🌤️ \(weatherCondition.capitalized)"
        }
    }
    
    deinit {
        // Clean up timers synchronously to avoid Task outliving object
        refreshTimer?.invalidate()
        countdownTimer?.invalidate()
    }
}

// MARK: - Enhanced Recommendation Logic

extension RecommendationViewModel {
    
    /// Extract RER departures from recommendation's full RER schedule
    private func extractRERDepartures(from recommendation: Recommendation) -> [(lineName: String, departureTime: Date)] {
        var rerDepartures: [(String, Date)] = []
        
        // PRIORITY 1: Use allRERDepartures from transit details (lightweight full schedule)
        if let transitDetails = recommendation.transitDetails, !transitDetails.allRERDepartures.isEmpty {
            for departure in transitDetails.allRERDepartures {
                rerDepartures.append((departure.lineName, departure.departureTime))
            }
            
            print("   🔍 Extracted \(rerDepartures.count) RER departures from allRERDepartures (full schedule)")
            return rerDepartures.sorted(by: { $0.1 < $1.1 })
        }
        
        // FALLBACK: Use alternative lines if allRERDepartures not available
        if let transitDetails = recommendation.transitDetails {
            for altLine in transitDetails.alternativeLines {
                if altLine.lineNumber.contains("RER") {
                    rerDepartures.append((altLine.lineNumber, altLine.nextDepartureTime))
                }
            }
        }
        
        if let altTransit = recommendation.alternativeTransitDetails {
            for altLine in altTransit.alternativeLines {
                if altLine.lineNumber.contains("RER") {
                    rerDepartures.append((altLine.lineNumber, altLine.nextDepartureTime))
                }
            }
        }
        
        print("   🔍 Extracted \(rerDepartures.count) RER departures from alternative lines (fallback)")
        return rerDepartures.sorted(by: { $0.1 < $1.1 })
    }
    
    /// Convert standard Recommendation to EnhancedRecommendation with full timing breakdown
    func createEnhancedRecommendation(from recommendation: Recommendation) -> EnhancedRecommendation? {
        switch recommendation.mode {
        case .walk:
            return createEnhancedWalkRecommendation(from: recommendation)
        case .bus:
            return createEnhancedBusRecommendation(from: recommendation)
        case .tie:
            // For tie, we can show both options
            return createEnhancedTieRecommendation(from: recommendation)
        }
    }
    
    /// Create enhanced walk recommendation with RER details
    private func createEnhancedWalkRecommendation(from recommendation: Recommendation) -> EnhancedRecommendation {
        
        guard let currentLocation = locationService.currentLocation else {
            // Fallback with default values
            let walkDetails = WalkRecommendationDetails(
                walkToStationMinutes: recommendation.walkETA ?? 15,
                stationName: "Val de Fontenay",
                rerWaitMinutes: 5
            )
            
            
            return EnhancedRecommendation(
                recommendationType: .walk,
                confidence: recommendation.confidence,
                walkDetails: walkDetails,
                alternativeBusOptions: extractAlternativeBusOptions(from: recommendation)
            )
        }
        
        // Calculate walk time to Val de Fontenay
        let walkMinutes = rerEstimator.estimateWalkTimeToRER(
            from: currentLocation,
            walkingSpeed: settingsManager.settings.walkingSpeedMps
        )
        
        // Calculate arrival time at station
        let arrivalTime = Date().addingTimeInterval(TimeInterval(walkMinutes * 60))
        
        // Get RER schedule from recommendation
        let rerDepartures = extractRERDepartures(from: recommendation)
        
        // Calculate RER wait time using real schedule if available
        let rerWaitMinutes: Int
        if !rerDepartures.isEmpty {
            rerWaitMinutes = rerEstimator.calculateRealRERWaitTime(arrivalTime: arrivalTime, rerDepartures: rerDepartures)
        } else {
            rerWaitMinutes = rerEstimator.estimateRERWaitTime(arrivalTime: arrivalTime)
        }
        
        // Find next viable bus option
        let nextBusMinutes = findNextViableBusOption(from: recommendation)
        
        let walkDetails = WalkRecommendationDetails(
            walkToStationMinutes: walkMinutes,
            stationName: "Val de Fontenay RER",
            rerWaitMinutes: rerWaitMinutes,
            nextBusOptionMinutes: nextBusMinutes
        )
        
        // if let nextBus = nextBusMinutes {
        //     print("   🚌 Next bus option in \(nextBus) minutes")
        // }
        
        // Get alternative bus options
        let alternativeBusOptions = extractAlternativeBusOptions(from: recommendation)
        // print("   📋 Found \(alternativeBusOptions.count) alternative bus options")
        
        return EnhancedRecommendation(
            recommendationType: .walk,
            confidence: recommendation.confidence,
            walkDetails: walkDetails,
            alternativeBusOptions: alternativeBusOptions
        )
    }
    
    /// Create enhanced bus recommendation with full timing breakdown
    private func createEnhancedBusRecommendation(from recommendation: Recommendation) -> EnhancedRecommendation? {
        // print("🚌 Creating enhanced BUS recommendation")
        
        guard let transitDetails = recommendation.transitDetails else {
            print("   ❌ No transit details, returning nil")
            return nil
        }
        
        // print("   📍 Bus: \(transitDetails.lineName) → \(transitDetails.destinationName)")
//         print("   🚏 Stop: \(transitDetails.stopName)")
        
        // Calculate wait time at bus stop
        let waitMinutes = max(0, transitDetails.minutesUntilDeparture - transitDetails.walkToStopMinutes)
        
        // Get RER schedule from recommendation
        let rerDepartures = extractRERDepartures(from: recommendation)
        
        // Estimate bus ride time and RER wait with real schedule
        let (busRideMinutes, rerWaitMinutes) = rerEstimator.estimateTotalBusJourneyTime(
            lineName: transitDetails.lineName,
            departureTime: transitDetails.departureTime,
            walkToStopMinutes: transitDetails.walkToStopMinutes,
            destinationName: transitDetails.destinationName,
            rerDepartures: rerDepartures
        )
        
        // print("   ⏱️ Timing: \(transitDetails.walkToStopMinutes)min walk + \(waitMinutes)min wait + \(busRideMinutes)min ride + \(rerWaitMinutes)min RER = \(transitDetails.walkToStopMinutes + waitMinutes + busRideMinutes + rerWaitMinutes)min total")
        
        let primaryBusOption = BusOptionTiming(
            lineName: transitDetails.lineName,
            lineRef: transitDetails.lineRef,
            destinationName: transitDetails.destinationName,
            stopName: transitDetails.stopName,
            departureTime: transitDetails.departureTime,
            departureStatus: transitDetails.departureStatus,
            walkToStopMinutes: transitDetails.walkToStopMinutes,
            waitAtStopMinutes: waitMinutes,
            busRideMinutes: busRideMinutes,
            rerWaitMinutes: rerWaitMinutes
        )
        
        // Extract alternative bus options from upcoming departures
        let alternativeBusOptions = extractAlternativeBusOptionsFromTransit(transitDetails: transitDetails, rerDepartures: rerDepartures)
        // print("   📋 Found \(alternativeBusOptions.count) alternative bus options")
        
        // 🧪 TEST: DualRouteCalculator with real data
        // Try to get actual user location, fallback to calculating from stop distance
        let userLocation: CLLocationCoordinate2D
        if let currentLoc = locationService.currentLocation {
            userLocation = currentLoc
            // print("   ✅ Using actual user location: (\(String(format: "%.6f", currentLoc.latitude)), \(String(format: "%.6f", currentLoc.longitude)))")
        } else {
            // Fallback: Calculate approximate user position from stop location and walk distance
            // This is a rough estimate - in practice location should always be available
            let stopLat = 48.86095  // Cimetière de Vincennes
            let stopLon = 2.48124
            let walkDistanceMeters = Double(transitDetails.walkToStopMinutes) * 1.4 * 60 // walkSpeed * 60 seconds
            let offsetLat = walkDistanceMeters / 111000.0 // ~111km per degree latitude
            userLocation = CLLocationCoordinate2D(latitude: stopLat - offsetLat, longitude: stopLon - offsetLat)
            print("   ⚠️ Location not available, using estimated position from stop")
        }
        
        testDualRouteCalculator(
            userLocation: userLocation,
            busOption: primaryBusOption,
            rerDepartures: rerDepartures
        )
        
        return EnhancedRecommendation(
            recommendationType: .bus,
            confidence: recommendation.confidence,
            primaryBusOption: primaryBusOption,
            alternativeBusOptions: alternativeBusOptions
        )
    }
    
    /// Create enhanced tie recommendation
    private func createEnhancedTieRecommendation(from recommendation: Recommendation) -> EnhancedRecommendation {
        // For tie, create both walk and bus details
        let walkDetails: WalkRecommendationDetails?
        let primaryBusOption: BusOptionTiming?
        
        // Extract RER departures once for all calculations
        let rerDepartures = extractRERDepartures(from: recommendation)
        
        if let _ = recommendation.walkETA, let currentLocation = locationService.currentLocation {
            let walkMinutes = rerEstimator.estimateWalkTimeToRER(from: currentLocation)
            let arrivalTime = Date().addingTimeInterval(TimeInterval(walkMinutes * 60))
            
            // Use real RER schedule if available
            let rerWaitMinutes: Int
            if !rerDepartures.isEmpty {
                rerWaitMinutes = rerEstimator.calculateRealRERWaitTime(arrivalTime: arrivalTime, rerDepartures: rerDepartures)
            } else {
                rerWaitMinutes = rerEstimator.estimateRERWaitTime(arrivalTime: arrivalTime)
            }
            
            walkDetails = WalkRecommendationDetails(
                walkToStationMinutes: walkMinutes,
                stationName: "Val de Fontenay RER",
                rerWaitMinutes: rerWaitMinutes
            )
        } else {
            walkDetails = nil
        }
        
        if let transitDetails = recommendation.transitDetails {
            let waitMinutes = max(0, transitDetails.minutesUntilDeparture - transitDetails.walkToStopMinutes)
            let (busRideMinutes, rerWaitMinutes) = rerEstimator.estimateTotalBusJourneyTime(
                lineName: transitDetails.lineName,
                departureTime: transitDetails.departureTime,
                walkToStopMinutes: transitDetails.walkToStopMinutes,
                destinationName: transitDetails.destinationName,
                rerDepartures: rerDepartures
            )
            
            primaryBusOption = BusOptionTiming(
                lineName: transitDetails.lineName,
                lineRef: transitDetails.lineRef,
                destinationName: transitDetails.destinationName,
                stopName: transitDetails.stopName,
                departureTime: transitDetails.departureTime,
                departureStatus: transitDetails.departureStatus,
                walkToStopMinutes: transitDetails.walkToStopMinutes,
                waitAtStopMinutes: waitMinutes,
                busRideMinutes: busRideMinutes,
                rerWaitMinutes: rerWaitMinutes
            )
        } else {
            primaryBusOption = nil
        }
        
        return EnhancedRecommendation(
            recommendationType: .tie,
            confidence: recommendation.confidence,
            walkDetails: walkDetails,
            primaryBusOption: primaryBusOption,
            alternativeBusOptions: extractAlternativeBusOptions(from: recommendation)
        )
    }
    
    /// Extract alternative bus options from recommendation
    private func extractAlternativeBusOptions(from recommendation: Recommendation) -> [BusOptionTiming] {
        var options: [BusOptionTiming] = []
        
        // Extract RER departures once for all options
        let rerDepartures = extractRERDepartures(from: recommendation)
        
        // Check alternative transit details
        if let altTransit = recommendation.alternativeTransitDetails {
            options.append(contentsOf: extractAlternativeBusOptionsFromTransit(transitDetails: altTransit, rerDepartures: rerDepartures))
        }
        
        // Check transit details upcoming departures
        if let transitDetails = recommendation.transitDetails {
            options.append(contentsOf: extractAlternativeBusOptionsFromTransit(transitDetails: transitDetails, rerDepartures: rerDepartures))
        }
        
        // CRITICAL: Limit to 3 alternative options to keep Live Activity payload under 4KB
        return Array(options.prefix(3))
    }
    
    /// Extract bus options from transit details
    private func extractAlternativeBusOptionsFromTransit(transitDetails: TransitDetails, rerDepartures: [(lineName: String, departureTime: Date)]) -> [BusOptionTiming] {
        var options: [BusOptionTiming] = []
        
        // Process upcoming departures for the same line
        for departure in transitDetails.upcomingDepartures where departure.isCatchable {
            let waitMinutes = departure.minutesUntilDeparture - transitDetails.walkToStopMinutes
            guard waitMinutes >= 0 else { continue }
            
            let (busRideMinutes, rerWaitMinutes) = rerEstimator.estimateTotalBusJourneyTime(
                lineName: transitDetails.lineName,
                departureTime: departure.departureTime,
                walkToStopMinutes: transitDetails.walkToStopMinutes,
                destinationName: transitDetails.destinationName,
                rerDepartures: rerDepartures
            )
            
            let option = BusOptionTiming(
                lineName: transitDetails.lineName,
                lineRef: transitDetails.lineRef,
                destinationName: transitDetails.destinationName,
                stopName: transitDetails.stopName,
                departureTime: departure.departureTime,
                departureStatus: departure.status,
                walkToStopMinutes: transitDetails.walkToStopMinutes,
                waitAtStopMinutes: waitMinutes,
                busRideMinutes: busRideMinutes,
                rerWaitMinutes: rerWaitMinutes
            )
            
            options.append(option)
        }
        
        // Process alternative lines at the same stop
        for altLine in transitDetails.alternativeLines where altLine.isCatchable {
            let waitMinutes = altLine.minutesUntilDeparture - transitDetails.walkToStopMinutes
            guard waitMinutes >= 0 else { continue }
            
            let (busRideMinutes, rerWaitMinutes) = rerEstimator.estimateTotalBusJourneyTime(
                lineName: altLine.lineNumber,
                departureTime: altLine.nextDepartureTime,
                walkToStopMinutes: transitDetails.walkToStopMinutes,
                destinationName: altLine.destination
            )
            
            let option = BusOptionTiming(
                lineName: altLine.lineNumber,
                lineRef: altLine.lineRef,
                destinationName: altLine.destination,
                stopName: transitDetails.stopName,
                departureTime: altLine.nextDepartureTime,
                departureStatus: altLine.departureStatus,
                walkToStopMinutes: transitDetails.walkToStopMinutes,
                waitAtStopMinutes: waitMinutes,
                busRideMinutes: busRideMinutes,
                rerWaitMinutes: rerWaitMinutes
            )
            
            options.append(option)
        }
        
        // Sort by total time
        return options.sorted { $0.totalMinutes < $1.totalMinutes }
    }
    
    /// Find next viable bus option in minutes
    private func findNextViableBusOption(from recommendation: Recommendation) -> Int? {
        if let altTransit = recommendation.alternativeTransitDetails {
            let timeUntilCatchable = altTransit.minutesUntilDeparture
            return timeUntilCatchable > 0 ? timeUntilCatchable : nil
        }
        
        return nil
    }
    
    // MARK: - 🧪 DualRouteCalculator Test
    
    /// Test DualRouteCalculator with real PRIM data
    private func testDualRouteCalculator(
        userLocation: CLLocationCoordinate2D,
        busOption: BusOptionTiming,
        rerDepartures: [(lineName: String, departureTime: Date)]
    ) {
        print("\n" + String(repeating: "=", count: 80))
        print("🧪 TESTING DUALROUTECALCULATOR WITH REAL DATA")
        print(String(repeating: "=", count: 80))
        
        let calculator = DualRouteCalculator()
        
        // Convert RER departures to RERDeparture structs
        let rerSchedule = rerDepartures.map { departure in
            RERDeparture(lineName: departure.lineName, departureTime: departure.departureTime)
        }
        
        // Assume Val de Fontenay RER station coordinates
        let rerStationCoord = CLLocationCoordinate2D(latitude: 48.85316, longitude: 2.48711)
        
        // Calculate walk route
        let walkWindow = calculator.calculateWalkRoute(
            from: userLocation,
            to: rerStationCoord,
            rerSchedule: rerSchedule
        )
        
        // Calculate bus route
        let busWindow = calculator.calculateBusRoute(
            busOption: busOption,
            rerSchedule: rerSchedule
        )
        
        // Compare routes
        let comparison = calculator.compareRoutes(
            walkWindow: walkWindow,
            busWindow: busWindow
        )
        
        // 🎨 PHASE 2: Visual Feedback Test
        print("\n" + String(repeating: "🎨", count: 10))
        print("PHASE 2: VISUAL FEEDBACK & SAFETY SYSTEM")
        print(String(repeating: "🎨", count: 10))
        
        // Display urgency and safety for both routes
        print("\n📊 Walk Route:")
        print("   Urgency: \(String(format: "%.2f", walkWindow.urgencyScore)) (0.0=relaxed → 1.0=rush)")
        print("   Safety: \(walkWindow.safetyStatus.emoji) \(walkWindow.safetyStatus.description)")
        print("   Buffer: \(walkWindow.bufferMinutes) minutes until RER departure")
        
        print("\n� Bus Route:")
        print("   Urgency: \(String(format: "%.2f", busWindow.urgencyScore)) (0.0=relaxed → 1.0=rush)")
        print("   Safety: \(busWindow.safetyStatus.emoji) \(busWindow.safetyStatus.description)")
        print("   Buffer: \(busWindow.bufferMinutes) minutes until bus departure")
        
        print("\n✅ Recommended: \(comparison.recommended == RouteType.walk ? "🚶 WALK" : "🚌 BUS")")
        print("   Urgency difference: \(String(format: "%.2f", comparison.urgencyDifference))")
        
        print("\n" + String(repeating: "=", count: 80))
        print("✅ DUALROUTECALCULATOR TEST COMPLETE")
        print(String(repeating: "=", count: 80) + "\n")
    }
}