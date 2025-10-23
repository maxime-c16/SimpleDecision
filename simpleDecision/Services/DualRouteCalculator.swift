//
//  DualRouteCalculator.swift
//  simpleDecision
//
//  Created by Dual-Route Live Activity Feature on 23/10/2025.
//

import Foundation
import CoreLocation

/// Calculates and compares walk vs bus+RER routes with urgency scoring
class DualRouteCalculator {
    
    // MARK: - Constants
    
    /// Walking speed in meters per second (1.4 m/s = average pace)
    private let walkingSpeedMPS: Double = 1.4
    
    /// Sliding window parameters
    private let earlyBufferMinutes: Int = 5
    private let lateBufferMinutes: Int = 2
    
    // MARK: - Public Methods
    
    /// Calculate walking route timing and urgency
    /// - Parameters:
    ///   - from: User's current location
    ///   - to: RER station location
    ///   - rerSchedule: Array of upcoming RER departures
    /// - Returns: RouteWindow with timing details and urgency score
    func calculateWalkRoute(
        from: CLLocationCoordinate2D,
        to: CLLocationCoordinate2D,
        rerSchedule: [RERDeparture]
    ) -> RouteWindow {
        
        print("\n🚶 DualRouteCalculator - WALK ROUTE CALCULATION")
        print("   From: (\(String(format: "%.6f", from.latitude)), \(String(format: "%.6f", from.longitude)))")
        print("   To: (\(String(format: "%.6f", to.latitude)), \(String(format: "%.6f", to.longitude)))")
        print("   RER Schedule: \(rerSchedule.count) departures")
        
        // Calculate walking time
        let walkingDistanceMeters = calculateDistance(from: from, to: to)
        let walkingMinutes = Int(ceil(walkingDistanceMeters / (walkingSpeedMPS * 60)))
        print("   Walking distance: \(Int(walkingDistanceMeters))m → \(walkingMinutes)min")
        
        // Find next viable RER
        let now = Date()
        let arrivalAtStation = now.addingTimeInterval(TimeInterval(walkingMinutes * 60))
        print("   Arrival at station: \(DateFormatter.localizedString(from: arrivalAtStation, dateStyle: .none, timeStyle: .medium))")
        
        guard let nextRER = rerSchedule.first(where: { $0.departureTime > arrivalAtStation }) else {
            // No viable RER found - create expired window
            print("   ⚠️ No viable RER found for walk route")
            return RouteWindow(
                totalMinutes: walkingMinutes,
                windowStart: now,
                windowEnd: now,
                urgencyScore: 1.0,
                bufferMinutes: -999,
                safetyStatus: .tooRisky,
                phases: [
                    TravelPhase(type: .walk, minutes: walkingMinutes, description: "Walk to RER")
                ]
            )
        }
        
        // Calculate RER buffer time (safety margin at station)
        let rerBufferSeconds = nextRER.departureTime.timeIntervalSince(arrivalAtStation)
        let rerBufferMinutes = Int(rerBufferSeconds / 60)
        let totalMinutes = walkingMinutes + rerBufferMinutes
        
        print("   Next RER: \(nextRER.lineName) at \(DateFormatter.localizedString(from: nextRER.departureTime, dateStyle: .none, timeStyle: .medium))")
        print("   🎯 RER BUFFER TIME: \(rerBufferMinutes)min (safety margin at station)")
        print("   Total time: \(totalMinutes)min")
        
        // Calculate urgency and safety based on RER buffer time
        let (urgencyScore, safetyStatus) = calculateBufferBasedUrgency(bufferMinutes: rerBufferMinutes, routeType: "walk")
        
        // Calculate sliding window for visualization
        let idealDepartureTime = now
        let windowStart = idealDepartureTime.addingTimeInterval(TimeInterval(-earlyBufferMinutes * 60))
        let windowEnd = idealDepartureTime.addingTimeInterval(TimeInterval(lateBufferMinutes * 60))
        
        let phases = [
            TravelPhase(type: .walk, minutes: walkingMinutes, description: "Walk to \(nextRER.lineName) station"),
            TravelPhase(type: .wait, minutes: rerBufferMinutes, description: "Wait for \(nextRER.lineName)")
        ]
        
        return RouteWindow(
            totalMinutes: totalMinutes,
            windowStart: windowStart,
            windowEnd: windowEnd,
            urgencyScore: urgencyScore,
            bufferMinutes: rerBufferMinutes,
            safetyStatus: safetyStatus,
            phases: phases
        )
    }
    
