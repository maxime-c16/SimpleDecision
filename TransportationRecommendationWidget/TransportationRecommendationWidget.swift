//
//  TransportationRecommendationWidget.swift
//  TransportationRecommendationWidget
//
//  Created by Tristan Aranda  on 30/09/2025.
//

import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), recommendation: Recommendation.mockWalk)
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date(), recommendation: Recommendation.mockWalk)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        var entries: [SimpleEntry] = []

        // Generate a timeline with mock transportation recommendations
        let currentDate = Date()
        let mockRecommendations = [Recommendation.mockWalk, Recommendation.mockBus, Recommendation.mockTie]
        
        for (index, mockRec) in mockRecommendations.enumerated() {
            let entryDate = Calendar.current.date(byAdding: .minute, value: index * 20, to: currentDate)!
            let entry = SimpleEntry(date: entryDate, recommendation: mockRec)
            entries.append(entry)
        }

        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let recommendation: Recommendation
}

struct TransportationRecommendationWidgetEntryView : View {
    var entry: Provider.Entry

    var body: some View {
        VStack(spacing: 8) {
            // Transportation mode icon and name
            HStack {
                Image(systemName: entry.recommendation.mode.iconName)
                    .font(.title2)
                    .foregroundColor(Color(entry.recommendation.mode.colorName))
                
                Text(entry.recommendation.mode.displayName)
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            // ETA information
            if let eta = entry.recommendation.primaryETA {
                Text("\(eta) min")
                    .font(.title3)
                    .fontWeight(.medium)
            }
            
            // Confidence indicator
            HStack {
                Image(systemName: "gauge")
                    .font(.caption)
                Text("\(entry.recommendation.confidencePercentage)%")
                    .font(.caption)
            }
            .foregroundColor(.secondary)
        }
        .padding(8)
    }
}

struct TransportationRecommendationWidget: Widget {
    let kind: String = "TransportationRecommendationWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            if #available(iOS 17.0, *) {
                TransportationRecommendationWidgetEntryView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                TransportationRecommendationWidgetEntryView(entry: entry)
                    .padding()
                    .background()
            }
        }
        .configurationDisplayName("Transportation Recommendation")
        .description("Shows your recommended transportation mode with ETA.")
    }
}

#Preview(as: .systemSmall) {
    TransportationRecommendationWidget()
} timeline: {
    SimpleEntry(date: .now, recommendation: Recommendation.mockWalk)
    SimpleEntry(date: .now, recommendation: Recommendation.mockBus)
}
