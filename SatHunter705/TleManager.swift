//
//  TleManager.swift
//  SatHunter705
//
//  Created by Zhuo Peng on 5/29/23.
//

import Foundation

public enum TleManagerError : Error {
  case TleFileIOError
  case TleFileContentsError
}
public class TleManager {
  private static let kTleFileName = "tle.txt"
  static func load(url: URL? = nil, force: Bool = false) -> Result<TleDict, Error> {
    let fm = FileManager.default
    let appSupportDir = try! fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
    let tleFile = appSupportDir.appending(component: kTleFileName)
    
    if force || !fm.fileExists(atPath: tleFile.path) {
      let tmpFile = appSupportDir.appending(component: kTleFileName + ".tmp")
      try? fm.removeItem(at: tmpFile)
      if case .success(let contents) = downloadAmsatTleFile(url) {
        fm.createFile(atPath: tmpFile.path, contents: contents.data(using: .utf8))
        try! fm.replaceItem(at: tleFile, withItemAt: tmpFile, backupItemName: nil, resultingItemURL: nil)
      }
    }
    
    if !fm.fileExists(atPath: tleFile.path) {
      return .failure(TleManagerError.TleFileIOError)
    }
    
    if let contents = fm.contents(atPath: tleFile.path) {
      if let sContents = String(data: contents, encoding: .utf8) {
        return parseTleFile(sContents)
      }
    }
    return .failure(TleManagerError.TleFileContentsError)
  }
  
  static func lastLoadTime() -> Date? {
    let fm = FileManager.default
    let appSupportDir = try! fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
    let tleFile = appSupportDir.appending(component: kTleFileName)
    if !fm.fileExists(atPath: tleFile.path) {
      return nil
    }
    return try? fm.attributesOfFileSystem(forPath: kTleFileName)[.creationDate] as? Date
  }
}
