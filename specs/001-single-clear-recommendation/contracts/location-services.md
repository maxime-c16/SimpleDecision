# Location Services Contract

**Version**: 1.0  
**Last Updated**: 2025-09-30  
**Purpose**: Define location detection and destination management contract

## LocationService Interface
```swift
protocol LocationServiceProtocol {
    var currentLocation: CLLocation? { get }
    var authorizationStatus: CLAuthorizationStatus { get }
    var destinations: [Destination] { get }
    
    func requestLocationPermission() async -> Bool
    func getCurrentLocation() async throws -> CLLocation
    func addDestination(_ destination: Destination)
    func removeDestination(_ destination: Destination)
    func setDefaultDestination(_ destination: Destination)
}

class CoreLocationService: NSObject, LocationServiceProtocol, CLLocationManagerDelegate {
    // Implementation using CoreLocation
}
```

## Location Permission Contract

### Permission Request Flow
1. App checks current authorization status
2. If not determined, request "when in use" permission
3. Show purpose dialog with clear explanation
4. Handle user response (granted/denied/restricted)

### Permission States
```swift
enum LocationPermissionState {
    case notRequested
    case requesting
    case granted
    case denied
    case restricted
}
```

### Fallback Behavior
```swift
// When permission denied:
// 1. Show clear error message
// 2. Offer manual location entry
// 3. Store manual entry for future use
// 4. Provide settings link for permission change

struct ManualLocationEntry {
    let address: String
    let coordinate: CLLocationCoordinate2D
    let timestamp: Date
}
```

## Destination Management Contract

### Destination Storage
```swift
struct Destination: Identifiable, Codable {
    let id: UUID
    let name: String
    let address: String?
    let coordinate: CLLocationCoordinate2D
    let isDefault: Bool
    let createdAt: Date
}
```

### Default Destinations
- User can set one default destination
- App suggests "Home" and "Work" during onboarding
- Destinations stored in UserDefaults
- Maximum 10 saved destinations

### Address Resolution
```swift
protocol GeocodingServiceProtocol {
    func geocode(address: String) async throws -> CLLocationCoordinate2D
    func reverseGeocode(coordinate: CLLocationCoordinate2D) async throws -> String
}

class AppleGeocodingService: GeocodingServiceProtocol {
    // Implementation using CLGeocoder
}
```

## Location Accuracy Contract

### Accuracy Requirements
- Desired accuracy: 100 meters (kCLLocationAccuracyHundredMeters)
- Maximum age: 5 minutes for cached location
- Timeout: 10 seconds for location acquisition
- Distance filter: 50 meters minimum change

### Quality Validation
```swift
func validateLocation(_ location: CLLocation) -> Bool {
    // Check accuracy (< 100m)
    // Check age (< 5 minutes)
    // Check coordinate validity
    // Reject obviously invalid coordinates
}
```

## Error Handling Contract

### Location Errors
```swift
enum LocationServiceError: Error {
    case permissionDenied
    case locationUnavailable
    case timeout
    case accuracyInsufficient
    case networkError
}
```

### Error Recovery
- **Permission denied**: Prompt for manual entry
- **Location unavailable**: Use last known location with warning
- **Timeout**: Retry once, then manual entry option
- **Accuracy insufficient**: Continue with warning indicator

## Background Location

### Policy
- **No background location tracking**
- Location only updated when app is active
- Respects user privacy and battery life
- Location services stopped when app backgrounded

### Foreground Updates
- Location updates while app active
- 30-second refresh cycle aligns with recommendation updates
- Automatic stop when no longer needed

## Integration Points

### DecisionEngine Integration
```swift
func getRecommendation() async throws -> Recommendation {
    guard let currentLocation = await locationService.getCurrentLocation(),
          let destination = locationService.defaultDestination else {
        throw LocationServiceError.locationUnavailable
    }
    
    // Calculate ETAs and make recommendation
}
```

### UI Integration
```swift
// Location permission UI
// Manual entry UI when permission denied
// Destination management UI
// Location status indicators
```

## Testing & Debug Support

### Mock Location Service
```swift
class MockLocationService: LocationServiceProtocol {
    var mockLocation: CLLocation?
    var mockPermissionStatus: CLAuthorizationStatus = .authorizedWhenInUse
    
    // Deterministic responses for testing
}
```

### Debug Controls
- Override current location
- Simulate permission states
- Test geocoding with known addresses
- Force location errors for testing fallbacks