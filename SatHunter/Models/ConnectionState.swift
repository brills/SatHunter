//
//  ConnectionState.swift
//  SatHunter
//
//  Created by Aleksandar Zdravković on 8/10/24.
//

import Foundation

public enum ConnectionState {
    case NotConnected
    case Connecting
    case Connected
    
    var description: String {
        switch self {
        case .Connected:
            return "Connected"
        case .NotConnected:
            return "Connect"
        case .Connecting:
            return "Connecting"
        }
    }
}
