import SwiftUI

struct TrackingView: View {
  var satellite: Satellite
  var body: some View {
    VStack {
      RigControlView(trackedSat: satellite)
      SatView(trackedSat: satellite)
    }
    .onAppear {
      UIApplication.shared.isIdleTimerDisabled = true
    }
    .onDisappear {
      UIApplication.shared.isIdleTimerDisabled = false
    }
  }
}
