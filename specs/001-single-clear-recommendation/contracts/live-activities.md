# Live Activities Contract

**Version**: 3.0  
**Last Updated**: 2025-09-30  
**Purpose**: Define simplified Live Activities integration for transportation recommendations using ActivityKit

## ActivityKit Architecture (Simplified for Our App)

### Core Components (Required)
1. **ActivityAttributes**: Static data that doesn't change (destination, start location)
2. **ContentState**: Dynamic data that gets updated (recommendation, ETAs, confidence)  
3. **Widget Extension**: UI presentation logic (separate target required)
4. **Activity Management**: Start/update/end activities from main app only (no push notifications)

### Push Notifications Strategy: **NOT USED** 
**Rationale**: Keeping implementation simple for fast iteration
- No remote notification server setup required
- No push token management needed  
- No APNs payload construction required
- Updates only when app is active (sufficient for commuter use case)

## ActivityKit Data Contract

### Activity Attributes (Static Data)
```swift
import ActivityKit

struct TransportationRecommendationAttributes: ActivityAttributes {
    public typealias ContentState = TransportationRecommendationContentState
    
    // Static data - set once when activity starts
    let destinationName: String
    let startLocationName: String
}
```

### Content State (Dynamic Data)
```swift
struct TransportationRecommendationContentState: Codable, Hashable {
    // Dynamic data - updated during activity lifecycle
    let recommendedMode: String     // "Walk", "Bus", or "Tie"
    let walkETAMinutes: Int?       // nil if unavailable
    let busETAMinutes: Int?        // nil if unavailable
    let confidenceScore: Double    // 0.0 to 1.0
    let lastUpdated: Date
    let dataSource: String         // "PRIM", "Local", "Mock"
    
    // For Dynamic Island presentation
    var primaryETA: Int? {
        switch recommendedMode {
        case "Walk": return walkETAMinutes
        case "Bus": return busETAMinutes
        default: return walkETAMinutes // Tie defaults to walk
        }
    }
    
    var recommendationColor: String {
        switch recommendedMode {
        case "Walk": return "green"
        case "Bus": return "blue" 
        case "Tie": return "orange"
        default: return "gray"
        }
    }
}
```

## Widget Extension Required

### Extension Target Setup
Live Activities require a **separate Widget Extension target** in Xcode:
1. Add new target: File → New → Target → Widget Extension
2. Name: `TransportationRecommendationWidget`
3. Include configuration intent: No (simpler)
4. Supports Live Activities: Yes

### Widget Implementation
```swift
// In Widget Extension target
import ActivityKit
import WidgetKit
import SwiftUI

@main
struct TransportationRecommendationWidget: Widget {
    let kind: String = "TransportationRecommendationWidget"

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TransportationRecommendationAttributes.self) { context in
            // Lock Screen / Banner UI
            RecommendationLockScreenView(context: context)
        } dynamicIsland: { context in
            // Dynamic Island UI
            DynamicIsland {
                // Expanded UI
                DynamicIslandExpandedRegion(.leading) {
                    RecommendationIconView(mode: context.state.recommendedMode)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    RecommendationETAView(context: context)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    RecommendationDetailView(context: context)
                }
            } compactLeading: {
                // Compact leading
                RecommendationIconView(mode: context.state.recommendedMode)
            } compactTrailing: {
                // Compact trailing  
                Text("\(context.state.primaryETA ?? 0)m")
                    .font(.caption2)
                    .fontWeight(.semibold)
            } minimal: {
                // Minimal
                RecommendationIconView(mode: context.state.recommendedMode)
            }
        }
    }
}
```

## ActivityManager Interface (App-Only Updates)

