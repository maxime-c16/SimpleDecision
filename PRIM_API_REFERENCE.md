# PRIM API Documentation & Field Reference

**API:** Île-de-France Mobilités - PRIM (Platform for Regional Mobility Information)  
**Endpoint:** `https://prim.iledefrance-mobilites.fr/marketplace/stop-monitoring`  
**Format:** SIRI Lite (Service Interface for Real-time Information)  
**Dev API Key:** `r1NDADYoOpUH6qS5XkJoPhiRrNjPpee5`

## Rate Limits
- **New Users** (tokens after Mar 2024): 5 requests/second, 1,000/day
- **Legacy Users** (before Mar 2024): 100 requests/second, 1,000,000/day

---

## Stop & Line Reference Format

### Documented Examples

#### Lines (LineRef):
```
Bus 122:  STIF:Line::C01151:
Bus 124:  STIF:Line::C01153:
RER A:    STIF:Line::C01742:
```

#### Stops (MonitoringRef):
```
CIMETIERE_DE_VINCENNES (StopPoint):  STIF:StopPoint:Q:7807:
CIMETIERE_DE_VINCENNES (StopArea):   STIF:StopArea:SP:46543:
VAL_DE_FONTENAY_RER_A (StopArea):    STIF:StopArea:SP:47900:
```

**Format Pattern:**
- **Lines**: `STIF:Line::{code}:`
- **Stop Points**: `STIF:StopPoint:Q:{id}:`
- **Stop Areas**: `STIF:StopArea:SP:{id}:`

---

## API Request Structure

### Basic Request:
```bash
GET /stop-monitoring?MonitoringRef={stopId}&apikey={key}
```

### With Line Filter:
```bash
GET /stop-monitoring?MonitoringRef={stopId}&LineRef={lineId}&apikey={key}
```

### Example cURL:
```bash
curl "https://prim.iledefrance-mobilites.fr/marketplace/stop-monitoring?MonitoringRef=STIF:StopPoint:Q:41305:&apikey=r1NDADYoOpUH6qS5XkJoPhiRrNjPpee5"
```

---

## SIRI Lite Response Structure

### Response Envelope:
```json
{
  "Siri": {
    "ServiceDelivery": {
      "ResponseTimestamp": "2025-10-01T01:18:52.403Z",
      "ProducerRef": "IVTR_HET",
      "ResponseMessageIdentifier": "...",
      "StopMonitoringDelivery": [...]
    }
  }
}
```

### MonitoredStopVisit (Departure):
```json
{
  "MonitoredStopVisit": {
    "RecordedAtTime": "2025-10-01T10:30:00Z",
    "MonitoringRef": {
      "value": "STIF:StopPoint:Q:41305:"
    },
    "MonitoredVehicleJourney": {
      "LineRef": {
        "value": "STIF:Line::C01742:"
      },
      "DirectionRef": {
        "value": "aller"
      },
      "OperatorRef": {
        "value": "STIF:Operator::RATP:"
      },
      "FramedVehicleJourneyRef": {
        "DataFrameRef": {
          "value": "2025-10-01"
        },
        "DatedVehicleJourneyRef": "STIF:VehicleJourney::..."
      },
      "DirectionName": [
        {
          "value": "Cergy le Haut • Poissy • Saint-Germain-en-Laye"
        }
      ],
      "PublishedLineName": [
        {
          "value": "RER A"
        }
      ],
      "DestinationName": [
        {
          "value": "Saint-Germain-en-Laye"
        }
      ],
      "VehicleFeatureRef": [
        "accessibility"
      ],
      "MonitoredCall": {
        "StopPointName": [
          {
            "value": "Val de Fontenay"
          }
        ],
        "VehicleAtStop": false,
        "DestinationDisplay": [
          {
            "value": "Saint-Germain-en-Laye"
          }
        ],
        "ArrivalStatus": "onTime",
        "DepartureStatus": "onTime",
        "ExpectedDepartureTime": "2025-10-01T10:35:00Z",
        "AimedDepartureTime": "2025-10-01T10:35:00Z",
        "DeparturePlatformName": {
          "value": "1"
        },
        "Occupancy": "seatsAvailable"
      }
    }
  }
}
```

---

## Key Fields Mapping

