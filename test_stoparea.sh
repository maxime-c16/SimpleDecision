#!/bin/bash
# Test StopArea format for Val de Fontenay

API_KEY="r1NDADYoOpUH6qS5XkJoPhiRrNjPpee5"

echo "Testing Val de Fontenay with CORRECT StopArea format"
echo "===================================================="
echo ""

# Test with StopArea and trailing colon (as per docs)
echo "Test: STIF:StopArea:SP:47900:"
curl -s "https://prim.iledefrance-mobilites.fr/marketplace/stop-monitoring?MonitoringRef=STIF:StopArea:SP:47900:&apikey=$API_KEY" \
  -H "Accept: application/json" > /tmp/vdf_test.json

if grep -q "MonitoredStopVisit" /tmp/vdf_test.json; then
  echo "✅ SUCCESS!"
  echo ""
  cat /tmp/vdf_test.json | python3 -m json.tool | grep -E '"PublishedLineName"|"DestinationName"' | head -10
else
  echo "❌ FAILED - Error:"
  cat /tmp/vdf_test.json | python3 -m json.tool | grep -E "ErrorText|ErrorDescription"
fi
