//
//  TransportationPreferences.swift
//  simpleDecision
//
//  Created by Transportation Recommendation System on 22/10/2025.
//

import Foundation

/// User preferences for transportation filtering
struct TransportationPreferences: Codable {
    /// Which transit lines user wants to monitor
    var enabledLines: Set<String>
    
    /// Which stops user wants to use (by stop name)
    var enabledStops: Set<String>
    
    /// Which destinations user cares about (by destination name)
    /// If empty, all destinations are allowed
    var allowedDestinations: Set<String>
    
    /// Exclude specific destinations even if they're monitored
    var excludedDestinations: Set<String>
    
    // MARK: - Codable Conformance (Sets need custom encoding)
    enum CodingKeys: String, CodingKey {
        case enabledLines
        case enabledStops
        case allowedDestinations
        case excludedDestinations
    }
    
    init(
        enabledLines: Set<String> = ["RER A", "RER E", "Bus 122", "Bus 124", "N34"],
        enabledStops: Set<String> = ["Cimetière de Vincennes", "Val de Fontenay RER"],
        allowedDestinations: Set<String> = [],
        excludedDestinations: Set<String> = ["Place de la Résistance"]
    ) {
        self.enabledLines = enabledLines
        self.enabledStops = enabledStops
        self.allowedDestinations = allowedDestinations
        self.excludedDestinations = excludedDestinations
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Array(enabledLines), forKey: .enabledLines)
        try container.encode(Array(enabledStops), forKey: .enabledStops)
        try container.encode(Array(allowedDestinations), forKey: .allowedDestinations)
        try container.encode(Array(excludedDestinations), forKey: .excludedDestinations)
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabledLines = Set(try container.decode([String].self, forKey: .enabledLines))
        enabledStops = Set(try container.decode([String].self, forKey: .enabledStops))
        allowedDestinations = Set(try container.decode([String].self, forKey: .allowedDestinations))
        excludedDestinations = Set(try container.decode([String].self, forKey: .excludedDestinations))
    }
    
    /// Check if a departure should be included based on user preferences
    /// - Parameters:
    ///   - lineName: e.g., "RER A", "Bus 122"
    ///   - destination: e.g., "Château de Vincennes"
    ///   - stopName: e.g., "Cimetière de Vincennes"
    /// - Returns: true if departure matches user preferences
    func shouldIncludeDeparture(lineName: String, destination: String, stopName: String) -> Bool {
        // Check if line is enabled
        guard enabledLines.contains(lineName) else {
            return false
        }
        
        // Check if stop is enabled
        guard enabledStops.contains(stopName) else {
            return false
        }
        
        // Check if destination is excluded
        if excludedDestinations.contains(destination) {
            return false
        }
        
        // If we have allowed destinations, check if destination is in the list
        if !allowedDestinations.isEmpty {
            return allowedDestinations.contains(destination)
        }
        
        // If no specific destinations are configured, allow all
        return true
    }
    
    /// Get all unique available lines (for UI configuration)
    static var availableLines: [String] {
        return [
            "RER A",
            "RER E",
            "Bus 122",
            "Bus 124",
            "N34"
        ].sorted()
    }
    
    /// Get all unique available stops (would be fetched from API in real app)
    static var availableStops: [String] {
        return [
            "Cimetière de Vincennes",
            "Val de Fontenay RER"
        ].sorted()
    }
}