### Our Model → PRIM API Fields

| Our Field | PRIM Path | Type | Example |
|-----------|-----------|------|---------|
| `lineName` | `PublishedLineName[0].value` | String | "RER A" |
| `lineRef` | `LineRef.value` | String | "STIF:Line::C01742:" |
| `destinationName` | `DestinationName[0].value` | String | "Saint-Germain-en-Laye" |
| `destinationRef` | `DestinationRef.value` | String | "STIF:StopPoint:Q:..." |
| `direction` | `DirectionName[0].value` | String | "Cergy • Poissy • St-Germain" |
| `expectedDepartureTime` | `MonitoredCall.ExpectedDepartureTime` | ISO8601 | "2025-10-01T10:35:00Z" |
| `departureStatus` | `MonitoredCall.DepartureStatus` | String | "onTime" / "delayed" / "early" |
| `platformName` | `MonitoredCall.DeparturePlatformName.value` | String | "1" / "Quai A" |
| `operatorRef` | `OperatorRef.value` | String | "STIF:Operator::RATP:" |
| `vehicleJourneyRef` | `FramedVehicleJourneyRef.DatedVehicleJourneyRef` | String | "STIF:VehicleJourney::..." |
| `delay` | Calculated from Expected - Aimed | Int (seconds) | 120 (2min delay) |
| `occupancy` | `MonitoredCall.Occupancy` | String | "seatsAvailable" / "standingRoomOnly" / "full" |
| `accessibility` | `VehicleFeatureRef` contains "accessibility" | Boolean | true/false |

---

## Occupancy Values

| PRIM Value | Meaning | Our Emoji |
|------------|---------|-----------|
| `seatsAvailable` | Seats available | 💺 |
| `standingRoomOnly` | Standing room only | 🧍 |
| `full` | Vehicle full | 🚫 |
| `notAcceptingPassengers` | Not accepting | ⛔ |

---

## Departure Status Values

| Status | Color | Meaning |
|--------|-------|---------|
| `onTime` | Green | On schedule |
| `delayed` | Orange | Running late |
| `early` | Blue | Ahead of schedule |
| `cancelled` | Red | Trip cancelled |
| `notExpected` | Gray | Not expected |

---

## Operators

| Operator Ref | Name | Services |
|--------------|------|----------|
| `STIF:Operator::RATP:` | RATP | Metro, Bus, Tram |
| `STIF:Operator::SNCF:` | SNCF | RER, Transilien |
| `STIF:Operator::OPTILE:` | Optile | Private buses |

---

## Data Sources

### Official Documentation:
- **API Docs**: https://prim.iledefrance-mobilites.fr/en/apis/idfm-ivtr-requete_unitaire
- **Stop Reference**: https://data.iledefrance-mobilites.fr/explore/dataset/arrets/
- **Line Reference**: https://data.iledefrance-mobilites.fr/explore/dataset/referentiel-des-lignes/

### Swagger/OpenAPI:
- **Contract**: https://prim.iledefrance-mobilites.fr/assets/apis/idfm-ivtr-requete_unitaire/swagger.json

---

## Example Responses

### Successful Response (with departures):
```json
{
  "Siri": {
    "ServiceDelivery": {
      "ResponseTimestamp": "2025-10-01T10:30:45.123Z",
      "StopMonitoringDelivery": [{
        "Status": "true",
        "MonitoredStopVisit": [
          {
            "MonitoredVehicleJourney": {
              "PublishedLineName": [{"value": "Bus 122"}],
              "DestinationName": [{"value": "Gare du Nord"}],
              "MonitoredCall": {
                "ExpectedDepartureTime": "2025-10-01T10:35:00Z",
                "DepartureStatus": "onTime",
                "Occupancy": "seatsAvailable"
              }
            }
          }
        ]
      }]
    }
  }
}
```

### Error Response (unknown stop):
```json
{
  "Siri": {
    "ServiceDelivery": {
      "StopMonitoringDelivery": [{
        "Status": "true",
        "ErrorCondition": {
          "ErrorInformation": {
            "ErrorText": "La requête contient des identifiants qui sont inconnus",
            "ErrorDescription": "Les paramètres ne peuvent contenir qu'un MonitoringRef..."
          }
        }
      }]
    }
  }
}
```

