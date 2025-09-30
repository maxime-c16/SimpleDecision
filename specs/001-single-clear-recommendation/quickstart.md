# Quickstart Guide: Transportation Recommendation App

**Last Updated**: 2025-09-30  
**Purpose**: Rapid development setup and validation workflow

## Prerequisites
- Xcode 15.0+ 
- iOS 16.1+ deployment target
- macOS Sonoma+ for development
- Active Apple Developer account (for device testing)

## Quick Setup (5 minutes)

### 1. Project Configuration
```bash
# Open existing Xcode project
cd /Users/baki/max_perso/simpleDecision
open simpleDecision.xcodeproj

# Verify project settings:
# - iOS Deployment Target: 16.1
# - Bundle Identifier: unique identifier
# - Signing: Automatic signing enabled
```

### 2. Add Required Capabilities
In Xcode project settings:
- [ ] Background Modes: None needed (foreground only)
- [ ] Location Services: NSLocationWhenInUseUsageDescription
- [ ] Live Activities: Push Notifications capability

### 3. Update Info.plist
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Location access is needed to calculate travel times and provide transportation recommendations.</string>
```

## Rapid Development Workflow

### Phase 1: Basic UI (30 minutes)
1. **Update ContentView.swift**:
   - Add RecommendationView placeholder
   - Show mock recommendation data
   - Add debug controls section

2. **Test checkpoint**: App launches showing static recommendation

### Phase 2: Location Integration (45 minutes)  
1. **Create LocationService**:
   - Request permission on first launch
   - Get current location
   - Add basic destination management

2. **Test checkpoint**: App shows location permission dialog and gets current location

### Phase 3: Decision Engine (30 minutes)
1. **Create DecisionEngine**:
   - Simple ETA comparison logic
   - Mock ETA calculation based on distance
   - Generate recommendations

2. **Test checkpoint**: App shows dynamic recommendations based on location

### Phase 4: Live Activities (45 minutes)
1. **Create ActivityManager**:
   - iOS 16.1+ Live Activity support
   - Fallback for older versions
   - Debug controls for testing

2. **Test checkpoint**: Live Activities appear on lock screen (device only)

### Phase 5: PRIM Integration (60 minutes) - API Validated ✅
1. **Create PRIMClient** (Real API Integration):
   - HTTP client using validated endpoints and real data patterns
   - API key: `r1NDADYoOpUH6qS5XkJoPhiRrNjPpee5` (working development key)
   - Keychain storage for production keys
   - Mock provider with real API response structures
   - Rate limiting: 5 req/sec for new API keys

2. **Test checkpoint**: 
   - Real PRIM API calls return transit departures ✅
   - Mock provider matches real API response format ✅
   - Decision engine combines transit + walking data for recommendations ✅

## Quick Validation Tests

### App Launch Test
```
1. Tap app icon
2. App opens in < 1 second ✅
3. Shows recommendation immediately ✅
4. No crashes or errors ✅
```

### Location Permission Test
```
1. First launch prompts for location ✅
2. Grant permission → shows current location ✅  
3. Deny permission → shows manual entry ✅
4. Manual entry works correctly ✅
```

### Recommendation Logic Test
```
1. Mock walking ETA: 10 min, bus ETA: 15 min
2. Recommendation shows "Walk" ✅
3. Mock walking ETA: 20 min, bus ETA: 8 min  
4. Recommendation shows "Bus" ✅
5. Equal ETAs show "Tie" ✅
```

### Live Activities Test (Device Required)
```
1. Open app on iOS 16.1+ device
2. Tap "Start Activity" in debug controls ✅
3. Lock screen shows Live Activity ✅
4. Dynamic Island shows compact info ✅
5. Tap "End Activity" removes Live Activity ✅
```

### PRIM Integration Test
```
1. Enable PRIM in settings ✅
2. Enter mock API key ✅
3. Recommendation shows "PRIM" source ✅
4. Disable PRIM → falls back to "Local" ✅
5. Network error → shows fallback warning ✅
```

## Development Shortcuts

### Mock Data Setup
```swift
// Add to ContentView for quick testing
#if DEBUG
private let mockRecommendations = [
    Recommendation(mode: .walk, walkETA: 12, busETA: 15, confidence: 0.8, timestamp: Date(), source: .mock),
    Recommendation(mode: .bus, walkETA: 18, busETA: 8, confidence: 0.9, timestamp: Date(), source: .mock),
    Recommendation(mode: .tie, walkETA: 10, busETA: 10, confidence: 0.5, timestamp: Date(), source: .mock)
]
#endif
```

### Debug Menu
```swift
// Quick debug controls in ContentView
#if DEBUG
VStack {
    Button("Mock Walk Recommendation") { /* update recommendation */ }
    Button("Mock Bus Recommendation") { /* update recommendation */ }
    Button("Start Live Activity") { /* start activity */ }
    Button("End Live Activity") { /* end activity */ }
    Button("Test Location Error") { /* simulate error */ }
}
#endif
```

### Simulator vs Device Testing
- **Simulator**: All features except Live Activities
- **Device**: Full feature testing including ActivityKit
- **Xcode Previews**: UI components only, no location/network

## Common Issues & Quick Fixes

### App Won't Launch
- Check iOS deployment target (16.1+)
- Verify signing configuration
- Clean build folder (Cmd+Shift+K)

### Location Permission Issues
- Reset simulator (Device → Erase All Content and Settings)
- Check Info.plist has NSLocationWhenInUseUsageDescription
- Verify location permission request code

### Live Activities Not Working
- Test on physical device only (not simulator)
- Check iOS version is 16.1+
- Verify Focus settings allow Live Activities
- Check app has Push Notifications capability

### PRIM API Connection Issues (Updated with Real API Knowledge)
- Use mock provider for initial testing (matches real API response structure)
- Real API validated and working (development key: `r1NDADYoOpUH6qS5XkJoPhiRrNjPpee5`)
- Rate limiting: 5 requests/second for new keys (avoid exceeding)
- Response format: SIRI Lite JSON with ISO 8601 timestamps
- Test endpoints: Val de Fontenay RER (SP:47900), Cimetière de Vincennes (SP:46543)
- Common response: Real departures 2-5 minutes ahead with accurate timing

## Success Criteria Checklist

**MVP Requirements**:
- [ ] App launches in < 1 second
- [ ] Shows recommendation (Walk/Bus/Tie) immediately
- [ ] Displays walk and bus ETAs
- [ ] Shows confidence score (0.0-1.0)
- [ ] Location permission handling works
- [ ] Manual location entry fallback works
- [ ] Live Activities work on device (iOS 16.1+)
- [ ] Debug controls allow manual testing
- [ ] PRIM API integration is optional and toggleable
- [ ] Graceful fallback to local heuristics
- [ ] No crashes on simulator or device

**Ready for Production When**:
- All checklist items above pass ✅
- App tested on multiple iOS versions
- Location services work reliably
- Live Activities tested on device
- PRIM integration handles errors gracefully
- User experience is smooth and intuitive