//
//  LocationData.swift
//  simpleDecision
//
//  Created by Transportation Recommendation System on 30/09/2025.
//

import Foundation
import CoreLocation

/// User location and destination for ETA calculations
struct LocationData: Codable {
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

/// Destination category for organization
enum DestinationCategory: String, Codable, CaseIterable {
    case work = "work"
    case home = "home"
    case transport = "transport"
    case shopping = "shopping"
    case entertainment = "entertainment"
    case custom = "custom"
}

/// Destination information
struct Destination: Codable, Identifiable {
    let id: UUID
    let name: String
    let address: String
    let coordinate: CLLocationCoordinate2D
    let category: DestinationCategory
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

// MARK: - Equatable Conformance
extension LocationData: Equatable {
    static func == (lhs: LocationData, rhs: LocationData) -> Bool {
        // Compare optional coordinates manually
        let locationsEqual: Bool
        switch (lhs.currentLocation, rhs.currentLocation) {
        case (nil, nil):
            locationsEqual = true
        case (let loc1?, let loc2?):
            locationsEqual = loc1.latitude == loc2.latitude && loc1.longitude == loc2.longitude
        default:
            locationsEqual = false
        }
        
        return locationsEqual && 
               lhs.destination == rhs.destination && 
               lhs.lastUpdated == rhs.lastUpdated
    }
}

extension Destination: Equatable {
    static func == (lhs: Destination, rhs: Destination) -> Bool {
        return lhs.id == rhs.id &&
               lhs.name == rhs.name &&
               lhs.address == rhs.address &&
               lhs.coordinate.latitude == rhs.coordinate.latitude &&
               lhs.coordinate.longitude == rhs.coordinate.longitude &&
               lhs.category == rhs.category &&
               lhs.isDefault == rhs.isDefault
    }
}

// MARK: - CLLocationCoordinate2D Codable Extension
extension CLLocationCoordinate2D: @retroactive Codable {
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
        name: "Office La Défense",
        address: "1 Esplanade du Général de Gaulle, 92400 Courbevoie",
        coordinate: CLLocationCoordinate2D(latitude: 48.8915, longitude: 2.2388),
        category: .work,
        isDefault: true
    )
    
    static let mockHome = Destination(
        id: UUID(),
        name: "Home",
        address: "Paris 11e Arrondissement, France",
        coordinate: CLLocationCoordinate2D(latitude: 48.8566, longitude: 2.3650),
        category: .home,
        isDefault: false
    )
    
    static let mockChatelet = Destination(
        id: UUID(),
        name: "Châtelet - Les Halles",
        address: "Place Marguerite de Navarre, 75001 Paris",
        coordinate: CLLocationCoordinate2D(latitude: 48.8606, longitude: 2.3472),
        category: .transport,
        isDefault: false
    )
    
    static let mockLouvre = Destination(
        id: UUID(),
        name: "Musée du Louvre",
        address: "Rue de Rivoli, 75001 Paris",
        coordinate: CLLocationCoordinate2D(latitude: 48.8606, longitude: 2.3376),
        category: .entertainment,
        isDefault: false
    )
    
    /// Array of all mock destinations
    static let mockDestinations = [
        mockWork,
        mockHome, 
        mockChatelet,
        mockLouvre
    ]
}

extension LocationData {
    /// Access to mock destinations from LocationData
    static var mockDestinations: [Destination] {
        return Destination.mockDestinations
    }
}

// MARK: - DestinationCategory Extension
extension DestinationCategory {
    var sortOrder: Int {
        switch self {
        case .work:
            return 1
        case .home:
            return 2
        case .transport:
            return 3
        case .shopping:
            return 4
        case .entertainment:
            return 5
        case .custom:
            return 6
        }
    }
    
    var displayName: String {
        switch self {
        case .work:
            return "Work"
        case .home:
            return "Home"
        case .transport:
            return "Transport"
        case .shopping:
            return "Shopping"
        case .entertainment:
            return "Entertainment"
        case .custom:
            return "Custom"
        }
    }
    
    var systemImage: String {
        switch self {
        case .work:
            return "building.2"
        case .home:
            return "house"
        case .transport:
            return "tram"
        case .shopping:
            return "bag"
        case .entertainment:
            return "theatermasks"
        case .custom:
            return "star"
        }
    }
}