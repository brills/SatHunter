//
//  SatFreqView.swift
//  SatHunter
//
//  Created by Zhuo Peng on 6/9/23.
//

import SwiftUI

struct SatFreqView: View {
  @Binding var downlinkFreqAtSat: Int
  @Binding var uplinkFreqAtSat: Int
  @Binding var downlinkFreqAtGround: Int?
  @Binding var uplinkFreqAtGround: Int?
  var body: some View {
    VStack{
      HStack {
        Image(systemName: "arrow.down")
        Text(downlinkFreqAtSat.asFormattedFreq)
        Spacer()
        Divider()
        Image(systemName: "dot.radiowaves.forward")
        Text(getDownlinkFreqAtGround())
          .frame(maxHeight: .infinity)
        Spacer()
      }
      HStack {
        Image(systemName: "arrow.up")
        Text(uplinkFreqAtSat.asFormattedFreq)
        Spacer()
        Divider()
        Image(systemName: "dot.radiowaves.forward")
        Text(getUplinkFreqAtGround())
          .frame(maxHeight: .infinity)
        Spacer()
      }
    }.font(.body.monospaced())
  }

  private func getDownlinkFreqAtGround() -> String {
    if let f = downlinkFreqAtGround {
      return f.asFormattedFreq
    }
    return "N/A"
  }

  private func getUplinkFreqAtGround() -> String {
    if let f = uplinkFreqAtGround {
      return f.asFormattedFreq
    }
    return "N/A"
  }
}

struct SatFreqView_Previews: PreviewProvider {
    static var previews: some View {
        SatFreqView(
          downlinkFreqAtSat: .constant(144000000), uplinkFreqAtSat: .constant(440000000), downlinkFreqAtGround: .constant(144005000), uplinkFreqAtGround: .constant(440010000)
        )
    }
}
