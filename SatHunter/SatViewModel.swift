//
//  SatViewModel.swift
//  SatHunter
//
//  Created by Zhuo Peng on 6/6/23.
//

import Foundation
import SwiftUI
import CoreLocation
import OSLog

fileprivate let logger = Logger()

class SatViewModel: NSObject, ObservableObject, CLLocationManagerDelegate {
  var trackedSat: SatOrbitElements? = nil {
    didSet {
      self.refresh()
    }
  }
  // whether the sat is currently passing.
  // if nil, none if the data below are available.
  @Published var visible: Bool? = nil
  
  // the following only available when visible == false
  @Published var nextAos: Date? = nil
  @Published var nextLos: Date? = nil
  // in degree
  @Published var maxEl: Double? = nil
  
  // the following only available when visible == true
  @Published var currentLos: Date? = nil
  // both in degree
  @Published var currentAz: Double? = nil
  @Published var currentEl: Double? = nil
  
  @Published var userHeading: Double = 0
  @Published var userLat: Double = 0
  @Published var userLon: Double = 0
  @Published var userAlt: Double = 0
  @Published var userGridSquare: String = ""
  
  private var timer: Timer? = nil
  private var locationManager: CLLocationManager? = nil
  // APPLE PARK (:D)
  // 37.33481435508938, -122.00893980785605
  private var observer = SatObserver(name: "user", lat: 37.33481435508938, lon:-122.00893980785605, alt: 25)
  override init() {
    super.init()
    timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: {_ in self.refresh()})
    locationManager = CLLocationManager()
    locationManager!.delegate = self
    locationManager!.requestWhenInUseAuthorization()
    if !CLLocationManager.headingAvailable() {
      logger.error("CLLocationManager: headingAvailable returned false")
    }
    locationManager!.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
    locationManager!.startUpdatingLocation()
    locationManager!.startUpdatingHeading()
  }
  
  func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
    self.userHeading = newHeading.trueHeading
  }
  
  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    if let location = locations.last {
      userAlt = location.altitude
      userLon = location.coordinate.longitude
      userLat = location.coordinate.latitude
      observer = SatObserver(name: "user", lat: userLat, lon: userLon, alt: userAlt)
      userGridSquare = latLonToGridSquare(lat: userLat, lon: userLon)
    }
  }

  func refresh() {
    if let trackedSat = trackedSat {
      if case let .success(observation) = getSatObservation(observer: observer,
                                                            orbit: trackedSat)
      {
        if observation.elevation > 0 {
          currentAz = observation.azimuth.deg
          currentEl = observation.elevation.deg
          let los = getSatNextLos(observer: observer, orbit: trackedSat)
          currentLos = los.date
        } else {
          let nextPass = getNextSatPass(observer: observer, orbit: trackedSat)
          nextAos = nextPass.aos.date
          nextLos = nextPass.los.date
          maxEl = nextPass.maxElevation.elevation.deg
        }
        visible = observation.elevation > 0
      }
    }
  }
}
// az, el in degree
func azElToXy(az: Double, el: Double) -> (Double, Double) {
  var r = 1 - el / 90
  r = max(0, r)
  r = min(1, r)
  return (r * sin(az.rad), r * cos(az.rad))
}

func latLonToGridSquare(lat: Double, lon: Double) -> String {
  var lon = lon + 180
  var lat = lat + 90
  var result = ""
  var lonBand = floor(lon / 20)
  var latBand = floor(lat / 10)
  result.append(Character(UnicodeScalar((UInt8(lonBand) + Character("A").asciiValue!))))
  result.append(Character(UnicodeScalar((UInt8(latBand) + Character("A").asciiValue!))))
  lon -= lonBand * 20
  lat -= latBand * 10
  lonBand = lon / 2
  latBand = lat
  result.append(Character(UnicodeScalar((UInt8(lonBand) + Character("0").asciiValue!))))
  result.append(Character(UnicodeScalar((UInt8(latBand) + Character("0").asciiValue!))))
  return result
}

