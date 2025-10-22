//
//  RecommendationView.swift
//  simpleDecision
//
//  Created by Transportation Recommendation System on 30/09/2025.
//

import SwiftUI

/// SwiftUI view component for displaying transportation recommendations
struct RecommendationView: View {
    let recommendation: Recommendation
    @State private var showingDetails = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Main recommendation card
            recommendationCard
            
            // Details section
            if showingDetails {
                detailsSection
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
            
            // Action buttons
            actionButtons
        }
        .padding()
        .background(cardBackground)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
    
    // MARK: - View Components
    
    private var recommendationCard: some View {
        HStack(spacing: 16) {
            // Transportation mode icon
            transportationIcon
            
            // Main content
            VStack(alignment: .leading, spacing: 8) {
                // Mode and time
                HStack {
                    Text(recommendation.mode.displayName)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(Color(recommendation.mode.colorName))
                    
                    Spacer()
                    
                    Text("\(recommendation.primaryETA ?? 0) min")
                        .font(.title)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
                
                // Transit quick info (when available)
                if let transit = recommendation.transitDetails {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: "bus.fill")
                                .font(.caption)
                                .foregroundColor(.blue)
                            Text(transit.lineName)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Image(systemName: "arrow.right")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(transit.destinationName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        
                        HStack(spacing: 8) {
                            Label("\(transit.walkToStopMinutes) min", systemImage: "figure.walk")
                                .font(.caption2)
                                .foregroundColor(.orange)
                            Label("\(transit.minutesUntilDeparture) min", systemImage: "clock")
                                .font(.caption2)
                                .foregroundColor(.blue)
                        }
                        
                        // DEBUG: Show lineRef for debugging
                        Text("Ref: \(transit.lineRef ?? "no-ref")")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                } else if let alternativeTransit = recommendation.alternativeTransitDetails {
                    // Show alternative transit option when walking is recommended
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "info.circle")
                                .font(.caption2)
                                .foregroundColor(.blue)
                            Text("Alternative:")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text("\(alternativeTransit.lineName)")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.blue)
                        }
                        
                        HStack(spacing: 8) {
                            Label("\(recommendation.busETA ?? 0) min", systemImage: "bus")
                                .font(.caption2)
                                .foregroundColor(.blue)
                            Label("\(alternativeTransit.walkToStopMinutes) min walk", systemImage: "figure.walk")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                        
                        // DEBUG: Show lineRef for debugging
                        Text("Ref: \(alternativeTransit.lineRef ?? "no-ref")")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                    .padding(8)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                } else {
                    // Source info for non-transit
                    Text("Source: \(recommendation.source.displayName)")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                // Confidence and source
                HStack {
                    confidenceIndicator
                    
                    Spacer()
                    
                    sourceIndicator
                }
            }
        }
    }
    
    private var transportationIcon: some View {
        ZStack {
            Circle()
                .fill(Color(recommendation.mode.colorName).opacity(0.2))
                .frame(width: 60, height: 60)
            
            Image(systemName: recommendation.mode.iconName)
                .font(.system(size: 28, weight: .medium))
                .foregroundColor(Color(recommendation.mode.colorName))
        }
    }
    
