import SwiftUI

struct TrackingView: View {
  @State var satellite: Satellite
  var body: some View {
    VStack {
      RigControlView(trackedSat: Binding<Satellite?>($satellite))
      SatView(trackedSat: Binding<Satellite?>($satellite))
      .ignoresSafeArea(.keyboard)
    }
  }
}
