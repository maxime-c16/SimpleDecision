import SwiftUI
import ActivityKit

/// Reusable components for Live Activity UI presentation
/// Used in both Lock Screen and Dynamic Island views

// MARK: - Mode Icon Component

struct ModeIconView: View {
    let mode: TransportationMode
    let size: CGFloat
    
    init(mode: TransportationMode, size: CGFloat = 16) {
        self.mode = mode
        self.size = size
    }
    
    var body: some View {
        Image(systemName: mode.iconName)
            .foregroundColor(Color(mode.colorName))
            .font(.system(size: size, weight: .semibold))
    }
}

// MARK: - ETA Display Component

struct ETADisplayView: View {
    let walkETA: Int?
    let busETA: Int?
    let recommendedMode: TransportationMode
    let layout: Layout
    
    enum Layout {
        case horizontal
        case vertical
        case compact
    }
    
    var body: some View {
        switch layout {
        case .horizontal:
            HStack(spacing: 12) {
                etaItems
            }
        case .vertical:
            VStack(spacing: 4) {
                etaItems
            }
        case .compact:
            HStack(spacing: 6) {
                etaItems
            }
        }
    }
    
    @ViewBuilder
    private var etaItems: some View {
        if let walkETA = walkETA {
            ETAItemView(
                icon: "figure.walk",
                time: walkETA,
                isRecommended: recommendedMode == .walk,
                isCompact: layout == .compact
            )
        }
        
        if let busETA = busETA {
            ETAItemView(
                icon: "bus",
                time: busETA,
                isRecommended: recommendedMode == .bus,
                isCompact: layout == .compact
            )
        }
    }
}

struct ETAItemView: View {
    let icon: String
    let time: Int
    let isRecommended: Bool
    let isCompact: Bool
    
    var body: some View {
        HStack(spacing: isCompact ? 2 : 4) {
            Image(systemName: icon)
                .font(isCompact ? .caption2 : .caption)
            Text("\(time)m")
                .font(isCompact ? .caption2 : .caption)
                .fontWeight(isRecommended ? .semibold : .regular)
        }
        .foregroundColor(isRecommended ? .primary : .secondary)
        .padding(.horizontal, isCompact ? 4 : 6)
        .padding(.vertical, isCompact ? 2 : 3)
        .background(
            RoundedRectangle(cornerRadius: isCompact ? 4 : 6)
                .fill(isRecommended ? Color.primary.opacity(0.1) : Color.clear)
        )
    }
}

// MARK: - Confidence Indicator

struct ConfidenceIndicatorView: View {
    let confidence: Double
    let showPercentage: Bool
    
    init(confidence: Double, showPercentage: Bool = true) {
        self.confidence = confidence
        self.showPercentage = showPercentage
    }
    
    var body: some View {
        HStack(spacing: 4) {
            // Confidence dots indicator
            HStack(spacing: 2) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(confidenceColor(for: index))
                        .frame(width: 4, height: 4)
                }
            }
            
            if showPercentage {
                Text("\(Int(confidence * 100))%")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func confidenceColor(for index: Int) -> Color {
        let threshold = Double(index + 1) / 3.0
        return confidence >= threshold ? .green : .gray.opacity(0.3)
    }
}

// MARK: - Status Badge

struct StatusBadgeView: View {
    let source: RecommendationSource
    let lastUpdated: Date
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(source.displayName)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(sourceColor)
            
            Text("Updated: \(lastUpdated, style: .time)")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
    
    private var sourceColor: Color {
        switch source {
        case .primAPI:
            return .blue
        case .localHeuristics:
            return .orange
        case .mock:
            return .purple
        }
    }
}

// MARK: - Recommendation Summary

struct RecommendationSummaryView: View {
    let recommendation: Recommendation
    let showDetails: Bool
    
    init(recommendation: Recommendation, showDetails: Bool = true) {
        self.recommendation = recommendation
        self.showDetails = showDetails
    }
    
    var body: some View {
        HStack(spacing: 8) {
            ModeIconView(mode: recommendation.mode, size: 18)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(recommendation.mode.displayName)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                if showDetails {
                    HStack(spacing: 8) {
                        if let eta = recommendation.primaryETA {
                            Text("\(eta) min")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        ConfidenceIndicatorView(
                            confidence: recommendation.confidence,
                            showPercentage: false
                        )
                    }
                }
            }
            
            Spacer()
            
            if let primaryETA = recommendation.primaryETA {
                Text("\(primaryETA)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(Color(recommendation.mode.colorName))
            }
        }
    }
}

// MARK: - Preview Helpers

// MARK: - Preview Support (Widget Extension Only)

#if DEBUG
extension TransportationRecommendationWidgetAttributes.ContentState {
    static var previewWalk: TransportationRecommendationWidgetAttributes.ContentState {
        TransportationRecommendationWidgetAttributes.ContentState(
            recommendation: Recommendation.mockWalk,
            lastUpdated: Date()
        )
    }
    
    static var previewBus: TransportationRecommendationWidgetAttributes.ContentState {
        TransportationRecommendationWidgetAttributes.ContentState(
            recommendation: Recommendation.mockBus,
            lastUpdated: Date()
        )
    }
    
    static var previewTie: TransportationRecommendationWidgetAttributes.ContentState {
        TransportationRecommendationWidgetAttributes.ContentState(
            recommendation: Recommendation.mockTie,
            lastUpdated: Date()
        )
    }
}
#endif