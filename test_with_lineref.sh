#!/bin/bash
API_KEY="r1NDADYoOpUH6qS5XkJoPhiRrNjPpee5"

echo "Testing WITH LineRef parameter (as error suggests)"
echo "=================================================="
echo ""

# Test with both MonitoringRef AND LineRef
echo "Cimetière de Vincennes + Line 53 (C01153)"
curl -s "https://prim.iledefrance-mobilites.fr/marketplace/stop-monitoring?MonitoringRef=STIF:StopPoint:Q:46543:&LineRef=STIF:Line::C01153:&apikey=$API_KEY" \
  -H "Accept: application/json" > /tmp/with_line.json

if grep -q "MonitoredStopVisit" /tmp/with_line.json; then
  count=$(grep -o "MonitoredStopVisit" /tmp/with_line.json | wc -l | tr -d ' ')
  echo "✅ SUCCESS - Found $count arrivals for Line 53"
  cat /tmp/with_line.json | python3 -m json.tool | grep -E "PublishedLineName|DestinationName" | head -4
else
  echo "❌ FAILED"
  cat /tmp/with_line.json | python3 -m json.tool | grep "ErrorText"
fi
