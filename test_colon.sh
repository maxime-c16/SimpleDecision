#!/bin/bash
API_KEY="r1NDADYoOpUH6qS5XkJoPhiRrNjPpee5"

echo "Testing COLON vs NO COLON for stop 46543 (Cimetière de Vincennes)"
echo "================================================================="
echo ""

echo "1. WITH trailing colon: STIF:StopPoint:Q:46543:"
result=$(curl -s "https://prim.iledefrance-mobilites.fr/marketplace/stop-monitoring?MonitoringRef=STIF:StopPoint:Q:46543:&apikey=$API_KEY" -H "Accept: application/json")
if echo "$result" | grep -q "MonitoredStopVisit"; then
  count=$(echo "$result" | grep -o "MonitoredStopVisit" | wc -l | tr -d ' ')
  echo "✅ SUCCESS - Found $count arrivals"
else
  echo "❌ FAILED"
fi

echo ""
echo "2. WITHOUT trailing colon: STIF:StopPoint:Q:46543"
result=$(curl -s "https://prim.iledefrance-mobilites.fr/marketplace/stop-monitoring?MonitoringRef=STIF:StopPoint:Q:46543&apikey=$API_KEY" -H "Accept: application/json")
if echo "$result" | grep -q "MonitoredStopVisit"; then
  count=$(echo "$result" | grep -o "MonitoredStopVisit" | wc -l | tr -d ' ')
  echo "✅ SUCCESS - Found $count arrivals"
else
  echo "❌ FAILED"
fi
