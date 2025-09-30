
# Implementation Plan: Transportation Mode Recommendation with Live Activities

**Branch**: `001-single-clear-recommendation` | **Date**: 2025-09-30 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/Users/baki/max_perso/simpleDecision/specs/001-single-clear-recommendation/spec.md`

## Execution Flow (/plan command scope)
```
1. Load feature spec from Input path
   → If not found: ERROR "No feature spec at {path}"
2. Fill Technical Context (scan for NEEDS CLARIFICATION)
   → Detect Project Type from file system structure or context (web=frontend+backend, mobile=app+api)
   → Set Structure Decision based on project type
3. Fill the Constitution Check section based on the content of the constitution document.
4. Evaluate Constitution Check section below
   → If violations exist: Document in Complexity Tracking
   → If no justification possible: ERROR "Simplify approach first"
   → Update Progress Tracking: Initial Constitution Check
5. Execute Phase 0 → research.md
   → If NEEDS CLARIFICATION remain: ERROR "Resolve unknowns"
6. Execute Phase 1 → contracts, data-model.md, quickstart.md, agent-specific template file (e.g., `CLAUDE.md` for Claude Code, `.github/copilot-instructions.md` for GitHub Copilot, `GEMINI.md` for Gemini CLI, `QWEN.md` for Qwen Code or `AGENTS.md` for opencode).
7. Re-evaluate Constitution Check section
   → If new violations: Refactor design, return to Phase 1
   → Update Progress Tracking: Post-Design Constitution Check