    /// Calculate bus+RER route timing and urgency
    /// - Parameters:
    ///   - busOption: Selected bus option with timing details
    ///   - rerSchedule: Array of upcoming RER departures
    /// - Returns: RouteWindow with timing details and urgency score
    func calculateBusRoute(
        busOption: BusOptionTiming,
        rerSchedule: [RERDeparture]
    ) -> RouteWindow {
        
        print("\n🚌 DualRouteCalculator - BUS ROUTE CALCULATION")
        print("   Bus: \(busOption.lineName) to \(busOption.destinationName)")
        print("   Stop: \(busOption.stopName)")
        print("   Departure: \(DateFormatter.localizedString(from: busOption.departureTime, dateStyle: .none, timeStyle: .medium))")
        
        let walkToBusMinutes = busOption.walkToStopMinutes
        let busWaitMinutes = busOption.waitAtStopMinutes  // This is the BUFFER TIME!
        let busRideMinutes = busOption.busRideMinutes
        let rerWaitMinutes = busOption.rerWaitMinutes ?? 0
        
        print("   Breakdown:")
        print("     • Walk to stop: \(walkToBusMinutes)min")
        print("     • 🎯 BUS BUFFER TIME: \(busWaitMinutes)min (wait at stop = safety margin)")
        print("     • Bus ride: \(busRideMinutes)min")
        print("     • RER wait: \(rerWaitMinutes)min")
        
        let totalMinutes = walkToBusMinutes + busWaitMinutes + busRideMinutes + rerWaitMinutes
        print("   Total time: \(totalMinutes)min")
        
        // Calculate urgency and safety based on bus wait buffer time
        let (urgencyScore, safetyStatus) = calculateBufferBasedUrgency(bufferMinutes: busWaitMinutes, routeType: "bus")
        
        // Calculate when user needs to leave
        let now = Date()
        let idealDepartureTime = busOption.departureTime.addingTimeInterval(TimeInterval(-(walkToBusMinutes + busWaitMinutes) * 60))
        
        // Calculate sliding window for visualization
        let windowStart = idealDepartureTime.addingTimeInterval(TimeInterval(-earlyBufferMinutes * 60))
        let windowEnd = idealDepartureTime.addingTimeInterval(TimeInterval(lateBufferMinutes * 60))
        
        let phases = [
            TravelPhase(type: .walk, minutes: walkToBusMinutes, description: "Walk to \(busOption.stopName)"),
            TravelPhase(type: .wait, minutes: busWaitMinutes, description: "Wait for \(busOption.lineName)"),
            TravelPhase(type: .ride, minutes: busRideMinutes, description: "\(busOption.lineName) ride"),
            TravelPhase(type: .wait, minutes: rerWaitMinutes, description: "Wait for RER")
        ]
        
        return RouteWindow(
            totalMinutes: totalMinutes,
            windowStart: windowStart,
            windowEnd: windowEnd,
            urgencyScore: urgencyScore,
            bufferMinutes: busWaitMinutes,
            safetyStatus: safetyStatus,
            phases: phases
        )
    }
    
