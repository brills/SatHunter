import Foundation
import CoreLocation
import SwiftUI

extension Satellite {
  var tleTuple: (String, String) {
    (self.tle.line1, self.tle.line2)
  }
}

extension Int {
  var isHamUVFreq: Bool {
    return self < 450000000 && self > 144000000
  }
}

extension Satellite {
  var hasUplink: Bool {
    transponders.contains(where: {t in t.hasUplinkFreqLower })
  }
    
  var hasActiveUVTransponder: Bool {
    transponders.contains(where: {
      t in
      guard t.isActive else {
        return false
      }
      guard let uplink = t.uplinkCenterFreq else {
        return false
      }
      guard uplink.isHamUVFreq else {
        return false
      }
      guard t.downlinkCenterFreq.isHamUVFreq else {
        return false
      }
      return true
    })
  }
}

class SatellitesListStore: NSObject, ObservableObject, CLLocationManagerDelegate {
  
  @Published var satellites = [SatelliteListItem]()
  @Published var lastUpdateTime: Date? = nil
  
  private var observer = SatelliteObserver(name: "user", latitudeDegrees: 37.33481435508938, longitudeDegrees:-122.00893980785605, altitude: 25)
  private var locationManager: CLLocationManager? = nil
  private var satInfoManager: SatInfoManager? = nil
  
  override init() {
    super.init()
    locationManager = CLLocationManager()
    locationManager!.delegate = self
    locationManager!.requestWhenInUseAuthorization()
    locationManager!.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
    locationManager!.startUpdatingLocation()
  }
   
  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    if let location = locations.last {
      let userAltitude = location.altitude
      let userLongitude = location.coordinate.longitude
      let userLatitude = location.coordinate.latitude
      observer = SatelliteObserver(name: "user", latitudeDegrees: userLatitude, longitudeDegrees: userLongitude, altitude: userAltitude)
    }
  }
  
  func load(searchText: String? = nil) async {
    
    if satInfoManager == nil {
      satInfoManager = .init()
    }
      
    var result: [SatelliteListItem] = []
    let showOnlySatsWithUplink = getShowOnlySatsWithUplink()
    let showOnlyUVActiveSats = getShowUVActiveSatsOnly()
      
    for satellite in satInfoManager!.satellites.values {
      let tle = satellite.tleTuple
      let orbit = SatelliteOrbitElements(tle)
        
      if showOnlySatsWithUplink && !satellite.hasUplink {
        continue
      }
        
      if showOnlyUVActiveSats && !satellite.hasActiveUVTransponder {
        continue
      }
        
      if case .success(let observation) = getSatelliteObservation(observer: observer, orbit: orbit) {
        let visible = observation.elevation > 0
        var item = SatelliteListItem(satellite: satellite, visible: visible)
        if observation.elevation > 0 {
            item.los = getSatNextLos(observer: observer, orbit: orbit).julianDate
        } else {
          let nextPass = getNextSatellitePass(observer: observer, orbit: orbit)
            item.nextAos = nextPass.aos.julianDate
            item.nextLos = nextPass.los.julianDate
          item.maxEl = nextPass.maxElevation.elevation.deg
        }
        
        // TODO: Add in settings view "minimal elevation", so that user can configure this value!
        if item.maxEl != nil && item.maxEl! < 0 {
        } else {
          result.append(item)
        }
      }
      result.sort {
      (lhs, rhs) in
        if lhs.visible && rhs.visible {
          return lhs.los! < rhs.los!
        } else if !lhs.visible && !rhs.visible {
          return lhs.nextAos! < rhs.nextAos!
        } else {
          return lhs.visible
        }
      }
      let toSend = result
      DispatchQueue.main.async {
        [toSend] in
        self.satellites = toSend
        self.lastUpdateTime = Date.now
      }
    }
  }
}

struct SatellitesListView : View {
  @StateObject var store = SatellitesListStore()
  @State private var searchText: String = ""
  @EnvironmentObject private var rig: Icom705Rig
  
  var items: [SatelliteListItem] {
    if searchText.isEmpty {
      return store.satellites
    }
    return store.satellites.filter {
      return $0.satellite.name.range(of:searchText, options: .caseInsensitive) != nil
    }
  }
  
  var body: some View {
    // NavigationStack requires iOS16+, but NavigationView is buggy with
    // the environmentObject.
    // https://developer.apple.com/forums/thread/653367
    NavigationStack {
      List(items) {
        item in
        VStack {
          NavigationLink(destination: {
            TrackingView(satellite: item.satellite)
          }) {
            HStack {
              Text(item.satellite.name)
              Spacer()
              if item.visible {
                Text("Passing").foregroundColor(.mint)
              }
            }
          }
          
          if item.visible {
            HStack {
              Text("LOS:")
              Text("\(item.los!.formatted(date: .omitted, time: .shortened))")
              Spacer()
            }.font(.footnote)
          } else {
            VStack {
              HStack {
                Text("AOS:")
                Text(item.nextAos!.formatted(date: .omitted, time: .shortened))
                Spacer()
              }
              HStack {
                Text("LOS:")
                Text(item.nextLos!.formatted(date: .omitted, time: .shortened))
                Spacer()
              }
              HStack {
                Text("Max El:")
                Text(String(format: "%.0f", item.maxEl!))
                Spacer()
              }
            }.font(.footnote)
          }
        }
      }
      .searchable(text: $searchText)
      .refreshable {
        await store.load()
      }
      .overlay(Group {
        if items.isEmpty {
          Text("Pull to refresh").foregroundColor(Color.secondary)
        }
      })
      .onAppear {
        Task.detached {
          await store.load()
        }
      }
      .toolbar {
        ToolbarItem(placement: .primaryAction) {
            NavigationLink (destination: SettingsView(themeManager: ThemeManager())) {
            Image(systemName: "gearshape")
          }
        }
      }
    }
    .environmentObject(rig)
  }
}
