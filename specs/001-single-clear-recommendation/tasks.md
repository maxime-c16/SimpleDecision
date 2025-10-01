# Tasks: Transportation Mode Recommendation with Live Activities

**Input**: Design documents from `/Users/baki/max_perso/simpleDecision/specs/001-single-clear-recommendation/`
**Prerequisites**: plan.md (required), research.md, data-model.md, contracts/

## Execution Flow (main)
```
1. Load plan.md from feature directory ✓
   → Tech stack: Swift 5.9+, SwiftUI, ActivityKit, CoreLocation, Keychain Services
   → Structure: iOS Xcode project with MVVM architecture
2. Load optional design documents ✓:
   → data-model.md: Recommendation, LocationData, PRIMResponse entities
   → contracts/: PRIM API, Live Activities, Location Services contracts
   → research.md: Technical decisions and implementation patterns
3. Generate tasks by category ✓:
   → Setup: project structure, Info.plist, capabilities
   → Tests: minimal testing per user request - basic framework only
   → Core: models, services, view models, views
   → Integration: PRIM API, location services, live activities
   → Polish: validation, error handling, debug controls
4. Apply task rules ✓:
   → Different files = mark [P] for parallel
   → Same file = sequential (no [P])
   → Models before services, services before view models
5. Number tasks sequentially (T001, T002...) ✓
6. Generate dependency graph ✓
7. Create parallel execution examples ✓
8. Validate task completeness ✓:
   → All contracts have implementation tasks
   → All entities have model tasks
   → All view components implemented
9. Return: SUCCESS (tasks ready for execution)
```

## Format: `[ID] [P?] Description`
- **[P]**: Can run in parallel (different files, no dependencies)
- Include exact file paths in descriptions

## Path Conventions
- **iOS Project**: `simpleDecision/` (Xcode project directory)
- Update existing files: `ContentView.swift`, `simpleDecisionApp.swift`
- New directories: `Models/`, `Services/`, `ViewModels/`, `Views/`, `Managers/`

## Phase 3.1: Setup
- [x] T001 Create directory structure: Models/, Services/, ViewModels/, Views/, Managers/ in simpleDecision/
- [x] T002 Update main app Info.plist with NSLocationWhenInUseUsageDescription and NSSupportsLiveActivities
- [x] T003 Create Widget Extension target named "TransportationRecommendationWidget" with Live Activities support

## Phase 3.2: Core Models (Foundation Layer)
**CRITICAL: Core data structures MUST be implemented before services**
- [x] T004 [P] Create Recommendation model in simpleDecision/Models/Recommendation.swift
- [x] T005 [P] Create LocationData model in simpleDecision/Models/LocationData.swift
- [x] T006 [P] Create PRIMResponse and Departure models in simpleDecision/Models/PRIMResponse.swift
- [x] T007 [P] Create AppSettings model in simpleDecision/Models/AppSettings.swift

## Phase 3.3: Service Layer (Business Logic)
- [x] T008 [S] Create LocationService in simpleDecision/Services/LocationService.swift
- [x] T009 [S] Create PRIMClient in simpleDecision/Services/PRIMClient.swift
- [x] T010 [S] Create DecisionEngine in simpleDecision/Services/DecisionEngine.swift
- [x] T011 [S] Create ActivityManager in simpleDecision/Services/ActivityManager.swift
- [x] T012 [S] Create BackgroundScheduler in simpleDecision/Services/BackgroundScheduler.swift

## Phase 3.4: MVVM Integration
- [x] T013 [V] Create MainViewModel in simpleDecision/ViewModels/MainViewModel.swift
- [x] T014 Update existing ContentView.swift to display recommendations and integrate ContentViewModel
- [x] T015 [P] Create RecommendationView component in simpleDecision/Views/RecommendationView.swift
- [x] T016 [P] Create DebugControlsView for Live Activities testing in simpleDecision/Views/DebugControlsView.swift

## Phase 3.5: API Integration
- [x] T017 Implement real PRIM API client with validated endpoints in PRIMClient.swift (update existing file)
- [x] T018 Add Keychain storage for PRIM API keys in PRIMClient.swift (update existing file)
- [x] T019 Add rate limiting and retry logic (5 req/sec) in PRIMClient.swift (update existing file)
- [x] T020 Integrate LocationService with permission handling in DecisionEngine.swift (update existing file)

## Phase 3.6: Live Activities Integration  
- [ ] T021 Create ActivityKit data structures (Attributes & ContentState) in simpleDecision/Models/LiveActivityModels.swift
- [ ] T022 Implement Widget Extension with Dynamic Island support in TransportationRecommendationWidget/Widget.swift
- [ ] T023 [P] Create Live Activity UI views in TransportationRecommendationWidget/Views/ directory
- [ ] T024 Update ActivityManager with official ActivityKit patterns in ActivityManager.swift (update existing file)
- [ ] T025 Connect ActivityManager to ContentViewModel for automatic updates in ContentViewModel.swift (update existing file)

## Phase 3.7: Polish & Validation
- [ ] T026 Add input validation for location coordinates and API responses in DecisionEngine.swift (update existing file)
- [ ] T027 [P] Implement error handling and user-friendly messages in ContentViewModel.swift (update existing file)
- [ ] T028 [P] Add confidence scoring based on departure status in DecisionEngine.swift (update existing file)
- [ ] T029 Add debug controls integration to main UI in ContentView.swift (update existing file)
- [ ] T030 Validate <1 second app launch performance and optimize if needed in simpleDecisionApp.swift (update existing file)

