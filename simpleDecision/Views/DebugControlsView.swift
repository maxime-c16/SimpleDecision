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
    
    private let activityManager = ActivityManagerFactory.createActivityManager()
    
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()
    
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
            
            // Destination Testing
            destinationTestSection
            
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
    
    private var destinationTestSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            debugSectionHeader("Destination Testing", icon: "map.fill")
            
            VStack(spacing: 8) {
                Text("Test different walk/bus times")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                // Pre-configured test destinations with known ETAs
                VStack(spacing: 6) {
                    destinationTestButton(
                        title: "Close (Walk wins)",
                        subtitle: "Walk: 8min, Bus: 15min",
                        lat: 48.8614,
                        lon: 2.4750
                    )
                    
                    destinationTestButton(
                        title: "Medium (Bus wins)",
                        subtitle: "Walk: 25min, Bus: 12min",
                        lat: 48.8450,
                        lon: 2.3700
                    )
                    
                    destinationTestButton(
                        title: "Far (Bus wins big)",
                        subtitle: "Walk: 45min, Bus: 18min",
                        lat: 48.8566,
                        lon: 2.3522
                    )
                    
                    destinationTestButton(
                        title: "Tie Scenario",
                        subtitle: "Walk: 15min, Bus: 15min",
                        lat: 48.8580,
                        lon: 2.4100
                    )
                }
            }
        }
    }
    
    private func destinationTestButton(title: String, subtitle: String, lat: Double, lon: Double) -> some View {
        Button {
            setTestDestination(lat: lat, lon: lon, name: title)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(Color.purple.opacity(0.15))
            .cornerRadius(8)
        }
    }
    
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
                    .disabled(!activityManager.hasActiveActivities())
                    
                    // End activity
                    Button("End") {
                        endTestActivity()
                    }
                    .buttonStyle(.bordered)
                    .font(.caption)
                    .disabled(!activityManager.hasActiveActivities())
                }
                
                // Activity status
                HStack {
                    Text("Status:")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    if activityManager.hasActiveActivities() {
                        Text("Active")
                            .font(.caption2)
                            .foregroundColor(.green)
                    } else {
                        Text("None")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    Text("Supported: \(activityManager.isActivitySupported() ? "Yes" : "No")")
                        .font(.caption2)
                        .foregroundColor(activityManager.isActivitySupported() ? .green : .red)
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
                        Text("Last: \(Self.timeFormatter.string(from: lastRefresh))")
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
                systemInfoRow("Location Auth", value: "\(locationService.authorizationStatus)")
                
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
    
    private func setTestDestination(lat: Double, lon: Double, name: String) {
        // Store test destination in UserDefaults for the app to use
        let testDest = [
            "latitude": lat,
            "longitude": lon,
            "name": name
        ] as [String : Any]
        
        UserDefaults.standard.set(testDest, forKey: "debugTestDestination")
        
        print("🎯 DEBUG: Set test destination: \(name)")
        print("   Coordinates: \(lat), \(lon)")
        print("   App will use this on next recommendation update")
        
        // Trigger a notification to refresh the recommendation
        NotificationCenter.default.post(name: NSNotification.Name("RefreshRecommendation"), object: nil)
    }
    
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
                destinationName: "Test Destination",
                startLocationName: "Current Location",
                recommendation: testRecommendation
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
            await activityManager.endAllActivities()
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
                mode: .walk,
                walkETA: 12,
                busETA: nil,
                confidence: 0.9,
                timestamp: Date(),
                source: .mock
            )
        case .transit:
            return Recommendation(
                mode: .bus,
                walkETA: nil,
                busETA: 18,
                confidence: 0.8,
                timestamp: Date(),
                source: .primAPI
            )
        case .bicycle:
            return Recommendation(
                mode: .walk,
                walkETA: 8,
                busETA: nil,
                confidence: 0.75,
                timestamp: Date(),
                source: .localHeuristics
            )
        case .car:
            return Recommendation(
                mode: .bus,
                walkETA: nil,
                busETA: 15,
                confidence: 0.6,
                timestamp: Date(),
                source: .localHeuristics
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