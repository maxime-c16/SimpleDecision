//
//  MainViewModel.swift
//  simpleDecision
//
//  Created by Transportation Recommendation System on 30/09/2025.
//

import Foundation
import SwiftUI
import Combine
import CoreLocation

/// Main view model coordinating the transportation recommendation system
@MainActor
class MainViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var currentRecommendation: Recommendation?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedDestination: Destination?
    @Published var availableDestinations: [Destination] = []
    @Published var showingSettings = false
    @Published var showingDestinationPicker = false
    
    // MARK: - Services
    private let locationService: LocationService
    private let decisionEngine: DecisionEngine
    private let settingsManager: AppSettingsManager
    private let activityManager: ActivityManager
    private let backgroundScheduler: BackgroundScheduler
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private var refreshTimer: Timer?
    private let refreshInterval: TimeInterval = 30 // 30 seconds
    
    // MARK: - Initialization
    init(
        locationService: LocationService = LocationService(),
        settingsManager: AppSettingsManager = AppSettingsManager(),
        activityManager: ActivityManager = ActivityManager.shared,
        backgroundScheduler: BackgroundScheduler = BackgroundScheduler.shared
    ) {
        self.locationService = locationService
        self.settingsManager = settingsManager
        self.activityManager = activityManager
        self.backgroundScheduler = backgroundScheduler
        self.decisionEngine = DecisionEngine(locationService: locationService)
        
        setupBindings()
        loadInitialData()
    }
    
    // MARK: - Setup
    private func setupBindings() {
        // Monitor location service errors
        locationService.$locationError
            .compactMap { $0 }
            .sink { [weak self] error in
                self?.errorMessage = "Location Error: \(error)"
            }
            .store(in: &cancellables)
        
        // Monitor decision engine errors
        decisionEngine.$lastError
            .compactMap { $0 }
            .sink { [weak self] error in
                self?.errorMessage = "Decision Error: \(error)"
            }
            .store(in: &cancellables)
        
        // Monitor activity manager errors
        if #available(iOS 16.1, *) {
            activityManager.$activityError
                .compactMap { $0 }
                .sink { [weak self] error in
                    self?.errorMessage = "Activity Error: \(error)"
                }
                .store(in: &cancellables)
        }
        
        // Auto-refresh when location changes significantly
        locationService.$currentLocation
            .compactMap { $0 }
            .removeDuplicates { old, new in
                // Only refresh if moved more than 50 meters
                let oldLocation = CLLocation(latitude: old.latitude, longitude: old.longitude)
                let newLocation = CLLocation(latitude: new.latitude, longitude: new.longitude)
                return oldLocation.distance(from: newLocation) < 50
            }
            .debounce(for: .seconds(2), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                Task {
                    await self?.refreshRecommendation()
                }
            }
            .store(in: &cancellables)
    }
    
    private func loadInitialData() {
        // Load saved destinations
        availableDestinations = LocationData.mockDestinations
        
        // Set default destination if configured
        if let defaultDestinationId = settingsManager.settings.defaultDestination {
            selectedDestination = availableDestinations.first { $0.id == defaultDestinationId }
        }
        
        // Request location permission if not already done
        if !settingsManager.settings.locationPermissionRequested {
            requestLocationPermission()
        }
        
        // Start automatic refresh if we have a destination
        if selectedDestination != nil {
            startPeriodicRefresh()
        }
    }
    
    // MARK: - Public Methods
    
    /// Request location permission from user
    func requestLocationPermission() {
        locationService.requestLocationPermission()
        settingsManager.updateLocationPermissionRequested(true)
    }
    
    /// Manually refresh the transportation recommendation
    func refreshRecommendation() async {
        guard let destination = selectedDestination else {
            errorMessage = "Please select a destination first"
            return
        }
        
        guard locationService.hasValidLocation else {
            errorMessage = "Location not available. Please enable location services."
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let recommendation = try await decisionEngine
                .generateRecommendation(to: destination.coordinate, weather: getCurrentWeather())
                .async()
            
            currentRecommendation = recommendation
            
            // Start Live Activity if supported and enabled
            if #available(iOS 16.1, *), activityManager.canStartActivity {
                await activityManager.startActivity(with: recommendation, destination: destination.name)
            }
            
            // Update last known location in settings
            if let currentLocation = locationService.currentLocation {
                settingsManager.updateLastKnownLocation(currentLocation)
            }
            
        } catch {
            errorMessage = "Failed to generate recommendation: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    /// Select a destination and refresh recommendation
    func selectDestination(_ destination: Destination) {
        selectedDestination = destination
        settingsManager.updateDefaultDestination(destination.id)
        showingDestinationPicker = false
        
        Task {
            await refreshRecommendation()
        }
        
        startPeriodicRefresh()
    }
    
    /// Clear current recommendation and stop tracking
    func clearRecommendation() {
        currentRecommendation = nil
        stopPeriodicRefresh()
        
        if #available(iOS 16.1, *) {
            Task {
                await activityManager.endCurrentActivity()
            }
        }
    }
    
    /// Mark journey as completed
    func markJourneyCompleted() {
        if #available(iOS 16.1, *) {
            Task {
                await activityManager.markActivityCompleted(with: "Journey completed successfully!")
            }
        }
        
        clearRecommendation()
    }
    
    /// Show destination picker
    func showDestinationPicker() {
        showingDestinationPicker = true
    }
    
    /// Show settings screen
    func showSettings() {
        showingSettings = true
    }
    
    /// Clear any error messages
    func clearError() {
        errorMessage = nil
        locationService.clearError()
        decisionEngine.clearError()
        
        if #available(iOS 16.1, *) {
            activityManager.clearError()
        }
    }
    
    /// Force location update
    func updateLocation() {
        locationService.requestLocation()
    }
    
    // MARK: - Private Methods
    
    private func startPeriodicRefresh() {
        stopPeriodicRefresh()
        
        refreshTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            Task {
                await self?.refreshRecommendation()
            }
        }
    }
    
    private func stopPeriodicRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
    
    private func getCurrentWeather() -> String {
        // For development, return "clear"
        // In production, this would integrate with weather API
        return "clear"
    }
    
    // MARK: - Computed Properties
    
    var hasSelectedDestination: Bool {
        selectedDestination != nil
    }
    
    var canRefresh: Bool {
        !isLoading && hasSelectedDestination && locationService.hasValidLocation
    }
    
    var isSetupComplete: Bool {
        settingsManager.settings.isSetupComplete && hasSelectedDestination
    }
    
    var locationStatusText: String {
        switch locationService.authorizationStatus {
        case .notDetermined:
            return "Location permission not requested"
        case .denied, .restricted:
            return "Location permission denied"
        case .authorizedWhenInUse, .authorizedAlways:
            if locationService.currentLocation != nil {
                return "Location available"
            } else {
                return "Getting location..."
            }
        @unknown default:
            return "Unknown location status"
        }
    }
    
    var destinationStatusText: String {
        if let destination = selectedDestination {
            if let currentLocation = locationService.currentLocation {
                let distance = locationService.formattedDistance(to: destination.coordinate)
                return "\(destination.name) (\(distance))"
            } else {
                return destination.name
            }
        } else {
            return "No destination selected"
        }
    }
    
    deinit {
        stopPeriodicRefresh()
    }
}

// MARK: - Publisher Extension for async/await conversion
extension Publisher {
    func async() async throws -> Output {
        try await withCheckedThrowingContinuation { continuation in
            var cancellable: AnyCancellable?
            cancellable = first()
                .sink(
                    receiveCompletion: { completion in
                        switch completion {
                        case .finished:
                            break
                        case .failure(let error):
                            continuation.resume(throwing: error)
                        }
                        cancellable?.cancel()
                    },
                    receiveValue: { value in
                        continuation.resume(returning: value)
                        cancellable?.cancel()
                    }
                )
        }
    }
}