//
//  Recommendation.swift
//  simpleDecision
//
//  Created by Transportation Recommendation System on 30/09/2025.
//

import Foundation

/// Core decision output with transportation mode and metadata
struct Recommendation: Codable, Equatable, Identifiable {
    let id = UUID()
    let mode: TransportationMode
    let walkETA: Int?           // minutes, nil if unavailable
    let busETA: Int?            // minutes, nil if unavailable  
    let confidence: Double      // 0.0 to 1.0
    let timestamp: Date
    let source: RecommendationSource
    
    /// Validation for recommendation data integrity
    var isValid: Bool {
        // Confidence must be between 0.0 and 1.0
        guard confidence >= 0.0 && confidence <= 1.0 else { return false }
        
        // At least one ETA should be non-nil for non-tie recommendations
        if mode != .tie && walkETA == nil && busETA == nil {
            return false
        }
        
        // Timestamp should be recent (within last 5 minutes for validity)
        let fiveMinutesAgo = Date().addingTimeInterval(-300)
        return timestamp > fiveMinutesAgo
    }
    
    /// Primary ETA based on recommended mode
    var primaryETA: Int? {
        switch mode {
        case .walk:
            return walkETA
        case .bus:
            return busETA
        case .tie:
            return min(walkETA ?? Int.max, busETA ?? Int.max)
        }
    }
    
    /// Display-friendly confidence percentage
    var confidencePercentage: Int {
        Int(confidence * 100)
    }
}

/// Transportation mode options
enum TransportationMode: String, Codable, CaseIterable {
    case walk = "Walk"
    case bus = "Bus" 
    case tie = "Tie"
    
    /// Icon name for UI display
    var iconName: String {
        switch self {
        case .walk: return "figure.walk"
        case .bus: return "bus"
        case .tie: return "arrow.left.arrow.right"
        }
    }
    
    /// Color for UI display
    var colorName: String {
        switch self {
        case .walk: return "green"
        case .bus: return "blue"
        case .tie: return "orange"
        }
    }
}

/// Source of recommendation data
enum RecommendationSource: String, Codable {
    case localHeuristics = "Local"
    case primAPI = "PRIM"
    case mock = "Mock"
    
    /// Display name for UI
    var displayName: String {
        switch self {
        case .localHeuristics: return "Local Calculation"
        case .primAPI: return "PRIM Real-time"
        case .mock: return "Mock Data"
        }
    }
}

// MARK: - Mock Data for Development
extension Recommendation {
    /// Mock recommendation for development and testing
    static let mockWalk = Recommendation(
        mode: .walk,
        walkETA: 12,
        busETA: 15,
        confidence: 0.8,
        timestamp: Date(),
        source: .mock
    )
    
    static let mockBus = Recommendation(
        mode: .bus,
        walkETA: 18,
        busETA: 8,
        confidence: 0.9,
        timestamp: Date(),
        source: .mock
    )
    
    static let mockTie = Recommendation(
        mode: .tie,
        walkETA: 10,
        busETA: 10,
        confidence: 0.7,
        timestamp: Date(),
        source: .mock
    )
    
    /// Array of mock recommendations for testing
    static let mockRecommendations = [mockWalk, mockBus, mockTie]
}