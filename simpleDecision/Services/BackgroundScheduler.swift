//
//  BackgroundScheduler.swift
//  simpleDecision
//
//  Created by Transportation Recommendation System on 30/09/2025.
//

import Foundation
import BackgroundTasks
import Combine
import UserNotifications
import UIKit

/// Handles background refresh and scheduling for the transportation recommendation system
class BackgroundScheduler: ObservableObject {
    static let shared = BackgroundScheduler()
    
    // Background task identifiers (must match Info.plist)
    static let refreshIdentifier = "com.simpleDecision.backgroundRefresh"
    static let processingIdentifier = "com.simpleDecision.backgroundProcessing"
    
    @Published var isBackgroundRefreshEnabled = false
    @Published var lastBackgroundRefresh: Date?
    @Published var backgroundError: String?
    
    private var cancellables = Set<AnyCancellable>()
    private let notificationCenter = UNUserNotificationCenter.current()
    
    private init() {
        checkBackgroundRefreshStatus()
        registerBackgroundTasks()
    }
    
    /// Register background task handlers
    private func registerBackgroundTasks() {
        // Quick refresh task (30 seconds)
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.refreshIdentifier, using: nil) { task in
            self.handleBackgroundRefresh(task: task as! BGAppRefreshTask)
        }
        
        // Longer processing task (1 minute)
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.processingIdentifier, using: nil) { task in
            self.handleBackgroundProcessing(task: task as! BGProcessingTask)
        }
    }
    
    /// Handle quick background refresh
    private func handleBackgroundRefresh(task: BGAppRefreshTask) {
        scheduleNextBackgroundRefresh()
        
        let operation = BackgroundRefreshOperation()
        
        task.expirationHandler = {
            operation.cancel()
        }
        
        operation.completionBlock = {
            task.setTaskCompleted(success: !operation.isCancelled)
            DispatchQueue.main.async {
                self.lastBackgroundRefresh = Date()
            }
        }
        
        OperationQueue().addOperation(operation)
    }
    
    /// Handle longer background processing
    private func handleBackgroundProcessing(task: BGProcessingTask) {
        scheduleNextBackgroundProcessing()
        
        let operation = BackgroundProcessingOperation()
        
        task.expirationHandler = {
            operation.cancel()
        }
        
        operation.completionBlock = {
            task.setTaskCompleted(success: !operation.isCancelled)
        }
        
        OperationQueue().addOperation(operation)
    }
    
    /// Schedule next background refresh (app refresh)
    func scheduleNextBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Self.refreshIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes from now
        
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            DispatchQueue.main.async {
                self.backgroundError = "Failed to schedule background refresh: \(error.localizedDescription)"
            }
        }
    }
    
    /// Schedule next background processing (longer task)
    func scheduleNextBackgroundProcessing() {
        let request = BGProcessingTaskRequest(identifier: Self.processingIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60) // 1 hour from now
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            DispatchQueue.main.async {
                self.backgroundError = "Failed to schedule background processing: \(error.localizedDescription)"
            }
        }
    }
    
    /// Check system background refresh authorization
    private func checkBackgroundRefreshStatus() {
        isBackgroundRefreshEnabled = UIApplication.shared.backgroundRefreshStatus == .available
    }
    
    /// Request notification permissions for background alerts
    func requestNotificationPermissions() {
        notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                DispatchQueue.main.async {
                    self.backgroundError = "Notification permission error: \(error.localizedDescription)"
                }
            }
        }
    }
    
    /// Send local notification (for significant transportation updates)
    func sendNotification(title: String, body: String, identifier: String = UUID().uuidString) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        
        notificationCenter.add(request) { error in
            if let error = error {
                DispatchQueue.main.async {
                    self.backgroundError = "Failed to send notification: \(error.localizedDescription)"
                }
            }
        }
    }
    
    /// Initialize background scheduling when app becomes active
    func initializeBackgroundTasks() {
        guard isBackgroundRefreshEnabled else {
            backgroundError = "Background refresh is disabled in Settings"
            return
        }
        
        scheduleNextBackgroundRefresh()
        scheduleNextBackgroundProcessing()
        requestNotificationPermissions()
    }
    
    /// Cancel all pending background tasks
    func cancelAllBackgroundTasks() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.refreshIdentifier)
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.processingIdentifier)
    }
    
    /// Clear any stored errors
    func clearError() {
        backgroundError = nil
    }
}

// MARK: - Background Operations
class BackgroundRefreshOperation: Operation, @unchecked Sendable {
    override func main() {
        guard !isCancelled else { return }
        
        // Quick refresh: check for transit alerts, update cached data
        let semaphore = DispatchSemaphore(value: 0)
        
        // Simulate quick background work
        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 2) {
            // In production: fetch critical updates, check for alerts
            print("Background refresh completed")
            semaphore.signal()
        }
        
        semaphore.wait()
    }
}

class BackgroundProcessingOperation: Operation, @unchecked Sendable {
    override func main() {
        guard !isCancelled else { return }
        
        // Longer processing: preload transit data, analyze patterns
        let semaphore = DispatchSemaphore(value: 0)
        
        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 10) {
            // In production: analyze usage patterns, preload route data
            print("Background processing completed")
            semaphore.signal()
        }
        
        semaphore.wait()
    }
}

// MARK: - Background Task Management Extensions
extension BackgroundScheduler {
    /// Debug method to test background tasks in simulator
    func simulateBackgroundRefresh() {
        #if DEBUG
        let operation = BackgroundRefreshOperation()
        operation.completionBlock = {
            DispatchQueue.main.async {
                self.lastBackgroundRefresh = Date()
                print("Simulated background refresh completed")
            }
        }
        OperationQueue().addOperation(operation)
        #endif
    }
    
    /// Get status information for debugging
    var debugStatus: String {
        var status = "Background Refresh: \(isBackgroundRefreshEnabled ? "Enabled" : "Disabled")\n"
        
        if let lastRefresh = lastBackgroundRefresh {
            let formatter = DateFormatter()
            formatter.timeStyle = .medium
            formatter.dateStyle = .short
            status += "Last Refresh: \(formatter.string(from: lastRefresh))\n"
        } else {
            status += "Last Refresh: Never\n"
        }
        
        if let error = backgroundError {
            status += "Error: \(error)"
        } else {
            status += "Status: OK"
        }
        
        return status
    }
}

// MARK: - Notification Categories
extension BackgroundScheduler {
    /// Register notification categories for interactive notifications
    func registerNotificationCategories() {
        let refreshAction = UNNotificationAction(
            identifier: "REFRESH_ACTION",
            title: "Refresh Now",
            options: [.foreground]
        )
        
        let transportationCategory = UNNotificationCategory(
            identifier: "TRANSPORTATION_UPDATE",
            actions: [refreshAction],
            intentIdentifiers: [],
            options: []
        )
        
        notificationCenter.setNotificationCategories([transportationCategory])
    }
}