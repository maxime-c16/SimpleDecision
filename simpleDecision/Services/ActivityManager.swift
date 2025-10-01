//
//  ActivityManager.swift
//  simpleDecision
//
//  Created by Transportation Recommendation System on 30/09/2025.
//

import Foundation
import ActivityKit
import SwiftUI
import Combine

/// Protocol for Activity Management (supports both iOS 16.1+ and fallback implementations)
protocol ActivityManagerProtocol {
    func startActivity(destinationName: String, startLocationName: String, recommendation: Recommendation) async -> Bool
    func updateActivity(with recommendation: Recommendation) async -> Bool
    func endAllActivities() async -> Bool
    func markActivityCompleted() async -> Bool
    func isActivitySupported() -> Bool
    func hasActiveActivities() -> Bool
    var canStartActivity: Bool { get }
}

/// Manages Live Activities for displaying transportation recommendations on Lock Screen and Dynamic Island
/// Official ActivityKit implementation following Apple's recommended patterns
@available(iOS 16.1, *)
class LiveActivityManager: ActivityManagerProtocol, ObservableObject {
    nonisolated static let shared = LiveActivityManager()
    
    @Published var currentActivity: Activity<TransportationRecommendationWidgetAttributes>?
    @Published var activityError: String?
    @Published var isActivitiesEnabled: Bool
    
    private var activityUpdateTask: Task<Void, Never>?
    
    private init() {
        self.isActivitiesEnabled = ActivityAuthorizationInfo().areActivitiesEnabled
        
        // Monitor activity authorization changes
        startMonitoringActivityAuthorization()
        
        // Monitor existing activities on app launch
        restoreActiveActivities()
    }
    
    deinit {
        activityUpdateTask?.cancel()
    }
    
    // MARK: - ActivityManagerProtocol Implementation
    
    func startActivity(destinationName: String, startLocationName: String, recommendation: Recommendation) async -> Bool {
        print("🟡 ActivityManager: Attempting to start Live Activity")
        print("🟡 Activities enabled: \(isActivitiesEnabled)")
        print("🟡 Authorization info: \(ActivityAuthorizationInfo().areActivitiesEnabled)")
        
        guard isActivitiesEnabled else {
            await updateError("Live Activities are not enabled by user")
            print("🔴 Live Activities disabled by user")
            return false
        }
        
        // End any existing activity first
        await endAllActivities()
        
        // Create session ID that includes destination info
        let sessionId = "\(startLocationName)-to-\(destinationName)-\(Date().timeIntervalSince1970)"
        
        let attributes = TransportationRecommendationWidgetAttributes(
            sessionId: sessionId
        )
        
        let initialState = TransportationRecommendationWidgetAttributes.ContentState(
            recommendation: recommendation,
            lastUpdated: Date()
        )
        
        do {
            // Simple Activity.request without push notifications (app-only updates)
            let activity = try Activity.request(
                attributes: attributes,
                content: ActivityContent(
                    state: initialState,
                    staleDate: Date().addingTimeInterval(120) // 2 minutes staleness
                )
            )
            
            print("✅ Live Activity started successfully!")
            print("✅ Activity ID: \(activity.id)")
            
            await MainActor.run {
                self.currentActivity = activity
                self.activityError = nil
            }
            
            // Schedule automatic end after reasonable time (8 hours max)
            scheduleAutomaticEnd(after: TimeInterval(8 * 60 * 60)) // 8 hours
            
            return true
            
        } catch {
            print("🔴 Failed to start Live Activity: \(error)")
            await updateError("Failed to start Live Activity: \(error.localizedDescription)")
            return false
        }
    }
    
    func updateActivity(with recommendation: Recommendation) async -> Bool {
        guard let activity = currentActivity else { 
            return false 
        }
        
        let updatedState = TransportationRecommendationWidgetAttributes.ContentState(
            recommendation: recommendation,
            lastUpdated: Date()
        )
        
        await activity.update(
            ActivityContent(
                state: updatedState,
                staleDate: Date().addingTimeInterval(120) // 2 minutes staleness
            )
        )
        
        return true
    }
    
