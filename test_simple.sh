#!/bin/bash
# Simple test for Val de Fontenay stop IDs

API_KEY="r1NDADYoOpUH6qS5XkJoPhiRrNjPpee5"

echo "Testing Val de Fontenay Stop IDs"
echo "================================"
echo ""

# Test zdaid 47900 (rail station area)
echo "Test 1: STIF:StopPoint:Q:47900"
curl -s "https://prim.iledefrance-mobilites.fr/marketplace/stop-monitoring?MonitoringRef=STIF:StopPoint:Q:47900&apikey=$API_KEY" \
  -H "Accept: application/json" > /tmp/test1.json

if grep -q "MonitoredStopVisit" /tmp/test1.json; then
  echo "✅ SUCCESS - Found arrivals"
  cat /tmp/test1.json | python3 -m json.tool | grep -E "PublishedLineName|DestinationName" | head -6
else
  echo "❌ FAILED"
  cat /tmp/test1.json | head -c 200
fi

echo ""
echo "================================"
echo ""

# Test zdaid 473595 (bus stop)
echo "Test 2: STIF:StopPoint:Q:473595"
curl -s "https://prim.iledefrance-mobilites.fr/marketplace/stop-monitoring?MonitoringRef=STIF:StopPoint:Q:473595&apikey=$API_KEY" \
  -H "Accept: application/json" > /tmp/test2.json

if grep -q "MonitoredStopVisit" /tmp/test2.json; then
  echo "✅ SUCCESS - Found arrivals"
  cat /tmp/test2.json | python3 -m json.tool | grep -E "PublishedLineName|DestinationName" | head -6
else
  echo "❌ FAILED"
  cat /tmp/test2.json | head -c 200
fi

echo ""
echo "Done!"
