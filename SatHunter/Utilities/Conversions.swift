//
//  Conversions.swift
//  SatHunter
//
//  Created by Aleksandar Zdravković on 8/10/24.
//

import Foundation
import OSLog

fileprivate let kPi = 3.1415926535897932384626433832795028841415926

public enum BCDConversionError: Error {
    case overflow(value: Int)
    case invalidInput
}

public func convertNumberToBCD(_ number: Int) throws -> [UInt8] {
    let maxBCDValue = 1_000_000_000
    let bcdDigitCount = 5
    
    guard number < maxBCDValue else {
        throw BCDConversionError.overflow(value: number)
    }
    
    var remainder = number
    var bcdBytes = Array(repeating: UInt8(0), count: bcdDigitCount)
    var divisor = maxBCDValue
    
    for i in (0..<bcdDigitCount).reversed() {
        let highNibble = UInt8(remainder / divisor) << 4
        remainder %= divisor
        divisor /= 10
        
        let lowNibble = UInt8(remainder / divisor)
        remainder %= divisor
        divisor /= 10
        
        bcdBytes[i] = highNibble | lowNibble
    }
    
    return bcdBytes
}

public func convertBCDToNumber<S: Sequence>(_ bcdBytes: S) throws -> Int where S.Element == UInt8 {
    var number = 0
    var multiplier = 1
    
    for byte in bcdBytes {
        let lowNibble = Int(byte & 0x0F)
        let highNibble = Int(byte >> 4)
        
        guard lowNibble < 10 && highNibble < 10 else {
            throw BCDConversionError.invalidInput
        }
        
        number += lowNibble * multiplier
        multiplier *= 10
        number += highNibble * multiplier
        multiplier *= 10
    }
    
    return number
}

public extension Double {
  var rad: Double {
    self * kPi / 180
  }
  var deg: Double {
    self * 180 / kPi
  }
}
