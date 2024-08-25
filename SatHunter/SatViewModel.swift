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
  var trackedSat: SatelliteOrbitElements? = nil {
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
  @Published var userLatitude: Double = 0
  @Published var userLongitude: Double = 0
  @Published var userAltitude: Double = 0
  @Published var userGridSquare: String = ""
  @Published var passTrack: [(Double, Double)] = []
  
  private var timer: Timer? = nil
  private var locationManager: CLLocationManager? = nil
  // APPLE PARK (:D)
  // 37.33481435508938, -122.00893980785605
  private var observer = SatelliteObserver(name: "user", latitudeDegrees: 37.33481435508938, longitudeDegrees:-122.00893980785605, altitude: 25)
    
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
      userAltitude = location.altitude
      userLongitude = location.coordinate.longitude
      userLatitude = location.coordinate.latitude
      observer = SatelliteObserver(name: "user", latitudeDegrees: userLatitude, longitudeDegrees: userLongitude, altitude: userAltitude)
      userGridSquare = latLonToGridSquare(latitude: userLatitude, longitude: userLongitude)
    }
  }

  func refresh() {
    if let trackedSat = trackedSat {
      if case let .success(observation) = getSatelliteObservation(observer: observer,
                                                            orbit: trackedSat)
      {
        if observation.elevation > 0 {
          currentAz = observation.azimuth.deg
          currentEl = observation.elevation.deg
          let los = getSatNextLos(observer: observer, orbit: trackedSat)
            currentLos = los.julianDate
        } else {
          let nextPass = getNextSatellitePass(observer: observer, orbit: trackedSat)
            nextAos = nextPass.aos.julianDate
            nextLos = nextPass.los.julianDate
            maxEl = nextPass.maxElevation.elevation.deg
        }
        let newVisible = observation.elevation > 0
        if visible == nil || visible! != newVisible {
          computePassTrack(newVisible)
        }
        visible = newVisible
      }
    }
  }
  
  private func computePassTrack(_ isVisible: Bool) {
    let startTime = isVisible ? Date.now : nextAos!
    let endTime = isVisible ? currentLos! : nextLos!
    var newPassTrack: [(Double, Double)] = []
    for t in stride(from: startTime, through: endTime, by: 10) {
      if case let .success(observation) = getSatelliteObservation(observer: observer, orbit: trackedSat!, time: t) {
        newPassTrack.append((observation.azimuth.deg, observation.elevation.deg))
      }
    }
    passTrack = newPassTrack
  }
}
// az, el in degree
func azElToXy(az: Double, el: Double) -> (Double, Double) {
  var r = 1 - el / 90
  r = max(0, r)
  r = min(1, r)
  return (r * sin(az.rad), r * cos(az.rad))
}

func latLonToGridSquare(latitude: Double, longitude: Double) -> String {
  var lon = longitude + 180
  var lat = latitude + 90
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

