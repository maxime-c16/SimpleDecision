#!/bin/bash

# Test different Val de Fontenay stop IDs with PRIM API
# Based on arrets.json data

echo "Testing Val de Fontenay Stop IDs with PRIM API"
echo "=============================================="
echo ""

# Rail stops (RER A - zdaid 47900)
RAIL_STOPS=(
  "471698"
  "471194"
  "471654"
  "474002"
  "41019"
  "470867"
  "474001"
)

# Bus stops (zdaid 473595)
BUS_STOPS=(
  "488339"
  "37673"
  "37672"
  "19893"
  "472122"
  "427651"
  "21175"
)

API_KEY="EZrIx7Yr7K9XJZwN6zFNa7IrKGF2aCaa"

echo "🚆 Testing RAIL stops (RER A - zdaid 47900):"
echo "----------------------------------------"
for stop_id in "${RAIL_STOPS[@]}"; do
  echo -n "Testing STIF:StopPoint:Q:$stop_id ... "
  
  response=$(curl -s -w "\n%{http_code}" "https://prim.iledefrance-mobilites.fr/marketplace/stop-monitoring" \
    -H "Accept: application/json" \
    -H "apikey: $API_KEY" \
    -d "MonitoringRef=STIF:StopPoint:Q:$stop_id")
  
  http_code=$(echo "$response" | tail -n1)
  body=$(echo "$response" | sed '$d')
  
  if [ "$http_code" = "200" ]; then
    # Check if response contains arrivals
    if echo "$body" | grep -q "MonitoredStopVisit"; then
      count=$(echo "$body" | grep -o "MonitoredStopVisit" | wc -l)
      echo "✅ SUCCESS - Found $count arrivals"
      # Print first line info
      echo "$body" | python3 -m json.tool 2>/dev/null | grep -A 5 "LineName\|DestinationName" | head -10
    else
      echo "⚠️  HTTP 200 but no arrivals found"
    fi
  else
    error=$(echo "$body" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('error', {}).get('message', 'Unknown error'))" 2>/dev/null || echo "Unknown error")
    echo "❌ HTTP $http_code - $error"
  fi
  echo ""
done

echo ""
echo "🚌 Testing BUS stops (zdaid 473595):"
echo "----------------------------------------"
for stop_id in "${BUS_STOPS[@]}"; do
  echo -n "Testing STIF:StopPoint:Q:$stop_id ... "
  
  response=$(curl -s -w "\n%{http_code}" "https://prim.iledefrance-mobilites.fr/marketplace/stop-monitoring" \
    -H "Accept: application/json" \
    -H "apikey: $API_KEY" \
    -d "MonitoringRef=STIF:StopPoint:Q:$stop_id")
  
  http_code=$(echo "$response" | tail -n1)
  body=$(echo "$response" | sed '$d')
  
  if [ "$http_code" = "200" ]; then
    if echo "$body" | grep -q "MonitoredStopVisit"; then
      count=$(echo "$body" | grep -o "MonitoredStopVisit" | wc -l)
      echo "✅ SUCCESS - Found $count arrivals"
    else
      echo "⚠️  HTTP 200 but no arrivals found"
    fi
  else
    error=$(echo "$body" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('error', {}).get('message', 'Unknown error'))" 2>/dev/null || echo "Unknown error")
    echo "❌ HTTP $http_code - $error"
  fi
done

echo ""
echo "=============================================="
echo "Test Complete!"
