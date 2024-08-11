//
//  ByteUtilities.swift
//  SatHunter
//
//  Created by Aleksandar Zdravković on 8/10/24.
//

import Foundation

public func chainBytes(_ byteSequence: [UInt8]...) -> [UInt8] {
  var result: [UInt8] = []
  for byte in byteSequence {
    result.append(contentsOf: byte)
  }
  return result
}
