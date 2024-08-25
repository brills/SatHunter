import Foundation
import SwiftUI

struct SatView: View {
  var trackedSat: Satellite
  @StateObject var model = SatViewModel()

  var body: some View {
    HStack {
      SkyView(model: model)
      SatInfoView(
        satName: trackedSat.name,
        isVisible: $model.visible,
        los: $model.currentLos,
        nextAos: $model.nextAos,
        nextLos: $model.nextLos,
        elevation: $model.currentEl,
        azimuth: $model.currentAz,
        maxEl: $model.maxEl,
        userGrid: $model.userGridSquare
      )
    }.onAppear {
      model.trackedSat = SatelliteOrbitElements(trackedSat.tleTuple)
    }
  }
}
