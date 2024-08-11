//
//  FreqTone.swift
//  SatHunter
//
//  Created by Aleksandar Zdravković on 8/10/24.
//

import Foundation

public enum ToneFrequency: Int, CaseIterable, Identifiable, CustomStringConvertible {
    case NotSet = 0
    case F67 = 670
    case F88_5 = 885
    case F141_3 = 1413
    
    public var id: Int {
        rawValue
    }

    static func toString(for toneFrequency: ToneFrequency) -> String {
        switch toneFrequency {
        case .NotSet:
            return "No CTCSS"
        default:
            return String(format: "%5.01f", Double(toneFrequency.rawValue) / 10)
        }
    }
    
    public var description: String {
        return ToneFrequency.toString(for: self)
    }
}
