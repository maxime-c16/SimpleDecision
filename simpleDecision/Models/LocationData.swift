//
//  LocationData.swift
//  simpleDecision
//
//  Created by Transportation Recommendation System on 30/09/2025.
//

import Foundation
import CoreLocation

/// User location and destination for ETA calculations
struct LocationData: Codable, Equatable {
    let currentLocation: CLLocationCoordinate2D?
    let destination: Destination
    let lastUpdated: Date
    
    /// Check if location data is recent and valid
    var isValid: Bool {
        // Must have a destination
        guard destination.isValidCoordinate else { return false }
        
        // Location should be updated within last 5 minutes
        let fiveMinutesAgo = Date().addingTimeInterval(-300)
        return lastUpdated > fiveMinutesAgo
    }
    
    /// Distance between current location and destination (in meters)
    var distanceToDestination: CLLocationDistance? {
        guard let current = currentLocation else { return nil }
        
        let currentCLLocation = CLLocation(latitude: current.latitude, longitude: current.longitude)
        let destinationCLLocation = CLLocation(latitude: destination.coordinate.latitude, longitude: destination.coordinate.longitude)
        
        return currentCLLocation.distance(from: destinationCLLocation)
    }
}

/// Destination information
struct Destination: Codable, Equatable, Identifiable {
    let id: UUID
    let name: String
    let coordinate: CLLocationCoordinate2D
    let isDefault: Bool
    
    /// Validate coordinate bounds
    var isValidCoordinate: Bool {
        // Latitude must be between -90 and 90
        guard coordinate.latitude >= -90 && coordinate.latitude <= 90 else { return false }
        
        // Longitude must be between -180 and 180
        guard coordinate.longitude >= -180 && coordinate.longitude <= 180 else { return false }
        
        // Name must not be empty
        return !name.isEmpty
    }
    
    /// Display address or coordinate string
    var displayLocation: String {
        return "\(coordinate.latitude), \(coordinate.longitude)"
    }
}

// MARK: - CLLocationCoordinate2D Codable Extension
extension CLLocationCoordinate2D: Codable {
    enum CodingKeys: String, CodingKey {
        case latitude
        case longitude
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let latitude = try container.decode(Double.self, forKey: .latitude)
        let longitude = try container.decode(Double.self, forKey: .longitude)
        self.init(latitude: latitude, longitude: longitude)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(latitude, forKey: .latitude)
        try container.encode(longitude, forKey: .longitude)
    }
}

// MARK: - Mock Data for Development
extension LocationData {
    /// Mock location data for development
    static let mockParisWork = LocationData(
        currentLocation: CLLocationCoordinate2D(latitude: 48.8566, longitude: 2.3522), // Paris center
        destination: Destination.mockWork,
        lastUpdated: Date()
    )
    
    static let mockValDeFontenay = LocationData(
        currentLocation: CLLocationCoordinate2D(latitude: 48.8584, longitude: 2.4551), // Val de Fontenay
        destination: Destination.mockWork,
        lastUpdated: Date()
    )
}

extension Destination {
    /// Mock destinations for development
    static let mockWork = Destination(
        id: UUID(),
        name: "Work",
        coordinate: CLLocationCoordinate2D(latitude: 48.8606, longitude: 2.3376), // Louvre area
        isDefault: true
    )
    
    static let mockHome = Destination(
        id: UUID(),
        name: "Home",
        coordinate: CLLocationCoordinate2D(latitude: 48.8471, longitude: 2.4125), // Vincennes area
        isDefault: false
    )
    
    static let mockDestinations = [mockWork, mockHome]
}