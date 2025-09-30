//
//  LocationService.swift
//  simpleDecision
//
//  Created by Transportation Recommendation System on 30/09/2025.
//

import Foundation
import CoreLocation
import Combine

/// Location service that handles GPS permissions and updates
class LocationService: NSObject, ObservableObject {
    @Published var currentLocation: CLLocationCoordinate2D?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var locationError: String?
    @Published var isUpdating: Bool = false
    
    private let locationManager = CLLocationManager()
    private var cancellables = Set<AnyCancellable>()
    
    override init() {
        super.init()
        setupLocationManager()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        locationManager.distanceFilter = 10.0 // Only update when moved 10+ meters
    }
    
    /// Request location permission
    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    /// Start location updates
    func startLocationUpdates() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            locationError = "Location permission not granted"
            return
        }
        
        isUpdating = true
        locationManager.startUpdatingLocation()
        
        // Stop updates after 30 seconds to save battery
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [weak self] in
            self?.stopLocationUpdates()
        }
    }
    
    /// Stop location updates
    func stopLocationUpdates() {
        locationManager.stopUpdatingLocation()
        isUpdating = false
    }
    
    /// Get one-time location fix
    func requestLocation() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            locationError = "Location permission not granted"
            return
        }
        
        locationManager.requestLocation()
    }
    
    /// Calculate distance to destination
    func distanceToDestination(_ destination: CLLocationCoordinate2D) -> Double? {
        guard let currentLocation = currentLocation else { return nil }
        
        let current = CLLocation(latitude: currentLocation.latitude, longitude: currentLocation.longitude)
        let dest = CLLocation(latitude: destination.latitude, longitude: destination.longitude)
        
        return current.distance(from: dest)
    }
    
    /// Format distance for display
    func formattedDistance(to destination: CLLocationCoordinate2D) -> String {
        guard let distance = distanceToDestination(destination) else {
            return "Distance unknown"
        }
        
        if distance < 1000 {
            return String(format: "%.0f m", distance)
        } else {
            return String(format: "%.1f km", distance / 1000)
        }
    }
    
    /// Check if location is available and recent
    var hasValidLocation: Bool {
        return currentLocation != nil && authorizationStatus.isAuthorized
    }
    
    /// Mock location for development/testing
    func setMockLocation(_ coordinate: CLLocationCoordinate2D) {
        #if DEBUG
        currentLocation = coordinate
        locationError = nil
        #endif
    }
    
    /// Clear any location errors
    func clearError() {
        locationError = nil
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationService: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        DispatchQueue.main.async { [weak self] in
            self?.currentLocation = location.coordinate
            self?.locationError = nil
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async { [weak self] in
            self?.locationError = error.localizedDescription
            self?.isUpdating = false
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        DispatchQueue.main.async { [weak self] in
            self?.authorizationStatus = status
            
            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                self?.locationError = nil
                // Start location updates when permission is granted
                self?.startLocationUpdates()
            case .denied, .restricted:
                self?.locationError = "Location permission denied"
                self?.currentLocation = nil
            case .notDetermined:
                break
            @unknown default:
                break
            }
        }
    }
}

// MARK: - CLAuthorizationStatus Extension
extension CLAuthorizationStatus {
    var isAuthorized: Bool {
        return self == .authorizedWhenInUse || self == .authorizedAlways
    }
    
    var isDenied: Bool {
        return self == .denied || self == .restricted
    }
}