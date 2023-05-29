//
//  main.swift
//  LibPredictTestProgram
//
//  Created by Zhuo Peng on 5/27/23.
//

import Foundation
import CoreLocation
//class LMDelegate : NSObject, CLLocationManagerDelegate {
//  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
//
//  }
//}
//
//let del = LMDelegate()
//let locationManager = CLLocationManager()
//if locationManager.authorizationStatus == .notDetermined {
//  print("XXX---")
//  locationManager.requestAlwaysAuthorization()
//}
//while locationManager.authorizationStatus != .authorized {
//  Thread.sleep(forTimeInterval: 1)
//  locationManager.requestAlwaysAuthorization()
//}
//locationManager.delegate = del
//locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
//locationManager.startUpdatingLocation()
//print("\(locationManager.authorizationStatus.rawValue)")
//let cod = manager.location!.coordinate
//Thread.sleep(forTimeInterval: 60)
//
//
//
//print("libpredict \(predict_version_major())\n")
//
//guard case .success(let tle) = downloadAmsatTleFile() else {
//  exit(-1)
//}
//guard case .success(let tleDict) = parseTleFile(tle) else {
//  exit (-2)
//}
//// 37.37242332262484, -121.87909086365032
//let obs = SatObserver(name: "ne6ne", lat: 37.37242332262484, lon:-121.87909086365032
//, alt: 25)
//let sat = SatOrbitElements(tleDict["PO-101"]!)
//
//while true {
//  if case .success(let pos) = getSatObservation(observer: obs, orbit: sat) {
//    print("Downlink shift: \(getSatDopplerShift(observation: pos, freq: .DownLink(145900000)))")
//    print("Uplink shift: \(getSatDopplerShift(observation: pos, freq: .UpLink(437500000)))")
//  } else {
//    print("XXX: wtf??")
//  }
//  Thread.sleep(forTimeInterval: 1.0)
//
//}
//
