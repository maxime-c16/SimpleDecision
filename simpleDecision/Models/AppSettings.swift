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
    let primAPIEnabled: Bool
    let primAPIKeyConfigured: Bool
    let locationPermissionRequested: Bool
    let defaultDestination: UUID?
    let lastKnownLocation: CLLocationCoordinate2D?
    let refreshIntervalSeconds: Int
    var enableDebugControls: Bool
    
    /// Default settings for new installations
    static let defaultSettings = AppSettings(
        primAPIEnabled: false,                    // User must opt-in
        primAPIKeyConfigured: false,              // Set when API key is stored
        locationPermissionRequested: false,       // Set when permission requested
        defaultDestination: nil,                  // User must choose
        lastKnownLocation: nil,                   // Set after first location fix
        refreshIntervalSeconds: 30,               // 30-second refresh cycle
        enableDebugControls: true                 // Enable for development
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
        settings = AppSettings(
            primAPIEnabled: enabled,
            primAPIKeyConfigured: settings.primAPIKeyConfigured,
            locationPermissionRequested: settings.locationPermissionRequested,
            defaultDestination: settings.defaultDestination,
            lastKnownLocation: settings.lastKnownLocation,
            refreshIntervalSeconds: settings.refreshIntervalSeconds,
            enableDebugControls: settings.enableDebugControls
        )
        saveSettings()
    }
    
    /// Update API key configured status
    func updateAPIKeyConfigured(_ configured: Bool) {
        settings = AppSettings(
            primAPIEnabled: settings.primAPIEnabled,
            primAPIKeyConfigured: configured,
            locationPermissionRequested: settings.locationPermissionRequested,
            defaultDestination: settings.defaultDestination,
            lastKnownLocation: settings.lastKnownLocation,
            refreshIntervalSeconds: settings.refreshIntervalSeconds,
            enableDebugControls: settings.enableDebugControls
        )
        saveSettings()
    }
    
    /// Update location permission requested status
    func updateLocationPermissionRequested(_ requested: Bool) {
        settings = AppSettings(
            primAPIEnabled: settings.primAPIEnabled,
            primAPIKeyConfigured: settings.primAPIKeyConfigured,
            locationPermissionRequested: requested,
            defaultDestination: settings.defaultDestination,
            lastKnownLocation: settings.lastKnownLocation,
            refreshIntervalSeconds: settings.refreshIntervalSeconds,
            enableDebugControls: settings.enableDebugControls
        )
        saveSettings()
    }
    
    /// Update default destination
    func updateDefaultDestination(_ destinationId: UUID?) {
        settings = AppSettings(
            primAPIEnabled: settings.primAPIEnabled,
            primAPIKeyConfigured: settings.primAPIKeyConfigured,
            locationPermissionRequested: settings.locationPermissionRequested,
            defaultDestination: destinationId,
            lastKnownLocation: settings.lastKnownLocation,
            refreshIntervalSeconds: settings.refreshIntervalSeconds,
            enableDebugControls: settings.enableDebugControls
        )
        saveSettings()
    }
    
    /// Update last known location
    func updateLastKnownLocation(_ location: CLLocationCoordinate2D?) {
        settings = AppSettings(
            primAPIEnabled: settings.primAPIEnabled,
            primAPIKeyConfigured: settings.primAPIKeyConfigured,
            locationPermissionRequested: settings.locationPermissionRequested,
            defaultDestination: settings.defaultDestination,
            lastKnownLocation: location,
            refreshIntervalSeconds: settings.refreshIntervalSeconds,
            enableDebugControls: settings.enableDebugControls
        )
        saveSettings()
    }
    
    /// Update debug controls enabled status
    func updateDebugControlsEnabled(_ enabled: Bool) {
        settings = AppSettings(
            primAPIEnabled: settings.primAPIEnabled,
            primAPIKeyConfigured: settings.primAPIKeyConfigured,
            locationPermissionRequested: settings.locationPermissionRequested,
            defaultDestination: settings.defaultDestination,
            lastKnownLocation: settings.lastKnownLocation,
            refreshIntervalSeconds: settings.refreshIntervalSeconds,
            enableDebugControls: enabled
        )
        saveSettings()
    }
    
    /// Reset all settings to defaults
    func resetToDefaults() {
        settings = AppSettings.defaultSettings
        saveSettings()
    }
}