//
//  IC705.swift
//  SatHunter
//
//  Created by Aleksandar Zdravković on 8/10/24.
//

import Foundation
import CoreBluetooth
import OSLog

public var IC705_CIV_PREAMBLE: [UInt8] = [0xFE, 0xFE, 0xA4, 0xE0]
private let logger = Logger()

public class Icom705Rig: Rig, RigStateObserver, ObservableObject {
 
  @Published var connectionState: ConnectionState = .NotConnected
  private var bluetoothDelegate: IC705BluetoothDelegate?
  private var bluetoothManager: CBCentralManager?
  private var dispatchQueue = DispatchQueue(label: "rig_bt")
  private var rigState = RigState()
  private var rigStateSemaphore = DispatchSemaphore(value: 1)

  public init() {}

  func observe(vfoAFreq: Int) {
    rigStateSemaphore.wait()
    rigState.vfoAFreq = vfoAFreq
    rigStateSemaphore.signal()
  }

  func observe(vfoBFreq: Int) {
    rigStateSemaphore.wait()
    rigState.vfoBFreq = vfoBFreq
    rigStateSemaphore.signal()
  }

  func observe(connected _: Bool) {
    DispatchQueue.main.async {
      self.connectionState = .Connected
    }
  }

  public func connect() {
    connectionState = .Connecting
    bluetoothDelegate = IC705BluetoothDelegate()
    bluetoothDelegate!.rigStateObserver = self
    bluetoothManager = CBCentralManager(delegate: bluetoothDelegate, queue: dispatchQueue)
  }

  public func disconnect() {
    if let p = bluetoothDelegate?.ic705 {
        bluetoothManager?.cancelPeripheralConnection(p)
    }
    bluetoothDelegate = nil
    bluetoothManager = nil
    connectionState = .NotConnected
  }

  public func getVfoAFreq() -> Int {
    rigStateSemaphore.wait()
    let frequency = rigState.vfoAFreq
    rigStateSemaphore.signal()
    return frequency
  }

  public func getVfoBFreq() -> Int {
    rigStateSemaphore.wait()
    let frequency = rigState.vfoBFreq
    rigStateSemaphore.signal()
    return frequency
  }

  public func setVfoAFreq(_ frequency: Int) {
    guard frequency > 0 else { return }
      
      do {
          try bluetoothDelegate?.sendPacket(.init(
            chainBytes(IC705_CIV_PREAMBLE, [0x25, 0x00], convertNumberToBCD(frequency), [0xFD])
          ))
      } catch {
          logger.error("Failed to set VFO-A frequency! Could not convert frequency BCD number!")
      }
  }

  public func setVfoBFreq(_ frequency: Int) {
    guard frequency > 0 else { return }
    
      do{
          try bluetoothDelegate?.sendPacket(.init(
            chainBytes(IC705_CIV_PREAMBLE, [0x25, 0x01], convertNumberToBCD(frequency), [0xFD])
          ))
      } catch {
          logger.error("Failed to set VFO-B frequency! Could not convert frequency to BCD number!")
      }
  }

  public func enableSplit() {
    bluetoothDelegate?.sendPacket(.init(
      chainBytes(IC705_CIV_PREAMBLE, [0x0F, 0x01, 0xFD])
    ))
  }

  public func setVfoAMode(_ mode: Mode) {
    bluetoothDelegate?.sendPacket(.init(
        chainBytes(IC705_CIV_PREAMBLE, [0x26, 0x00, convertModeToCivByte(mode: mode), 00, 0xFD])
    ))
  }

  public func setVfoBMode(_ mode: Mode) {
    bluetoothDelegate?.sendPacket(.init(
        chainBytes(IC705_CIV_PREAMBLE, [0x26, 0x01, convertModeToCivByte(mode: mode), 00, 0xFD])
    ))
  }

  public func enableVfoARepeaterTone(_ enable: Bool) {
    let enableByte: UInt8 = enable ? 0x01 : 0x00
    bluetoothDelegate?.sendPacket(.init(
      chainBytes(IC705_CIV_PREAMBLE, [0x16, 0x42, enableByte, 0xFD])
    ))
  }

  public func selectVfo(_ vfoA: Bool) {
    let selectionByte: UInt8 = vfoA ? 0x00 : 0x01
    bluetoothDelegate?.sendPacket(.init(
      chainBytes(IC705_CIV_PREAMBLE, [0x07, selectionByte, 0xFD])
    ))
  }

  public func setVfoAToneFreq(_ toneFrequency: ToneFrequency) {
    var b1: UInt8 = 0
    var b2: UInt8 = 0
    var v = toneFrequency.rawValue
    b1 |= UInt8((v / 1000) << 4)
    v %= 1000
    b1 |= UInt8(v / 100)
    v %= 100
    b2 |= UInt8((v / 10) << 4)
    v %= 10
    b2 |= UInt8(v)
    bluetoothDelegate?.sendPacket(.init(
      chainBytes(IC705_CIV_PREAMBLE, [0x1B, 00, b1, b2, 0xFD])
    ))
  }
    
  private func convertModeToCivByte(mode: Mode) -> UInt8 {
        switch mode {
        case .FM:
            return 0x05
        case .LSB:
            return 0x00
        case .USB:
            return 0x01
        case .CW:
            return 0x03
        }
    }
}
