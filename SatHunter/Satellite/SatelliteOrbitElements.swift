//
//  SatelliteOrbitElements.swift
//  SatHunter
//
//  Created by Aleksandar Zdravković on 8/11/24.
//

import Foundation

public class SatelliteOrbitElements {
  init(_ tle: (String, String)) {
    self.tle = tle
    ptrInternal = predict_parse_tle(tle.0, tle.1)
  }
  deinit {
    predict_destroy_orbital_elements(ptrInternal)
  }
  
  private var ptrInternal: UnsafeMutablePointer<predict_orbital_elements_t>
  var ptr: UnsafeMutablePointer<predict_orbital_elements_t> {
    get {
      ptrInternal
    }
  }
  var tle: (String, String)
}
