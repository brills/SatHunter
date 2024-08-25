//
//  Mode.swift
//  SatHunter
//
//  Created by Aleksandar Zdravković on 8/10/24.
//

import Foundation

public enum Mode {
    case LSB, USB, FM, CW
    
    func Invert() -> Mode {
        switch self {
        case .FM:
            return .FM
        case .USB:
            return .LSB
        case .LSB:
            return .USB
        case .CW:
            return .CW
        }
    }
}
