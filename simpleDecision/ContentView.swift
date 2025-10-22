//
//  ContentView.swift
//  simpleDecision
//
//  Created by Tristan Aranda  on 30/09/2025.
//

import SwiftUI
import CoreLocation

struct ContentView: View {
    @StateObject private var mainViewModel: MainViewModel
    @StateObject private var destinationViewModel: DestinationViewModel
    @StateObject private var settingsViewModel: SettingsViewModel
    @State private var showingFullDebugControls = false
    
    init() {
        let locationService = LocationService()
        let settingsManager = AppSettingsManager()
        let backgroundScheduler = BackgroundScheduler.shared
        let activityManager = ActivityManagerFactory.createActivityManager()
        
        _mainViewModel = StateObject(wrappedValue: MainViewModel(
            locationService: locationService,
            settingsManager: settingsManager,
            activityManager: activityManager,
            backgroundScheduler: backgroundScheduler
        ))
        
        _destinationViewModel = StateObject(wrappedValue: DestinationViewModel(
            locationService: locationService,
            settingsManager: settingsManager
        ))
        
        _settingsViewModel = StateObject(wrappedValue: SettingsViewModel(
            settingsManager: settingsManager,
            locationService: locationService,
            backgroundScheduler: backgroundScheduler,
            activityManager: activityManager
        ))
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header Section
                    headerSection
                    
                    // Status Section
                    statusSection
                    
                    // Main Content
                    if mainViewModel.isSetupComplete {
                        mainContentSection
                    } else {
                        setupSection
                    }
                    
                    // Action Buttons
                    actionButtonsSection
                    
                    // Add some bottom padding for better scrolling experience
                    Spacer(minLength: 20)
                }
                .padding()
            }
            .navigationTitle("Simple Decision")
            .navigationBarItems(
                leading: Button("Settings") {
                    mainViewModel.showSettings()
                },
                trailing: Button("Destinations") {
                    mainViewModel.showDestinationPicker()
                }
            )
            .sheet(isPresented: $mainViewModel.showingSettings) {
                SettingsView(viewModel: settingsViewModel)
            }
            .sheet(isPresented: $mainViewModel.showingDestinationPicker) {
                DestinationPickerView(viewModel: destinationViewModel) { destination in
                    mainViewModel.selectDestination(destination)
                }
            }
            .sheet(isPresented: $destinationViewModel.showingAddDestination) {
                AddressSearchView { name, address, coordinate in
                    destinationViewModel.addDestination(
                        name: name,
                        address: address,
                        coordinate: coordinate
                    )
                }
            }
            .sheet(isPresented: $showingFullDebugControls) {
                NavigationView {
                    DebugControlsView()
                        .navigationTitle("Debug Controls")
                        .navigationBarItems(
                            trailing: Button("Done") {
                                showingFullDebugControls = false
                            }
                        )
                }
            }
            .alert("Error", isPresented: .constant(mainViewModel.errorMessage != nil)) {
                Button("OK") {
                    mainViewModel.clearError()
                }
            } message: {
                if let errorMessage = mainViewModel.errorMessage {
                    Text(errorMessage)
                }
            }
        }
    }
    
    // MARK: - View Components
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "location.circle")
                .font(.system(size: 50))
                .foregroundColor(.blue)
            
            Text("Transportation Recommender")
                .font(.headline)
                .multilineTextAlignment(.center)
        }
    }
    
    private var statusSection: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "location")
                    .foregroundColor(locationStatusColor)
                Text(mainViewModel.locationStatusText)
                    .font(.caption)
                Spacer()
            }
            
            if mainViewModel.hasSelectedDestination {
                HStack {
                    Image(systemName: "mappin.and.ellipse")
                        .foregroundColor(.green)
                    Text(mainViewModel.destinationStatusText)
                        .font(.caption)
                    Spacer()
                }
            }
        }
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private var mainContentSection: some View {
        if let recommendation = mainViewModel.currentRecommendation {
            RecommendationView(recommendation: recommendation)
                .transition(.opacity.combined(with: .scale))
        } else if mainViewModel.isLoading {
            VStack {
                ProgressView()
                    .scaleEffect(1.5)
                Text("Analyzing transportation options...")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top)
            }
        } else {
            VStack(spacing: 12) {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 40))
                    .foregroundColor(.gray)
                
                Text("Ready to get a recommendation")
                    .font(.title3)
                    .fontWeight(.medium)
                
                Text("Tap 'Get Recommendation' to analyze your best transportation option")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    private var setupSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "gear")
                .font(.system(size: 40))
                .foregroundColor(.orange)
            
            Text("Setup Required")
                .font(.title2)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 8) {
                setupCheckItem(
                    "Enable location services",
                    isCompleted: mainViewModel.locationStatusText.contains("available")
                )
                
                setupCheckItem(
                    "Select a destination",
                    isCompleted: mainViewModel.hasSelectedDestination
                )
            }
            
            Button("Complete Setup") {
                if !mainViewModel.hasSelectedDestination {
                    mainViewModel.showDestinationPicker()
                } else {
                    mainViewModel.requestLocationPermission()
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }
    
    private func setupCheckItem(_ text: String, isCompleted: Bool) -> some View {
        HStack {
            Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isCompleted ? .green : .gray)
            Text(text)
                .font(.body)
            Spacer()
        }
    }
    
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            if mainViewModel.canRefresh {
                Button(action: {
                    Task {
                        await mainViewModel.refreshRecommendation()
                    }
                }) {
                    HStack {
                        if mainViewModel.isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                        Text(mainViewModel.isLoading ? "Analyzing..." : "Get Recommendation")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(mainViewModel.isLoading)
            }
            
            if mainViewModel.currentRecommendation != nil {
                HStack(spacing: 12) {
                    Button("Clear") {
                        mainViewModel.clearRecommendation()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Journey Complete") {
                        mainViewModel.markJourneyCompleted()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            
            // Debug controls for development
            debugControlsSection
        }
    }
    
    /// Enhanced debug controls section with improved integration
    private var debugControlsSection: some View {
        Group {
            if settingsViewModel.settings.enableDebugControls {
                VStack(spacing: 12) {
                    Divider()
                        .padding(.horizontal)
                    
                    // Debug Controls Header with Toggle
                    HStack {
                        Image(systemName: "ladybug")
                            .foregroundColor(.orange)
                        Text("Debug Controls")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                        Button(action: {
                            settingsViewModel.settings.enableDebugControls.toggle()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Compact Debug Controls Panel
                    compactDebugPanel
                }
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                        .opacity(0.3)
                )
                .padding(.horizontal, 4)
            } else {
                // Show debug toggle button when disabled
                debugToggleButton
            }
        }
    }
    
    /// Compact debug panel for main UI integration
    private var compactDebugPanel: some View {
        VStack(spacing: 8) {
            // Quick Actions Row
            HStack(spacing: 12) {
                Button("Mock Location") {
                    // Quick mock location action
                    Task {
                        await mockCurrentLocation()
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Button("Test Activity") {
                    // Quick live activity test
                    Task {
                        await testLiveActivity()
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Button("Full Debug") {
                    // Show full debug controls
                    presentFullDebugControls()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            
            // Status indicators
            HStack(spacing: 16) {
                debugStatusIndicator(
                    title: "Location",
                    status: mainViewModel.locationStatusText.contains("available") ? "OK" : "Error",
                    color: mainViewModel.locationStatusText.contains("available") ? .green : .red
                )
                
                debugStatusIndicator(
                    title: "Activities",
                    status: "Ready",
                    color: .blue
                )
                
                debugStatusIndicator(
                    title: "API",
                    status: "Connected",
                    color: .green
                )
            }
            .font(.caption)
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
    
    /// Debug toggle button for when debug controls are disabled
    private var debugToggleButton: some View {
        HStack {
            Spacer()
            Button(action: {
                settingsViewModel.settings.enableDebugControls = true
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "ladybug")
                        .font(.caption)
                    Text("Debug")
                        .font(.caption)
                }
                .foregroundColor(.orange)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.orange.opacity(0.5), lineWidth: 1)
                )
            }
        }
        .padding(.horizontal)
    }
    
    /// Debug status indicator component
    private func debugStatusIndicator(title: String, status: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(status)
                .font(.caption2)
                .fontWeight(.medium)
        }
    }
    
    // MARK: - Debug Helper Methods
    
    /// Mock current location for testing
    private func mockCurrentLocation() async {
        // Quick mock location to Chatelet (Paris center) for testing
        let parisCenter = CLLocationCoordinate2D(latitude: 48.8606, longitude: 2.3472)
        // This would require LocationService to support mock locations
        print("Debug: Mock location set to Paris Chatelet: \(parisCenter)")
        // Trigger a recommendation refresh with the mocked location
        await mainViewModel.refreshRecommendation()
    }
    
    /// Test live activity creation
    private func testLiveActivity() async {
        // Create a test recommendation for live activity
        let testRecommendation = Recommendation(
            mode: .bus,
            walkETA: nil,
            busETA: 15,
            confidence: 0.85,
            timestamp: Date(),
            source: .primAPI
        )
        
        // This would test the activity manager
        if #available(iOS 16.1, *) {
            let activityManager = ActivityManagerFactory.createActivityManager()
            let result = await activityManager.startActivity(
                destinationName: "Test Destination",
                startLocationName: "Current Location",
                recommendation: testRecommendation
            )
            print("Debug: Live activity test result: \(result)")
        }
    }
    
    /// Present full debug controls
    private func presentFullDebugControls() {
        showingFullDebugControls = true
    }
    
    // MARK: - Computed Properties
    
    private var locationStatusColor: Color {
        if mainViewModel.locationStatusText.contains("available") {
            return .green
        } else if mainViewModel.locationStatusText.contains("denied") {
            return .red
        } else {
            return .orange
        }
    }
}

// MARK: - Supporting Views

struct DestinationPickerView: View {
    @ObservedObject var viewModel: DestinationViewModel
    let onDestinationSelected: (Destination) -> Void
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if viewModel.filteredDestinations.isEmpty {
                    // Empty state
                    VStack(spacing: 20) {
                        Image(systemName: "map.fill")
                            .font(.system(size: 64))
                            .foregroundColor(.secondary)
                        
                        Text("No Destinations Yet")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Add your first destination to get started")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button(action: {
                            viewModel.showingAddDestination = true
                        }) {
                            Label("Add Destination", systemImage: "plus.circle.fill")
                                .font(.headline)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                        .padding(.top)
                    }
                    .padding()
                } else {
                    List {
                        ForEach(viewModel.filteredDestinations, id: \.id) { destination in
                            Button(action: {
                                onDestinationSelected(destination)
                                presentationMode.wrappedValue.dismiss()
                            }) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(destination.name)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    Text(destination.address)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Text(viewModel.distanceToDestination(destination))
                                        .font(.caption2)
                                        .foregroundColor(.blue)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .onDelete { indexSet in
                            indexSet.forEach { index in
                                let destination = viewModel.filteredDestinations[index]
                                viewModel.removeDestination(destination)
                            }
                        }
                    }
                    .searchable(text: $viewModel.searchText, prompt: "Search destinations")
                }
            }
            .navigationTitle("Select Destination")
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button(action: {
                    viewModel.showingAddDestination = true
                }) {
                    Image(systemName: "plus")
                }
            )
        }
    }
}

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Location") {
                    HStack {
                        Text("Status")
                        Spacer()
                        Text(viewModel.locationStatusText)
                            .foregroundColor(viewModel.locationStatusColor)
                    }
                    
                    if viewModel.locationAuthorizationStatus != .authorizedWhenInUse {
                        Button("Request Permission") {
                            viewModel.requestLocationPermission()
                        }
                    }
                }
                
                Section("Features") {
                    Toggle("PRIM API", isOn: Binding(
                        get: { viewModel.settings.primAPIEnabled },
                        set: { _ in viewModel.togglePRIMAPI() }
                    ))
                    
                    HStack {
                        Text("Live Activities")
                        Spacer()
                        Text(viewModel.activityStatusText)
                            .foregroundColor(viewModel.activityStatusColor)
                    }
                }
                
                Section("Transportation Preferences") {
                    NavigationLink(destination: TransportationConfigurationView(settingsViewModel: viewModel)) {
                        HStack {
                            Image(systemName: "tram.fill")
                                .foregroundColor(.blue)
                            Text("Configure Transit Filters")
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Customize which lines, stops, and destinations you want to monitor")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section(header: Text("PRIM API Configuration")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("API Key")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        TextField("Enter your PRIM API key", text: $viewModel.primAPIKey)
                            .textFieldStyle(.roundedBorder)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                        
                        if viewModel.primAPIKey.isEmpty {
                            Text("Using default development key")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        } else {
                            Text("✓ Custom key configured")
                                .font(.caption2)
                                .foregroundColor(.green)
                        }
                    }
                    
                    Button("Save API Key") {
                        viewModel.savePRIMAPIKey()
                    }
                    .disabled(viewModel.primAPIKey.isEmpty)
                    
                    Button("Clear API Key") {
                        viewModel.clearPRIMAPIKey()
                    }
                    .foregroundColor(.red)
                }
                
                Section("Walking Preferences") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Walking Speed")
                            Spacer()
                            Text(String(format: "%.1f km/h", viewModel.settings.walkingSpeedMps * 3.6))
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(
                            value: Binding(
                                get: { viewModel.settings.walkingSpeedMps },
                                set: { viewModel.updateWalkingSpeed($0) }
                            ),
                            in: 0.5...3.0,
                            step: 0.1
                        )
                        
                        Text("Adjust based on your typical walking pace")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Max Walking Distance")
                            Spacer()
                            Text(String(format: "%.1f km", viewModel.settings.maxWalkingDistanceMeters / 1000))
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(
                            value: Binding(
                                get: { viewModel.settings.maxWalkingDistanceMeters },
                                set: { viewModel.updateMaxWalkingDistance($0) }
                            ),
                            in: 500...10000,
                            step: 100
                        )
                        
                        Text("Maximum distance you're willing to walk")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Toggle("Prefer Walking", isOn: Binding(
                        get: { viewModel.settings.preferWalking },
                        set: { viewModel.updatePreferWalking($0) }
                    ))
                    .help("Favor walking recommendations when transit and walking are similar")
                }
                
                Section("Debug") {
                    Toggle("Debug Controls", isOn: Binding(
                        get: { viewModel.settings.enableDebugControls },
                        set: { _ in viewModel.toggleDebugControls() }
                    ))
                    
                    if viewModel.settings.enableDebugControls {
                        Button("Reset Settings") {
                            viewModel.showResetAlert()
                        }
                        .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarItems(
                trailing: Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
            .alert("Reset Settings", isPresented: $viewModel.showingResetAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    viewModel.resetToDefaults()
                }
            } message: {
                Text("This will reset all settings to their default values.")
            }
        }
    }
}

#Preview {
    ContentView()
}
