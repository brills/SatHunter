//
//  SatInfoView.swift
//  SatHunter
//
//  Created by Zhuo Peng on 6/6/23.
//

import SwiftUI

struct SatInfoView: View {
  var satName: String
  @Binding var isVisible: Bool?
  @Binding var los: Date?
  @Binding var nextAos: Date?
  @Binding var nextLos: Date?
  @Binding var maxEl: Double?
  @Binding var userGrid: String

  var body: some View {
    VStack {
      Text(satName).font(.title)
      if let isVisible = isVisible {
        if isVisible {
          Text("Passing")
          HStack {
            Text("LOS:")
            Spacer()
            Text(
              "\(los!.formatted(date: .omitted, time: .shortened)) (\(Duration.seconds(los!.timeIntervalSinceNow).formatted(.time(pattern: .minuteSecond))))"
            )
          }
        } else {
          Text("Next pass")
          HStack {
            Text("AOS:")
            Spacer()
            Text(
              "\(nextAos!.formatted(date: .omitted, time: .shortened))"
            )
          }
          HStack {
            Text("LOS:")
            Spacer()
            Text(
              "\(nextLos!.formatted(date: .omitted, time: .shortened))"
            )
          }
          HStack {
            Text(
              "Max el:"
            )
            Spacer()
            Text("\(String(format: "%.0f", maxEl!)) deg")
          }
        }
        HStack {
          Text("Your grid:")
          Spacer()
          Text(userGrid)
        }
        HStack {
          Text("Times are local").font(.footnote)
          Spacer()
        }
      } else {
        Text("Calculating...")
      }
    }.frame(maxWidth: .infinity).font(.body.monospaced())
  }
}

struct SatInfoView_Previews: PreviewProvider {
  static var previews: some View {
    SatInfoView(
      satName: "XW-2A",
      isVisible: .constant(true),
      los: .constant(Date.now),
      nextAos: .constant(Date.now),
      nextLos: .constant(Date.now),
      maxEl: .constant(13.5),
      userGrid: .constant("CM87")
    )
  }
}
