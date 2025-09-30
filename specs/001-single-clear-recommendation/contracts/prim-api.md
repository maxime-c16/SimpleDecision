# PRIM API Contract - Île-de-France Mobilités

**Version**: 1.0  
**Last Updated**: 2025-09-30  
**Purpose**: Define PRIM (Plateforme Régionale d'Information sur la Mobilité) API integration for Île-de-France transit data

## API Endpoint
```
GET https://prim.iledefrance-mobilites.fr/marketplace/stop-monitoring
Authorization: apikey {r1NDADYoOpUH6qS5XkJoPhiRrNjPpee5}
Accept: application/json
```

## Request Parameters
```
MonitoringRef (required): Stop Point ID or Stop Area ID
  - Format: "STIF:StopPoint:Q:{id}:" or "STIF:StopArea:SP:{id}:"
  - Example: "STIF:StopArea:SP:47900:" (Val de Fontenay)

LineRef (optional): Line identifier  
  - Format: "STIF:Line::{line_id}:"
  - Example: "STIF:Line::C01742:" (RER A)
```

**Example Request**:
```bash
curl -X 'GET' \
  'https://prim.iledefrance-mobilites.fr/marketplace/stop-monitoring?MonitoringRef=STIF%3AStopArea%3ASP%3A47900%3A' \
  -H 'accept: application/json' \
  -H 'apikey: r1NDADYoOpUH6qS5XkJoPhiRrNjPpee5'
```

## Response Schema (SIRI Lite Format)
```json
{
  "Siri": {
    "ServiceDelivery": {
      "ResponseTimestamp": "string (ISO8601)",
      "ProducerRef": {"value": "string"},
      "StopMonitoringDelivery": [{
        "ResponseTimestamp": "string (ISO8601)",
        "MonitoredStopVisit": [{
          "RecordedAtTime": "string (ISO8601)",
          "MonitoringRef": {"value": "string"},
          "MonitoredVehicleJourney": {
            "LineRef": {"value": "string"},
            "DirectionName": [{"value": "string"}],
            "DestinationName": [{"value": "string"}],
            "MonitoredCall": {
              "StopPointName": [{"value": "string"}],
              "ExpectedArrivalTime": "string (ISO8601)",
              "ExpectedDepartureTime": "string (ISO8601)",
              "DepartureStatus": "string",
              "DeparturePlatformName": {"value": "string"}
            }
          }
        }]
      }]
    }
  }
}
```

**Key Response Fields**:
- `ExpectedArrivalTime`: Next vehicle arrival time (ISO8601)
- `ExpectedDepartureTime`: Next vehicle departure time (ISO8601)
- `DestinationName`: Final destination of the service
- `DepartureStatus`: "onTime", "early", "delayed", etc.
- `DeparturePlatformName`: Platform identifier

## Error Responses
Standard HTTP error codes:
- `400`: Bad Request - Invalid MonitoringRef format
- `401`: Unauthorized - Invalid or missing API key  
- `429`: Too Many Requests - Rate limit exceeded
- `500`: Internal Server Error - Service unavailable

## Rate Limits & Quotas
Based on API documentation:
- **Legacy users** (API key before March 2024): 100 req/sec, 1M daily
- **New users** (API key after March 2024): 5 req/sec, 1,000 daily
- Our key: `r1NDADYoOpUH6qS5XkJoPhiRrNjPpee5` (development key)

## Client Implementation Contract

### PRIMClient Interface
```swift
protocol PRIMClientProtocol {
    func getNextDepartures(stopAreaId: String, lineRef: String?) async throws -> PRIMResponse
    func isConfigured() -> Bool
}

struct PRIMRequest {
    let stopAreaId: String      // e.g., "STIF:StopArea:SP:47900:"
    let lineRef: String?        // Optional line filter
}

struct PRIMResponse {
    let departures: [Departure]
    let responseTimestamp: Date
}

struct Departure {
    let lineName: String
    let destinationName: String
    let expectedDepartureTime: Date
    let departureStatus: String
    let platformName: String
}

class PRIMClient: PRIMClientProtocol {
    private let apiKey = "r1NDADYoOpUH6qS5XkJoPhiRrNjPpee5"
    private let baseURL = "https://prim.iledefrance-mobilites.fr/marketplace"
    
    func getNextDepartures(stopAreaId: String, lineRef: String?) async throws -> PRIMResponse {
        // Implementation with URLSession
        // Parse SIRI Lite JSON response
        // Handle rate limiting and errors
    }
}
```

### Timeout & Retry Policy
- Request timeout: 15 seconds (network can be slow)
- Retry attempts: 2 with exponential backoff (2s, 4s)
- Rate limiting: Respect 5 requests/second limit for new users
- Circuit breaker: Disable for 10 minutes after 3 consecutive failures

### Mock Provider Contract
```swift
class MockPRIMClient: PRIMClientProtocol {
    func getNextDepartures(stopAreaId: String, lineRef: String?) async throws -> PRIMResponse {
        let now = Date()
        var departures: [Departure] = []
        
        switch stopAreaId {
        case "STIF:StopArea:SP:47900:": // Val de Fontenay (API Testing Validated)
            if lineRef == nil || lineRef == "STIF:Line::C01742:" {
                // RER A departures every 2-5 minutes (real API pattern)
                departures.append(contentsOf: [
                    Departure(
                        lineName: "RER A",
                        destinationName: "Saint-Germain-en-Laye", // Real destination from API
                        expectedDepartureTime: now.addingTimeInterval(180), // 3 min
                        departureStatus: "onTime",
                        platformName: "1"
                    ),
                    Departure(
                        lineName: "RER A", 
                        destinationName: "Le Vésinet - Le Pecq", // Real destination from API
                        expectedDepartureTime: now.addingTimeInterval(300), // 5 min
                        departureStatus: "onTime",
                        platformName: "1"
                    ),
                    Departure(
                        lineName: "RER A",
                        destinationName: "Rueil-Malmaison", // Real destination from API
                        expectedDepartureTime: now.addingTimeInterval(420), // 7 min
                        departureStatus: "onTime",
                        platformName: "1"
                    )
                ])
            }
            
        case "STIF:StopArea:SP:46543:": // Cimetière de Vincennes (API Testing Validated)
            if lineRef == nil || lineRef == "STIF:Line::C01151:" {
                // Bus 122 departures (real API data pattern)
                departures.append(contentsOf: [
                    Departure(
                        lineName: "Bus 122",
                        destinationName: "Gallieni", // Real destination from API
                        expectedDepartureTime: now.addingTimeInterval(420), // 7 min
                        departureStatus: "onTime",
                        platformName: "A"
                    ),
                    Departure(
                        lineName: "Bus 122",
                        destinationName: "Val-de-Fontenay <RER>", // Real destination from API
                        expectedDepartureTime: now.addingTimeInterval(660), // 11 min
                        departureStatus: "onTime",
                        platformName: "A"
                    )
                ])
            }
            if lineRef == nil || lineRef == "STIF:Line::C01156:" {
                // Bus C01156 departures (discovered via API testing)
                departures.append(Departure(
                    lineName: "Bus C01156", 
                    destinationName: "Place de la Résistance", // Real destination from API
                    expectedDepartureTime: now.addingTimeInterval(540), // 9 min
                    departureStatus: "onTime",
                    platformName: "B"
                ))
            }
            
        default:
            // Return empty for unknown stops
            break
        }
        
        return PRIMResponse(departures: departures, responseTimestamp: now)
    }
}
```

## Usage for Transportation Recommendations

### Data Processing Strategy (Validated via API Testing)
PRIM provides real-time transit departures with high accuracy. Based on testing results:

1. **Get next bus/train departures** from nearby stops using PRIM API
   - Departures are real-time and current (tested: 3.8 minutes ahead accuracy)
   - Consistent ISO 8601 timestamps in UTC format
   - Rich metadata including destination names, platform info, onTime status
2. **Calculate walking time** using CoreLocation distance + average walking speed (1.4 m/s)
3. **Compare options** locally to generate Walk/Bus/Tie recommendation
4. **Apply confidence scoring** based on data freshness and departure status
   - `onTime` departures: 0.9 confidence
   - `delayed` departures: 0.6 confidence
   - API failure fallback: 0.3 confidence

### Stop Area Mapping & Transit Reference Data

#### Confirmed Stop Areas & Lines (API Testing Validated)
```swift
// RER Lines (Tested: Val de Fontenay returns 81 monitored stops)
static let RER_A = "STIF:Line::C01742:"

// Bus Lines (Tested: Returns real departure data)
static let BUS_122 = "STIF:Line::C01151:"   // 4 departures found with destinations
static let BUS_124 = "STIF:Line::C01153:"
static let BUS_C01156 = "STIF:Line::C01156:" // Discovered via testing

// Major Stop Areas (API Validated)
static let VAL_DE_FONTENAY_RER = "STIF:StopArea:SP:47900:"      // RER A hub - 81 stops
static let CIMETIERE_DE_VINCENNES_AREA = "STIF:StopArea:SP:46543:" // Bus lines 122, C01156

// Individual Stop Points (Tested: More specific than areas)
static let CIMETIERE_DE_VINCENNES_STOP = "STIF:StopPoint:Q:7807:" // Returns 6 monitored stops
```

#### Direction Reference (API Testing Confirmed)
- **RER A Westbound**: "Cergy le Haut • Poissy • Saint-Germain-en-Laye"
  - Tested destinations: "Saint-Germain-en-Laye", "Le Vésinet - Le Pecq", "Rueil-Malmaison"
  - Departure frequency: ~2-5 minutes during peak hours
- **RER A Eastbound**: "Boissy-Saint-Léger • Marne-la-Vallée – Chessy"
- **Bus 122**: Destinations include "Gallieni", "Val-de-Fontenay <RER>" (bi-directional)
- **Bus C01156**: "Place de la Résistance" destination confirmed but not needed for this app just for development purposes

#### Usage Examples
```swift
// Get all RER A departures from Val de Fontenay
let rerDepartures = try await primClient.getNextDepartures(
    stopAreaId: "STIF:StopArea:SP:47900:",
    lineRef: "STIF:Line::C01742:"
)

// Get Bus 122 departures from Cimetière de Vincennes
let busDepartures = try await primClient.getNextDepartures(
    stopAreaId: "STIF:StopArea:SP:46543:",
    lineRef: "STIF:Line::C01151:"
)

// Get all transit options from a stop area (no line filter)
let allDepartures = try await primClient.getNextDepartures(
    stopAreaId: "STIF:StopArea:SP:47900:",
    lineRef: nil
)
```

## Security Requirements
- API key stored in iOS Keychain (production) / hardcoded (development)
- HTTPS-only communication (enforced by PRIM API)
- Location data used only for transit stop lookup
- User opt-in required before first API call
- Clear data usage disclosure in privacy settings

## Practical Implementation Guide

### 1. Location-to-Transit Mapping
```swift
func findNearestTransitOptions(from location: CLLocation) -> [TransitOption] {
    // Map user location to relevant transit stops
    let valDeFontenayLocation = CLLocation(latitude: 48.8584, longitude: 2.4551)
    let cimetiereLocation = CLLocation(latitude: 48.8471, longitude: 2.4125)
    
    var options: [TransitOption] = []
    
    if location.distance(from: valDeFontenayLocation) < 1000 { // Within 1km
        options.append(TransitOption(
            stopAreaId: "STIF:StopArea:SP:47900:",
            name: "Val de Fontenay RER",
            walkingTimeSeconds: Int(location.distance(from: valDeFontenayLocation) / 1.4), // 1.4 m/s walking speed
            lines: ["STIF:Line::C01742:"] // RER A
        ))
    }
    
    if location.distance(from: cimetiereLocation) < 800 { // Within 800m
        options.append(TransitOption(
            stopAreaId: "STIF:StopArea:SP:46543:",
            name: "Cimetière de Vincennes",
            walkingTimeSeconds: Int(location.distance(from: cimetiereLocation) / 1.4),
            lines: ["STIF:Line::C01151:", "STIF:Line::C01153:"] // Bus 122, 124
        ))
    }
    
    return options
}
```

### 2. Decision Logic Implementation
```swift
func generateRecommendation(from origin: CLLocation, to destination: CLLocation) async -> Recommendation {
    // Calculate walking time
    let walkingDistance = origin.distance(from: destination)
    let walkingTimeMinutes = Int(walkingDistance / 83.3) // 5 km/h average walking speed
    
    // Find transit options
    let transitOptions = findNearestTransitOptions(from: origin)
    
    var bestTransitTime: Int? = nil
    var confidence: Double = 0.5
    
    for option in transitOptions {
        do {
            let departures = try await primClient.getNextDepartures(
                stopAreaId: option.stopAreaId,
                lineRef: option.lines.first
            )
            
            if let nextDeparture = departures.departures.first {
                let waitTimeMinutes = Int(nextDeparture.expectedDepartureTime.timeIntervalSinceNow / 60)
                let walkToStopMinutes = option.walkingTimeSeconds / 60
                let estimatedTripMinutes = estimateTransitTripTime(
                    from: option,
                    to: destination,
                    line: nextDeparture.lineName
                )
                
                let totalTransitTime = walkToStopMinutes + waitTimeMinutes + estimatedTripMinutes
                bestTransitTime = min(bestTransitTime ?? Int.max, totalTransitTime)
                confidence = max(confidence, nextDeparture.departureStatus == "onTime" ? 0.9 : 0.6)
            }
        } catch {
            // PRIM API failed, use local estimates
            confidence = 0.3
        }
    }
    
    // Generate recommendation
    let mode: TransportationMode
    if let transitTime = bestTransitTime {
        if walkingTimeMinutes <= transitTime + 5 { // 5-minute buffer
            mode = walkingTimeMinutes < transitTime - 5 ? .walk : .tie
        } else {
            mode = .bus
        }
    } else {
        mode = .walk
    }
    
    return Recommendation(
        mode: mode,
        walkETA: walkingTimeMinutes,
        busETA: bestTransitTime,
        confidence: confidence,
        timestamp: Date(),
        source: bestTransitTime != nil ? .primAPI : .localHeuristics
    )
}
```

### 3. Testing with Real Data (Validated September 30, 2025)
```bash
# Test RER A from Val de Fontenay (✅ Working - Returns 81 monitored stops)
curl -X 'GET' \
  'https://prim.iledefrance-mobilites.fr/marketplace/stop-monitoring?MonitoringRef=STIF%3AStopArea%3ASP%3A47900%3A&LineRef=STIF%3ALine%3A%3AC01742%3A' \
  -H 'accept: application/json' \
  -H 'apikey: r1NDADYoOpUH6qS5XkJoPhiRrNjPpee5'

# Test Bus 122 from Cimetière de Vincennes (✅ Working - Returns 4 real departures)
curl -X 'GET' \
  'https://prim.iledefrance-mobilites.fr/marketplace/stop-monitoring?MonitoringRef=STIF%3AStopArea%3ASP%3A46543%3A&LineRef=STIF%3ALine%3A%3AC01151%3A' \
  -H 'accept: application/json' \
  -H 'apikey: r1NDADYoOpUH6qS5XkJoPhiRrNjPpee5'

# Test All Departures from a Stop Area (✅ Working - Returns multiple transit lines)
curl -X 'GET' \
  'https://prim.iledefrance-mobilites.fr/marketplace/stop-monitoring?MonitoringRef=STIF%3AStopArea%3ASP%3A47900%3A' \
  -H 'accept: application/json' \
  -H 'apikey: r1NDADYoOpUH6qS5XkJoPhiRrNjPpee5'

# Results Summary:
# - Real-time departures with 3-4 minute accuracy
# - Rich destination and platform information
# - Consistent onTime status reporting
# - Multiple transit options per stop area
```

## Integration Points
- **DecisionEngine**: Uses PRIM departure data + local walking calculations for recommendations
- **ContentViewModel**: Shows data source (PRIM real-time vs. local estimates)  
- **AppSettings**: Controls PRIM API enable/disable, stop configuration
- **LocationService**: Maps current location to nearby PRIM stop areas using the reference data above
- **Debug Controls**: Switch between real/mock PRIM client, test different stops and lines