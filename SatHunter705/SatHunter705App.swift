//
//  SatHunter705App.swift
//  SatHunter705
//
//  Created by Zhuo Peng on 5/28/23.
//

import SwiftUI

@main
struct SatHunter705App: App {
  @StateObject var satInfoMgr = SatInfoManager()
  var body: some Scene {
    WindowGroup {
      SatListView().environmentObject(satInfoMgr)
    }
  }
}