---

## Implementation Notes

### Stop ID Validation:
- Must start with `STIF:`
- Use `StopPoint:Q:` for individual stops
- Use `StopArea:SP:` for station areas (returns all platforms)
- Include trailing `:` in IDs

### Line Filtering:
- Optional `LineRef` parameter to filter by line
- Returns all lines if omitted
- Format: `STIF:Line::{code}:`

### Time Handling:
- All times in ISO 8601 UTC
- Convert to local time (Europe/Paris) for display
- Calculate delay: `ExpectedDepartureTime - AimedDepartureTime`

### Real-time Coverage:
- Not all stops have real-time data
- Check perimeter dataset for coverage
- Fallback to scheduled times when real-time unavailable

---

## Bonus Features to Extract

1. **Vehicle Features**: Accessibility, air conditioning, bike racks
2. **Arrival/Departure**: Separate arrival and departure times
3. **Platform Changes**: Compare aimed vs expected platform
4. **Call Status**: `VehicleAtStop` boolean
5. **Next Stops**: Journey pattern for upcoming stops
6. **Disruptions**: Service alerts and messages
7. **Vehicle Position**: Real-time location (lat/lon)
8. **Bearing**: Direction of travel

---

## Testing Strategy

### ✅ ACTUAL API TEST RESULTS (October 1, 2025)

**Working Test:**
```bash
curl -X 'GET' \
  'https://prim.iledefrance-mobilites.fr/marketplace/stop-monitoring?MonitoringRef=STIF%3AStopArea%3ASP%3A46543%3A' \
  -H 'accept: application/json' \
  -H 'apikey: r1NDADYoOpUH6qS5XkJoPhiRrNjPpee5'
```

**Confirmed Available Fields:**

✅ **Basic Info:**
- LineRef: "STIF:Line::C01398:"
- OperatorRef: "MeC_Bus_PC:Operator::100:"
- DirectionName: "Gare de Lyon"
- DirectionRef: "Aller" / "Retour"
- DestinationName: "Gare de Lyon - Maison de la Ratp"
- DestinationShortName: "Gare de Lyon"

✅ **Timing:**
- ExpectedDepartureTime: "2025-10-01T01:43:04.000Z"
- DepartureStatus: "onTime" (can be "delayed", "cancelled", etc.)
- VehicleAtStop: true/false

✅ **Journey Info:**
- FramedVehicleJourneyRef: Vehicle journey identifier
- TrainNumbers: For rail services
- VehicleJourneyName: Service name
- JourneyNote: Service notes/alerts

✅ **Features:**
- VehicleFeatureRef: Array of vehicle features (often empty)

❌ **NOT Available in API (Removed from Implementation):**
- Occupancy data (no field exists)
- Accessibility assessment (no wheelchair/step-free info)
- Real-time delay minutes (only status text)
- Extensions field

**Working Stop IDs:**
- STIF:StopArea:SP:46543: ✅
- STIF:StopPoint:Q:26416: ✅
- STIF:StopPoint:Q:7807: ✅

**Test Results:**
1. ✅ Valid stop with departures - WORKING
2. ✅ Valid stop with no departures - Returns empty array
3. ⚠️ Invalid stop ID - Returns error message
4. ✅ Stop with LineRef filter - WORKING
5. ✅ Real-time data - ExpectedDepartureTime provided
6. ❌ Accessibility - Not in API response
7. ❌ Occupancy - Not in API response
8. ⏸️ Delayed departures - Need to find delayed vehicle to test

### Known Working Examples:
```bash
# Add working examples here after successful tests
# Example: RER A at La Défense
# curl "https://prim.iledefrance-mobilites.fr/marketplace/stop-monitoring?MonitoringRef=STIF:StopArea:SP:...:&apikey=..."
```

---

## Future Enhancements

- [ ] Parse vehicle position for map display
- [ ] Extract full journey pattern (all stops)
- [ ] Service alerts integration
- [ ] Historical data analysis
- [ ] Multi-stop journey planning
- [ ] Platform change notifications
- [ ] Crowding predictions

---

**Last Updated:** October 1, 2025  
**API Version:** SIRI Lite 2.0  
**Status:** In Development - Need valid stop IDs for testing
