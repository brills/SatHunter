import SwiftUI

@main
struct SatHunterApp: App {
  @StateObject private var rig = MyIc705()
  var body: some Scene {
    WindowGroup {
      SatListView().environmentObject(rig)
    }
  }
}
