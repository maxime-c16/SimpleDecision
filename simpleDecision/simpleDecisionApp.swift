//
//  simpleDecisionApp.swift
//  simpleDecision
//
//  Created by Tristan Aranda  on 30/09/2025.
//

import SwiftUI
@_exported import Inject

@main
struct simpleDecisionApp: App {
    
    // MARK: - Performance Optimization
    
    /// App launch performance tracker
    private let launchStartTime = CFAbsoluteTimeGetCurrent()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    // T030: Validate <1 second app launch performance
                    let launchTime = CFAbsoluteTimeGetCurrent() - launchStartTime
                    print("App launch time: \(String(format: "%.3f", launchTime))s")
                    
                    // Performance validation - warn if >1 second
                    if launchTime > 1.0 {
                        print("⚠️ App launch time exceeds 1 second target: \(String(format: "%.3f", launchTime))s")
                    } else {
                        print("✅ App launch performance target met: \(String(format: "%.3f", launchTime))s")
                    }
                }
        }
    }
}
