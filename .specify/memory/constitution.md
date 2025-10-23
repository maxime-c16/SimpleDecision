`/constitution - Establish project principles`

This document defines the core principles, priorities, and working agreements for the walkingBus app. Keep it short, actionable, and living — we will revisit it as requirements clarify.

## Purpose
- Help users choose the best way to get to a destination (walk vs bus) by providing clear, timely recommendations and estimated times.
- Focus on simple, reliable on-device UX with optional Live Activities for ongoing guidance.
- Integrate PRIM API as a first-class enhancement: request PRIM predictions when available to improve recommendation accuracy, with secure opt-in and key storage.
- **Provide real-time decision pulse**: Live Activities show dual-route comparison (walk vs bus+RER) with visual urgency indicators, enabling instant "at a glance" decisions without reading numbers.

## Core Principles
1. Minimal, actionable UX: surface exactly one clear recommendation at a time (Walk / Bus / Tie) and two ETAs.
2. Predictable data flow: single source of truth (lightweight view models) and deterministic state transitions.
3. Progressive enhancement: app works fully offline with local heuristics; network/PRIM improves accuracy when available.
4. Build for device-first: prioritize device behaviour (iPhone + Live Activities) over simulator-only features.
5. Safety & privacy: defaults favor privacy (no unnecessary location uploads), explicit consent for sharing data.
6. Keep it small: prefer native APIs and minimal dependencies to avoid brittle CI and signing issues.
7. **Visual intelligence over numbers**: Use color, animation, and haptics to convey urgency intuitively—users should understand the situation without reading text.

## Scope & Priorities (MVP)
- Core: present recommendation + walkETA + busETA + confidence indicator on main screen.
- Device feature: Live Activity integration to display active recommendation on lock screen / Dynamic Island (iOS 16.1+).
- Offline behavior: local ETA heuristics and simple cached network results.
- Developer ergonomics: a small debug panel to manually trigger Live Activities and mock recommendations.
 - Network & PRIM: PRIM API integration is a high priority — app should query PRIM for predictions when the user opts in; gracefully fall back to local heuristics when unavailable.

## Architecture & Patterns
- UI: SwiftUI for screens and modular views (ContentView, RecommendationView, DebugControls).
- State: MVVM with small ObservableObject view models for each screen; use immutable value types for model payloads.
- Background: a single BackgroundScheduler abstraction to refresh predictions when appropriate (low frequency).
- Live Activity: ActivityKit-backed `ActivityManager` with a safe no-op fallback for environments without ActivityKit.

## Platform & Compatibility
- Target: iOS 16.1+ for full Live Activities; support graceful degraded behaviour on earlier OS versions and macOS builds (compile guards).
- Language: Swift 5.0+ / modern Swift concurrency where useful (Task/async-await) but keep concurrency surface small and testable.

## Data Contract (short)
- Recommendation { mode: Walk|Bus|Tie, walkETA: seconds?, busETA: seconds?, confidence: 0.0-1.0, timestamp }
- The Activity content state mirrors this contract and must be serializable with Codable.

## Privacy & Permissions
- Only request Location permissions when needed; prefer approximate/coarse location where useful.
- Show a clear privacy notice for any data that will be uploaded.

## Error Handling & Resilience
- Fail gracefully: network failures revert to cached/local heuristics and show unobtrusive status.
- No crashes for ActivityKit absence: provide guarded implementations and notifications.

## Developer Workflow
- Keep the project simple: `main` branch for releases, short-lived feature branches, PRs for review.
- Commits: small, focused, and descriptive. Include one-line summary and short body for context.
- Use the scheme `walkingBus` as the canonical scheme; keep shared schemes minimal.

## Testing (lightweight)
- Manual & exploratory testing prioritized (we agreed to deprioritize heavy XCUITest initially).

## Observability
- Use lightweight console logs and NotificationCenter hooks for Activity lifecycle events during development.
- Add a simple in-app debug toggle to surface logs and to trigger manual refreshes / activity start/stop.

## Release & Entitlements
- Document steps needed to enable Live Activities (enable capability in Xcode, update provisioning profile) in the repo README.

## Deliverables & Short roadmap (first sprint)
1. Restore a clean project (done). Add `CONSTITUTION.md` (this file).
2. Wire `RecommendationView` + `ContentViewModel` with static/mock data and the debug controls (on-device ready).
3. Implement ActivityKit-backed `ActivityManager` (guarded) and wire debug buttons to it.
4. Add README with run-on-device checklist (capabilities + provisioning steps).
5. Implement PRIM client and integration (small, testable client, secure key storage, mocked responses for development). 

---

This is a short, living constitution. If you're happy with it I can:
- Commit it (done), and
- Follow up by wiring the debug control visibly into the main screen so you can tap it on device, or
- Add a short `README.md` with the device run checklist and how to enable Live Activities.

Choose next action: `wire-ui`, `add-readme`, or `start-t012-plan`.