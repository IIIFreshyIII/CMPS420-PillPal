import SwiftUI
import WidgetKit

@main
@available(iOS 16.1, *)
struct PillPalWidgetBundle: WidgetBundle {
  var body: some Widget {
    PillPalLiveActivityWidget()
  }
}
