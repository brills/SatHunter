import SwiftUI

func getBtId(requestNew: Bool = false) -> UUID {
    if let stored = UserDefaults.standard.string(forKey: "BTID") {
        if let uuid = UUID(uuidString: stored) {
            if !requestNew {
                return uuid
            }
        }
    }
    let new = UUID()
    UserDefaults.standard.set(new.uuidString, forKey: "BTID")
    return new
}

func getShowOnlySatsWithUplink() -> Bool {
    UserDefaults.standard.bool(forKey: "showOnlySatsWithUplink")
}

func setShowOnlySatsWithUplink(_ v: Bool) {
    UserDefaults.standard.setValue(v, forKey: "showOnlySatsWithUplink")
}

func getShowUVActiveSatsOnly() -> Bool {
    UserDefaults.standard.bool(forKey: "showUVActiveSatsOnly")
}

func setShowUVActiveSatsOnly(_ v: Bool) {
    UserDefaults.standard.setValue(v, forKey: "showUVActiveSatsOnly")
}

struct SettingsView: View {
    @ObservedObject var themeManager: ThemeManager
    @State var isLoading: Bool = false
    @State var lastTleLoadTime: Date? = SatInfoManager(onlyLoadLocally: true).lastUpdated
    @State var btId: UUID = getBtId(requestNew: false)
    @State var showOnlySatsWithUplink: Bool = getShowOnlySatsWithUplink()
    @State var showUVActiveSatsOnly: Bool = getShowUVActiveSatsOnly()
    
    var body: some View {
        ZStack {
            List {
                Section {
                    Text("[Getting Started Guide](https://github.com/brills/SatHunter/blob/main/Docs/GettingStarted.md)")
                }
                // App theme
                Section {
                    Picker("Theme", selection: $themeManager.selectedTheme) {
                        ForEach(AppTheme.allCases) { theme in
                            Text(theme.rawValue).tag(theme)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                // Bluetooth ID
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
                // Update satellites
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
                        "SatHunter downloads TLE and transponder information " +
                        "from the Internet. Use the latest orbit elements for the " +
                        "most accurate predictions."
                    )
                })
                // Show active U/V satellites only
                Section(content: {
                    Toggle("Show active U/V satellites only", isOn: $showUVActiveSatsOnly).onChange(of: showUVActiveSatsOnly) { newValue in
                        setShowUVActiveSatsOnly(newValue)
                    }
                }, footer: {
                    Text("Only show satellites that have at least an active " +
                         "transponder in UHF / VHF range.")
                })
            }
            .disabled(isLoading)
            
            if isLoading {
                ProgressView()
            }
        }
    }
    
    private func getLastTleLoadTime() -> String {
        if let d = lastTleLoadTime {
            return d.formatted(date: .numeric, time: .standard)
        }
        return "Never"
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(themeManager: ThemeManager())
    }
}