    /// Compare two routes and determine which is recommended
    /// - Parameters:
    ///   - walkWindow: Walk route timing window
    ///   - busWindow: Bus route timing window
    /// - Returns: RouteComparison with overlap detection and recommendation
    func compareRoutes(
        walkWindow: RouteWindow,
        busWindow: RouteWindow
    ) -> RouteComparison {
        
        // Detect window overlap
        let overlapping = !(walkWindow.windowEnd < busWindow.windowStart || 
                           busWindow.windowEnd < walkWindow.windowStart)
        
        // Calculate urgency difference
        let urgencyDifference = abs(walkWindow.urgencyScore - busWindow.urgencyScore)
        
        // Determine recommended route based on safety first, then urgency, then time
        let recommended: RouteType
        
        // Safety check: avoid routes marked as "too risky" if better alternative exists
        if walkWindow.safetyStatus == .tooRisky && busWindow.safetyStatus != .tooRisky {
            recommended = .bus
            print("⚠️  Walk route too risky (\(walkWindow.bufferMinutes)min buffer), preferring bus")
        } else if busWindow.safetyStatus == .tooRisky && walkWindow.safetyStatus != .tooRisky {
            recommended = .walk
            print("⚠️  Bus route too risky (\(busWindow.bufferMinutes)min buffer), preferring walk")
        } else if walkWindow.urgencyScore < busWindow.urgencyScore {
            // Lower urgency = better
            recommended = .walk
        } else if busWindow.urgencyScore < walkWindow.urgencyScore {
            recommended = .bus
        } else {
            // If urgency is equal, prefer the shorter route
            recommended = walkWindow.totalMinutes <= busWindow.totalMinutes ? .walk : .bus
        }
        
        // Log comparison with safety information
        print("\n🔄 Route Comparison:")
        print("   Walk: \(walkWindow.totalMinutes)min, urgency=\(String(format: "%.2f", walkWindow.urgencyScore)), safety=\(walkWindow.safetyStatus.emoji) \(walkWindow.safetyStatus.description)")
        print("   Bus: \(busWindow.totalMinutes)min, urgency=\(String(format: "%.2f", busWindow.urgencyScore)), safety=\(busWindow.safetyStatus.emoji) \(busWindow.safetyStatus.description)")
        print("   Overlapping: \(overlapping)")
        print("   ✅ Recommended: \(recommended)")
        print("   Urgency difference: \(String(format: "%.2f", urgencyDifference))")
        
        return RouteComparison(
            walkWindow: walkWindow,
            busWindow: busWindow,
            overlapping: overlapping,
            recommended: recommended,
            urgencyDifference: urgencyDifference
        )
    }
    
    // MARK: - Private Helpers
    
