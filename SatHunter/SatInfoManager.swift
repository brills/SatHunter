import Foundation

extension Transponder.Mode {
  static func fromString(_ s: String?) -> Transponder.Mode {
    guard let s = s else {
      return .unknown
    }
    let normalized = s.lowercased().trimmingCharacters(in: .whitespaces)
    switch normalized {
    case "lsb":
      return .lsb
    case "usb":
      return .usb
    case "cw":
      return .cw
    case "fm":
      return .fm
    default:
      return .unknown
    }
  }
  var libPredictMode: Mode {
    switch self {
    case .lsb:
      fallthrough
    case .unknown:
      fallthrough
    case .cw:
      return .LSB
    case .usb:
      return .USB
    case .fm:
      return .FM
    }
  }
}

extension Transponder {
  var downlinkCenterFreq: Int {
    if downlinkFreqUpper > downlinkFreqLower {
      return Int((downlinkFreqLower + downlinkFreqUpper) / 2)
    }
    return Int(downlinkFreqLower)
  }
  
  var uplinkCenterFreq: Int? {
    guard uplinkFreqLower > 0 else {
      return nil
    }
    if uplinkFreqUpper > uplinkFreqLower {
      return Int((uplinkFreqLower + uplinkFreqUpper) / 2)
    }
    return Int(uplinkFreqLower)
  }
}

fileprivate let kInfoFileName = "sat_info.pbbin"

class SatInfoManager {
  var satellites: [Int: Satellite] = [:]
  var lastUpdated: Date? = nil
  
  init(onlyLoadLocally: Bool = false) {
    if !loadLocally() && !onlyLoadLocally{
      _ = loadFromInternet()
    }
  }
  
  func loadLocally() -> Bool {
    let fm = FileManager.default
    let appSupportDir = try! fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
    let f = appSupportDir.appending(component: kInfoFileName)
    if !fm.fileExists(atPath: f.path) {
      return false
    }
    if let contents = fm.contents(atPath: f.path) {
      if let sats = try? SatelliteList(serializedData: contents) {
        for sat in sats.items {
          satellites[Int(sat.noradID)] = sat
        }
        lastUpdated = .init(timeIntervalSince1970: Double(sats.lastUpdatedTs))
      } else {
        return false
      }
    }
    return true
  }
  
  func loadFromInternet() -> Bool {
    guard let tleDict = loadTle() else {
      return false
    }
    guard let transponderDict = loadTransponderInfo() else {
      return false
    }
    var proto = SatelliteList()
    for (id, (name, (tle1, tle2))) in tleDict {
      var sat = Satellite()
      sat.noradID = Int32(id)
      sat.name = name
      sat.tle.line1 = tle1
      sat.tle.line2 = tle2
      if let transponders = transponderDict[id] {
        sat.transponders = transponders
      }
      satellites[id] = sat
      proto.items.append(sat)
    }
    lastUpdated = Date.now
    proto.lastUpdatedTs = Int64(lastUpdated!.timeIntervalSince1970)
    let fm = FileManager.default
    let appSupportDir = try! fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
    let tmpFile = appSupportDir.appending(component: kInfoFileName + ".tmp")
    try? fm.removeItem(at: tmpFile)
    try! fm.createFile(atPath: tmpFile.path, contents: proto.serializedData())
    let f = appSupportDir.appending(component: kInfoFileName)
    try! fm.replaceItem(at: f, withItemAt: tmpFile, backupItemName: nil, resultingItemURL: nil)
    return true
  }
  
  private func loadTle() -> [Int: (String, (String, String))]? {
    let tleUrl = "https://www.amsat.org/tle/current/dailytle.txt"
    guard let tleContents = try? String(contentsOf:URL(string: tleUrl)!) else {
      return nil
    }
    guard case(.success(let d)) = parseTleFile(tleContents) else {
      return nil
    }
    var result: [Int: (String, (String, String))] = [:]
    for (satName, (tle1, tle2)) in d {
      guard let id = getNoardIdFromTle(tleLine2: tle2) else {
        continue
      }
      result[id] = (satName, (tle1, tle2))
    }
    return result
  }
  
  private func loadTransponderInfo() -> [Int: [Transponder]]? {
    let transponderUrl = "https://db.satnogs.org/api/transmitters/?format=json"
    guard let jsonContents = try? Data(contentsOf:URL(string: transponderUrl)!) else {
      return nil
    }
    guard let json = try? JSONSerialization.jsonObject(with: jsonContents, options: []) else {
      return nil
    }
    guard let transponderList = json as? [Any] else {
      return nil
    }
    var result: [Int: [Transponder]] = [:]
    for t in transponderList {
      guard let transponder = t as? [String: Any] else {
        continue
      }
      guard let noradId = transponder["norad_cat_id"] as? Int else {
        continue
      }
      var proto = Transponder()
      guard let downlinkLow = transponder["downlink_low"] as? Int else {
        continue
      }
      proto.downlinkFreqLower = Int64(downlinkLow)
      if let downlinkHigh = transponder["downlink_high"] as? Int {
        proto.downlinkFreqUpper = Int64(downlinkHigh)
      }
      if let uplinkLow = transponder["uplink_low"] as? Int {
        proto.uplinkFreqLower = Int64(uplinkLow)
      }
      if let uplinkHigh = transponder["uplink_high"] as? Int {
        proto.uplinkFreqUpper = Int64(uplinkHigh)
      }
      if let desc = transponder["description"] as? String {
        proto.description_p = desc
      }
      if let inverted = transponder["invert"] as? Bool {
        proto.inverted = inverted
      }
      if let status = transponder["status"] as? String {
        proto.isActive = (status.lowercased() == "active")
      }
      proto.downlinkMode = .fromString(transponder["mode"] as? String)
      proto.uplinkMode = .fromString(transponder["uplink_mode"] as? String)
      result[noradId, default: []].append(proto)
    }
    return result
  }
}
 
fileprivate func getNoardIdFromTle(tleLine2: String) -> Int? {
  let s = tleLine2.split(separator: " ", maxSplits: 2)
  guard s.count == 3 else {
    return nil
  }
  return Int(s[1])
}


public let kDefaultTleUrl = URL(string: "https://www.amsat.org/tle/current/dailytle.txt")!
public func downloadAmsatTleFile(_ url: URL? = nil) -> Result<String, Error> {
  do {
    let contents = try String(contentsOf: url ?? kDefaultTleUrl)
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
