//
//  ContentView.swift
//  SatHunter705
//
//  Created by Zhuo Peng on 5/28/23.
//

import SwiftUI

struct TrackingView: View {
  @State var satName: String
  @State var trackedSatTle: (String, String)
  var body: some View {
    VStack {
      RigControlView(trackedSatTle: Binding($trackedSatTle))
      SatView(
        satName: .constant(satName),
        trackedSat: .constant(SatOrbitElements(trackedSatTle))
      ).ignoresSafeArea(.keyboard)
    }
  }
}

struct TrackingView_Previews: PreviewProvider {
    static var previews: some View {
      SatView(
        satName: .constant("SO-50"),
        trackedSat: .constant(SatOrbitElements((
          "1 43017U 17073E   23148.65820382  .00005218  00000-0  36602-3 0  9991",
          "2 43017  97.6335  33.7713 0235411 133.4974 228.6079 14.85813046298284"
        )))
      )

    }
}

fileprivate func getTrackedSatForTesting() -> SatOrbitElements? {
  guard case let .success(tle) = downloadAmsatTleFile() else {
    return nil
  }
  guard case let .success(tleDict) = parseTleFile(tle) else {
    return nil
  }
  
  return SatOrbitElements(tleDict["AO-07"]!)
}
