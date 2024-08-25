//
//  SatFreqView.swift
//  SatHunter
//
//  Created by Zhuo Peng on 6/9/23.
//

import SwiftUI

struct SatelliteFrequencyView: View {
  @Binding var satelliteDownlinkFrequency: Int
  @Binding var satelliteUplinkFrequency: Int
  @Binding var groundDownlinkFrequency: Int?
  @Binding var groundUplinkFrequency: Int?
    
  var body: some View {
    VStack{
      HStack {
        Image(systemName: "arrow.down")
        Text(satelliteDownlinkFrequency.asFormattedFreq)
        Spacer()
        Divider()
        Image(systemName: "dot.radiowaves.forward")
        Text(getGroundDownlinkFrequency())
          .frame(maxHeight: .infinity)
        Spacer()
      }
      HStack {
        Image(systemName: "arrow.up")
        Text(satelliteUplinkFrequency.asFormattedFreq)
        Spacer()
        Divider()
        Image(systemName: "dot.radiowaves.forward")
        Text(getGroundUplinkFrequency())
          .frame(maxHeight: .infinity)
        Spacer()
      }
    }.font(.body.monospaced())
  }

  private func getGroundDownlinkFrequency() -> String {
    if let f = groundDownlinkFrequency {
      return f.asFormattedFreq
    }
    return "N/A"
  }

  private func getGroundUplinkFrequency() -> String {
    if let f = groundUplinkFrequency {
      return f.asFormattedFreq
    }
    return "N/A"
  }
}

struct SatelliteFrequencyView_Previews: PreviewProvider {
    static var previews: some View {
        SatelliteFrequencyView(
            satelliteDownlinkFrequency: .constant(144000000), satelliteUplinkFrequency: .constant(440000000), groundDownlinkFrequency: .constant(144005000), groundUplinkFrequency: .constant(440010000)
        )
    }
}
