//
//  ContentView.swift
//  SatHunter705
//
//  Created by Zhuo Peng on 5/28/23.
//

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
