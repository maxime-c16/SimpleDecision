//
//  ContentView.swift
//  simpleDecision
//
//  Created by Tristan Aranda  on 30/09/2025.
//

import SwiftUI
import CoreLocation

struct ContentView: View {
    @StateObject private var mainViewModel = MainViewModel()
    @StateObject private var destinationViewModel = DestinationViewModel()
    @StateObject private var settingsViewModel = SettingsViewModel()
    
    var body: some View {
        NavigationView {
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
                
                Spacer()
                
                // Action Buttons
                actionButtonsSection
            }
            .padding()
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
            if settingsViewModel.settings.enableDebugControls {
                DebugControlsView()
            }
        }
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
            List(viewModel.filteredDestinations, id: \.id) { destination in
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
            .navigationTitle("Select Destination")
            .navigationBarItems(
                trailing: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
            .searchable(text: $viewModel.searchText, prompt: "Search destinations")
        }
    }
}

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
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
