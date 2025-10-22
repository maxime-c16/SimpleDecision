//
//  TransportationConfigurationView.swift
//  simpleDecision
//
//  Created by Transportation Recommendation System on 22/10/2025.
//

import SwiftUI

/// Configuration view for users to filter lines, stops, and destinations
struct TransportationConfigurationView: View {
    @ObservedObject var settingsViewModel: SettingsViewModel
    @Environment(\.dismiss) var dismiss
    @State private var selectedTab: ConfigTab = .lines
    
    enum ConfigTab {
        case lines
        case stops
        case destinations
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab selector
            Picker("Configuration", selection: $selectedTab) {
                Text("Lines").tag(ConfigTab.lines)
                Text("Stops").tag(ConfigTab.stops)
                Text("Destinations").tag(ConfigTab.destinations)
            }
            .pickerStyle(.segmented)
            .padding()
            
            // Content based on tab
            TabView(selection: $selectedTab) {
                LinesConfigurationView(preferences: $settingsViewModel.settings.transportationPreferences)
                    .tag(ConfigTab.lines)
                    .onAppear { print("🔧 LinesConfigurationView appeared") }
                    .onDisappear { print("🔧 LinesConfigurationView disappeared") }
                
                StopsConfigurationView(preferences: $settingsViewModel.settings.transportationPreferences)
                    .tag(ConfigTab.stops)
                    .onAppear { print("🔧 StopsConfigurationView appeared") }
                    .onDisappear { print("🔧 StopsConfigurationView disappeared") }
                
                DestinationsConfigurationView(preferences: $settingsViewModel.settings.transportationPreferences)
                    .tag(ConfigTab.destinations)
                    .onAppear { print("🔧 DestinationsConfigurationView appeared") }
                    .onDisappear { print("🔧 DestinationsConfigurationView disappeared") }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .navigationTitle("Transportation Setup")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    print("🔧 TransportationConfigurationView: Done button tapped")
                    settingsViewModel.saveSettings()
                    dismiss()
                }
                .fontWeight(.semibold)
            }
        }
        .onAppear {
            print("🔧 TransportationConfigurationView: onAppear called")
        }
        .onDisappear {
            print("🔧 TransportationConfigurationView: onDisappear called")
            // Make sure settings are saved when leaving
            settingsViewModel.saveSettings()
        }
    }
}

// MARK: - Lines Configuration

struct LinesConfigurationView: View {
    @Binding var preferences: TransportationPreferences
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Select Transit Lines")
                .font(.headline)
                .padding(.horizontal)
            
            Text("Choose which lines you want to monitor")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(TransportationPreferences.availableLines, id: \.self) { line in
                        Toggle(isOn: Binding(
                            get: { preferences.enabledLines.contains(line) },
                            set: { isEnabled in
                                print("🔧 Lines: Toggling \(line) to \(isEnabled)")
                                if isEnabled {
                                    preferences.enabledLines.insert(line)
                                } else {
                                    preferences.enabledLines.remove(line)
                                }
                            }
                        )) {
                            HStack(spacing: 12) {
                                Image(systemName: lineIcon(line))
                                    .font(.title3)
                                    .foregroundColor(lineColor(line))
                                    .frame(width: 24)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(line)
                                        .fontWeight(.semibold)
                                    Text(lineDescription(line))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            
            Spacer()
        }
        .padding(.vertical)
    }
    
    private func lineIcon(_ line: String) -> String {
        return line.contains("RER") ? "tram.fill" : "bus.fill"
    }
    
    private func lineColor(_ line: String) -> Color {
        if line.contains("RER A") { return .red }
        if line.contains("RER E") { return .purple }
        if line.contains("122") { return .green }
        if line.contains("124") { return .orange }
        if line.contains("N34") { return .blue }
        return .gray
    }
    
    private func lineDescription(_ line: String) -> String {
        switch line {
        case "RER A": return "North-South suburban rail"
        case "RER E": return "East-West suburban rail"
        case "Bus 122": return "Vincennes to Val de Fontenay"
        case "Bus 124": return "Vincennes to Château"
        case "N34": return "Night bus service"
        default: return ""
        }
    }
}
// MARK: - Stops Configuration

struct StopsConfigurationView: View {
    @Binding var preferences: TransportationPreferences
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Select Transit Stops")
                .font(.headline)
                .padding(.horizontal)
            
            Text("Choose which stops are accessible to you")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(TransportationPreferences.availableStops, id: \.self) { stop in
                        Toggle(isOn: Binding(
                            get: { preferences.enabledStops.contains(stop) },
                            set: { isEnabled in
                                print("🔧 Stops: Toggling \(stop) to \(isEnabled)")
                                if isEnabled {
                                    preferences.enabledStops.insert(stop)
                                } else {
                                    preferences.enabledStops.remove(stop)
                                }
                            }
                        )) {
                            HStack(spacing: 12) {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(.red)
                                    .frame(width: 24)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(stop)
                                        .fontWeight(.semibold)
                                    Text(stopDistance(stop))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            
            Spacer()
        }
        .padding(.vertical)
    }
    
    private func stopDistance(_ stop: String) -> String {
        switch stop {
        case "Cimetière de Vincennes": return "~500m walking"
        case "Val de Fontenay RER": return "~1.2km walking"
        default: return ""
        }
    }
}

// MARK: - Destinations Configuration

struct DestinationsConfigurationView: View {
    @Binding var preferences: TransportationPreferences
    @State private var newDestination = ""
    @State private var showingExclusionsInfo = false
    
    var availableDestinations: [String] {
        return [
            "Château de Vincennes",
            "Cergy",
            "Gare de l'Est",
            "Poissy",
            "Saint-Germain-en-Laye",
            "Tournan",
            "Villiers-sur-Marne",
            "Place de la Résistance"
        ].sorted()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Destination Preferences")
                .font(.headline)
                .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Exclude destinations")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                
                Text("Destinations you don't want to see (optional)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            }
            
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(availableDestinations, id: \.self) { destination in
                        Toggle(isOn: Binding(
                            get: { preferences.excludedDestinations.contains(destination) },
                            set: { isExcluded in
                                if isExcluded {
                                    preferences.excludedDestinations.insert(destination)
                                } else {
                                    preferences.excludedDestinations.remove(destination)
                                }
                            }
                        )) {
                            HStack(spacing: 12) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(.red)
                                    .frame(width: 24)
                                    .opacity(preferences.excludedDestinations.contains(destination) ? 1 : 0.3)
                                
                                Text(destination)
                                    .fontWeight(.semibold)
                                    .strikethrough(preferences.excludedDestinations.contains(destination))
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                    Text("Toggled destinations will be filtered out")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(6)
                .padding(.horizontal)
            }
            
            Spacer()
        }
        .padding(.vertical)
    }
}

// Preview disabled - requires complex setup
// To enable, provide proper test instances