### Simple Activity Management (No Push Notifications)
```swift
protocol ActivityManagerProtocol {
    func startActivity(destinationName: String, startLocationName: String, recommendation: Recommendation) async -> Bool
    func updateActivity(with recommendation: Recommendation) async -> Bool
    func endAllActivities() async -> Bool
    func isActivitySupported() -> Bool
    func hasActiveActivities() -> Bool
}

@available(iOS 16.1, *)
class LiveActivityManager: ActivityManagerProtocol {
    private var currentActivity: Activity<TransportationRecommendationAttributes>?
    
    func startActivity(destinationName: String, startLocationName: String, recommendation: Recommendation) async -> Bool {
        let attributes = TransportationRecommendationAttributes(
            destinationName: destinationName,
            startLocationName: startLocationName
        )
        
        let contentState = TransportationRecommendationContentState(
            recommendedMode: recommendation.mode.rawValue,
            walkETAMinutes: recommendation.walkETA,
            busETAMinutes: recommendation.busETA,
            confidenceScore: recommendation.confidence,
            lastUpdated: recommendation.timestamp,
            dataSource: recommendation.source.rawValue
        )
        
        do {
            // Simple Activity.request without push notifications
            currentActivity = try Activity.request(
                attributes: attributes,
                content: ActivityContent(
                    state: contentState, 
                    staleDate: Date().addingTimeInterval(120) // 2 minutes staleness
                )
            )
            return true
        } catch {
            print("Failed to start Live Activity: \(error)")
            return false
        }
    }
    
    func updateActivity(with recommendation: Recommendation) async -> Bool {
        guard let activity = currentActivity else { return false }
        
        let updatedState = TransportationRecommendationContentState(
            recommendedMode: recommendation.mode.rawValue,
            walkETAMinutes: recommendation.walkETA,
            busETAMinutes: recommendation.busETA,
            confidenceScore: recommendation.confidence,
            lastUpdated: recommendation.timestamp,
            dataSource: recommendation.source.rawValue
        )
        
        await activity.update(
            ActivityContent(
                state: updatedState,
                staleDate: Date().addingTimeInterval(120)
            )
        )
        return true
    }
    
    func endAllActivities() async -> Bool {
        guard let activity = currentActivity else { return false }
        
        await activity.end(nil, dismissalPolicy: .immediate)
        currentActivity = nil
        return true
    }
    
    func isActivitySupported() -> Bool {
        return ActivityAuthorizationInfo().areActivitiesEnabled
    }
    
    func hasActiveActivities() -> Bool {
        return currentActivity != nil
    }
}

class NoOpActivityManager: ActivityManagerProtocol {
    // Fallback implementation for iOS < 16.1
    func startActivity(destinationName: String, startLocationName: String, recommendation: Recommendation) async -> Bool { false }
    func updateActivity(with recommendation: Recommendation) async -> Bool { false }
    func endAllActivities() async -> Bool { false }
    func isActivitySupported() -> Bool { false }
    func hasActiveActivities() -> Bool { false }
}
```

## Live Activity UI Views (Widget Extension)

### Lock Screen View
```swift
struct RecommendationLockScreenView: View {
    let context: ActivityViewContext<TransportationRecommendationAttributes>
    
    var body: some View {
        HStack(spacing: 16) {
            // Mode icon
            RecommendationIconView(mode: context.state.recommendedMode)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Go to \(context.attributes.destinationName)")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                HStack(spacing: 12) {
                    if let walkETA = context.state.walkETAMinutes {
                        ETAView(icon: "figure.walk", time: walkETA, isRecommended: context.state.recommendedMode == "Walk")
                    }
                    if let busETA = context.state.busETAMinutes {
                        ETAView(icon: "bus", time: busETA, isRecommended: context.state.recommendedMode == "Bus")
                    }
                }
                
                Text("Confidence: \(Int(context.state.confidenceScore * 100))% • \(context.state.dataSource)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(16)
    }
}
```

