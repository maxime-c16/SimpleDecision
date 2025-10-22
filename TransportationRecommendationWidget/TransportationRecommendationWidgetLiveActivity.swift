//
//  TransportationRecommendationWidgetLiveActivity.swift
//  TransportationRecommendationWidget
//
//  Created by Tristan Aranda  on 30/09/2025.
//

import ActivityKit
import WidgetKit
import SwiftUI

// TransportationRecommendationWidgetAttributes is defined in SharedModels.swift

struct TransportationRecommendationWidgetLiveActivity: Widget {
    let kind: String = "TransportationRecommendationWidget"
    
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TransportationRecommendationWidgetAttributes.self) { context in
            // Lock Screen / Banner UI
            RecommendationLockScreenView(context: context)
        } dynamicIsland: { context in
            // Dynamic Island UI
            DynamicIsland {
                // Expanded UI
                DynamicIslandExpandedRegion(.leading) {
                    RecommendationIconView(mode: context.state.recommendation.mode)
                        .font(.system(size: 20, weight: .semibold))
                }
                DynamicIslandExpandedRegion(.trailing) {
                    RecommendationETAView(context: context)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    RecommendationDetailView(context: context)
                }
            } compactLeading: {
                // Compact leading
                RecommendationIconView(mode: context.state.recommendation.mode)
            } compactTrailing: {
                // Compact trailing  
                Text("\(context.state.recommendation.primaryETA ?? 0)m")
                    .font(.caption2)
                    .fontWeight(.semibold)
            } minimal: {
                // Minimal
                RecommendationIconView(mode: context.state.recommendation.mode)
            }
            .widgetURL(URL(string: "simpledecision://recommendation"))
            .keylineTint(context.state.recommendation.mode.uiColor)
        }
    }
}

// MARK: - Lock Screen View

struct RecommendationLockScreenView: View {
    let context: ActivityViewContext<TransportationRecommendationWidgetAttributes>
    
    var body: some View {
        HStack(spacing: 16) {
            // Mode icon
            RecommendationIconView(mode: context.state.recommendation.mode)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Recommended: \(context.state.recommendation.mode.displayName)")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    if let eta = context.state.recommendation.primaryETA {
                        Text("\(eta) min")
                            .font(.title3)
                            .fontWeight(.medium)
                    }
                }
                
                // Transit details for bus recommendations
                if let transit = context.state.recommendation.transitDetails {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Image(systemName: "bus.fill")
                                .font(.caption2)
                            Text(transit.lineName)
                                .font(.caption)
                                .fontWeight(.semibold)
                            Image(systemName: "arrow.right")
                                .font(.caption2)
                            Text(transit.destinationName)
                                .font(.caption2)
                                .lineLimit(1)
                        }
                        .foregroundColor(.blue)
                        
                        HStack(spacing: 8) {
                            Label("\(transit.walkToStopMinutes)m", systemImage: "figure.walk")
                                .font(.caption2)
                            Label("\(transit.minutesUntilDeparture)m", systemImage: "clock")
                                .font(.caption2)
                        }
                        .foregroundColor(.secondary)
                    }
                } else if let alternativeTransit = context.state.recommendation.alternativeTransitDetails {
                    // Alternative transit when walking is recommended
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Image(systemName: "info.circle")
                                .font(.caption2)
                            Text("Alternative:")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Image(systemName: "bus.fill")
                                .font(.caption2)
                            Text(alternativeTransit.lineName)
                                .font(.caption)
                                .fontWeight(.semibold)
                            Image(systemName: "arrow.right")
                                .font(.caption2)
                            Text(alternativeTransit.destinationName)
                                .font(.caption2)
                                .lineLimit(1)
                        }
                        .foregroundColor(.blue)
                        
                        HStack(spacing: 8) {
                            Label("\(alternativeTransit.walkToStopMinutes)m walk", systemImage: "figure.walk")
                                .font(.caption2)
                            Label("\(alternativeTransit.minutesUntilDeparture)m wait", systemImage: "clock")
                                .font(.caption2)
                            if let busETA = context.state.recommendation.busETA {
                                Label("\(busETA)m total", systemImage: "sum")
                                    .font(.caption2)
                            }
                        }
                        .foregroundColor(.secondary)
                    }
                } else {
                    // ETAs for walk/tie
                    HStack(spacing: 12) {
                        if let walkETA = context.state.recommendation.walkETA {
                            ETAView(
                                icon: "figure.walk",
                                time: walkETA,
                                isRecommended: context.state.recommendation.mode == .walk
                            )
                        }
                        if let busETA = context.state.recommendation.busETA {
                            ETAView(
                                icon: "bus",
                                time: busETA,
                                isRecommended: context.state.recommendation.mode == .bus
                            )
                        }
                    }
                }
                
                HStack {
                    Text("Confidence: \(context.state.recommendation.confidencePercentage)%")
                        .font(.caption2)
                    Spacer()
                    Text("Updated: \(context.state.lastUpdated, style: .time)")
                        .font(.caption2)
                    Text("• \(context.state.recommendation.source.displayName)")
                        .font(.caption2)
                }
                .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(16)
        .activityBackgroundTint(context.state.recommendation.mode.uiColor.opacity(0.1))
        .activitySystemActionForegroundColor(Color.primary)
    }
}

