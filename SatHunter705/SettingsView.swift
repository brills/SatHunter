//
//  SettingsView.swift
//  SatHunter705
//
//  Created by Zhuo Peng on 6/1/23.
//

import SwiftUI

struct SettingsView: View {
  @State var isLoading: Bool = false
  @State var lastTleLoadTime: Date? = SatInfoManager(
    onlyLoadLocally: true).lastUpdated
  @State var btId: UUID = getBtId(requestNew: false)
  var body: some View {
    ZStack {
      List {
        Section(content: {
          HStack {
            Text("Bluetooth ID")
            Text(btId.uuidString)
              .font(.body.monospaced())
              .minimumScaleFactor(0.6)
              .scaledToFit()
          }
          Button("Reset") {
            btId = getBtId(requestNew: true)
          }
        }, footer: {
          Text(
            "Your IC-705 remembers this ID when you pair it " +
            "with your iPhone the first time, after which it " +
            "only accepts BTLE connection from this iPhone."
          )
        })
        Section(content: {
          HStack {
            Text("Data last updated")
            Text(getLastTleLoadTime()).foregroundColor(.gray)
          }
          Button("Update now") {
            self.isLoading = true
            DispatchQueue.global().async {
              let m = SatInfoManager()
              _ = m.loadFromInternet()
              let d = m.lastUpdated
              DispatchQueue.main.async {
                self.lastTleLoadTime = d
                self.isLoading = false
              }
            }
          }
        }, footer: {
          Text(
            "SatHunter705 downloads TLE and transponder information " +
            "from the Internet. Use the latest orbit elements for the " +
            "most accurate predictions."
          )
          })
      }
      .navigationTitle("Settings")
    }.disabled(isLoading)
    if isLoading {
      ProgressView()
    }
  }
  private func getLastTleLoadTime() -> String {
    if let d = lastTleLoadTime {
      return d.formatted(date:.numeric, time:.standard)
    }
    return "Never"
  }
}

struct SettingsView_Previews: PreviewProvider {
  static var previews: some View {
    SettingsView()
  }
}
