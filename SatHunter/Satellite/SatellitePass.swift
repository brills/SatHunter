//
//  SatellitePass.swift
//  SatHunter
//
//  Created by Aleksandar Zdravković on 8/11/24.
//

import Foundation

public struct SatellitePass {
  var aos: predict_observation
  var los: predict_observation
  var maxElevation: predict_observation
  
  var description: String {
      "AOS (local): \(self.aos.julianDate.description(with: .current))\nLOS (local): \(self.los.julianDate.description(with: .current))\nMax elevation: \(self.maxElevation.elevation.deg) deg"
  }
}