### Dynamic Island Views
```swift
struct RecommendationIconView: View {
    let mode: String
    
    var body: some View {
        Image(systemName: iconName)
            .foregroundColor(iconColor)
            .font(.system(size: 16, weight: .semibold))
    }
    
    private var iconName: String {
        switch mode {
        case "Walk": return "figure.walk"
        case "Bus": return "bus"
        case "Tie": return "arrow.left.arrow.right"
        default: return "questionmark"
        }
    }
    
    private var iconColor: Color {
        switch mode {
        case "Walk": return .green
        case "Bus": return .blue
        case "Tie": return .orange
        default: return .gray
        }
    }
}
```

### Update Frequency & Lifecycle  
- **Update Interval**: Every 30 seconds while app is active
- **Background Behavior**: No updates when app backgrounded (no background app refresh)
- **Automatic End**: Activity ends after 8 hours (iOS system limit) or when manually ended
- **Stale Date**: Set to 1 minute after last update to indicate freshness

## Activity Lifecycle (Simplified App-Only Pattern)

### Start Activity (No Push Notifications)
```swift
// Simple ActivityKit pattern - app updates only
let attributes = TransportationRecommendationAttributes(
    destinationName: "Work",
    startLocationName: "Current Location"
)

let initialContentState = TransportationRecommendationContentState(
    recommendedMode: "Bus",
    walkETAMinutes: 15,
    busETAMinutes: 8,
    confidenceScore: 0.85,
    lastUpdated: Date(),
    dataSource: "PRIM"
)

do {
    // No pushType parameter = app-only updates (simpler)
    let activity = try Activity.request(
        attributes: attributes,
        content: ActivityContent(
            state: initialContentState,
            staleDate: Date().addingTimeInterval(120) // 2 minutes staleness
        )
    )
} catch {
    print("Failed to start Live Activity: \(error)")
}
```

### Update Activity (30-second Intervals)
```swift
// Update every 30 seconds while app is active
Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
    Task {
        let updatedContentState = TransportationRecommendationContentState(
            recommendedMode: newRecommendation.mode.rawValue,
            walkETAMinutes: newRecommendation.walkETA,
            busETAMinutes: newRecommendation.busETA,
            confidenceScore: newRecommendation.confidence,
            lastUpdated: Date(),
            dataSource: newRecommendation.source.rawValue
        )

        await activity.update(
            ActivityContent(
                state: updatedContentState,
                staleDate: Date().addingTimeInterval(120)
            )
        )
    }
}
```

### End Activity (Simple Pattern)
```swift
// End when user reaches destination or closes app
await activity.end(nil, dismissalPolicy: .immediate)

// Or end all transportation activities
for activity in Activity<TransportationRecommendationAttributes>.activities {
    await activity.end(nil, dismissalPolicy: .immediate)
}
```

### Activity Authorization Check
```swift
// Check if Live Activities are enabled by user
let authInfo = ActivityAuthorizationInfo()
if authInfo.areActivitiesEnabled {
    // Start Live Activity
} else {
    // Show in-app UI only (graceful fallback)
}
```

## Error Handling

### ActivityKit Unavailable
- Fall back to NoOpActivityManager
- Show alternative UI feedback in app
- No error messages to user (graceful degradation)

### Activity Permission Denied
- Respect user choice
- Continue with in-app recommendations only
- Provide settings link for permission change

### Activity Limit Reached
- End oldest activity before starting new
- Log warning for debugging
- Continue normal app functionality

## Debug Interface Contract
```swift
protocol DebugActivityControlsProtocol {
    func manualStartActivity() async
    func manualUpdateActivity() async  
    func manualEndActivity() async
    func simulateActivityError() async
}
```

**Usage**: Debug panel in app for testing Live Activities on device without waiting for automatic triggers

## Required Project Setup (Simplified)

### 1. Widget Extension Target
```bash
# In Xcode:
# File → New → Target → Widget Extension
# Product Name: TransportationRecommendationWidget
# Include Configuration Intent: No
# Supports Live Activities: Yes
```

