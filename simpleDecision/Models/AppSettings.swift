//
//  AppSettings.swift
//  simpleDecision
//
//  Created by Transportation Recommendation System on 30/09/2025.
//

import Foundation
import CoreLocation
import Combine

/// User preferences and API configuration
struct AppSettings: Codable {
    var primAPIEnabled: Bool
    var primAPIKeyConfigured: Bool
    var locationPermissionRequested: Bool
    var defaultDestination: UUID?
    var lastKnownLocation: CLLocationCoordinate2D?
    let refreshIntervalSeconds: Int
    var enableDebugControls: Bool
    
    // User customization preferences
    var walkingSpeedMps: Double // Walking speed in meters per second
    var preferWalking: Bool // User prefers walking over transit
    var maxWalkingDistanceMeters: Double // Maximum distance willing to walk
    
    // Safety preferences
    var minimumAcceptableBuffer: Int // Minimum buffer time in minutes (default 2 min)
    
    // Transportation filtering preferences
    var transportationPreferences: TransportationPreferences
    
    /// Default settings for new installations
    static let defaultSettings = AppSettings(
        primAPIEnabled: false,                    // User must opt-in
        primAPIKeyConfigured: false,              // Set when API key is stored
        locationPermissionRequested: false,       // Set when permission requested
        defaultDestination: nil,                  // User must choose
        lastKnownLocation: nil,                   // Set after first location fix
        refreshIntervalSeconds: 30,               // 30-second refresh cycle
        enableDebugControls: true,                // Enable for development
        walkingSpeedMps: 1.4,                    // Average walking speed (5 km/h)
        preferWalking: false,                     // Balanced recommendation
        maxWalkingDistanceMeters: 2000,          // 2km max walking distance
        minimumAcceptableBuffer: 2,              // Minimum 2 min buffer for safety
        transportationPreferences: TransportationPreferences()  // Use defaults
    )
    
    /// Check if basic setup is complete
    var isSetupComplete: Bool {
        return defaultDestination != nil && locationPermissionRequested
    }
    
    /// Check if PRIM API is available for use
    var isPRIMAvailable: Bool {
        return primAPIEnabled && primAPIKeyConfigured
    }
    
    /// Refresh interval as TimeInterval
    var refreshInterval: TimeInterval {
        return TimeInterval(refreshIntervalSeconds)
    }
}

/// Settings persistence manager
class AppSettingsManager: ObservableObject {
    private let userDefaults = UserDefaults.standard
    private let settingsKey = "AppSettings"
    
    @Published var settings: AppSettings
    
    init() {
        // Load settings from UserDefaults or use defaults
        if let data = userDefaults.data(forKey: settingsKey),
           let savedSettings = try? JSONDecoder().decode(AppSettings.self, from: data) {
            self.settings = savedSettings
        } else {
            self.settings = AppSettings.defaultSettings
        }
    }
    
    /// Save current settings to UserDefaults
    func saveSettings() {
        if let data = try? JSONEncoder().encode(settings) {
            userDefaults.set(data, forKey: settingsKey)
        }
    }
    
    /// Update PRIM API enabled status
    func updatePRIMEnabled(_ enabled: Bool) {
        settings.primAPIEnabled = enabled
        saveSettings()
    }
    
    /// Update API key configured status
    func updateAPIKeyConfigured(_ configured: Bool) {
        settings.primAPIKeyConfigured = configured
        saveSettings()
    }
    
    /// Update location permission requested status
    func updateLocationPermissionRequested(_ requested: Bool) {
        settings.locationPermissionRequested = requested
        saveSettings()
    }
    
    /// Update default destination
    func updateDefaultDestination(_ destinationId: UUID?) {
        settings.defaultDestination = destinationId
        saveSettings()
    }
    
    /// Update last known location
    func updateLastKnownLocation(_ location: CLLocationCoordinate2D?) {
        settings.lastKnownLocation = location
        saveSettings()
    }
    
    /// Update debug controls enabled status
    func updateDebugControlsEnabled(_ enabled: Bool) {
        settings.enableDebugControls = enabled
        saveSettings()
    }
    
    /// Update walking speed preference
    func updateWalkingSpeed(_ speedMps: Double) {
        settings.walkingSpeedMps = max(0.5, min(speedMps, 3.0)) // Clamp between 0.5-3.0 m/s
        saveSettings()
    }
    
    /// Update walking preference
    func updatePreferWalking(_ prefer: Bool) {
        settings.preferWalking = prefer
        saveSettings()
    }
    
    /// Update maximum walking distance
    func updateMaxWalkingDistance(_ distanceMeters: Double) {
        settings.maxWalkingDistanceMeters = max(500, min(distanceMeters, 10000)) // Clamp 500m-10km
        saveSettings()
    }
    
    /// Update minimum acceptable buffer time
    func updateMinimumAcceptableBuffer(_ minutes: Int) {
        settings.minimumAcceptableBuffer = max(0, min(minutes, 15)) // Clamp 0-15 minutes
        saveSettings()
    }
    
    /// Reset all settings to defaults
    func resetToDefaults() {
        settings = AppSettings.defaultSettings
        saveSettings()
    }
}