    func endAllActivities() async -> Bool {
        var hasEnded = false
        
        // End current managed activity
        if let activity = currentActivity {
            await endActivity(activity)
            hasEnded = true
        }
        
        // End any other transportation activities (cleanup)
        for activity in Activity<TransportationRecommendationWidgetAttributes>.activities {
            if activity.id != currentActivity?.id {
                await activity.end(nil, dismissalPolicy: .immediate)
                hasEnded = true
            }
        }
        
        await MainActor.run {
            self.currentActivity = nil
        }
        
        return hasEnded
    }
    
    func isActivitySupported() -> Bool {
        return isActivitiesEnabled
    }
    
    func hasActiveActivities() -> Bool {
        return currentActivity != nil
    }
    
    func markActivityCompleted() async -> Bool {
        return await markActivityCompleted(with: "Journey completed")
    }
    
    var canStartActivity: Bool {
        return isActivitiesEnabled && currentActivity == nil
    }
    
    
    // MARK: - Private Implementation
    
    /// Monitor activity authorization changes
    private func startMonitoringActivityAuthorization() {
        activityUpdateTask = Task {
            for await update in ActivityAuthorizationInfo().activityEnablementUpdates {
                await MainActor.run {
                    self.isActivitiesEnabled = update
                    if !update {
                        // If activities become disabled, end current activity
                        Task {
                            await self.endAllActivities()
                        }
                    }
                }
            }
        }
    }
    
    /// Restore any existing activities on app launch
    private func restoreActiveActivities() {
        Task {
            let activities = Activity<TransportationRecommendationWidgetAttributes>.activities
            if let latestActivity = activities.last {
                await MainActor.run {
                    self.currentActivity = latestActivity
                }
            }
        }
    }
    
    /// End specific activity
    private func endActivity(_ activity: Activity<TransportationRecommendationWidgetAttributes>) async {
        await activity.end(nil, dismissalPolicy: .immediate)
        
        await MainActor.run {
            if self.currentActivity?.id == activity.id {
                self.currentActivity = nil
            }
        }
    }
    
    /// Schedule automatic activity end (safety measure)
    private func scheduleAutomaticEnd(after timeInterval: TimeInterval) {
        DispatchQueue.main.asyncAfter(deadline: .now() + timeInterval) {
            Task {
                await self.endAllActivities()
            }
        }
    }
    
    /// Generate unique session ID for activity
    private func generateSessionId(destination: String, start: String) -> String {
        let timestamp = Date().timeIntervalSince1970
        return "\(start.prefix(10))-to-\(destination.prefix(10))-\(Int(timestamp))"
    }
    
    /// Update error message on main actor
    private func updateError(_ message: String) async {
        await MainActor.run {
            self.activityError = message
        }
    }
    
    // MARK: - Public Convenience Methods
    
    /// Mark activity as completed (user arrived)
    func markActivityCompleted(with message: String = "Journey completed") async -> Bool {
        guard let activity = currentActivity else { return false }
        
        // Brief completion state before ending
        let completedState = TransportationRecommendationWidgetAttributes.ContentState(
            recommendation: activity.content.state.recommendation,
            lastUpdated: Date()
        )
        
        await activity.update(
            ActivityContent(
                state: completedState,
                staleDate: Date().addingTimeInterval(30) // End after 30 seconds
            )
        )
        
        // End activity after brief delay to show completion
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            Task {
                await self.endActivity(activity)
            }
        }
        
        return true
    }
    

    
    /// Clear any stored errors
    func clearError() {
        activityError = nil
    }
}

// MARK: - Fallback Implementation for iOS < 16.1

/// No-operation Activity Manager for iOS versions that don't support Live Activities
class NoOpActivityManager: ActivityManagerProtocol, @unchecked Sendable {
    func startActivity(destinationName: String, startLocationName: String, recommendation: Recommendation) async -> Bool {
        return false
    }
    
    func updateActivity(with recommendation: Recommendation) async -> Bool {
        return false
    }
    
    func endAllActivities() async -> Bool {
        return false
    }
    
    func isActivitySupported() -> Bool {
        return false
    }
    
    func hasActiveActivities() -> Bool {
        return false
    }
    
    func markActivityCompleted() async -> Bool {
        return false
    }
    
    var canStartActivity: Bool {
        return false
    }
}

// MARK: - Activity Manager Factory

/// Factory for creating appropriate Activity Manager based on iOS version
class ActivityManagerFactory {
    static func createActivityManager() -> ActivityManagerProtocol {
        if #available(iOS 16.1, *) {
            return LiveActivityManager.shared
        } else {
            return NoOpActivityManager()
        }
    }
}