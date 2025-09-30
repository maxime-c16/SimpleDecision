//
//  TransportationRecommendationWidgetLiveActivity.swift
//  TransportationRecommendationWidget
//
//  Created by Tristan Aranda  on 30/09/2025.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct TransportationRecommendationWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct TransportationRecommendationWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TransportationRecommendationWidgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension TransportationRecommendationWidgetAttributes {
    fileprivate static var preview: TransportationRecommendationWidgetAttributes {
        TransportationRecommendationWidgetAttributes(name: "World")
    }
}

extension TransportationRecommendationWidgetAttributes.ContentState {
    fileprivate static var smiley: TransportationRecommendationWidgetAttributes.ContentState {
        TransportationRecommendationWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: TransportationRecommendationWidgetAttributes.ContentState {
         TransportationRecommendationWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: TransportationRecommendationWidgetAttributes.preview) {
   TransportationRecommendationWidgetLiveActivity()
} contentStates: {
    TransportationRecommendationWidgetAttributes.ContentState.smiley
    TransportationRecommendationWidgetAttributes.ContentState.starEyes
}
