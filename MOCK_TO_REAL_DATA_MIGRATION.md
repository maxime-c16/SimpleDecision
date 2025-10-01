# Mock Data to Real Data Migration Guide

## Summary

The app currently uses mock data in several places for development. This document outlines how to systematically replace mock data with real data.

## ✅ What's Already Using Real Data

- **LocationService**: Uses real GPS location data
- **PRIM API Client**: Makes real API calls to PRIM service
- **Weather Integration**: Uses real weather data
- **Activity Kit**: Uses real Live Activities

## 🔄 What Still Uses Mock Data (Needs Replacement)

### 1. **Destinations** (PRIORITY 1)

**Current State:**
- `MainViewModel.swift` line 115: `availableDestinations = LocationData.mockDestinations`
- `DestinationViewModel.swift` line 75: `destinations = LocationData.mockDestinations`

**Solution:**
```swift
// Replace with saved destinations from UserDefaults
private func loadSavedDestinations() {
    if let savedData = UserDefaults.standard.data(forKey: "savedDestinations"),
       let saved = try? JSONDecoder().decode([Destination].self, from: savedData) {
        availableDestinations = saved
    } else {
        availableDestinations = [] // Start empty
    }
}

// Save when destinations change
func saveDestinations() {
    if let encoded = try? JSONEncoder().encode(availableDestinations) {
        UserDefaults.standard.set(encoded, forKey: "savedDestinations")
    }
}
```

### 2. **Mock Recommendations in Widget** (PRIORITY 2)

**Current State:**
- `SharedModels.swift` lines 88-113: `mockWalk`, `mockBus`, `mockTie` static properties

**Action:**
- Keep these for **Preview purposes only**
- Never use in production code
- These are okay to keep for SwiftUI previews

**Files Currently Using Mock Recommendations:**
- ✅ `RecommendationView.swift` lines 338-348: **Previews only** - OK to keep
- ❌ `DecisionEngine.swift` line 157: **REMOVE** - use real fallback
- ❌ `RecommendationViewModel.swift` line 302: **REMOVE** - use real fallback

### 3. **Fallback Recommendations** (PRIORITY 3)

**Files to Update:**

#### `DecisionEngine.swift` line 157:
```swift
// BEFORE:
) ?? Recommendation.mockWalk

// AFTER:
) ?? Recommendation(
    mode: .walk,
    walkETA: Int(distance / 80), // 80m/min walking speed
    busETA: nil,
    confidence: 0.5,
    timestamp: Date(),
    source: .fallback
)
```

#### `RecommendationViewModel.swift` line 302:
```swift
// BEFORE:
return Recommendation.mockWalk

// AFTER:
return Recommendation(
    mode: .walk,
    walkETA: nil,
    busETA: nil,
    confidence: 0.3,
    timestamp: Date(),
    source: .fallback
)
```

### 4. **PRIM API Mock Responses** (PRIORITY 4)

**Current State:**
- `PRIMClient.swift` line 92: Returns mock PRIM response on API failure
- `PRIMClient.swift` line 106: Returns mock nearby stops
- `PRIMClient.swift` line 149: `mockPRIMResponse()` function

**Solution:**
```swift
// Replace mock fallback with empty data:
.catch { [weak self] error -> AnyPublisher<PRIMResponse, Error> in
    self?.lastError = error.localizedDescription
    // Return empty response - let decision engine handle it
    return Just(PRIMResponse(departures: [], responseTimestamp: Date()))
        .setFailureType(to: Error.self)
        .eraseToAnyPublisher()
}

// For nearby stops - implement real API or return empty:
func findNearbyStops(...) -> AnyPublisher<[TransitStop], Error> {
    // TODO: Implement real PRIM stops API
    return Just([TransitStop]())
        .setFailureType(to: Error.self)
        .eraseToAnyPublisher()
}

// REMOVE: mockPRIMResponse() function entirely
```