8. Plan Phase 2 → Describe task generation approach (DO NOT create tasks.md)
9. STOP - Ready for /tasks command
```

**IMPORTANT**: The /plan command STOPS at step 7. Phases 2-4 are executed by other commands:
- Phase 2: /tasks command creates tasks.md
- Phase 3-4: Implementation execution (manual or via tools)

## Summary
Primary requirement: Build a fast-launch iOS app that provides clear transportation recommendations (Walk/Bus/Tie) with ETAs and confidence scores. Features Live Activities integration for iOS 16.1+, optional PRIM API integration with secure storage, and debug controls for testing. Technical approach: SwiftUI + MVVM architecture with minimal dependencies, existing ContentView.swift and simpleDecisionApp.swift files as foundation, progressive enhancement from local heuristics to PRIM API predictions.

## Technical Context  
**Language/Version**: Swift 5.9+ (iOS 16.1+ target, backwards compatible)  
**Primary Dependencies**: SwiftUI, ActivityKit, CoreLocation, Keychain Services, Foundation URLSession  
**Storage**: UserDefaults for settings, Keychain for API keys, no persistent database needed  
**Testing**: Minimal testing per user request - basic framework only  
**Target Platform**: iOS 16.1+ (Live Activities), graceful degradation for earlier versions  
**Project Type**: mobile - single Xcode project structure  
**Performance Goals**: <1 second app launch, 30-second data refresh cycle  
**Constraints**: Privacy-first design, minimal dependencies, device-first development  
**Scale/Scope**: Single-user commuter app, ~5 main screens, PRIM API integration optional

**User Context**: Fast iteration app with simple implementation, PRIM API support, basic tools only, no comprehensive testing, update existing ContentView.swift and simpleDecisionApp.swift files in current Xcode project structure.

## Constitution Check
*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

**Minimal, actionable UX**: ✅ Single recommendation (Walk/Bus/Tie) + two ETAs on main screen  
**Predictable data flow**: ✅ MVVM with ObservableObject view models, immutable value types  
**Progressive enhancement**: ✅ Works offline with local heuristics, PRIM API enhances when available  
**Build for device-first**: ✅ Live Activities for iOS 16.1+, graceful degradation  
**Safety & privacy**: ✅ Explicit PRIM API opt-in, secure Keychain storage, location permissions only when needed  
**Keep it small**: ✅ Native APIs only (SwiftUI, ActivityKit, CoreLocation), minimal dependencies  

**MVP Scope Alignment**: ✅ Core recommendation + ETAs + confidence, Live Activities, offline behavior, debug panel  
**Architecture Alignment**: ✅ SwiftUI + MVVM + ActivityManager + BackgroundScheduler as specified  
**Platform Target**: ✅ iOS 16.1+ with backwards compatibility  
**Data Contract**: ✅ Matches specification - Recommendation with mode/ETAs/confidence/timestamp  

**Constitutional Compliance**: PASS - No violations detected

## Project Structure

### Documentation (this feature)
```
specs/[###-feature]/
├── plan.md              # This file (/plan command output)
├── research.md          # Phase 0 output (/plan command)
├── data-model.md        # Phase 1 output (/plan command)
├── quickstart.md        # Phase 1 output (/plan command)
├── contracts/           # Phase 1 output (/plan command)
└── tasks.md             # Phase 2 output (/tasks command - NOT created by /plan)
```

### Source Code (repository root)
```
simpleDecision/ (Xcode project - existing files to be updated)
├── simpleDecisionApp.swift     # Main app entry point (existing)
├── ContentView.swift           # Main UI view (existing, to be updated)
├── Views/                      # New directory for additional views
│   ├── RecommendationView.swift
│   └── DebugControlsView.swift
├── Models/                     # New directory for data models
│   ├── Recommendation.swift
│   ├── ETAData.swift
│   └── PRIMResponse.swift
├── ViewModels/                 # New directory for MVVM
│   └── ContentViewModel.swift
├── Services/                   # New directory for business logic
│   ├── DecisionEngine.swift
│   ├── PRIMClient.swift
│   └── LocationService.swift
├── Managers/                   # New directory for system integrations
│   ├── ActivityManager.swift
│   └── BackgroundScheduler.swift
└── Assets.xcassets/           # Existing assets directory
    ├── AccentColor.colorset/
    ├── AppIcon.appiconset/
    └── Contents.json

simpleDecision.xcodeproj/      # Existing Xcode project structure
├── project.pbxproj
└── [existing Xcode metadata]
```

**Structure Decision**: Mobile iOS app structure using existing Xcode project. Will extend current ContentView.swift and simpleDecisionApp.swift files, adding organized subdirectories for new components following MVVM architecture. No separate API project needed - PRIM integration via URLSession client.

## Phase 0: Outline & Research
1. **Extract unknowns from Technical Context** above:
   - For each NEEDS CLARIFICATION → research task
   - For each dependency → best practices task
   - For each integration → patterns task

2. **Generate and dispatch research agents**:
   ```
   For each unknown in Technical Context:
     Task: "Research {unknown} for {feature context}"
   For each technology choice:
     Task: "Find best practices for {tech} in {domain}"
   ```

3. **Consolidate findings** in `research.md` using format:
   - Decision: [what was chosen]
   - Rationale: [why chosen]
   - Alternatives considered: [what else evaluated]

**Output**: research.md with all NEEDS CLARIFICATION resolved

## Phase 1: Design & Contracts
*Prerequisites: research.md complete*

1. **Extract entities from feature spec** → `data-model.md`:
   - Entity name, fields, relationships
   - Validation rules from requirements
   - State transitions if applicable

2. **Generate API contracts** from functional requirements:
   - For each user action → endpoint
   - Use standard REST/GraphQL patterns
   - Output OpenAPI/GraphQL schema to `/contracts/`

3. **Generate contract tests** from contracts:
   - One test file per endpoint
   - Assert request/response schemas
   - Tests must fail (no implementation yet)

4. **Extract test scenarios** from user stories:
   - Each story → integration test scenario
   - Quickstart test = story validation steps

5. **Update agent file incrementally** (O(1) operation):
   - Run `.specify/scripts/bash/update-agent-context.sh copilot`
     **IMPORTANT**: Execute it exactly as specified above. Do not add or remove any arguments.
   - If exists: Add only NEW tech from current plan
   - Preserve manual additions between markers
   - Update recent changes (keep last 3)
   - Keep under 150 lines for token efficiency
   - Output to repository root

**Output**: data-model.md, /contracts/*, failing tests, quickstart.md, agent-specific file

## Phase 2: Task Planning Approach
*This section describes what the /tasks command will do - DO NOT execute during /plan*

**Task Generation Strategy** (Updated with API Validation):
- Update existing ContentView.swift and simpleDecisionApp.swift files
- Create new Swift files in organized directory structure 
- Models first (Recommendation, Departure, PRIMResponse with real API structures)
- Services layer (DecisionEngine with transit+walking logic, PRIMClient with validated endpoints, LocationService)
- Managers (ActivityManager, BackgroundScheduler)
- ViewModels (ContentViewModel)
- Views (RecommendationView, DebugControlsView)
- PRIM integration with real API key and tested endpoints (Val de Fontenay, Cimetière de Vincennes)
- Integration and manual validation steps

**Ordering Strategy**:
- Foundation first: Data models and core services
- Business logic: DecisionEngine with local heuristics
- UI updates: ContentView integration with mock data
- Advanced features: Location services, Live Activities
- PRIM integration: API client and settings
- Final integration and testing

**Estimated Output**: 15-20 focused tasks prioritizing fast iteration and minimal dependencies

**Key Constraints from User Requirements** (Updated with API Reality):
- Update existing ContentView.swift and simpleDecisionApp.swift files
- No comprehensive testing framework 
- Fast iteration approach with basic tools only
- PRIM API support with validated working integration (real endpoints + mock provider)
- Real API key available for development: `r1NDADYoOpUH6qS5XkJoPhiRrNjPpee5`
- Rate limiting: 5 req/sec (new API keys) - respect in implementation
- Minimal dependencies and simple implementation

**IMPORTANT**: This phase is executed by the /tasks command, NOT by /plan

## Phase 3+: Future Implementation
*These phases are beyond the scope of the /plan command*

**Phase 3**: Task execution (/tasks command creates tasks.md)  
**Phase 4**: Implementation (execute tasks.md following constitutional principles)  
**Phase 5**: Validation (run tests, execute quickstart.md, performance validation)

## Complexity Tracking
*Fill ONLY if Constitution Check has violations that must be justified*

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| [e.g., 4th project] | [current need] | [why 3 projects insufficient] |
| [e.g., Repository pattern] | [specific problem] | [why direct DB access insufficient] |


## Progress Tracking
*This checklist is updated during execution flow*

**Phase Status**:
- [x] Phase 0: Research complete (/plan command)
- [x] Phase 1: Design complete (/plan command)
- [x] Phase 2: Task planning complete (/plan command - describe approach only)
- [ ] Phase 3: Tasks generated (/tasks command)
- [ ] Phase 4: Implementation complete
- [ ] Phase 5: Validation passed

**Gate Status**:
- [x] Initial Constitution Check: PASS
- [x] Post-Design Constitution Check: PASS
- [x] All NEEDS CLARIFICATION resolved
- [x] Complexity deviations documented (none required)

**Artifacts Generated**:
- [x] research.md - Technical decisions and patterns
- [x] data-model.md - Core entities and relationships
- [x] contracts/prim-api.md - PRIM API integration contract
- [x] contracts/live-activities.md - ActivityKit integration contract  
- [x] contracts/location-services.md - CoreLocation integration contract
- [x] quickstart.md - Development workflow and validation
- [x] .github/copilot-instructions.md - Updated agent context

---
*Based on Constitution v2.1.1 - See `/memory/constitution.md`*
