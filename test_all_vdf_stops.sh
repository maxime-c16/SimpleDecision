#!/bin/bash
API_KEY="GTMvVD9BG8KTIRabGaEE3R65hkGe1N8D"

echo "Testing Val de Fontenay with URL-encoded format (as from API docs)"
echo "==================================================================="
echo ""

# Test with URL encoding like the API page shows
echo "1. STIF:StopArea:SP:473595: (URL encoded - bus stop)"
curl -X 'GET' \
  'https://prim.iledefrance-mobilites.fr/marketplace/stop-monitoring?MonitoringRef=STIF%3AStopArea%3ASP%3A473595%3A' \
  -H "accept: application/json" \
  -H "apikey: $API_KEY" > /tmp/test_encoded.json

if grep -q "MonitoredStopVisit" /tmp/test_encoded.json; then
  count=$(grep -o "MonitoredStopVisit" /tmp/test_encoded.json | wc -l | tr -d ' ')
  echo "✅ SUCCESS - Found $count arrivals"
  cat /tmp/test_encoded.json | python3 -m json.tool 2>/dev/null | grep -E "PublishedLineName|DestinationName" | head -10
else
  echo "❌ FAILED"
  cat /tmp/test_encoded.json | python3 -m json.tool 2>/dev/null | grep "ErrorText"
fi

echo ""
echo "2. STIF:StopArea:SP:47900: (URL encoded - rail station)"
curl -X 'GET' \
  'https://prim.iledefrance-mobilites.fr/marketplace/stop-monitoring?MonitoringRef=STIF%3AStopArea%3ASP%3A47900%3A' \
  -H "accept: application/json" \
  -H "apikey: $API_KEY" > /tmp/test_rail.json

if grep -q "MonitoredStopVisit" /tmp/test_rail.json; then
  count=$(grep -o "MonitoredStopVisit" /tmp/test_rail.json | wc -l | tr -d ' ')
  echo "✅ SUCCESS - Found $count arrivals"
  cat /tmp/test_rail.json | python3 -m json.tool 2>/dev/null | grep -E "PublishedLineName|DestinationName" | head -10
else
  echo "❌ FAILED"
  cat /tmp/test_rail.json | python3 -m json.tool 2>/dev/null | grep "ErrorText"
fi

echo ""
echo "3. Testing StopPoint format (URL encoded)"
curl -X 'GET' \
  'https://prim.iledefrance-mobilites.fr/marketplace/stop-monitoring?MonitoringRef=STIF%3AStopPoint%3AQ%3A473595%3A' \
  -H "accept: application/json" \
  -H "apikey: $API_KEY" > /tmp/test_point.json

if grep -q "MonitoredStopVisit" /tmp/test_point.json; then
  count=$(grep -o "MonitoredStopVisit" /tmp/test_point.json | wc -l | tr -d ' ')
  echo "✅ SUCCESS - Found $count arrivals"
else
  echo "❌ FAILED"
  cat /tmp/test_point.json | python3 -m json.tool 2>/dev/null | grep "ErrorText"
fi

echo ""
echo "=========================================="
echo "Testing arrid values from arrets.json"
echo "=========================================="
echo ""

# Sample of arrid values  
STOPS=(
  "488339:Val de Fontenay RER (bus)"
  "471698:Val de Fontenay (rail)"
  "492964:Gare de Val de Fontenay (bus) - FROM DOCS"
)

for stop_entry in "${STOPS[@]}"; do
  IFS=':' read -r stop_id stop_name <<< "$stop_entry"
  echo "  $stop_name (STIF:StopPoint:Q:$stop_id:)"
  
  curl -s -X 'GET' \
    "https://prim.iledefrance-mobilites.fr/marketplace/stop-monitoring?MonitoringRef=STIF%3AStopPoint%3AQ%3A${stop_id}%3A" \
    -H "accept: application/json" \
    -H "apikey: $API_KEY" > /tmp/test_arrid.json
  
  if grep -q "MonitoredStopVisit" /tmp/test_arrid.json; then
    count=$(grep -o "MonitoredStopVisit" /tmp/test_arrid.json | wc -l | tr -d ' ')
    echo "    ✅ Found $count arrivals"
  else
    echo "    ❌ Unknown stop ID"
  fi
done