    private var confidenceIndicator: some View {
        HStack(spacing: 4) {
            Image(systemName: "gauge.medium")
                .font(.caption)
                .foregroundColor(confidenceColor)
            
            Text("\(recommendation.confidencePercentage)%")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(confidenceColor)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(confidenceColor.opacity(0.2))
        .cornerRadius(6)
    }
    
    private var sourceIndicator: some View {
        HStack(spacing: 4) {
            Image(systemName: sourceIconName)
                .font(.caption2)
            
            Text(recommendation.source.displayName)
                .font(.caption2)
        }
        .foregroundColor(.secondary)
    }
    
    @ViewBuilder
    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
            
            // Transit-specific details (when available)
            if let transit = recommendation.transitDetails {
                VStack(alignment: .leading, spacing: 12) {
                    // Transit line and destination
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Line")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            HStack(spacing: 6) {
                                Image(systemName: "bus.fill")
                                    .foregroundColor(.blue)
                                Text(transit.lineName)
                                    .font(.headline)
                                    .fontWeight(.bold)
                            }
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Direction")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(transit.destinationName)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                    
                    // Stop information
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundColor(.red)
                            Text(transit.stopName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        
                        HStack(spacing: 16) {
                            HStack {
                                Image(systemName: "figure.walk")
                                    .foregroundColor(.orange)
                                Text("\(transit.walkToStopMinutes) min walk")
                                    .font(.caption)
                            }
                            
                            HStack {
                                Image(systemName: "clock.fill")
                                    .foregroundColor(Color(transit.statusColor))
                                Text("\(transit.minutesUntilDeparture) min")
                                    .font(.caption)
                            }
                            
                            // Status badge
                            HStack(spacing: 4) {
                                Text(transit.statusText)
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(transit.statusColor).opacity(0.2))
                            .foregroundColor(Color(transit.statusColor))
                            .cornerRadius(6)
                        }
                        
                        // Platform and additional info
                        HStack(spacing: 12) {
                            if !transit.platformName.isEmpty {
                                HStack {
                                    Image(systemName: "arrow.turn.up.right")
                                        .foregroundColor(.secondary)
                                    Text("Platform: \(transit.platformName)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            // Operator badge
                            if let operatorName = transit.operatorName, !operatorName.isEmpty {
                                Text(operatorName)
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.blue.opacity(0.2))
                                    .foregroundColor(.blue)
                                    .cornerRadius(4)
                            }
                        }
                        
                        // Full direction if different from destination
                        if let direction = transit.direction, direction != transit.destinationName {
                            HStack {
                                Image(systemName: "signpost.right.fill")
                                    .font(.caption2)
                                    .foregroundColor(.blue)
                                Text(direction)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }
                        }
                    }
                    
                    Divider()
                    
                    // Detailed ETA Breakdown
                    if let etaBreakdown = transit.etaBreakdown {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Detailed Journey Time")
                                .font(.headline)
                                .padding(.top, 4)
                            
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Image(systemName: "figure.walk")
                                        .frame(width: 20)
                                        .foregroundColor(.orange)
                                    Text("Walk to stop:")
                                        .font(.subheadline)
                                    Spacer()
                                    Text("\(etaBreakdown.walkToStopMinutes) min")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                }
                                
                                HStack {
                                    Image(systemName: "clock.fill")
                                        .frame(width: 20)
                                        .foregroundColor(.blue)
                                    Text("Wait for bus:")
                                        .font(.subheadline)
                                    Spacer()
                                    Text("\(etaBreakdown.waitForBusMinutes) min")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                }
                                
                                HStack {
                                    Image(systemName: "bus.fill")
                                        .frame(width: 20)
                                        .foregroundColor(.green)
                                    Text("Bus ride:")
                                        .font(.subheadline)
                                    Spacer()
                                    Text("\(etaBreakdown.busRideMinutes) min")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                }
                                
                                Divider()
                                
                                HStack {
                                    Image(systemName: "sum")
                                        .frame(width: 20)
                                        .foregroundColor(.primary)
                                    Text("Total ETA:")
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                    Spacer()
                                    Text("\(etaBreakdown.totalMinutes) min")
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                        }
                        
                        Divider()
                    }
                    
                    // Bus Schedule - Next Departures for the recommended line
                    if !transit.upcomingDepartures.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "calendar.badge.clock")
                                    .foregroundColor(.blue)
                                Text("\(transit.lineName) Schedule")
                                    .font(.headline)
                            }
                            .padding(.top, 4)
                            
                            VStack(spacing: 6) {
                                ForEach(transit.upcomingDepartures) { departure in
                                    HStack {
                                        // Time display
                                        Text(departure.displayTime)
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .frame(width: 70, alignment: .leading)
                                        
                                        // Minutes until departure
                                        HStack(spacing: 4) {
                                            Image(systemName: "clock.fill")
                                                .font(.caption2)
                                            Text("\(departure.minutesUntilDeparture) min")
                                                .font(.caption)
                                        }
                                        .foregroundColor(.blue)
                                        .frame(width: 70, alignment: .leading)
                                        
                                        // Catchability indicator
                                        if departure.isCatchable {
                                            HStack(spacing: 3) {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .font(.caption2)
                                                Text("Catchable")
                                                    .font(.caption2)
                                            }
                                            .foregroundColor(.green)
                                        } else {
                                            HStack(spacing: 3) {
                                                Image(systemName: "xmark.circle.fill")
                                                    .font(.caption2)
                                                Text("Too soon")
                                                    .font(.caption2)
                                            }
                                            .foregroundColor(.red)
                                        }
                                        
                                        Spacer()
                                        
                                        // Status badge
                                        Text(departure.status.capitalized)
                                            .font(.caption2)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(statusColor(for: departure.status).opacity(0.2))
                                            .foregroundColor(statusColor(for: departure.status))
                                            .cornerRadius(4)
                                    }
                                    .padding(.vertical, 4)
                                    .padding(.horizontal, 8)
                                    .background(departure.isCatchable ? Color.green.opacity(0.05) : Color.gray.opacity(0.05))
                                    .cornerRadius(6)
                                }
                            }
                        }
                        
