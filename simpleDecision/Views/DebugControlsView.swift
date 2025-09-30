//
//  DebugControlsView.swift
//  simpleDecision
//
//  Created by Transportation Recommendation System on 30/09/2025.
//

import SwiftUI
import CoreLocation

/// Debug controls for testing Live Activities and development features
struct DebugControlsView: View {
    @StateObject private var locationService = LocationService()
    @StateObject private var settingsManager = AppSettingsManager()
    @StateObject private var backgroundScheduler = BackgroundScheduler.shared
    
    @State private var mockLocationText = ""
    @State private var showingMockAlert = false
    @State private var selectedMockLocation = MockLocation.chatelet
    @State private var activityTestMode = ActivityTestMode.walking
    @State private var showingActivityControls = false
    
    private let activityManager = ActivityManager.shared
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Image(systemName: "ladybug")
                    .foregroundColor(.orange)
                Text("Debug Controls")
                    .font(.headline)
                Spacer()
            }
            
            // Location Controls
            locationControlsSection
            
            // Live Activities Controls
            if #available(iOS 16.1, *) {
                liveActivitiesSection
            }
            
            // Background Controls
            backgroundControlsSection
            
            // System Info
            systemInfoSection
        }
        .padding()
        .background(.regularMaterial)
        .cornerRadius(12)
        .alert("Set Mock Location", isPresented: $showingMockAlert) {
            TextField("lat,lng", text: $mockLocationText)
            Button("Set") { setCustomMockLocation() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Enter coordinates in format: latitude,longitude")
        }
    }
    
    // MARK: - View Sections
    
    private var locationControlsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            debugSectionHeader("Location", icon: "location")
            
            VStack(spacing: 8) {
                // Quick location presets
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                    ForEach(MockLocation.allCases, id: \.self) { location in
                        Button(location.displayName) {
                            setMockLocation(location)
                        }
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(6)
                    }
                }
                
                // Custom location input
                Button("Custom Location...") {
                    showingMockAlert = true
                }
                .font(.caption)
                .foregroundColor(.orange)
            }
            
            // Current location status
            if let currentLocation = locationService.currentLocation {
                Text("📍 \(String(format: "%.4f", currentLocation.latitude)), \(String(format: "%.4f", currentLocation.longitude))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    @available(iOS 16.1, *)
    private var liveActivitiesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            debugSectionHeader("Live Activities", icon: "bell.badge")
            
            VStack(spacing: 8) {
                // Activity test mode selector
                Picker("Test Mode", selection: $activityTestMode) {
                    ForEach(ActivityTestMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .font(.caption)
                
                HStack(spacing: 8) {
                    // Start test activity
                    Button("Start Activity") {
                        startTestActivity()
                    }
                    .buttonStyle(.bordered)
                    .font(.caption)
                    .disabled(!activityManager.canStartActivity)
                    
                    // Update activity
                    Button("Update") {
                        updateTestActivity()
                    }
                    .buttonStyle(.bordered)
                    .font(.caption)
                    .disabled(activityManager.currentActivity == nil)
                    
                    // End activity
                    Button("End") {
                        endTestActivity()
                    }
                    .buttonStyle(.bordered)
                    .font(.caption)
                    .disabled(activityManager.currentActivity == nil)
                }
                
                // Activity status
                HStack {
                    Text("Status:")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    if activityManager.currentActivity != nil {
                        Text("Active")
                            .font(.caption2)
                            .foregroundColor(.green)
                    } else {
                        Text("None")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    Text("Supported: \(activityManager.isActivitySupported ? "Yes" : "No")")
                        .font(.caption2)
                        .foregroundColor(activityManager.isActivitySupported ? .green : .red)
                }
            }
        }
    }
    
    private var backgroundControlsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            debugSectionHeader("Background Tasks", icon: "arrow.clockwise")
            
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Button("Simulate Refresh") {
                        backgroundScheduler.simulateBackgroundRefresh()
                    }
                    .buttonStyle(.bordered)
                    .font(.caption)
                    
                    Button("Initialize Tasks") {
                        backgroundScheduler.initializeBackgroundTasks()
                    }
                    .buttonStyle(.bordered)
                    .font(.caption)
                }
                
                // Background status
                VStack(alignment: .leading, spacing: 4) {
                    Text("Enabled: \(backgroundScheduler.isBackgroundRefreshEnabled ? "Yes" : "No")")
                        .font(.caption2)
                        .foregroundColor(backgroundScheduler.isBackgroundRefreshEnabled ? .green : .red)
                    
                    if let lastRefresh = backgroundScheduler.lastBackgroundRefresh {
                        let formatter = DateFormatter()
                        formatter.timeStyle = .short
                        Text("Last: \(formatter.string(from: lastRefresh))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Last: Never")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    private var systemInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            debugSectionHeader("System Info", icon: "info.circle")
            
            VStack(alignment: .leading, spacing: 4) {
                systemInfoRow("iOS Version", value: UIDevice.current.systemVersion)
                systemInfoRow("Device", value: UIDevice.current.model)
                systemInfoRow("PRIM API", value: settingsManager.settings.primAPIEnabled ? "Enabled" : "Disabled")
                systemInfoRow("Location Auth", value: locationService.authorizationStatus.debugDescription)
                
                if #available(iOS 16.1, *) {
                    systemInfoRow("ActivityKit", value: "Available")
                } else {
                    systemInfoRow("ActivityKit", value: "iOS 16.1+ Required")
                }
            }
        }
    }
    
    private func debugSectionHeader(_ title: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.blue)
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
            Spacer()
        }
    }
    
    private func systemInfoRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label + ":")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.caption2)
                .fontWeight(.medium)
        }
    }
    
    // MARK: - Actions
    
    private func setMockLocation(_ mockLocation: MockLocation) {
        locationService.setMockLocation(mockLocation.coordinate)
    }
    
    private func setCustomMockLocation() {
        let components = mockLocationText.split(separator: ",")
        guard components.count == 2,
              let lat = Double(components[0].trimmingCharacters(in: .whitespaces)),
              let lng = Double(components[1].trimmingCharacters(in: .whitespaces)) else {
            return
        }
        
        let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lng)
        locationService.setMockLocation(coordinate)
        mockLocationText = ""
    }
    
    @available(iOS 16.1, *)
    private func startTestActivity() {
        let testRecommendation = activityTestMode.mockRecommendation
        Task {
            await activityManager.startActivity(
                with: testRecommendation,
                destination: "Test Destination"
            )
        }
    }
    
    @available(iOS 16.1, *)
    private func updateTestActivity() {
        let updatedRecommendation = activityTestMode.mockRecommendation
        Task {
            await activityManager.updateActivity(with: updatedRecommendation)
        }
    }
    
    @available(iOS 16.1, *)
    private func endTestActivity() {
        Task {
            await activityManager.endCurrentActivity()
        }
    }
}

