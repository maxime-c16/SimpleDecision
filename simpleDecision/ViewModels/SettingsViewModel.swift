//
//  SettingsViewModel.swift
//  simpleDecision
//
//  Created by Transportation Recommendation System on 30/09/2025.
//

import Foundation
import SwiftUI
import Combine
import CoreLocation

/// View model for app settings and configuration
@MainActor
class SettingsViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var settings: AppSettings
    @Published var locationAuthorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isLocationAvailable = false
    @Published var isActivitySupported = false
    @Published var showingLocationAlert = false
    @Published var showingResetAlert = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    
    // Debug properties
    @Published var showingDebugInfo = false
    @Published var debugLocationText = ""
    
    // MARK: - Services
    private let settingsManager: AppSettingsManager
    private let locationService: LocationService
    private let backgroundScheduler: BackgroundScheduler
    private let activityManager: ActivityManager
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init(
        settingsManager: AppSettingsManager = AppSettingsManager(),
        locationService: LocationService = LocationService(),
        backgroundScheduler: BackgroundScheduler = BackgroundScheduler.shared,
        activityManager: ActivityManager = ActivityManager.shared
    ) {
        self.settingsManager = settingsManager
        self.locationService = locationService
        self.backgroundScheduler = backgroundScheduler
        self.activityManager = activityManager
        self.settings = settingsManager.settings
        
        setupBindings()
        loadInitialState()
    }
    
    // MARK: - Setup
    private func setupBindings() {
        // Monitor settings changes
        settingsManager.$settings
            .assign(to: \.settings, on: self)
            .store(in: &cancellables)
        
        // Monitor location authorization
        locationService.$authorizationStatus
            .assign(to: \.locationAuthorizationStatus, on: self)
            .store(in: &cancellables)
        
        // Monitor location availability
        locationService.$currentLocation
            .map { $0 != nil }
            .assign(to: \.isLocationAvailable, on: self)
            .store(in: &cancellables)
        
        // Monitor background scheduler errors
        backgroundScheduler.$backgroundError
            .compactMap { $0 }
            .sink { [weak self] error in
                self?.errorMessage = "Background: \(error)"
            }
            .store(in: &cancellables)
        
        // Monitor activity manager availability
        if #available(iOS 16.1, *) {
            activityManager.$isActivitySupported
                .assign(to: \.isActivitySupported, on: self)
                .store(in: &cancellables)
        }
    }
    
    private func loadInitialState() {
        if #available(iOS 16.1, *) {
            isActivitySupported = activityManager.isActivitySupported
        } else {
            isActivitySupported = false
        }
    }
    
    // MARK: - Settings Actions
    
    /// Toggle PRIM API enabled status
    func togglePRIMAPI() {
        settingsManager.updatePRIMEnabled(!settings.primAPIEnabled)
        
        if settings.primAPIEnabled {
            successMessage = "PRIM API enabled - real-time transit data active"
        } else {
            successMessage = "PRIM API disabled - using mock data"
        }
        
        clearMessagesAfterDelay()
    }
    
    /// Request location permission
    func requestLocationPermission() {
        locationService.requestLocationPermission()
        settingsManager.updateLocationPermissionRequested(true)
        showingLocationAlert = false
        
        successMessage = "Location permission requested"
        clearMessagesAfterDelay()
    }
    
    /// Open system settings for location permission
    func openLocationSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else {
            errorMessage = "Cannot open Settings app"
            return
        }
        
        UIApplication.shared.open(settingsURL)
        showingLocationAlert = false
    }
    
    /// Toggle debug controls
    func toggleDebugControls() {
        settingsManager.updateDebugControlsEnabled(!settings.enableDebugControls)
        
        if settings.enableDebugControls {
            successMessage = "Debug controls enabled"
        } else {
            successMessage = "Debug controls disabled"
            showingDebugInfo = false
        }
        
        clearMessagesAfterDelay()
    }
    
    /// Reset all settings to defaults
    func resetToDefaults() {
        settingsManager.resetToDefaults()
        showingResetAlert = false
        successMessage = "Settings reset to defaults"
        clearMessagesAfterDelay()
    }
    
    /// Show location permission alert
    func showLocationAlert() {
        showingLocationAlert = true
    }
    
    /// Show reset confirmation alert
    func showResetAlert() {
        showingResetAlert = true
    }
    
    /// Clear all error and success messages
    func clearMessages() {
        errorMessage = nil
        successMessage = nil
    }
    
    // MARK: - Debug Actions
    
    /// Toggle debug information display
    func toggleDebugInfo() {
        showingDebugInfo.toggle()
    }
    
    /// Set mock location for testing
    func setMockLocation() {
        guard !debugLocationText.isEmpty else {
            errorMessage = "Enter coordinates in format: lat,lng"
            return
        }
        
        let components = debugLocationText.split(separator: ",")
        guard components.count == 2,
              let lat = Double(components[0].trimmingCharacters(in: .whitespaces)),
              let lng = Double(components[1].trimmingCharacters(in: .whitespaces)) else {
            errorMessage = "Invalid coordinates format. Use: lat,lng"
            return
        }
        
        let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lng)
        locationService.setMockLocation(coordinate)
        
        successMessage = "Mock location set to \(lat), \(lng)"
        debugLocationText = ""
        clearMessagesAfterDelay()
    }
    
    /// Simulate background refresh for testing
    func simulateBackgroundRefresh() {
        backgroundScheduler.simulateBackgroundRefresh()
        successMessage = "Background refresh simulated"
        clearMessagesAfterDelay()
    }
    
    /// Initialize background tasks
    func initializeBackgroundTasks() {
        backgroundScheduler.initializeBackgroundTasks()
        successMessage = "Background tasks initialized"
        clearMessagesAfterDelay()
    }
    
    // MARK: - Computed Properties
    
    var locationStatusText: String {
        switch locationAuthorizationStatus {
        case .notDetermined:
            return "Not requested"
        case .denied, .restricted:
            return "Denied"
        case .authorizedWhenInUse:
            return "Authorized (when in use)"
        case .authorizedAlways:
            return "Authorized (always)"
        @unknown default:
            return "Unknown"
        }
    }
    
    var locationStatusColor: Color {
        switch locationAuthorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            return .green
        case .denied, .restricted:
            return .red
        case .notDetermined:
            return .orange
        @unknown default:
            return .gray
        }
    }
    
    var primAPIStatusText: String {
        if settings.primAPIEnabled {
            return settings.primAPIKeyConfigured ? "Active" : "Enabled (no key)"
        } else {
            return "Disabled"
        }
    }
    
    var primAPIStatusColor: Color {
        if settings.primAPIEnabled && settings.primAPIKeyConfigured {
            return .green
        } else if settings.primAPIEnabled {
            return .orange
        } else {
            return .gray
        }
    }
    
    var activityStatusText: String {
        if #available(iOS 16.1, *) {
            return isActivitySupported ? "Supported" : "Not supported"
        } else {
            return "iOS 16.1+ required"
        }
    }
    
    var activityStatusColor: Color {
        if #available(iOS 16.1, *) {
            return isActivitySupported ? .green : .red
        } else {
            return .gray
        }
    }
    
    var backgroundStatusText: String {
        return backgroundScheduler.isBackgroundRefreshEnabled ? "Available" : "Disabled in Settings"
    }
    
    var backgroundStatusColor: Color {
        return backgroundScheduler.isBackgroundRefreshEnabled ? .green : .red
    }
    
    var setupCompletionPercentage: Double {
        var completed = 0
        let total = 4
        
        if locationAuthorizationStatus.isAuthorized { completed += 1 }
        if settings.defaultDestination != nil { completed += 1 }
        if settings.primAPIEnabled { completed += 1 }
        if isActivitySupported { completed += 1 }
        
        return Double(completed) / Double(total)
    }
    
    var debugStatusText: String {
        var status = "Location: \(isLocationAvailable ? "Available" : "Not available")\n"
        status += "PRIM API: \(primAPIStatusText)\n"
        status += "Live Activities: \(activityStatusText)\n"
        status += "Background: \(backgroundStatusText)\n"
        
        if let lastRefresh = backgroundScheduler.lastBackgroundRefresh {
            let formatter = DateFormatter()
            formatter.timeStyle = .medium
            formatter.dateStyle = .short
            status += "Last Refresh: \(formatter.string(from: lastRefresh))"
        } else {
            status += "Last Refresh: Never"
        }
        
        return status
    }
    
    // MARK: - Private Methods
    
    private func clearMessagesAfterDelay() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.clearMessages()
        }
    }
}

// MARK: - Settings Sections for organized display
extension SettingsViewModel {
    enum SettingsSection: String, CaseIterable {
        case location = "Location Services"
        case api = "Data Sources"
        case features = "Features"
        case debug = "Debug"
        
        var systemImage: String {
            switch self {
            case .location:
                return "location"
            case .api:
                return "globe"
            case .features:
                return "star"
            case .debug:
                return "ladybug"
            }
        }
    }
}