                        Divider()
                    }
                    
                    // Alternative Lines at Same Stop
                    if !transit.alternativeLines.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Other Lines at \(transit.stopName)")
                                .font(.headline)
                                .padding(.top, 4)
                            
                            ForEach(transit.alternativeLines) { altLine in
                                HStack {
                                    // Line badge
                                    Text(altLine.lineNumber)
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.blue)
                                        .foregroundColor(.white)
                                        .cornerRadius(4)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(altLine.destination)
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .lineLimit(1)
                                        
                                        Text(altLine.departureStatus.capitalized)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    HStack(spacing: 4) {
                                        Image(systemName: "clock")
                                            .font(.caption2)
                                        Text("\(altLine.minutesUntilDeparture) min")
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                    }
                                    .foregroundColor(.orange)
                                }
                                .padding(.vertical, 6)
                                .padding(.horizontal, 8)
                                .background(Color.gray.opacity(0.05))
                                .cornerRadius(6)
                            }
                        }
                        
                        Divider()
                    }
                }
            }
            
            // Alternative Transit Details (when walking is recommended but bus is available)
            if recommendation.mode == .walk, let alternativeTransit = recommendation.alternativeTransitDetails {
                VStack(alignment: .leading, spacing: 12) {
                    // Section header
                    HStack {
                        Image(systemName: "bus.fill")
                            .foregroundColor(.blue)
                        Text("Alternative: Take the Bus")
                            .font(.headline)
                            .foregroundColor(.blue)
                    }
                    .padding(.top, 4)
                    
                    // Bus line and destination
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Line")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            HStack(spacing: 6) {
                                Image(systemName: "bus.fill")
                                    .foregroundColor(.blue)
                                Text(alternativeTransit.lineName)
                                    .font(.headline)
                                    .fontWeight(.bold)
                            }
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Direction")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(alternativeTransit.destinationName)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                    
                    // Stop information
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundColor(.red)
                            Text(alternativeTransit.stopName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        
                        // Departure time and status
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Next Departure")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(alternativeTransit.departureTime.formatted(date: .omitted, time: .shortened))
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                            
                            HStack {
                                Image(systemName: "figure.walk")
                                    .foregroundColor(.orange)
                                Text("\(alternativeTransit.walkToStopMinutes) min walk")
                                    .font(.caption)
                            }
                            
                            HStack {
                                Image(systemName: "clock.fill")
                                    .foregroundColor(Color(alternativeTransit.statusColor))
                                Text("\(alternativeTransit.minutesUntilDeparture) min")
                                    .font(.caption)
                            }
                            
                            // Status badge
                            HStack(spacing: 4) {
                                Text(alternativeTransit.statusText)
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(alternativeTransit.statusColor).opacity(0.2))
                            .foregroundColor(Color(alternativeTransit.statusColor))
                            .cornerRadius(6)
                        }
                        
                        // Platform and additional info
                        HStack(spacing: 12) {
                            if !alternativeTransit.platformName.isEmpty {
                                HStack {
                                    Image(systemName: "arrow.turn.up.right")
                                        .foregroundColor(.secondary)
                                    Text("Platform: \(alternativeTransit.platformName)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            // Operator badge
                            if let operatorName = alternativeTransit.operatorName, !operatorName.isEmpty {
                                Text(operatorName)
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.blue.opacity(0.2))
                                    .foregroundColor(.blue)
                                    .cornerRadius(4)
                            }
                        }
                        
                        // Full direction if different from destination
                        if let direction = alternativeTransit.direction, direction != alternativeTransit.destinationName {
                            HStack {
                                Image(systemName: "signpost.right.fill")
                                    .font(.caption2)
                                    .foregroundColor(.blue)
                                Text(direction)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }
                        }
                    }
                    
                    Divider()
                    
                    // Detailed ETA Breakdown
                    if let etaBreakdown = alternativeTransit.etaBreakdown {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Detailed Journey Time")
                                .font(.headline)
                                .padding(.top, 4)
                            
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Image(systemName: "figure.walk")
                                        .frame(width: 20)
                                        .foregroundColor(.orange)
                                    Text("Walk to stop:")
                                        .font(.subheadline)
                                    Spacer()
                                    Text("\(etaBreakdown.walkToStopMinutes) min")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                }
                                
                                HStack {
                                    Image(systemName: "clock.fill")
                                        .frame(width: 20)
                                        .foregroundColor(.blue)
                                    Text("Wait for bus:")
                                        .font(.subheadline)
                                    Spacer()
                                    Text("\(etaBreakdown.waitForBusMinutes) min")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                }
                                
                                HStack {
                                    Image(systemName: "bus.fill")
                                        .frame(width: 20)
                                        .foregroundColor(.green)
                                    Text("Bus ride:")
                                        .font(.subheadline)
                                    Spacer()
                                    Text("\(etaBreakdown.busRideMinutes) min")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                }
                                
                                Divider()
                                
                                HStack {
                                    Image(systemName: "sum")
                                        .frame(width: 20)
                                        .foregroundColor(.primary)
                                    Text("Total ETA:")
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                    Spacer()
                                    Text("\(etaBreakdown.totalMinutes) min")
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                        }
                        
                        Divider()
                    }
                    
                    // Bus Schedule - Next Departures for the recommended line
                    if !alternativeTransit.upcomingDepartures.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "calendar.badge.clock")
                                    .foregroundColor(.blue)
                                Text("\(alternativeTransit.lineName) Schedule")
                                    .font(.headline)
                            }
                            .padding(.top, 4)
                            
                            VStack(spacing: 6) {
                                ForEach(alternativeTransit.upcomingDepartures) { departure in
                                    HStack {
                                        // Time display
                                        Text(departure.displayTime)
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .frame(width: 70, alignment: .leading)
                                        
                                        // Minutes until departure
                                        HStack(spacing: 4) {
                                            Image(systemName: "clock.fill")
                                                .font(.caption2)
                                            Text("\(departure.minutesUntilDeparture) min")
                                                .font(.caption)
                                        }
                                        .foregroundColor(.blue)
                                        .frame(width: 70, alignment: .leading)
                                        
                                        // Catchability indicator
                                        if departure.isCatchable {
                                            HStack(spacing: 3) {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .font(.caption2)
                                                Text("Catchable")
                                                    .font(.caption2)
                                            }
                                            .foregroundColor(.green)
                                        } else {
                                            HStack(spacing: 3) {
                                                Image(systemName: "xmark.circle.fill")
                                                    .font(.caption2)
                                                Text("Too soon")
                                                    .font(.caption2)
                                            }
                                            .foregroundColor(.red)
                                        }
                                        
                                        Spacer()
                                        
                                        // Status badge
                                        Text(departure.status.capitalized)
                                            .font(.caption2)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(statusColor(for: departure.status).opacity(0.2))
                                            .foregroundColor(statusColor(for: departure.status))
                                            .cornerRadius(4)
                                    }
                                    .padding(.vertical, 4)
                                    .padding(.horizontal, 8)
                                    .background(departure.isCatchable ? Color.green.opacity(0.05) : Color.gray.opacity(0.05))
                                    .cornerRadius(6)
                                }
                            }
                        }
                        
                        Divider()
                    }
                    
                    // Alternative Lines at Same Stop
                    if !alternativeTransit.alternativeLines.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Other Lines at \(alternativeTransit.stopName)")
                                .font(.headline)
                                .padding(.top, 4)
                            
                            ForEach(alternativeTransit.alternativeLines) { altLine in
                                HStack {
                                    // Line badge
                                    Text(altLine.lineNumber)
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.blue)
                                        .foregroundColor(.white)
                                        .cornerRadius(4)
                                    
                                    // Destination
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(altLine.destination)
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .lineLimit(1)
                                        
                                        Text(altLine.nextDepartureTime.formatted(date: .omitted, time: .shortened))
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    // Catchability badge
                                    if altLine.isCatchable {
                                        HStack(spacing: 3) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.caption2)
                                            Text("Can catch")
                                                .font(.caption2)
                                        }
                                        .foregroundColor(.green)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                        .background(Color.green.opacity(0.1))
                                        .cornerRadius(4)
                                    } else {
                                        Text("Too soon")
                                            .font(.caption2)
                                            .foregroundColor(.orange)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 3)
                                            .background(Color.orange.opacity(0.1))
                                            .cornerRadius(4)
                                    }
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(Color.gray.opacity(0.05))
                                .cornerRadius(6)
                            }
                        }
                        
                        Divider()
                    }
                }
            }
            
            // General information
            VStack(alignment: .leading, spacing: 8) {
                detailRow("Created", value: formattedTimestamp)
                detailRow("Weather", value: weatherDisplayText)
                
                if recommendation.mode == .bus {
                    detailRow("Data Source", value: "PRIM API (Real-time)")
                }
                
                if recommendation.mode == .walk {
                    detailRow("Walking Speed", value: "5 km/h average")
                }
            }
            
            // Tips section
            if !recommendationTips.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tips")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    
                    ForEach(recommendationTips, id: \.self) { tip in
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "lightbulb")
                                .font(.caption2)
                                .foregroundColor(.yellow)
                            
                            Text(tip)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
    }
    
    private func detailRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
    
    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button(action: {
                withAnimation(.spring()) {
                    showingDetails.toggle()
                }
            }) {
                HStack {
                    Image(systemName: showingDetails ? "chevron.up" : "info.circle")
                    Text(showingDetails ? "Less Info" : "More Info")
                }
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            // Alternative action based on mode
            alternativeActionButton
        }
    }
    
    @ViewBuilder
    private var alternativeActionButton: some View {
        if recommendation.mode == .bus {
            Button(action: {
                // Open Maps app or show transit directions
                openMapsForTransit()
            }) {
                HStack {
                    Image(systemName: "map")
                    Text("Directions")
                }
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.2))
                .foregroundColor(.blue)
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
        } else {
            Button(action: {
                // Open Maps app for walking directions
                openMapsForWalking()
            }) {
                HStack {
                    Image(systemName: "figure.walk")
                    Text("Navigate")
                }
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.green.opacity(0.2))
                .foregroundColor(.green)
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Computed Properties
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(.regularMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color(recommendation.mode.colorName).opacity(0.3), lineWidth: 1)
            )
    }
    
    private var confidenceColor: Color {
        if recommendation.confidence > 0.8 {
            return .green
        } else if recommendation.confidence > 0.6 {
            return .orange
        } else {
            return .red
        }
    }
    
    private var sourceIconName: String {
        switch recommendation.source {
        case .primAPI:
            return "globe"
        case .localHeuristics:
            return "brain"
        case .mock:
            return "hand.raised"
        }
    }
    
    private var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: recommendation.timestamp)
    }
    
    // Helper function to get status color for departures
    private func statusColor(for status: String) -> Color {
        switch status.lowercased() {
        case "ontime", "on time":
            return .green
        case "delayed":
            return .orange
        case "early":
            return .blue
        case "cancelled":
            return .red
        default:
            return .gray
        }
    }
    
    private var weatherDisplayText: String {
        return "�️ Clear"
    }
    
    private var recommendationTips: [String] {
        var tips: [String] = []
        
        switch recommendation.mode {
        case .walk:
            if let walkETA = recommendation.walkETA, walkETA > 15 {
                tips.append("Consider bringing water for longer walks")
            }
            tips.append("Don't forget an umbrella if it looks like rain!")
            
        case .bus:
            tips.append("Check for service alerts before departing")
            if recommendation.confidence < 0.7 {
                tips.append("Consider walking as backup if transit is delayed")
            }
            
        case .tie:
            tips.append("Both options are equally good - choose based on your preference")
        }
        
        return tips
    }
    
    // MARK: - Actions
    
    private func openMapsForTransit() {
        // In a real app, this would open Maps with transit directions
        print("Opening Maps for transit directions")
    }
    
    private func openMapsForWalking() {
        // In a real app, this would open Maps with walking directions
        print("Opening Maps for walking directions")
    }
}

// MARK: - Preview

struct RecommendationView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Walking recommendation
            RecommendationView(recommendation: Recommendation.mockWalk)
                .padding()
                .previewDisplayName("Walking")
            
            // Transit recommendation
            RecommendationView(recommendation: Recommendation.mockBus)
                .padding()
                .previewDisplayName("Transit")
            
            // Tie recommendation
            RecommendationView(recommendation: Recommendation.mockTie)
                .padding()
                .previewDisplayName("Tie")
        }
        .previewLayout(.sizeThatFits)
    }
}