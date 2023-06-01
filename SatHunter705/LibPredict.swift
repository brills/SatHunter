//
//  LibPredict.swift
//  LibPredictTestProgram
//
//  Created by Zhuo Peng on 5/27/23.
//

import Foundation

// Rant: why does swift not have namespaces?

public class SatOrbitElements {
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

public class SatObserver {
  // lat / lon are DEGREES, not RAD; alt is in meters
  init(name: String, lat: Double, lon: Double, alt: Double) {
    ptrInternal = predict_create_observer(name, lat.rad, lon.rad, alt)
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

public struct SatPass {
  var aos: predict_observation
  var los: predict_observation
  var maxElevation: predict_observation
  
  var description: String {
    "AOS (local): \(self.aos.date.description(with: .current))\nLOS (local): \(self.los.date.description(with: .current))\nMax elevation: \(self.maxElevation.elevation.deg) deg"
  }
}



public extension predict_observation {
  // note that .time is julian
  var date: Date {
    get {
      Date(timeIntervalSince1970: Double(predict_from_julian(self.time)))
    }
  }
}

public func getNextSatPass(observer: SatObserver, orbit: SatOrbitElements, time: Date = Date.now) -> SatPass {
  let aos = predict_next_aos(observer.ptr, orbit.ptr, predict_to_julian(time_t(time.timeIntervalSince1970)))
  let los = predict_next_los(observer.ptr, orbit.ptr, aos.time)
  let maxElevation = predict_at_max_elevation(observer.ptr, orbit.ptr, aos.time)
  return SatPass(aos: aos, los: los, maxElevation: maxElevation)
}

fileprivate let kPi = 3.1415926535897932384626433832795028841415926
public extension Double {
  var rad: Double {
    self * kPi / 180
  }
  var deg: Double {
    self * 180 / kPi
  }
}

public enum FreqForDopplerCalculation {
  case UpLink(Int)  // Hz
  case DownLink(Int)  // Hz
}

// Returns the shift (the delta to be added to freq), not shifted freq.
public func getSatDopplerShift(observation: predict_observation, freq: FreqForDopplerCalculation) -> Int {
  var freqF: Double = 0
  switch freq {
  case .DownLink(let freqI):
    fallthrough
  case .UpLink(let freqI):
    freqF = Double(freqI)
  }
  
  let shift = withUnsafePointer(to: observation) {
    ptr in
    predict_doppler_shift(ptr, freqF)
  }
  switch freq {
  case .DownLink(_):
    return Int(shift)
  case .UpLink(_):
    return Int(-shift)
  }
}

// Where is the sat now?
public func getSatObservation(observer: SatObserver, orbit: SatOrbitElements, time: Date = Date.now) -> Result<predict_observation, Error> {
  var pos = predict_position()
  let errCode = withUnsafeMutablePointer(to: &pos) {
    ptr in
    predict_orbit(orbit.ptr, ptr, predict_to_julian(time_t(time.timeIntervalSince1970)))
  }
  if errCode != 0 {
    return .failure(NSError(domain: "getSatObservation", code: Int(errCode)))
  }
  var observation = predict_observation()
  withUnsafeMutablePointer(to: &observation) {
    obsPtr in
    withUnsafePointer(to: pos) {
      posPtr in
      predict_observe_orbit(observer.ptr, posPtr, obsPtr)
    }
  }
  return .success(observation)
}

// Returns the immediate next LOS. If the sat is currently visible, then it's
// the LOS of the current pass, otherwise, it's the next pass.
public func getSatNextLos(observer: SatObserver, orbit: SatOrbitElements, time: Date = Date.now) -> predict_observation {
  return predict_next_los(observer.ptr, orbit.ptr, predict_to_julian(time_t(time.timeIntervalSince1970)))
}
