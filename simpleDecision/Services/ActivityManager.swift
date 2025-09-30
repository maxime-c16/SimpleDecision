//
//  ActivityManager.swift
//  simpleDecision
//
//  Created by Transportation Recommendation System on 30/09/2025.
//

import Foundation
import ActivityKit
import SwiftUI

/// Manages Live Activities for displaying transportation recommendations on Lock Screen and Dynamic Island
@available(iOS 16.1, *)
class ActivityManager: ObservableObject {
    static let shared = ActivityManager()
    
    @Published var currentActivity: Activity<TransportationActivityAttributes>?
    @Published var activityError: String?
    @Published var isActivitySupported: Bool
    
    private init() {
        self.isActivitySupported = ActivityAuthorizationInfo().areActivitiesEnabled
        
        // Monitor activity authorization changes
        Task {
            for await update in ActivityAuthorizationInfo().activityEnablementUpdates {
                await MainActor.run {
                    self.isActivitySupported = update
                }
            }
        }
    }
    
    /// Start a new Live Activity with transportation recommendation
    func startActivity(with recommendation: Recommendation, destination: String) async {
        guard isActivitySupported else {
            activityError = "Live Activities are not enabled"
            return
        }
        
        // End any existing activity first
        await endCurrentActivity()
        
        let attributes = TransportationActivityAttributes(
            destinationName: destination,
            startTime: Date()
        )
        
        let initialState = TransportationActivityAttributes.ContentState(
            recommendation: recommendation,
            status: .active,
            lastUpdated: Date()
        )
        
        let content = ActivityContent(
            state: initialState,
            staleDate: Date().addingTimeInterval(300) // 5 minutes stale date
        )
        
        do {
            let activity = try Activity<TransportationActivityAttributes>.request(
                attributes: attributes,
                content: content,
                pushType: nil // Local updates only
            )
            
            await MainActor.run {
                self.currentActivity = activity
                self.activityError = nil
            }
            
            // Schedule automatic end after estimated time
            scheduleActivityEnd(after: recommendation.estimatedTimeMinutes * 60)
            
        } catch {
            await MainActor.run {
                self.activityError = "Failed to start Live Activity: \(error.localizedDescription)"
            }
        }
    }
    
    /// Update existing Live Activity with new recommendation data
    func updateActivity(with recommendation: Recommendation) async {
        guard let activity = currentActivity else { return }
        
        let updatedState = TransportationActivityAttributes.ContentState(
            recommendation: recommendation,
            status: .active,
            lastUpdated: Date()
        )
        
        let content = ActivityContent(
            state: updatedState,
            staleDate: Date().addingTimeInterval(300) // 5 minutes stale date
        )
        
        await activity.update(content)
    }
    
    /// Mark activity as completed (user arrived)
    func markActivityCompleted(with message: String = "Journey completed") async {
        guard let activity = currentActivity else { return }
        
        let completedState = TransportationActivityAttributes.ContentState(
            recommendation: activity.content.state.recommendation,
            status: .completed,
            lastUpdated: Date(),
            statusMessage: message
        )
        
        let content = ActivityContent(
            state: completedState,
            staleDate: Date().addingTimeInterval(60) // End after 1 minute
        )
        
        await activity.update(content)
        
        // End activity after brief delay to show completion
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            Task {
                await self.endActivity(activity)
            }
        }
    }
    
    /// End current Live Activity
    func endCurrentActivity() async {
        guard let activity = currentActivity else { return }
        await endActivity(activity)
    }
    
    /// End specific Live Activity
    private func endActivity(_ activity: Activity<TransportationActivityAttributes>) async {
        let finalState = TransportationActivityAttributes.ContentState(
            recommendation: activity.content.state.recommendation,
            status: .ended,
            lastUpdated: Date(),
            statusMessage: "Activity ended"
        )
        
        let content = ActivityContent(
            state: finalState,
            staleDate: nil
        )
        
        await activity.end(content, dismissalPolicy: .immediate)
        
        await MainActor.run {
            if self.currentActivity?.id == activity.id {
                self.currentActivity = nil
            }
        }
    }
    
    /// Schedule automatic activity end
    private func scheduleActivityEnd(after seconds: Double) {
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
            Task {
                await self.markActivityCompleted(with: "Estimated arrival time reached")
            }
        }
    }
    
    /// Check if Live Activities are available and enabled
    var canStartActivity: Bool {
        return isActivitySupported && currentActivity == nil
    }
    
    /// Clear any stored errors
    func clearError() {
        activityError = nil
    }
}

// MARK: - ActivityKit Attribute Definitions
@available(iOS 16.1, *)
struct TransportationActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        let recommendation: Recommendation
        let status: ActivityStatus
        let lastUpdated: Date
        let statusMessage: String?
        
        init(recommendation: Recommendation, status: ActivityStatus, lastUpdated: Date, statusMessage: String? = nil) {
            self.recommendation = recommendation
            self.status = status
            self.lastUpdated = lastUpdated
            self.statusMessage = statusMessage
        }
    }
    
    let destinationName: String
    let startTime: Date
}

/// Activity status for Live Activity states
enum ActivityStatus: String, Codable, CaseIterable {
    case active = "active"
    case completed = "completed"
    case ended = "ended"
    
    var displayText: String {
        switch self {
        case .active:
            return "En route"
        case .completed:
            return "Arrived"
        case .ended:
            return "Ended"
        }
    }
}

// MARK: - Live Activity Views
@available(iOS 16.1, *)
struct TransportationActivityView: View {
    let context: ActivityViewContext<TransportationActivityAttributes>
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: context.state.recommendation.transportationMode.iconName)
                    .foregroundColor(Color(context.state.recommendation.transportationMode.colorName))
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("To \(context.attributes.destinationName)")
                        .font(.headline)
                        .lineLimit(1)
                    
                    Text(context.state.recommendation.reasoning)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text(context.state.recommendation.primaryETA)
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text(context.state.status.displayText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if let statusMessage = context.state.statusMessage {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
        .padding()
    }
}

// MARK: - Dynamic Island Expanded View
@available(iOS 16.1, *)
struct TransportationDynamicIslandExpandedView: View {
    let context: ActivityViewContext<TransportationActivityAttributes>
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: context.state.recommendation.transportationMode.iconName)
                    .foregroundColor(Color(context.state.recommendation.transportationMode.colorName))
                    .font(.title)
                
                VStack(alignment: .leading) {
                    Text(context.attributes.destinationName)
                        .font(.headline)
                    Text(context.state.recommendation.reasoning)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text(context.state.recommendation.primaryETA)
                    .font(.largeTitle)
                    .fontWeight(.bold)
            }
            
            HStack {
                Text("Confidence: \(context.state.recommendation.confidencePercentage)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(context.state.status.displayText)
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
        .padding()
    }
}