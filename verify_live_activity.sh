#!/bin/bash

# Live Activity Target Membership Verification Script
# This script checks if SharedModels.swift is properly added to both targets

echo "🔍 Checking Live Activity Setup..."
echo ""

# Check if SharedModels.swift exists
if [ -f "TransportationRecommendationWidget/SharedModels.swift" ]; then
    echo "✅ SharedModels.swift file exists"
else
    echo "❌ SharedModels.swift file NOT found"
    exit 1
fi

# Check if SharedModels.swift is in project.pbxproj
if grep -q "SharedModels.swift" simpleDecision.xcodeproj/project.pbxproj; then
    echo "✅ SharedModels.swift is in Xcode project"
    
    # Count how many times it appears (should be multiple for build phases)
    COUNT=$(grep -c "SharedModels.swift" simpleDecision.xcodeproj/project.pbxproj)
    echo "   Found $COUNT references in project file"
    
    if [ $COUNT -lt 2 ]; then
        echo "⚠️  WARNING: SharedModels.swift may not be in both targets (expected 4+ references)"
    fi
else
    echo "❌ SharedModels.swift is NOT in Xcode project"
    echo "   👉 YOU MUST ADD IT TO BOTH TARGETS IN XCODE!"
    exit 1
fi

# Check for duplicate ActivityAttributes definitions
echo ""
echo "🔍 Checking for duplicate ActivityAttributes..."

ATTR_COUNT=$(find . -name "*.swift" -not -path "./.git/*" -exec grep -l "struct TransportationRecommendationWidgetAttributes" {} \; | wc -l)

if [ $ATTR_COUNT -gt 1 ]; then
    echo "⚠️  WARNING: Found multiple ActivityAttributes definitions:"
    find . -name "*.swift" -not -path "./.git/*" -exec grep -l "struct TransportationRecommendationWidgetAttributes" {} \;
    echo ""
    echo "   👉 You should have ONLY ONE definition in SharedModels.swift"
else
    echo "✅ Single ActivityAttributes definition found"
fi

# Check if NSSupportsLiveActivities is configured
echo ""
echo "🔍 Checking NSSupportsLiveActivities configuration..."

if grep -q "NSSupportsLiveActivities" simpleDecision.xcodeproj/project.pbxproj; then
    echo "✅ NSSupportsLiveActivities is configured"
else
    echo "❌ NSSupportsLiveActivities NOT configured"
fi

# Summary
echo ""
echo "📋 SUMMARY:"
echo "=========="
if grep -q "SharedModels.swift" simpleDecision.xcodeproj/project.pbxproj; then
    echo "✅ SharedModels.swift is in project"
else
    echo "❌ CRITICAL: Add SharedModels.swift to both targets in Xcode"
fi

if [ $ATTR_COUNT -eq 1 ]; then
    echo "✅ Single ActivityAttributes definition"
else
    echo "⚠️  Remove duplicate ActivityAttributes files"
fi

echo ""
echo "🚀 NEXT STEPS:"
echo "1. Open Xcode"
echo "2. Select SharedModels.swift in Project Navigator"
echo "3. In File Inspector (right sidebar), check target membership:"
echo "   ☑️ simpleDecision"
echo "   ☑️ TransportationRecommendationWidgetExtension"
echo "4. Clean Build Folder (Cmd+Shift+K)"
echo "5. Build and Run (Cmd+R)"
