//
//  TransportationRecommendationWidgetControl.swift
//  TransportationRecommendationWidget
//
//  Created by Tristan Aranda  on 30/09/2025.
//

import AppIntents
import SwiftUI
import WidgetKit

struct TransportationRecommendationWidgetControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(
            kind: "slaicer.simpleDecision.TransportationRecommendationWidget",
            provider: Provider()
        ) { value in
            ControlWidgetToggle(
                "Auto-Update Recommendations",
                isOn: value,
                action: ToggleRecommendationUpdatesIntent()
            ) { isEnabled in
                Label(isEnabled ? "Auto" : "Manual", systemImage: isEnabled ? "arrow.clockwise" : "pause.circle")
            }
        }
        .displayName("Transportation Updates")
        .description("Toggle automatic transportation recommendation updates.")
    }
}

extension TransportationRecommendationWidgetControl {
    struct Provider: ControlValueProvider {
        var previewValue: Bool {
            false
        }

        func currentValue() async throws -> Bool {
            let isAutoUpdateEnabled = true // Check if auto-updates are enabled
            return isAutoUpdateEnabled
        }
    }
}

struct ToggleRecommendationUpdatesIntent: SetValueIntent {
    static let title: LocalizedStringResource = "Toggle recommendation updates"

    @Parameter(title: "Auto-updates enabled")
    var value: Bool

    func perform() async throws -> some IntentResult {
        // Toggle automatic recommendation updates based on `value`.
        return .result()
    }
}
