# PRIM API Integration Fixes Applied

## Date: October 2, 2025

## Summary
Fixed critical issues with PRIM API integration causing inaccurate data (showing night buses during daytime, wrong schedules).

## Root Causes Identified

1. **Hardcoded Stop Discovery**: `findNearbyStops()` returned static array of 3 stops for everyone
2. **Invalid Stop ID Format**: Trailing colons in stop IDs caused API rejection ("unknown identifier")
3. **Empty LineRef Parameter**: Sending empty `LineRef=""` caused API errors
4. **Mock Data Showing Night Buses**: Fallback data always showed N34 night bus regardless of time

## Fixes Applied

### 1. Dynamic Stop Discovery with Navitia API
**File**: `simpleDecision/Services/PRIMClient.swift`
- Replaced hardcoded stops with real Navitia `places_nearby` API call
- Uses `https://api.navitia.io/v1/coverage/fr-idf/coords/{lon};{lat}/places_nearby`
- Converts Navitia stop IDs to PRIM MonitoringRef format
- Falls back to known working stops (Nation, Châtelet) if API fails
- Implements proper distance calculation using CoreLocation

### 2. Fixed Stop ID Format
**File**: `simpleDecision/Services/PRIMClient.swift`
- Removes trailing colons from stop codes before API call
- PRIM API expects: `STIF:StopPoint:Q:42016` (not `STIF:StopPoint:Q:42016:`)
- Added stop ID cleaning: `stopCode.trimmingCharacters(in: CharacterSet(charactersIn: ":"))`

### 3. Removed Empty LineRef Parameter
**File**: `simpleDecision/Services/PRIMClient.swift`
- Removed `URLQueryItem(name: "LineRef", value: "")` which caused API rejection
- PRIM API returns all lines when LineRef is omitted (no need for empty value)

### 4. Time-Aware Mock Data
**File**: `simpleDecision/Services/PRIMClient.swift`
- Mock data now checks current time (6 AM - 10 PM = daytime)
- **Daytime**: Shows bus 124, RER A, bus 122, Metro 1
- **Nighttime**: Shows night buses N34, N11
- Realistic departure times and destinations

### 5. Added Navitia API Models
**File**: `simpleDecision/Models/PRIMResponse.swift`
- Added `NavitiaPlacesResponse`, `NavitiaPlace`, `NavitiaStopArea`, `NavitiaStopPoint`
- Added `NavitiaCoord` for coordinate parsing
- Updated `PRIMRequest` validation to accept IDs without trailing colons

### 6. Enhanced Error Handling
**File**: `simpleDecision/Services/PRIMClient.swift`
- Added `PRIMError.networkError(Error)` case for HTTP errors
- Added debugging logs: `print("🚌 PRIM API Request: ...")` 
- Better error messages for HTTP status codes

## API Documentation Sources Used

1. **PRIM stop-monitoring API**: `https://prim.iledefrance-mobilites.fr/marketplace/stop-monitoring`
   - Uses MonitoringRef parameter for stop ID
   - Requires API key authentication
   - Rate limits: 5 req/sec (new users)

2. **Navitia places_nearby API**: `https://api.navitia.io/v1/coverage/fr-idf/coords/{lon};{lat}/places_nearby`
   - Returns nearby stop_areas and stop_points
   - Requires API key in Authorization header
   - Used for dynamic stop discovery

## Testing Recommendations

1. **Test with Real Location**:
   - Enable location permissions
   - Walk near Paris transit (e.g., Nation, Châtelet, Gare de Lyon)
   - Verify correct nearby stops appear

2. **Test Time-Based Behavior**:
   - Check recommendations during daytime (6 AM - 10 PM)
   - Check recommendations during nighttime (10 PM - 6 AM)
   - Verify appropriate bus lines shown

3. **Test API Calls**:
   - Check Xcode console for `🚌 PRIM API Request:` logs
   - Verify HTTP 200 responses
   - Check for valid departure data

4. **Test Fallback**:
   - Disable network temporarily
   - Verify app shows mock data gracefully
   - Check fallback stops appear (Nation, Châtelet)

## Known Limitations

1. **API Key**: Currently using development API key with 5 req/sec, 1000 req/day limit
2. **Coverage**: Only works in Paris region (Île-de-France)
3. **Real-time Data**: Not all stops have real-time data available
4. **Stop ID Mapping**: Navitia → PRIM ID conversion may not work for all stop types

## Next Steps

1. ✅ Build succeeded
2. ⏭️ Test with real device in Paris
3. ⏭️ Monitor API logs for any rejection errors
4. ⏭️ Consider implementing Navitia journey planner for accurate bus ride times
5. ⏭️ Add HealthKit integration for personalized walking speed

## Files Modified

1. `/Users/baki/max_perso/simpleDecision/simpleDecision/Services/PRIMClient.swift`
2. `/Users/baki/max_perso/simpleDecision/simpleDecision/Models/PRIMResponse.swift`

## Build Status

✅ **BUILD SUCCEEDED** - All compilation errors fixed
