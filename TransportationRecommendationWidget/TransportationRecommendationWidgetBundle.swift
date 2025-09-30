//
//  TransportationRecommendationWidgetBundle.swift
//  TransportationRecommendationWidget
//
//  Created by Tristan Aranda  on 30/09/2025.
//

import WidgetKit
import SwiftUI

@main
struct TransportationRecommendationWidgetBundle: WidgetBundle {
    var body: some Widget {
        TransportationRecommendationWidget()
        TransportationRecommendationWidgetControl()
        TransportationRecommendationWidgetLiveActivity()
    }
}
