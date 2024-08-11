//
//  LibPredict.swift
//  LibPredictTestProgram
//
//  Created by Zhuo Peng on 5/27/23.
//

import Foundation


public extension predict_observation {
  var julianDate: Date {
    get {
      Date(timeIntervalSince1970: Double(predict_from_julian(self.time)))
    }
  }
}

public func getNextSatellitePass(observer: SatelliteObserver, orbit: SatelliteOrbitElements, time: Date = Date.now) -> SatellitePass {
  let aos = predict_next_aos(observer.ptr, orbit.ptr, predict_to_julian(time_t(time.timeIntervalSince1970)))
  let los = predict_next_los(observer.ptr, orbit.ptr, aos.time)
  let maxElevation = predict_at_max_elevation(observer.ptr, orbit.ptr, aos.time)
  return SatellitePass(aos: aos, los: los, maxElevation: maxElevation)
}

public enum FrequencyForDopplerCalculation {
  case UpLinkHz(Int)
  case DownLinkHz(Int)
}

// Returns the shift (the delta to be added to freq), not shifted freq.
public func getSatDopplerShift(observation: predict_observation, freq: FrequencyForDopplerCalculation) -> Int {
  var freqF: Double = 0
  switch freq {
  case .DownLinkHz(let freqI):
    fallthrough
  case .UpLinkHz(let freqI):
    freqF = Double(freqI)
  }
  
  let shift = withUnsafePointer(to: observation) {
    ptr in
    predict_doppler_shift(ptr, freqF)
  }
  switch freq {
  case .DownLinkHz(_):
    return Int(shift)
  case .UpLinkHz(_):
    return Int(-shift)
  }
}

// Where is the sat now?
public func getSatelliteObservation(observer: SatelliteObserver, orbit: SatelliteOrbitElements, time: Date = Date.now) -> Result<predict_observation, Error> {
  var position = predict_position()
  let errorCode = withUnsafeMutablePointer(to: &position) {
    ptr in
    predict_orbit(orbit.ptr, ptr, predict_to_julian(time_t(time.timeIntervalSince1970)))
  }
  if errorCode != 0 {
    return .failure(NSError(domain: "getSatObservation", code: Int(errorCode)))
  }
  var observation = predict_observation()
  withUnsafeMutablePointer(to: &observation) {
    observerPtr in
    withUnsafePointer(to: position) {
      positionPtr in
      predict_observe_orbit(observer.ptr, positionPtr, observerPtr)
    }
  }
  return .success(observation)
}

// Returns the immediate next LOS. If the sat is currently visible, then it's
// the LOS of the current pass, otherwise, it's the next pass.
public func getSatNextLos(observer: SatelliteObserver, orbit: SatelliteOrbitElements, time: Date = Date.now) -> predict_observation {
  return predict_next_los(observer.ptr, orbit.ptr, predict_to_julian(time_t(time.timeIntervalSince1970)))
}