// MARK: - Dynamic Island Component Views

struct RecommendationIconView: View {
    let mode: TransportationMode
    
    var body: some View {
        Image(systemName: mode.iconName)
            .foregroundColor(mode.uiColor)
            .font(.system(size: 16, weight: .semibold))
    }
}

struct RecommendationETAView: View {
    let context: ActivityViewContext<TransportationRecommendationWidgetAttributes>
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            if let eta = context.state.recommendation.primaryETA {
                Text("\(eta) min")
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            Text("\(context.state.recommendation.confidencePercentage)%")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

struct RecommendationDetailView: View {
    let context: ActivityViewContext<TransportationRecommendationWidgetAttributes>
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(context.state.recommendation.mode.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                
                // Show transit details if available
                if let transit = context.state.recommendation.transitDetails {
                    HStack(spacing: 4) {
                        Text(transit.lineName)
                            .font(.caption2)
                            .fontWeight(.semibold)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 8))
                        Text(transit.destinationName)
                            .font(.caption2)
                            .lineLimit(1)
                    }
                    .foregroundColor(.blue)
                } else if let alternativeTransit = context.state.recommendation.alternativeTransitDetails {
                    // Show alternative transit when walking
                    HStack(spacing: 4) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 8))
                        Text("Alt:")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(alternativeTransit.lineName)
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                    }
                } else if context.state.recommendation.walkETA != nil && context.state.recommendation.busETA != nil {
                    HStack(spacing: 8) {
                        if let walkETA = context.state.recommendation.walkETA {
                            HStack(spacing: 2) {
                                Image(systemName: "figure.walk")
                                    .font(.caption2)
                                Text("\(walkETA)m")
                                    .font(.caption2)
                            }
                            .foregroundColor(context.state.recommendation.mode == .walk ? .primary : .secondary)
                        }
                        
                        if let busETA = context.state.recommendation.busETA {
                            HStack(spacing: 2) {
                                Image(systemName: "bus")
                                    .font(.caption2)
                                Text("\(busETA)m")
                                    .font(.caption2)
                            }
                            .foregroundColor(context.state.recommendation.mode == .bus ? .primary : .secondary)
                        }
                    }
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(context.state.recommendation.source.displayName)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Text("Updated: \(context.state.lastUpdated, style: .time)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct ETAView: View {
    let icon: String
    let time: Int
    let isRecommended: Bool
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
            Text("\(time) min")
                .font(.caption)
                .fontWeight(isRecommended ? .semibold : .regular)
        }
        .foregroundColor(isRecommended ? .primary : .secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isRecommended ? Color.primary.opacity(0.1) : Color.clear)
        )
    }
}

extension TransportationRecommendationWidgetAttributes {
    fileprivate static var preview: TransportationRecommendationWidgetAttributes {
        TransportationRecommendationWidgetAttributes(sessionId: "preview-session")
    }
}

extension TransportationRecommendationWidgetAttributes.ContentState {
    fileprivate static var walkRecommendation: TransportationRecommendationWidgetAttributes.ContentState {
        TransportationRecommendationWidgetAttributes.ContentState(
            recommendation: Recommendation.mockWalk,
            lastUpdated: Date()
        )
     }
     
     fileprivate static var busRecommendation: TransportationRecommendationWidgetAttributes.ContentState {
         TransportationRecommendationWidgetAttributes.ContentState(
            recommendation: Recommendation.mockBus,
            lastUpdated: Date()
         )
     }
}

#Preview("Notification", as: .content, using: TransportationRecommendationWidgetAttributes.preview) {
   TransportationRecommendationWidgetLiveActivity()
} contentStates: {
    TransportationRecommendationWidgetAttributes.ContentState.walkRecommendation
    TransportationRecommendationWidgetAttributes.ContentState.busRecommendation
}
