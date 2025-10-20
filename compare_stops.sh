#!/bin/bash
API_KEY="r1NDADYoOpUH6qS5XkJoPhiRrNjPpee5"

echo "Comparing Nation (working) vs Val de Fontenay"
echo "=============================================="
echo ""

# Test Nation (should work)
echo "1. Nation RER (STIF:StopPoint:Q:42016) - verified working:"
curl -s "https://prim.iledefrance-mobilites.fr/marketplace/stop-monitoring?MonitoringRef=STIF:StopPoint:Q:42016&apikey=$API_KEY" \
  -H "Accept: application/json" > /tmp/nation.json

if grep -q "MonitoredStopVisit" /tmp/nation.json; then
  count=$(grep -o "MonitoredStopVisit" /tmp/nation.json | wc -l)
  echo "✅ SUCCESS - Found $count arrivals"
else
  echo "❌ FAILED"
  cat /tmp/nation.json | python3 -m json.tool | grep "ErrorText"
fi

echo ""
echo "2. Val de Fontenay (STIF:StopPoint:Q:47900):"
curl -s "https://prim.iledefrance-mobilites.fr/marketplace/stop-monitoring?MonitoringRef=STIF:StopPoint:Q:47900&apikey=$API_KEY" \
  -H "Accept: application/json" > /tmp/vdf.json

if grep -q "MonitoredStopVisit" /tmp/vdf.json; then
  count=$(grep -o "MonitoredStopVisit" /tmp/vdf.json | wc -l)
  echo "✅ SUCCESS - Found $count arrivals"
else
  echo "❌ FAILED"
  cat /tmp/vdf.json | python3 -m json.tool | grep "ErrorText"
fi

echo ""
echo "3. Testing arrets.json rail stop IDs (471698, 471194):"
for id in 471698 471194; do
  echo -n "  STIF:StopPoint:Q:$id: "
  curl -s "https://prim.iledefrance-mobilites.fr/marketplace/stop-monitoring?MonitoringRef=STIF:StopPoint:Q:$id&apikey=$API_KEY" \
    -H "Accept: application/json" | grep -q "MonitoredStopVisit" && echo "✅" || echo "❌"
done
