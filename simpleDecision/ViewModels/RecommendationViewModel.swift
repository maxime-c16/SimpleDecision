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