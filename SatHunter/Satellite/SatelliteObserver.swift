//
//  SatelliteObserver.swift
//  SatHunter
//
//  Created by Aleksandar Zdravković on 8/11/24.
//

import Foundation

public class SatelliteObserver {
  init(name: String, latitudeDegrees: Double, longitudeDegrees: Double, altitude: Double) {
    ptrInternal = predict_create_observer(name, latitudeDegrees.rad, longitudeDegrees.rad, altitude)
  }
  deinit {
    predict_destroy_observer(ptrInternal)
  }
  
  var ptr: UnsafeMutablePointer<predict_observer_t> {
    get {
      ptrInternal
    }
  }
  
  private var ptrInternal: UnsafeMutablePointer<predict_observer_t>
}
