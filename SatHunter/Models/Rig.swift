//
//  Rig.swift
//
//
//  Created by Zhuo Peng on 5/26/23.
//

import Foundation

protocol Rig {
  func connect()
  func disconnect()
  func getVfoAFreq() -> Int
  func getVfoBFreq() -> Int
  func setVfoAFreq(_ f: Int)
  func setVfoBFreq(_ f: Int)
  func enableSplit()
  func setVfoAMode(_ m: Mode)
  func setVfoBMode(_ m: Mode)
}

protocol RigStateObserver {
  func observe(connected: Bool)
  func observe(vfoAFreq: Int)
  func observe(vfoBFreq: Int)
}