## Dependencies
- Setup (T001-T003) before models (T004-T007)
- Models (T004-T007) before services (T008-T012)
- Services (T008-T012) before view models (T013)
- View models (T013) before view updates (T014-T016)
- Core implementation (T004-T016) before API integration (T017-T020)
- API integration (T017-T020) before Live Activities (T021-T025)
- Widget Extension target (T003) required before Widget tasks (T022-T023)
- ActivityKit models (T021) before Widget implementation (T022-T025)
- Implementation before polish (T026-T030)

## Parallel Example
```
# Launch T004-T007 together (different model files):
Task: "Create Recommendation model in simpleDecision/Models/Recommendation.swift"
Task: "Create LocationData model in simpleDecision/Models/LocationData.swift"
Task: "Create PRIMResponse and Departure models in simpleDecision/Models/PRIMResponse.swift"
Task: "Create AppSettings model in simpleDecision/Models/AppSettings.swift"

# Launch T008-T009, T011-T012 together (different service files):
Task: "Create LocationService with CoreLocation integration in simpleDecision/Services/LocationService.swift"
Task: "Create PRIMClient with mock provider in simpleDecision/Services/PRIMClient.swift"
Task: "Create ActivityManager with iOS 16.1+ availability checks in simpleDecision/Managers/ActivityManager.swift"
Task: "Create BackgroundScheduler for 30-second refresh cycle in simpleDecision/Managers/BackgroundScheduler.swift"

# Widget Extension tasks (T023 can run in parallel with other phases):
Task: "Create Live Activity UI views in TransportationRecommendationWidget/Views/ directory"
```

## Notes
- [P] tasks = different files, no dependencies
- Update existing files (ContentView.swift, simpleDecisionApp.swift) rather than replace
- Minimal testing per user request - focus on working implementation
- PRIM API integration uses validated endpoints and real development API key
- Live Activities require iOS 16.1+ device testing (not available in simulator)
- Commit after each task completion

## Task Generation Rules
*Applied during main() execution*

1. **From Contracts**:
   - PRIM API contract → PRIMClient implementation (T009, T017-T019)
   - Live Activities contract → Widget Extension + ActivityManager implementation (T003, T021-T025)
   - Location Services contract → LocationService implementation (T008, T020)
   
2. **From Data Model**:
   - Recommendation entity → T004 model creation
   - LocationData entity → T005 model creation  
   - PRIMResponse entity → T006 model creation
   - AppSettings entity → T007 model creation
   - ActivityKit models → T021 Live Activity data structures
   
3. **From Quickstart Scenarios**:
   - Phase 1 mock UI → T014, T015 view implementation
   - Phase 2 location integration → T008, T020 location services
   - Phase 3 decision engine → T010, T026, T028 business logic
   - Phase 4 Live Activities → T003, T021-T025 Widget Extension + ActivityKit integration
   - Phase 5 PRIM integration → T009, T017-T019 API client

4. **Ordering**:
   - Setup (including Widget Extension) → Models → Services → ViewModels → Views → Integration → Polish
   - Widget Extension target required before Widget implementation tasks
   - Dependencies prevent parallel execution where files are shared

## Validation Checklist
*GATE: Checked before task execution*

- [x] All contracts have corresponding implementation tasks
- [x] All entities have model creation tasks  
- [x] All services come before view models that depend on them
- [x] Parallel tasks truly independent (different files)
- [x] Each task specifies exact file path
- [x] No task modifies same file as another [P] task (except planned updates)

## Implementation Notes

### Key Technical Requirements
- **Performance**: <1 second app launch (T030)
- **Refresh Rate**: 30-second update cycle (T012)
- **API Integration**: Real PRIM endpoints with rate limiting (T017-T019)  
- **Live Activities**: Widget Extension target with iOS 16.1+ Dynamic Island support (T003, T021-T025)
- **Privacy**: Location permission handling and API opt-in (T020)

### Widget Extension Architecture
- **Separate Target**: TransportationRecommendationWidget extension required
- **ActivityKit Integration**: Official Apple patterns with Activity.request() and update() methods
- **UI Components**: Lock screen and Dynamic Island presentations
- **No Push Notifications**: Simpler app-only updates (no server required)
- **Device Testing**: Live Activities don't appear in simulator (physical device required)

### Real API Details (Validated)
- **PRIM API Key**: `r1NDADYoOpUH6qS5XkJoPhiRrNjPpee5` (development)
- **Rate Limit**: 5 requests/second for new API keys
- **Test Endpoints**: Val de Fontenay (SP:47900), Cimetière de Vincennes (SP:46543)
- **Response Format**: SIRI Lite JSON with ISO 8601 timestamps

### Architecture Pattern
- **MVVM**: ObservableObject ViewModels with @Published properties
- **Progressive Enhancement**: Local heuristics → PRIM API when available
- **Error Handling**: Graceful fallback with user-friendly messages
- **Confidence Scoring**: Based on real departure status ("onTime" = 0.9, "delayed" = 0.6)