    /// Calculate distance between two coordinates in meters
    private func calculateDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let fromLocation = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let toLocation = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return fromLocation.distance(from: toLocation)
    }
    
    /// Calculate urgency based on buffer time (safety margin before critical departure)
    /// - Parameters:
    ///   - bufferMinutes: Time buffer/margin (RER wait for walk, bus wait for bus route)
    ///   - routeType: "walk" or "bus" for logging context
    /// - Returns: Tuple with urgency score (0.0-1.0) and safety status
    private func calculateBufferBasedUrgency(
        bufferMinutes: Int,
        routeType: String
    ) -> (urgency: Double, safetyStatus: SafetyStatus) {
        
        let urgency: Double
        let urgencyStatus: String
        let urgencyEmoji: String
        let safetyStatus: SafetyStatus
        
        switch bufferMinutes {
        case 8...:
            // 8+ minutes: Plenty of time, very relaxed
            urgency = 0.0 + Double(max(0, 10 - bufferMinutes)) * 0.02  // 0.0-0.2
            urgencyStatus = "Relaxed"
            urgencyEmoji = "🟢"
            safetyStatus = .comfortable
            
        case 5..<8:
            // 5-8 minutes: Comfortable pace
            urgency = 0.2 + Double(8 - bufferMinutes) * 0.067  // 0.2-0.4
            urgencyStatus = "Comfortable"
            urgencyEmoji = "🟡"
            safetyStatus = .comfortable
            
        case 3..<5:
            // 3-5 minutes: On time, normal pace
            urgency = 0.4 + Double(5 - bufferMinutes) * 0.1  // 0.4-0.6
            urgencyStatus = "On time"
            urgencyEmoji = "🟠"
            safetyStatus = .acceptable
            
        case 2..<3:
            // 2-3 minutes: Need to hurry
            urgency = 0.6 + Double(3 - bufferMinutes) * 0.2  // 0.6-0.8
            urgencyStatus = "Hurry up!"
            urgencyEmoji = "🔴"
            safetyStatus = .acceptable
            
        case 0..<2:
            // 0-2 minutes: RUSH! Walk fast or miss it
            urgency = 0.8 + Double(2 - bufferMinutes) * 0.1  // 0.8-1.0
            urgencyStatus = "RUSH - walk fast!"
            urgencyEmoji = "⚠️"
            safetyStatus = .tooRisky
            
        default:
            // Negative buffer (already late)
            urgency = 1.0
            urgencyStatus = "TOO LATE - missed it"
            urgencyEmoji = "🚫"
            safetyStatus = .tooRisky
        }
        
        print("      \(urgencyEmoji) \(routeType.uppercased()) URGENCY: \(String(format: "%.2f", urgency)) (\(bufferMinutes)min → \(urgencyStatus)) \(safetyStatus.emoji) \(safetyStatus.description)")
        
        return (min(max(urgency, 0.0), 1.0), safetyStatus)
    }
    
    /// Calculate urgency score based on current time and departure windows (OLD METHOD - kept for comparison)
    /// - Returns: Score from 0.0 (early) to 1.0 (late/missed)
    private func calculateUrgencyScore(
        now: Date,
        idealDeparture: Date,
        windowStart: Date,
        windowEnd: Date
    ) -> Double {
        
        // If before window starts, user is very early
        if now < windowStart {
            let secondsEarly = windowStart.timeIntervalSince(now)
            print("      ⏰ Urgency: Too early by \(Int(secondsEarly/60))min → 0.0")
            return 0.0
        }
        
        // If after window ends, user missed it
        if now > windowEnd {
            let secondsLate = now.timeIntervalSince(windowEnd)
            print("      ⏰ Urgency: Too late by \(Int(secondsLate/60))min → 1.0")
            return 1.0
        }
        
        // Calculate position within window
        let windowWidth = windowEnd.timeIntervalSince(windowStart)
        let positionInWindow = now.timeIntervalSince(windowStart)
        let ratio = positionInWindow / windowWidth
        
        let minutesIntoWindow = Int(positionInWindow / 60)
        let totalWindowMinutes = Int(windowWidth / 60)
        print("      ⏰ Urgency: \(minutesIntoWindow)min into \(totalWindowMinutes)min window → \(String(format: "%.2f", ratio))")
        
        // Clamp between 0 and 1
        return min(max(ratio, 0.0), 1.0)
    }
}

// MARK: - Supporting Types

/// Represents a route's timing window and urgency
struct RouteWindow {
    let totalMinutes: Int
    let windowStart: Date
    let windowEnd: Date
    let urgencyScore: Double  // 0.0 = early, 1.0 = late/missed
    let bufferMinutes: Int    // Safety margin before critical departure
    let safetyStatus: SafetyStatus  // Classification based on buffer
    let phases: [TravelPhase]
}

/// Represents a single phase of travel
struct TravelPhase {
    enum PhaseType {
        case walk
        case wait
        case ride
    }
    
    let type: PhaseType
    let minutes: Int
    let description: String
}

/// Represents comparison between two routes
struct RouteComparison {
    let walkWindow: RouteWindow
    let busWindow: RouteWindow
    let overlapping: Bool
    let recommended: RouteType
    let urgencyDifference: Double
}

/// Route type identifier
enum RouteType {
    case walk
    case bus
}
