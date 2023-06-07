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
        maxEl: $model.maxEl,
        userGrid: $model.userGridSquare
      )
    }.onAppear {
      model.trackedSat = SatOrbitElements(trackedSat.tleTuple)
    }
  }
}
