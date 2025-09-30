# Data Model Design

**Feature**: Transportation Mode Recommendation with Live Activities  
**Last Updated**: 2025-09-30

## Core Entities

### Recommendation
**Purpose**: Core decision output with transportation mode and metadata
```swift
struct Recommendation: Codable, Equatable {
    let mode: TransportationMode
    let walkETA: Int?           // minutes, nil if unavailable
    let busETA: Int?            // minutes, nil if unavailable  
    let confidence: Double      // 0.0 to 1.0
    let timestamp: Date
    let source: RecommendationSource
}

enum TransportationMode: String, Codable, CaseIterable {
    case walk = "Walk"
    case bus = "Bus" 
    case tie = "Tie"
}

enum RecommendationSource: String, Codable {
    case localHeuristics = "Local"
    case primAPI = "PRIM"
    case mock = "Mock"
}
```

**Validation Rules**:
- confidence must be between 0.0 and 1.0
- At least one ETA (walk or bus) should be non-nil for non-tie recommendations
- timestamp should be recent (within last 5 minutes for validity)

**State Transitions**:
- Initial: nil → mock/local recommendation on app launch
- Update: recommendation refreshes every 30 seconds via timer
- Fallback: PRIM failure → local heuristics with source change

### Location Data
**Purpose**: User location and destination for ETA calculations
```swift
struct LocationData: Codable, Equatable {
    let currentLocation: CLLocationCoordinate2D?
    let destination: Destination
    let lastUpdated: Date
}

struct Destination: Codable, Equatable, Identifiable {
    let id: UUID
    let name: String
    let coordinate: CLLocationCoordinate2D
    let isDefault: Bool
}
```

**Validation Rules**:
- destination name must not be empty
- coordinates must be valid (latitude -90 to 90, longitude -180 to 180)
- Only one destination can be marked as default

### PRIM API Data (Updated Based on Real API Testing)
**Purpose**: Transit departure data from PRIM API (not direct recommendations)
```swift
struct PRIMRequest: Codable {
    let stopAreaId: String      // e.g., "STIF:StopArea:SP:47900:"
    let lineRef: String?        // Optional line filter
    let requestTime: Date
}

struct PRIMResponse: Codable {
    let departures: [Departure]
    let responseTimestamp: Date
}

struct Departure: Codable, Identifiable {
    let id = UUID()
    let lineName: String              // e.g., "RER A", "Bus 122"
    let destinationName: String       // e.g., "Saint-Germain-en-Laye"
    let expectedDepartureTime: Date   // ISO 8601 format from API
    let departureStatus: String       // "onTime", "delayed", "early"
    let platformName: String          // Platform or stop designation
    let direction: String?            // Full direction description
}
```

**Validation Rules** (Based on API Testing):
- expectedDepartureTime should be future timestamp (real-time data)
- departureStatus maps to confidence: "onTime" = 0.9, "delayed" = 0.6, others = 0.7
- lineName format consistent with PRIM API responses
- destinationName non-empty (validated through API testing)

### App Settings
**Purpose**: User preferences and API configuration
```swift
struct AppSettings: Codable {
    let primAPIEnabled: Bool
    let primAPIKeyConfigured: Bool
    let locationPermissionRequested: Bool
    let defaultDestination: UUID?
    let lastKnownLocation: CLLocationCoordinate2D?
}
```

**Storage Strategy**:
- UserDefaults for app settings (non-sensitive)
- Keychain for PRIM API key (sensitive)
- No persistence for current recommendations (ephemeral)

## Data Flow Relationships

### Primary Flow
```
LocationService → DecisionEngine → ContentViewModel → RecommendationView
                      ↓
               PRIMClient (optional)
                      ↓
             ActivityManager (iOS 16.1+)
```

### Error Flow
```
PRIMClient failure → DecisionEngine fallback → Local heuristics
LocationService denial → Manual entry prompt → User input
```

### Data Dependencies
- Recommendation depends on LocationData (current + destination)
- PRIMClient depends on AppSettings (API enabled + key configured)
- ActivityManager depends on Recommendation (for Live Activity content)
- ContentViewModel aggregates all data for UI presentation

## State Management

### Single Source of Truth
- ContentViewModel holds current Recommendation as @Published property
- LocationService maintains current LocationData
- AppSettings stored in UserDefaults/Keychain

### Update Triggers
- Timer: Every 30 seconds while app active
- Location change: When user moves significantly
- Settings change: When PRIM API enabled/disabled
- Manual: Debug controls or pull-to-refresh

### Concurrency Considerations
- All UI updates on MainActor
- Network calls on background actors
- Location updates on background queue
- State changes serialized through MainActor

## Testing Data Structures

### Mock Data
```swift
extension Recommendation {
    static let mockWalk = Recommendation(
        mode: .walk,
        walkETA: 12,
        busETA: 15,
        confidence: 0.8,
        timestamp: Date(),
        source: .mock
    )
    
    static let mockBus = Recommendation(
        mode: .bus,
        walkETA: 18,
        busETA: 8,
        confidence: 0.9,
        timestamp: Date(),
        source: .mock
    )
}
```

**Usage**: Debug controls, development testing, simulator compatibility