// MARK: - Supporting Types

enum MockLocation: String, CaseIterable {
    case chatelet = "Châtelet"
    case republique = "République"
    case bastille = "Bastille"
    case montparnasse = "Montparnasse"
    case defense = "La Défense"
    case cdg = "CDG Airport"
    
    var displayName: String {
        return rawValue
    }
    
    var coordinate: CLLocationCoordinate2D {
        switch self {
        case .chatelet:
            return CLLocationCoordinate2D(latitude: 48.8606, longitude: 2.3472)
        case .republique:
            return CLLocationCoordinate2D(latitude: 48.8676, longitude: 2.3632)
        case .bastille:
            return CLLocationCoordinate2D(latitude: 48.8532, longitude: 2.3694)
        case .montparnasse:
            return CLLocationCoordinate2D(latitude: 48.8424, longitude: 2.3195)
        case .defense:
            return CLLocationCoordinate2D(latitude: 48.8915, longitude: 2.2388)
        case .cdg:
            return CLLocationCoordinate2D(latitude: 49.0097, longitude: 2.5479)
        }
    }
}

enum ActivityTestMode: String, CaseIterable {
    case walking = "Walking"
    case transit = "Transit"
    case bicycle = "Bicycle"
    case car = "Car"
    
    var displayName: String {
        return rawValue
    }
    
    var mockRecommendation: Recommendation {
        switch self {
        case .walking:
            return Recommendation(
                id: UUID(),
                transportationMode: .walking,
                estimatedTimeMinutes: 12,
                confidence: 0.9,
                reasoning: "Debug walking test",
                source: .manual,
                timestamp: Date(),
                weatherCondition: "clear"
            )
        case .transit:
            return Recommendation(
                id: UUID(),
                transportationMode: .publicTransit,
                estimatedTimeMinutes: 18,
                confidence: 0.8,
                reasoning: "Debug transit test - Line 1",
                source: .primAPI,
                timestamp: Date(),
                weatherCondition: "clear"
            )
        case .bicycle:
            return Recommendation(
                id: UUID(),
                transportationMode: .bicycle,
                estimatedTimeMinutes: 8,
                confidence: 0.75,
                reasoning: "Debug bicycle test",
                source: .algorithm,
                timestamp: Date(),
                weatherCondition: "clear"
            )
        case .car:
            return Recommendation(
                id: UUID(),
                transportationMode: .car,
                estimatedTimeMinutes: 15,
                confidence: 0.6,
                reasoning: "Debug car test with traffic",
                source: .algorithm,
                timestamp: Date(),
                weatherCondition: "clear"
            )
        }
    }
}

// MARK: - Preview

struct DebugControlsView_Previews: PreviewProvider {
    static var previews: some View {
        DebugControlsView()
            .padding()
            .previewLayout(.sizeThatFits)
    }
}