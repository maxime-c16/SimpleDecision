# Feature Specification: Transportation Mode Recommendation with Live Activities

**Feature Branch**: `001-single-clear-recommendation`  
**Created**: 2025-09-30  
**Status**: Draft  
**Input**: User description: "single clear recommendation (Walk|Bus|Tie) + walkETA + busETA + confidence; device-first with Live Activities (iOS 16.1+) ; PRIM API integration ASAP (opt-in, secure key storage, mock provider, fallback to local heuristics). Audience & Use-cases: commuter making quick decisions; keep UI minimal and fast. MVP UI: main screen with RecommendationView (recommendation, ~m walk ETA, ~m bus ETA, confidence), optional Details button, debug playground to Start/Update/End Live Activity. Data contract: { mode: \"Walk\"|\"Bus\"|\"Tie\", walkETA:Int?|null, busETA:Int?|null, confidence:Float(0.0-1.0), timestamp:ISO8601 }. PRIM response: { predictedMode, etaWalkSeconds, etaBusSeconds, confidenceScore, inferenceTimestamp, modelVersion }. PRIM client: async predict(request:), secure Keychain keys, exponential backoff, mock provider; merge strategy: use PRIM when confidenceScore > 0.7 else merge/fallback. Architecture: SwiftUI + MVVM, DecisionEngine (PRIM + heuristics), ActivityManager (ActivityKit guarded + no-op fallback), BackgroundScheduler. Non-functional: fast startup, privacy-first, minimal dependencies. Fast-iteration roadmap: (0) constitution+spec, (1) wire RecommendationView+ContentViewModel with mock data and show debug controls in main UI, (2) ensure ActivityManager and debug buttons work on device, (3) add PRIMClient skeleton + mock provider + opt-in UI, (4) wire DecisionEngine to use PRIM and fallback, (5) README with device run checklist & enable Live Activities. Acceptance: app launches showing static/mock recommendation; debug buttons control ActivityManager; PRIM pluggable and optional; compile/run on simulator and iOS device with guarded ActivityKit."

## Execution Flow (main)
```
1. Parse user description from Input ✓
   → Feature description provided: transportation mode recommendation system
2. Extract key concepts from description ✓
   → Actors: commuters, PRIM API service
   → Actions: display recommendation, show ETAs, update Live Activities
   → Data: transportation mode, walking/bus ETAs, confidence scores
   → Constraints: iOS 16.1+, minimal UI, fast startup, privacy-first
3. For each unclear aspect: ✓
   → No major clarifications needed - description is comprehensive
4. Fill User Scenarios & Testing section ✓
   → Clear user flow: commuter opens app → sees recommendation → acts on it
5. Generate Functional Requirements ✓
   → Each requirement is testable and measurable
6. Identify Key Entities ✓
   → Recommendation, ETA data, confidence metrics identified
7. Run Review Checklist ✓
   → No implementation details in requirements
   → All business value focused
8. Return: SUCCESS (spec ready for planning)
```

---

## Clarifications

### Session 2025-09-30
- Q: How does the app determine the user's current location and destination for calculating recommendations? → A: Automatic location detection (GPS) with preset destinations
- Q: What should happen when GPS location permission is denied or unavailable? → A: Show error message and require manual location entry
- Q: How often should the app refresh recommendations and ETA data? → A: Every 30 seconds while app is active
- Q: What is the maximum acceptable app launch time for "fast startup"? → A: Under 1 second from tap to first screen
- Q: When the PRIM API is unavailable, what local heuristics should determine the recommendation? → A: Always recommend the faster ETA option with API unavailability notification

---

## User Scenarios & Testing

### Primary User Story
As a daily commuter in Île-de-France, I want to quickly see whether I should walk or take transit (RER/bus) to my destination, along with estimated travel times and how confident the system is in its recommendation, so I can make fast, informed transportation decisions using real-time transit departure data.

