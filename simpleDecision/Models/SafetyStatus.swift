//
//  SafetyStatus.swift
//  simpleDecision
//
//  Created by Safety System on 23/10/2025.
//

import Foundation

/// Safety classification based on time buffer before critical departure
enum SafetyStatus {
    case comfortable      // ✅ 5+ min buffer - plenty of time
    case acceptable       // ⚠️ 2-5 min buffer - tight but manageable
    case tooRisky         // 🚫 < 2 min buffer - too risky to recommend
    
    var emoji: String {
        switch self {
        case .comfortable: return "✅"
        case .acceptable: return "⚠️"
        case .tooRisky: return "🚫"
        }
    }
    
    var description: String {
        switch self {
        case .comfortable: return "Comfortable - plenty of time"
        case .acceptable: return "Acceptable - tight timing"
        case .tooRisky: return "Too risky - use with caution"
        }
    }
}
