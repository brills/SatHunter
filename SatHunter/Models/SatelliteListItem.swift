//
//  SatelliteListItem.swift
//  SatHunter
//
//  Created by Aleksandar Zdravković on 8/11/24.
//

import Foundation

struct SatelliteListItem: Identifiable, Sendable {
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