### Acceptance Scenarios
1. **Given** I open the app, **When** the app loads, **Then** I see a clear recommendation (Walk, Bus, or Tie) with estimated travel times for both options and a confidence level
2. **Given** I receive a recommendation, **When** I want more information, **Then** I can optionally view additional details about the recommendation
3. **Given** I'm using iOS 16.1 or later, **When** a recommendation is made, **Then** I can see Live Activity updates on my lock screen and Dynamic Island showing real-time transportation information
4. **Given** I enable the PRIM API integration, **When** the system makes recommendations, **Then** it uses external prediction data when confidence is high, otherwise falls back to local heuristics
5. **Given** I'm using the debug mode, **When** I interact with debug controls, **Then** I can manually start, update, and end Live Activities to test the feature

### Edge Cases
- What happens when both walking and bus ETAs are unavailable or equal?
- How does the system handle network failures when trying to access the PRIM API?
- What occurs when Live Activities are not supported on the device?
- How does the app behave during first launch with no historical data?

## Requirements

### Functional Requirements
- **FR-001**: System MUST display a single, clear transportation mode recommendation (Walk, Bus, or Tie)
- **FR-001a**: System MUST automatically detect user's current location via GPS
- **FR-001b**: System MUST allow users to configure preset destination locations
- **FR-002**: System MUST show estimated travel time in minutes for walking when available
- **FR-003**: System MUST show estimated travel time in minutes for bus when available  
- **FR-004**: System MUST display a confidence score between 0.0 and 1.0 for each recommendation
- **FR-005**: System MUST provide Live Activities support for iOS 16.1+ devices showing real-time recommendation updates
- **FR-006**: System MUST support optional PRIM API integration with user opt-in capability
- **FR-007**: System MUST securely store API keys when PRIM integration is enabled
- **FR-008**: System MUST provide mock data functionality for testing and development
- **FR-009**: System MUST fall back to recommending the faster ETA option when PRIM API is unavailable or returns low confidence scores (< 0.7)
- **FR-009a**: System MUST display notification to user when PRIM API is unavailable and fallback heuristics are being used
- **FR-010**: System MUST launch in under 1 second from tap to first screen display
- **FR-010a**: System MUST refresh recommendations every 30 seconds while app is in foreground
- **FR-011**: System MUST provide debug controls for testing Live Activities (start, update, end)
- **FR-012**: System MUST maintain user privacy by keeping API usage optional and secure
- **FR-013**: System MUST work on both iOS simulator and physical devices
- **FR-014**: System MUST gracefully handle cases where Live Activities are not supported
- **FR-015**: System MUST display clear error message when location permission is denied
- **FR-016**: System MUST provide manual location entry fallback when GPS is unavailable

### Key Entities
- **Recommendation**: Contains the suggested transportation mode (Walk/Bus/Tie), confidence level, and timestamp of when the recommendation was generated
- **ETA Data**: Walking and bus estimated travel times in minutes, can be null when unavailable
- **PRIM Response**: External API response containing real-time transit departure data (not direct recommendations), includes departure times, destinations, line information, and departure status from Île-de-France Mobilités
- **Live Activity**: Real-time display component showing current recommendation status on lock screen and Dynamic Island

---

## Review & Acceptance Checklist

### Content Quality
- [x] No implementation details (languages, frameworks, APIs)
- [x] Focused on user value and business needs
- [x] Written for non-technical stakeholders
- [x] All mandatory sections completed

### Requirement Completeness
- [x] No [NEEDS CLARIFICATION] markers remain
- [x] Requirements are testable and unambiguous  
- [x] Success criteria are measurable
- [x] Scope is clearly bounded

---

## Execution Status

- [x] User description parsed
- [x] Key concepts extracted
- [x] Ambiguities marked
- [x] User scenarios defined
- [x] Requirements generated
- [x] Entities identified
- [x] Review checklist passed

---
