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
  @Binding var elevation: Double?
  @Binding var azimuth: Double?
  @Binding var maxEl: Double?
  @Binding var userGrid: String

  var body: some View {
    VStack {
      Text(satName).font(.title)
      if let isVisible = isVisible {
        if isVisible {
          Text("Passing")
            VStack {
                // LOS
                HStack {
                    Text("LOS:")
                    Spacer()
                    Text(
                        "\(los!.formatted(date: .omitted, time: .shortened)) (\(Duration.seconds(los!.timeIntervalSinceNow).formatted(.time(pattern: .minuteSecond))))"
                    )
                }
                // Azimuth
                HStack {
                    Text("Az: ")
                    Spacer()
                    Text(String(format: "%.1f°", azimuth!))
                }
                // Elevation
                HStack {
                    Text("El: ")
                    Spacer()
                    Text(String(format: "%.1f°", elevation!))
                }
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
            Text("\(String(format: "%.0f", maxEl!)) °")
          }
        }
        HStack {
          Text("My Grid:")
          Spacer()
          Text(userGrid)
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
      satName: "SO-50",
      isVisible: .constant(true),
      los: .constant(Date.now),
      nextAos: .constant(Date.now),
      nextLos: .constant(Date.now),
      elevation: .constant(0),
      azimuth: .constant(45),
      maxEl: .constant(13.5),
      userGrid: .constant("CM87")
    )
  }
}
