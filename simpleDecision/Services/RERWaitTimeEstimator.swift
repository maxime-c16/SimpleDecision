//
//  RERWaitTimeEstimator.swift
//  simpleDecision
//
//  Created by Transportation Recommendation System on 22/10/2025.
//

import Foundation
import CoreLocation

/// Service to estimate RER wait times at Val de Fontenay based on time of day and line
class RERWaitTimeEstimator {
    
    // Known RER frequencies (in minutes) based on time of day
    private let rerFrequencies: [String: [TimeRange: Int]] = [
        "RER A": [
            .rushHourMorning: 3,    // Every 3 minutes during morning rush
            .rushHourEvening: 3,    // Every 3 minutes during evening rush
            .midday: 6,             // Every 6 minutes midday
            .evening: 10,           // Every 10 minutes evening
            .night: 15              // Every 15 minutes night
        ],
        "RER E": [
            .rushHourMorning: 4,
            .rushHourEvening: 4,
            .midday: 8,
            .evening: 12,
            .night: 20
        ]
    ]
    
    // Average bus ride times from stops to Val de Fontenay (in minutes)
    private let busRideTimes: [String: [String: Int]] = [
        "Bus 122": ["Val de Fontenay": 8],           // Cimetière → Val de Fontenay
        "Bus 124": ["Château de Vincennes": 12],     // To Château (not Val de Fontenay)
        "N34": ["Val de Fontenay": 10]               // Night bus
    ]
    
    /// Estimate RER wait time at Val de Fontenay for a given arrival time
    func estimateRERWaitTime(
        arrivalTime: Date,
        preferredLines: Set<String> = ["RER A", "RER E"]
    ) -> Int {
        // Find the time range for the arrival
        let timeRange = getTimeRange(for: arrivalTime)
        
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: arrivalTime)
        let minute = calendar.component(.minute, from: arrivalTime)
        print("   🕐 RER wait calculation: arrival at \(hour):\(String(format: "%02d", minute)), timeRange: \(timeRange)")
        
        // Get frequencies for each preferred RER line
        var waitTimes: [Int] = []
        
        for line in preferredLines {
            if let frequency = rerFrequencies[line]?[timeRange] {
                // Average wait time is half the frequency (rounded up for safety)
                // Using ceil to round up: 3min frequency → 2min wait (not 1min)
                let averageWait = Int(ceil(Double(frequency) / 2.0))
                print("   🚆 \(line): frequency \(frequency)min → average wait \(averageWait)min")
                waitTimes.append(averageWait)
            }
        }
        
        // Return the minimum wait time (assuming user takes whichever RER comes first)
        if waitTimes.isEmpty {
            print("   ⚠️ No RER frequency data found, using default 5min")
            return 5 // Default to 5 minutes if no data
        }
        
        let minWait = waitTimes.min() ?? 5
        print("   ✅ Final RER wait time: \(minWait)min")
        return minWait
    }
    
    /// Calculate real RER wait time from actual departure schedule
    func calculateRealRERWaitTime(
        arrivalTime: Date,
        rerDepartures: [(lineName: String, departureTime: Date)],
        preferredLines: Set<String> = ["RER A", "RER E"]
    ) -> Int {
        // Filter to only preferred lines
        let relevantDepartures = rerDepartures.filter { preferredLines.contains($0.lineName) }
        
        guard !relevantDepartures.isEmpty else {
            print("   ⚠️ No RER departures available, falling back to frequency estimate")
            return estimateRERWaitTime(arrivalTime: arrivalTime, preferredLines: preferredLines)
        }
        
        // Find the next RER departure after arrival time
        let nextDeparture = relevantDepartures
            .filter { $0.departureTime >= arrivalTime }
            .sorted { $0.departureTime < $1.departureTime }
            .first
        
        guard let nextDep = nextDeparture else {
            print("   ⚠️ No upcoming RER departures found, falling back to frequency estimate")
            return estimateRERWaitTime(arrivalTime: arrivalTime, preferredLines: preferredLines)
        }
        
        // Calculate wait time in minutes
        let waitSeconds = nextDep.departureTime.timeIntervalSince(arrivalTime)
        let waitMinutes = Int(ceil(waitSeconds / 60.0))
        
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        print("   🚆 Next \(nextDep.lineName) at \(formatter.string(from: nextDep.departureTime)) → \(waitMinutes)min wait")
        
        return max(0, waitMinutes)
    }
    
    /// Estimate total journey time for a bus option including RER wait
    func estimateTotalBusJourneyTime(
        lineName: String,
        departureTime: Date,
        walkToStopMinutes: Int,
        destinationName: String,
        rerDepartures: [(lineName: String, departureTime: Date)] = []
    ) -> (busRideMinutes: Int, rerWaitMinutes: Int) {
        // Get bus ride time
        let busRideMinutes = busRideTimes[lineName]?[destinationName] ?? 10 // Default 10 min
        
        // Calculate arrival time at Val de Fontenay (or wherever the bus/RER ends up)
        let arrivalTime = departureTime.addingTimeInterval(TimeInterval(busRideMinutes * 60))
        
        // Use real RER schedule if available, otherwise fall back to frequency estimate
        let rerWaitMinutes: Int
        if !rerDepartures.isEmpty {
            rerWaitMinutes = calculateRealRERWaitTime(arrivalTime: arrivalTime, rerDepartures: rerDepartures)
        } else {
            rerWaitMinutes = estimateRERWaitTime(arrivalTime: arrivalTime)
        }
        
        return (busRideMinutes, rerWaitMinutes)
    }
    
    /// Get the time range for scheduling purposes
    private func getTimeRange(for date: Date) -> TimeRange {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        let weekday = calendar.component(.weekday, from: date)
        
        // Weekend has different patterns
        let isWeekend = (weekday == 1 || weekday == 7) // Sunday = 1, Saturday = 7
        
        if isWeekend {
            if hour >= 22 || hour < 6 {
                return .night
            } else if hour >= 18 {
                return .evening
            } else {
                return .midday
            }
        }
        
        // Weekday patterns
        switch hour {
        case 6..<9:
            return .rushHourMorning
        case 17..<20:
            return .rushHourEvening
        case 11..<17:
            return .midday
        case 20..<22:
            return .evening
        default:
            return .night
        }
    }
    
    /// Estimate walk time to Val de Fontenay from current location
    func estimateWalkTimeToRER(
        from location: CLLocationCoordinate2D,
        walkingSpeed: Double = 1.4 // m/s (default 5 km/h)
    ) -> Int {
        // Val de Fontenay RER station coordinates
        let valDeFontenay = CLLocationCoordinate2D(latitude: 48.85316, longitude: 2.48711)
        
        // Calculate straight-line distance
        let fromLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)
        let toLocation = CLLocation(latitude: valDeFontenay.latitude, longitude: valDeFontenay.longitude)
        let distance = fromLocation.distance(from: toLocation)
        
        // Add 20% for actual walking routes
        let actualDistance = distance * 1.2
        
        // Calculate time in minutes
        let timeInSeconds = actualDistance / walkingSpeed
        let timeInMinutes = Int(ceil(timeInSeconds / 60))
        
        return timeInMinutes
    }
}

// MARK: - Time Range Enum

enum TimeRange {
    case rushHourMorning    // 6-9am weekdays
    case rushHourEvening    // 5-8pm weekdays
    case midday             // 11am-5pm
    case evening            // 8-10pm
    case night              // 10pm-6am
}
