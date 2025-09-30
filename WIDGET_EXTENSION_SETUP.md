# Widget Extension Setup Instructions

**Task T003**: Create Widget Extension target named "TransportationRecommendationWidget" with Live Activities support

## Manual Steps Required in Xcode:

1. **Open Xcode Project**:
   ```bash
   open simpleDecision.xcodeproj
   ```

2. **Add Widget Extension Target**:
   - File → New → Target
   - Select "Widget Extension" from iOS section
   - Product Name: `TransportationRecommendationWidget`
   - Include Configuration Intent: **No** (simpler)
   - Supports Live Activities: **Yes** (required)
   - Click "Finish"

3. **Verify Target Creation**:
   - New target should appear in project navigator
   - New folder `TransportationRecommendationWidget/` should be created
   - Build settings should include Live Activities support

## What This Creates:
- Widget Extension target with proper entitlements
- Widget.swift file with basic ActivityConfiguration
- Info.plist configured for WidgetKit extension
- Proper bundle identifier (e.g., `slaicer.simpleDecision.TransportationRecommendationWidget`)

## Status:
- ✅ Instructions documented
- ⏳ Manual Xcode steps required
- 🔄 Can proceed with other tasks while this is pending

**Next Steps**: 
- Complete this task manually in Xcode
- Then proceed with Widget implementation tasks (T022-T023)