### 2. Info.plist Configuration (Essential Keys Only)
```xml
<!-- Main App Info.plist -->
<key>NSSupportsLiveActivities</key>
<true/>

<!-- Optional: For frequent updates (if needed later) -->
<key>NSSupportsLiveActivitiesFrequentUpdates</key>
<false/>

<!-- Widget Extension Info.plist (auto-configured by Xcode) -->
<key>NSExtension</key>
<dict>
    <key>NSExtensionPointIdentifier</key>
    <string>com.apple.widgetkit-extension</string>
</dict>
```

### 3. No Additional Setup Required
- ❌ **No Push Notifications capability needed**
- ❌ **No App Groups required** (no data sharing complexity)
- ❌ **No remote notification server setup**
- ❌ **No APNs certificates or keys**

## Platform Compatibility
- **iOS 16.1+**: Full Live Activities support with Dynamic Island
- **iOS 16.0**: ActivityKit available but no Dynamic Island
- **iOS < 16.0**: Compile with @available checks, no-op implementation
- **Simulator**: ActivityKit works but Live Activities don't appear (device testing required)

## Privacy & Permissions
- **No explicit permission required**: Live Activities are enabled by default
- **User control**: Users can disable in Settings → Face ID & Passcode → Live Activities
- **Data privacy**: No sensitive location data in Live Activity content (only ETAs and mode)
- **System limits**: Maximum 2 active Live Activities per app
- **Automatic cleanup**: System ends activities after 8 hours or when device restarts

## Implementation Approach: Simple & Fast

### Phase 1: App-Only Updates (Current Implementation)
**What We're NOT Using (For Simplicity)**
1. **❌ Push Notifications**: No server setup, APNs, or push tokens required
2. **❌ Push-to-Start**: No remote triggering of Live Activities  
3. **❌ Channel Management**: No channel IDs or broadcast capabilities
4. **❌ Frequent Updates Setting**: Standard update frequency is sufficient
5. **❌ Custom Relevance Scores**: System handles Dynamic Island priority
6. **❌ Complex Payload Construction**: No JSON payloads to APNs
7. **❌ Push Token Management**: No token retrieval or server-side handling

**What We're Using (Simplified)**
1. **✅ App-Only Updates**: Live Activities update when app is active (perfect for commuter use)
2. **✅ Basic ActivityKit**: `Activity.request()`, `activity.update()`, `activity.end()`
3. **✅ Simple UI**: Icons and text in Lock Screen and Dynamic Island
4. **✅ Authorization Check**: `ActivityAuthorizationInfo().areActivitiesEnabled`
5. **✅ Graceful Fallback**: No-op manager for iOS < 16.1
6. **✅ Debug Controls**: Manual start/stop for easy testing

**Benefits of This Approach**
- **Fast Development**: No server infrastructure needed
- **Simple Testing**: Works entirely on device
- **Reliable**: No network dependencies for Live Activity updates  
- **Privacy-Friendly**: No data sent to external servers
- **Battery Efficient**: Updates only when app is actively used
- **Perfect for Commuters**: Live Activities show current recommendation during active travel planning

### Phase 2: Future Enhancement (Push Notifications - If Needed)
**If later we need background updates, we could add:**
```swift
// Future: Push notification support
do {
    currentActivity = try Activity.request(
        attributes: attributes,
        content: ActivityContent(state: contentState, staleDate: staleDate),
        pushType: .token // Enable push notifications
    )
    
    // Monitor push token updates
    for await pushToken in currentActivity.pushTokenUpdates {
        // Send token to server for background updates
        await sendPushTokenToServer(pushToken)
    }
} catch {
    // Fallback to app-only updates
}
```

**Would require adding:**
- Push Notifications capability in Xcode
- `NSSupportsLiveActivitiesFrequentUpdates` in Info.plist  
- Server setup for APNs payloads
- Push token management and server integration

**Current decision: Not needed for MVP** - App-only updates are sufficient for transportation recommendations during active travel planning.