import SwiftUI
import WidgetKit

@main
struct LimitLensWidgetBundle: WidgetBundle {
    @WidgetBundleBuilder
    var body: some Widget {
        LimitLensWidget()
        LimitLensClaudeSmallWidget()
        LimitLensCodexSmallWidget()
        LimitLensClaudeMediumWidget()
        LimitLensCodexMediumWidget()
        LimitLensClaudeLargeWidget()
        LimitLensCodexLargeWidget()
        LimitLensOverviewLargeWidget()
    }
}
