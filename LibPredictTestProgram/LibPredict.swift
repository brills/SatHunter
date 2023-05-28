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

public func downloadAmsatTleFile() -> Result<String, Error> {
  do {
    let contents = try String(contentsOf: URL(string: "https://www.amsat.org/tle/current/dailytle.txt")!)
    return .success(contents)
  } catch {
    return .failure(error)
  }
}
// sat name -> TLE
public typealias TleDict = [String: (String, String)]

enum ParseTleError : Error {
  case UnexpectedLineCount
}
public func parseTleFile(_ contents: String) -> Result<TleDict, Error> {
  var result: TleDict = [:]
  let lines = contents.split(whereSeparator: \.isNewline)
  if lines.count % 3 != 0 {
    return .failure(ParseTleError.UnexpectedLineCount)
  }
  for i in stride(from: 0, to: lines.count, by: 3) {
    result[String(lines[i])] = (String(lines[i + 1]), String(lines[i + 2]))
  }
  return .success(result)
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

public func getNextSatPass(observer: SatObserver, orbit: SatOrbitElements, time: Date) -> SatPass {
  let aos = predict_next_aos(observer.ptr, orbit.ptr, predict_to_julian(time_t(time.timeIntervalSince1970)))
  let los = predict_next_los(observer.ptr, orbit.ptr, aos.time)
  let maxElevation = predict_at_max_elevation(observer.ptr, orbit.ptr, aos.time)
  return SatPass(aos: aos, los: los, maxElevation: maxElevation)
}

fileprivate let kPi = 3.1415926535897932384626433832795028841415926
fileprivate extension Double {
  var rad: Double {
    self * kPi / 180
  }
  var deg: Double {
    self * 180 / kPi
  }
}
