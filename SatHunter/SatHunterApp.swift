import SwiftUI

@main
struct SatHunterApp: App {
    @StateObject private var rig = Icom705Rig()
    @StateObject private var themeManager = ThemeManager()
    @State private var viewId = UUID() // Add a UUID to force view reload

    var body: some Scene {
        WindowGroup {
            SatellitesListView()
                .id(viewId) // Attach the UUID to the view
                .environmentObject(rig)
                .environment(\.colorScheme, themeManager.applyTheme()!)
                .environmentObject(themeManager)
                .onChange(of: themeManager.selectedTheme) { _ in
                    viewId = UUID()
                }
        }
    }
}