### 5. **Mock Location Service** (KEEP FOR DEBUGGING)

**Current State:**
- `LocationService.swift` line 99: `setMockLocation()` method
- `DebugControlsView.swift`: Uses mock locations for testing

**Action:**
- **KEEP** these for debugging purposes
- Only accessible in debug builds
- Useful for testing without physically moving

### 6. **Settings Message** (PRIORITY 5)

**File:** `SettingsViewModel.swift` line 113

```swift
// BEFORE:
successMessage = "PRIM API disabled - using mock data"

// AFTER:
successMessage = "PRIM API disabled - transit features unavailable"
```

## 📝 Implementation Checklist

### Phase 1: Core Data (Do First)
- [ ] Replace `mockDestinations` with UserDefaults persistence in MainViewModel
- [ ] Replace `mockDestinations` with UserDefaults persistence in DestinationViewModel  
- [ ] Add `saveDestinations()` method to both ViewModels
- [ ] Add UI for users to add/remove destinations
- [ ] Test destination persistence across app restarts

### Phase 2: Fallback Logic (Do Second)
- [ ] Remove `Recommendation.mockWalk` from DecisionEngine.swift
- [ ] Remove `Recommendation.mockWalk` from RecommendationViewModel.swift
- [ ] Create proper fallback Recommendation objects with real calculations
- [ ] Test error handling when PRIM API fails

### Phase 3: PRIM Cleanup (Do Third)
- [ ] Remove mock PRIM response fallback
- [ ] Remove mock nearby stops
- [ ] Delete `mockPRIMResponse()` function
- [ ] Update settings message
- [ ] Test behavior when PRIM API is unavailable

### Phase 4: Testing & Validation (Do Last)
- [ ] Test with no internet connection
- [ ] Test with no saved destinations
- [ ] Test with PRIM API disabled
- [ ] Test with failed PRIM API calls
- [ ] Verify Live Activities work with real data
- [ ] Test all error states

## 🚫 Do NOT Remove (Keep for Development)

1. **Mock Recommendations in SharedModels.swift** - Used for SwiftUI Previews
2. **Mock Location in LocationService** - Used for debugging
3. **Debug Controls** - Used for testing
4. **Preview data in RecommendationView** - Used for Xcode previews

## ⚠️ Important Notes

1. **UserDefaults vs Core Data**: For now, use UserDefaults for destinations. Consider Core Data if destinations grow complex.

2. **Migration Path**: When deploying to users who have mock data:
   - App should detect first launch
   - Clear any mock destinations
   - Show onboarding to add real destinations

3. **Fallback Strategy**: Always have a graceful fallback:
   - No destinations → Show "Add Destination" flow
   - No PRIM data → Fall back to walking recommendation
   - No location → Show "Enable Location" prompt

4. **Testing**: Test in this order:
   - Happy path (everything works)
   - No internet
   - No permissions
   - No saved data
   - API failures

## 🎯 Priority Order

1. **HIGH**: Destinations persistence (users need to save their places)
2. **HIGH**: Remove mock fallbacks (prevent showing wrong data)
3. **MEDIUM**: PRIM cleanup (improve error handling)
4. **LOW**: Settings messages (cosmetic)
5. **KEEP**: Debug/Preview mocks (developer tools)

## 📊 Impact Assessment

### After Migration:
- ✅ App shows only real, user-entered destinations
- ✅ Recommendations based on actual PRIM API data or calculated fallbacks
- ✅ No mock data confusion in production
- ✅ Clear error messages when services unavailable
- ✅ Debug tools still available for development

### User Experience:
- First launch: Prompted to add destinations
- No destinations: Clear CTA to add one
- API failures: Graceful fallback to walking
- Offline: Walking recommendations still work

---

**Created:** October 1, 2025  
**Status:** Migration plan ready for implementation  
**Next Step:** Implement Phase 1 - Destinations Persistence
