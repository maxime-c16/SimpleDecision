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
    @Published var errorType: MainViewModelError.ErrorType = .none
    @Published var showingErrorAlert = false
    @Published var selectedDestination: Destination?
    @Published var availableDestinations: [Destination] = []
    @Published var showingSettings = false
    @Published var showingDestinationPicker = false
    
    // MARK: - Services
    private let locationService: LocationService
    private let decisionEngine: DecisionEngine
    private let settingsManager: AppSettingsManager
    private let activityManager: ActivityManagerProtocol
    private let backgroundScheduler: BackgroundScheduler
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private var refreshTimer: Timer?
    private let refreshInterval: TimeInterval = 30 // 30 seconds
    
    // MARK: - Initialization
    @MainActor
    init(
        locationService: LocationService,
        settingsManager: AppSettingsManager,
        activityManager: ActivityManagerProtocol,
        backgroundScheduler: BackgroundScheduler
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
            .map { errorString -> Error in
                // Create a generic error from the string
                NSError(domain: "LocationService", code: 0, userInfo: [NSLocalizedDescriptionKey: errorString])
            }
            .sink { [weak self] error in
                self?.handleError(error)
            }
            .store(in: &cancellables)
        
        // Monitor decision engine errors
        decisionEngine.$lastError
            .compactMap { $0 }
            .map { errorString -> Error in
                // Create a generic error from the string
                NSError(domain: "DecisionEngine", code: 0, userInfo: [NSLocalizedDescriptionKey: errorString])
            }
            .sink { [weak self] error in
                self?.handleError(error)
            }
            .store(in: &cancellables)
        
        // Monitor activity manager errors (for LiveActivityManager)
        if #available(iOS 16.1, *), let liveActivityManager = activityManager as? LiveActivityManager {
            liveActivityManager.$activityError
                .compactMap { $0 }
                .sink { [weak self] errorString in
                    // Create a generic error from the string
                    let error = NSError(domain: "ActivityManager", code: 0, userInfo: [NSLocalizedDescriptionKey: errorString])
                    self?.handleError(error)
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
        
        // Listen for debug refresh requests
        NotificationCenter.default.publisher(for: NSNotification.Name("RefreshRecommendation"))
            .sink { [weak self] _ in
                Task {
                    await self?.fetchRecommendation()
                }
            }
            .store(in: &cancellables)
    }
    
    private func loadInitialData() {
        // Load saved destinations from UserDefaults
        loadSavedDestinations()
        
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
    
    private func loadSavedDestinations() {
        if let savedData = UserDefaults.standard.data(forKey: "savedDestinations"),
           let savedDestinations = try? JSONDecoder().decode([Destination].self, from: savedData) {
            availableDestinations = savedDestinations
        } else {
            // First launch - start with empty destinations
            availableDestinations = []
        }
    }
    
    func saveDestinations() {
        if let encoded = try? JSONEncoder().encode(availableDestinations) {
            UserDefaults.standard.set(encoded, forKey: "savedDestinations")
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
        await fetchRecommendation()
    }
    
    /// Fetch new recommendation based on current destination
    func fetchRecommendation() async {
        // Check for debug test destination first
        var destinationCoordinate: CLLocationCoordinate2D?
        var destinationName = "Unknown"
        
        #if DEBUG
        if let testDest = UserDefaults.standard.dictionary(forKey: "debugTestDestination"),
           let lat = testDest["latitude"] as? Double,
           let lon = testDest["longitude"] as? Double,
           let name = testDest["name"] as? String {
            destinationCoordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            destinationName = name
            print("🎯 DEBUG: Using test destination: \(name) at \(lat), \(lon)")
        }
        #endif
        
        // Fall back to selected destination if no test destination
        if destinationCoordinate == nil {
            guard let destination = selectedDestination else {
                let error = NSError(domain: "MainViewModel", code: 1001, 
                                   userInfo: [NSLocalizedDescriptionKey: "No destination selected"])
                handleError(error)
                return
            }
            destinationCoordinate = destination.coordinate
            destinationName = destination.name
        }
        
        guard let finalDestination = destinationCoordinate else {
            let error = NSError(domain: "MainViewModel", code: 1001, 
                               userInfo: [NSLocalizedDescriptionKey: "No destination available"])
            handleError(error)
            return
        }
        
        guard locationService.hasValidLocation else {
            let error = NSError(domain: "MainViewModel", code: 1002, 
                               userInfo: [NSLocalizedDescriptionKey: "Location not available"])
            handleError(error)
            return
        }
        
        isLoading = true
        clearError()
        
        do {
            let recommendation = try await decisionEngine
                .generateRecommendation(to: finalDestination, weather: getCurrentWeather())
                .async()
            
            currentRecommendation = recommendation
            
            // Start or update Live Activity if supported and enabled
            if activityManager.isActivitySupported() {
                if activityManager.hasActiveActivities() {
                    // Update existing activity
                    _ = await activityManager.updateActivity(with: recommendation)
                } else {
                    // Start new activity
                    let startLocationName = "Current Location" // Could be enhanced with reverse geocoding
                    let success = await activityManager.startActivity(
                        destinationName: destinationName,
                        startLocationName: startLocationName,
                        recommendation: recommendation
                    )
                    if !success {
                        print("Failed to start Live Activity")
                    }
                }
            }
            
            // Update last known location in settings
            if let currentLocation = locationService.currentLocation {
                settingsManager.updateLastKnownLocation(currentLocation)
            }
            
        } catch {
            handleError(error)
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
        
        Task {
            await activityManager.endAllActivities()
        }
    }
    
    /// Mark journey as completed
    func markJourneyCompleted() {
        Task {
            if let liveActivityManager = activityManager as? LiveActivityManager {
                await liveActivityManager.markActivityCompleted(with: "Journey completed successfully!")
            } else {
                await activityManager.endAllActivities()
            }
        }
        
        // Clear recommendation after a brief delay to allow completion message
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.currentRecommendation = nil
            self.stopPeriodicRefresh()
        }
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
        errorType = .none
        showingErrorAlert = false
        locationService.clearError()
        decisionEngine.clearError()
        
        // Clear activity manager errors if supported
        if let liveActivityManager = activityManager as? LiveActivityManager {
            liveActivityManager.clearError()
        }
    }
    
    /// Handle errors with user-friendly messages and recovery options
    private func handleError(_ error: Error) {
        let processedError = MainViewModelError.create(from: error)
        
        DispatchQueue.main.async {
            self.errorMessage = processedError.userMessage
            self.errorType = processedError.type
            self.showingErrorAlert = true
            self.isLoading = false
        }
        
        // Log the technical error for debugging
        print("MainViewModel Error - Type: \(processedError.type), Technical: '\(processedError.message)', User: '\(processedError.userMessage)'")
    }
    
    /// Retry the last operation based on error type
    func retryLastOperation() {
        clearError()
        
        switch errorType {
        case .location, .permissions:
            requestLocationPermission()
            updateLocation()
        case .network, .service, .timeout:
            Task {
                await refreshRecommendation()
            }
        case .data:
            // For data errors, try to refresh destinations and clear current state
            loadInitialData()
            clearRecommendation()
        default:
            // Generic retry - refresh recommendation
            Task {
                await refreshRecommendation()
            }
        }
    }
    
    /// Get user-friendly error message with suggested action
    var errorMessageWithAction: String {
        guard let message = errorMessage else { return "" }
        
        let processedError = MainViewModelError.create(from: NSError(domain: "Generic", code: 0, userInfo: [NSLocalizedDescriptionKey: message]))
        
        if let action = processedError.suggestedAction {
            return "\(message)\n\n\(action)"
        }
        
        return message
    }
    
    /// Check if current error can be retried
    var canRetryCurrentError: Bool {
        switch errorType {
        case .none:
            return false
        case .data:
            return false // Data errors usually need different action
        default:
            return true
        }
    }
    
    /// Force location update
    func updateLocation() {
        locationService.requestLocation()
    }
    
    // MARK: - Live Activity Management
    
    /// Start Live Activity manually (for debug/testing)
    func startLiveActivity() async {
        guard let recommendation = currentRecommendation,
              let destination = selectedDestination else {
            errorMessage = "Need active recommendation and destination to start Live Activity"
            return
        }
        
        let success = await activityManager.startActivity(
            destinationName: destination.name,
            startLocationName: "Current Location",
            recommendation: recommendation
        )
        
        if !success {
            errorMessage = "Failed to start Live Activity"
        }
    }
    
    /// End Live Activity manually
    func endLiveActivity() async {
        _ = await activityManager.endAllActivities()
    }
    
    /// Check if Live Activities are supported
    var isLiveActivitySupported: Bool {
        return activityManager.isActivitySupported()
    }
    
    /// Check if there are active Live Activities
    var hasActiveLiveActivity: Bool {
        return activityManager.hasActiveActivities()
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
            if locationService.currentLocation != nil {
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
        // Clean up any resources synchronously
        // Note: Cannot use Task in deinit as it may outlive the object
        refreshTimer?.invalidate()
    }
}

// MARK: - Error Handling

struct MainViewModelError {
    enum ErrorType: Equatable {
        case none
        case location
        case permissions
        case network
        case service
        case data
        case timeout
        case unknown
        
        var icon: String {
            switch self {
            case .none: return ""
            case .location: return "location.slash"
            case .permissions: return "exclamationmark.shield"
            case .network: return "wifi.slash"
            case .service: return "server.rack"
            case .data: return "exclamationmark.triangle"
            case .timeout: return "clock.badge.exclamationmark"
            case .unknown: return "questionmark.circle"
            }
        }
        
        var color: Color {
            switch self {
            case .none: return .clear
            case .location: return .orange
            case .permissions: return .red
            case .network: return .blue
            case .service: return .purple
            case .data: return .yellow
            case .timeout: return .orange
            case .unknown: return .gray
            }
        }
    }
    
    let type: ErrorType
    let message: String
    let userMessage: String
    let canRetry: Bool
    let suggestedAction: String?
    
    static func create(from error: Error) -> MainViewModelError {
        let errorString = error.localizedDescription.lowercased()
        
        // Location-related errors
        if errorString.contains("location") || errorString.contains("coordinate") {
            if errorString.contains("permission") || errorString.contains("denied") {
                return MainViewModelError(
                    type: .permissions,
                    message: error.localizedDescription,
                    userMessage: "Location access is required to provide transportation recommendations.",
                    canRetry: true,
                    suggestedAction: "Please enable location services in Settings"
                )
            } else if errorString.contains("not available") || errorString.contains("unavailable") {
                return MainViewModelError(
                    type: .location,
                    message: error.localizedDescription,
                    userMessage: "Unable to determine your current location.",
                    canRetry: true,
                    suggestedAction: "Try moving to an area with better GPS signal"
                )
            }
        }
        
        // Network-related errors
        if errorString.contains("network") || errorString.contains("internet") || 
           errorString.contains("connection") || errorString.contains("offline") {
            return MainViewModelError(
                type: .network,
                message: error.localizedDescription,
                userMessage: "No internet connection available.",
                canRetry: true,
                suggestedAction: "Check your internet connection and try again"
            )
        }
        
        // Timeout errors
        if errorString.contains("timeout") || errorString.contains("timed out") {
            return MainViewModelError(
                type: .timeout,
                message: error.localizedDescription,
                userMessage: "Request took too long to complete.",
                canRetry: true,
                suggestedAction: "The service may be busy. Please try again in a moment"
            )
        }
        
        // Service/API errors
        if errorString.contains("api") || errorString.contains("service") || 
           errorString.contains("server") || errorString.contains("invalid response") {
            return MainViewModelError(
                type: .service,
                message: error.localizedDescription,
                userMessage: "Transportation service is temporarily unavailable.",
                canRetry: true,
                suggestedAction: "Please try again in a few minutes"
            )
        }
        
        // Data validation errors
        if errorString.contains("invalid") || errorString.contains("validation") ||
           errorString.contains("data") {
            return MainViewModelError(
                type: .data,
                message: error.localizedDescription,
                userMessage: "Invalid data encountered.",
                canRetry: false,
                suggestedAction: "Please select a different destination or restart the app"
            )
        }
        
        // Default unknown error
        return MainViewModelError(
            type: .unknown,
            message: error.localizedDescription,
            userMessage: "An unexpected error occurred.",
            canRetry: true,
            suggestedAction: "Please try again or restart the app if the problem persists"
        )
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