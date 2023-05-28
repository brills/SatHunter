//
//  main.swift
//  LibPredictTestProgram
//
//  Created by Zhuo Peng on 5/27/23.
//

import Foundation
import CoreLocation
class LMDelegate : NSObject, CLLocationManagerDelegate {
  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        
    print("libpredict \(predict_version_major())\n")

    guard case .success(let tle) = downloadAmsatTleFile() else {
      exit(-1)
    }
    guard case .success(let tleDict) = parseTleFile(tle) else {
      exit (-2)
    }

    let cod = manager.location!.coordinate
    let obs = SatObserver(name: "ne6ne", lat: cod.latitude, lon: cod.longitude, alt: 25)
    let sat = SatOrbitElements(tleDict["AO-27"]!)
    print(getNextSatPass(observer: obs, orbit: sat, time: .now).description)
  }
}

let del = LMDelegate()
let locationManager = CLLocationManager()
if locationManager.authorizationStatus == .notDetermined {
  print("XXX---")
  locationManager.requestAlwaysAuthorization()
}
while locationManager.authorizationStatus != .authorized {
  Thread.sleep(forTimeInterval: 1)
  locationManager.requestAlwaysAuthorization()
}
locationManager.delegate = del
locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
locationManager.startUpdatingLocation()
print("\(locationManager.authorizationStatus.rawValue)")
Thread.sleep(forTimeInterval: 60)


