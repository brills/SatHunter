import Foundation
import CoreLocation
import SwiftUI

struct SatListItem: Identifiable, Sendable {
  var satellite: Satellite
  var visible: Bool
  // visible == true
  var los: Date?
  
  // visible = false
  var nextAos: Date?
  var nextLos: Date?
  var maxEl: Double?
  
  var id: Int {
    get {
      Int(satellite.noradID)
    }
  }
}

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

class SatListStore: NSObject, ObservableObject, CLLocationManagerDelegate {
  @Published var sats = [SatListItem]()
  @Published var lastLoadedAt: Date? = nil
  private var observer = SatObserver(name: "user", lat: 37.33481435508938, lon:-122.00893980785605, alt: 25)
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
      let userAlt = location.altitude
      let userLon = location.coordinate.longitude
      let userLat = location.coordinate.latitude
      observer = SatObserver(name: "user", lat: userLat, lon: userLon, alt: userAlt)
    }
  }
  
  func load(searchText: String? = nil) async {
    if satInfoManager == nil {
      satInfoManager = .init()
    }
    var result: [SatListItem] = []
    let showOnlySatsWithUplink = getShowOnlySatsWithUplink()
    let showOnlyUVActiveSats = getShowUVActiveSatsOnly()
    for sat in satInfoManager!.satellites.values {
      let tle = sat.tleTuple
      let orbit = SatOrbitElements(tle)
      if showOnlySatsWithUplink && !sat.hasUplink {
        continue
      }
      if showOnlyUVActiveSats && !sat.hasActiveUVTransponder {
        continue
      }
      if case .success(let observation) = getSatObservation(observer: observer, orbit: orbit) {
        let visible = observation.elevation > 0
        var item = SatListItem(satellite: sat, visible: visible)
        if observation.elevation > 0 {
          item.los = getSatNextLos(observer: observer, orbit: orbit).date
        } else {
          let nextPass = getNextSatPass(observer: observer, orbit: orbit)
          item.nextAos = nextPass.aos.date
          item.nextLos = nextPass.los.date
          item.maxEl = nextPass.maxElevation.elevation.deg
        }
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
        self.sats = toSend
        self.lastLoadedAt = Date.now
      }
    }
  }
}

struct SatListView : View {
  @ObservedObject var store = SatListStore()
  @State private var searchText: String = ""
  @EnvironmentObject private var rig: MyIc705
  
  var items: [SatListItem] {
    if searchText.isEmpty {
      return store.sats
    }
    return store.sats.filter {
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
          NavigationLink (destination: SettingsView()) {
            Image(systemName: "gearshape")
          }
        }
      }
    }
    .environmentObject(rig)
  }
}
