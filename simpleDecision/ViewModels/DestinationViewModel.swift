//
//  DestinationViewModel.swift
//  simpleDecision
//
//  Created by Transportation Recommendation System on 30/09/2025.
//

import Foundation
import SwiftUI
import Combine
import CoreLocation

/// View model for destination selection and management
@MainActor
class DestinationViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var destinations: [Destination] = []
    @Published var filteredDestinations: [Destination] = []
    @Published var searchText = "" {
        didSet {
            filterDestinations()
        }
    }
    @Published var selectedDestination: Destination?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showingAddDestination = false
    @Published var sortOption: SortOption = .alphabetical {
        didSet {
            sortDestinations()
        }
    }
    
    // MARK: - Services
    private let locationService: LocationService
    private let settingsManager: AppSettingsManager
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init(
        locationService: LocationService,
        settingsManager: AppSettingsManager
    ) {
        self.locationService = locationService
        self.settingsManager = settingsManager
        
        setupBindings()
        loadDestinations()
    }
    
    // MARK: - Setup
    private func setupBindings() {
        // Monitor location changes to update distances
        locationService.$currentLocation
            .sink { [weak self] _ in
                self?.sortDestinations()
            }
            .store(in: &cancellables)
        
        // Load selected destination from settings
        $selectedDestination
            .compactMap { $0 }
            .sink { [weak self] destination in
                self?.settingsManager.updateDefaultDestination(destination.id)
            }
            .store(in: &cancellables)
    }
    
    private func loadDestinations() {
        isLoading = true
        
        // Load mock destinations (in production, this might fetch from Core Data or API)
        destinations = LocationData.mockDestinations
        
        // Set selected destination from settings
        if let defaultDestinationId = settingsManager.settings.defaultDestination {
            selectedDestination = destinations.first { $0.id == defaultDestinationId }
        }
        
        filterDestinations()
        isLoading = false
    }
    
    // MARK: - Public Methods
    
    /// Select a destination
    func selectDestination(_ destination: Destination) {
        selectedDestination = destination
        settingsManager.updateDefaultDestination(destination.id)
    }
    
    /// Add a new custom destination
    func addDestination(name: String, address: String, coordinate: CLLocationCoordinate2D) {
        let newDestination = Destination(
            id: UUID(),
            name: name,
            address: address,
            coordinate: coordinate,
            category: .custom,
            isDefault: false
        )
        
        destinations.append(newDestination)
        filterDestinations()
        
        // Auto-select the new destination
        selectDestination(newDestination)
        
        showingAddDestination = false
    }
    
    /// Remove a custom destination
    func removeDestination(_ destination: Destination) {
        guard destination.category == .custom else {
            errorMessage = "Cannot remove built-in destinations"
            return
        }
        
        destinations.removeAll { $0.id == destination.id }
        
        // If this was the selected destination, clear selection
        if selectedDestination?.id == destination.id {
            selectedDestination = nil
            settingsManager.updateDefaultDestination(nil)
        }
        
        filterDestinations()
    }
    
    /// Get distance to destination from current location
    func distanceToDestination(_ destination: Destination) -> String {
        guard locationService.currentLocation != nil else {
            return "Distance unknown"
        }
        
        return locationService.formattedDistance(to: destination.coordinate)
    }
    
    /// Get estimated walking time to destination
    func walkingTimeToDestination(_ destination: Destination) -> String {
        guard locationService.currentLocation != nil else {
            return "Time unknown"
        }
        
        let distance = locationService.distanceToDestination(destination.coordinate) ?? 0
        let walkingSpeedMps = 1.4 // 1.4 m/s average walking speed
        let timeMinutes = distance / walkingSpeedMps / 60
        
        if timeMinutes < 60 {
            return String(format: "%.0f min walk", timeMinutes)
        } else {
            let hours = Int(timeMinutes / 60)
            let minutes = Int(timeMinutes.truncatingRemainder(dividingBy: 60))
            return "\(hours)h \(minutes)m walk"
        }
    }
    
    /// Show add destination form
    func showAddDestination() {
        showingAddDestination = true
    }
    
    /// Clear search text
    func clearSearch() {
        searchText = ""
    }
    
    /// Clear error message
    func clearError() {
        errorMessage = nil
    }
    
    // MARK: - Private Methods
    
    private func filterDestinations() {
        if searchText.isEmpty {
            filteredDestinations = destinations
        } else {
            filteredDestinations = destinations.filter { destination in
                destination.name.localizedCaseInsensitiveContains(searchText) ||
                destination.address.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        sortDestinations()
    }
    
    private func sortDestinations() {
        switch sortOption {
        case .alphabetical:
            filteredDestinations.sort { $0.name < $1.name }
            
        case .distance:
            guard let currentLocation = locationService.currentLocation else {
                // Fallback to alphabetical if no location
                filteredDestinations.sort { $0.name < $1.name }
                return
            }
            
            filteredDestinations.sort { first, second in
                let firstDistance = locationService.distanceToDestination(first.coordinate) ?? Double.greatestFiniteMagnitude
                let secondDistance = locationService.distanceToDestination(second.coordinate) ?? Double.greatestFiniteMagnitude
                return firstDistance < secondDistance
            }
            
        case .category:
            filteredDestinations.sort { first, second in
                if first.category == second.category {
                    return first.name < second.name
                } else {
                    return first.category.sortOrder < second.category.sortOrder
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    var hasDestinations: Bool {
        !destinations.isEmpty
    }
    
    var hasFilteredResults: Bool {
        !filteredDestinations.isEmpty
    }
    
    var isSearchActive: Bool {
        !searchText.isEmpty
    }
    
    var canAddDestination: Bool {
        locationService.hasValidLocation
    }
    
    /// Get destinations grouped by category for sectioned display
    var destinationsByCategory: [DestinationCategory: [Destination]] {
        Dictionary(grouping: filteredDestinations) { $0.category }
    }
    
    /// Get section titles for grouped display
    var sectionTitles: [DestinationCategory] {
        Array(destinationsByCategory.keys).sorted { $0.sortOrder < $1.sortOrder }
    }
}

// MARK: - Supporting Types

enum SortOption: String, CaseIterable {
    case alphabetical = "Alphabetical"
    case distance = "Distance"
    case category = "Category"
    
    var displayName: String {
        return rawValue
    }
    
    var systemImage: String {
        switch self {
        case .alphabetical:
            return "textformat.abc"
        case .distance:
            return "location"
        case .category:
            return "folder"
        }
    }
}

