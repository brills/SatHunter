//
//  rig.swift
//  705bt
//
//  Created by Zhuo Peng on 5/26/23.
//

import CoreBluetooth
import Foundation
import OSLog

fileprivate let logger = Logger()
fileprivate let kMyUUID = UUID(uuidString: "D91B0B94-C3C4-4540-8234-5BA06D25AA4F")!
fileprivate let k705BtleControlService =
  CBUUID(string: "14CF8001-1EC2-D408-1B04-2EB270F14203")
fileprivate let k705BtleServiceChar =
  CBUUID(string: "14CF8002-1EC2-D408-1B04-2EB270F14203")

public func getBtId(requestNew: Bool = false) -> UUID {
  if let stored = UserDefaults.standard.string(forKey: "BTID") {
    if let uuid = UUID(uuidString: stored) {
      if !requestNew {
        return uuid
      }
    }
  }
  let new = UUID()
  UserDefaults.standard.set(new.uuidString, forKey: "BTID")
  return new
}

public enum Mode {
  case LSB
  case USB
  case FM

  func toCivByte() -> UInt8 {
    switch self {
    case .FM:
      return 0x05
    case .LSB:
      return 0x00
    case .USB:
      return 0x01
    }
  }
  
  func inverted() -> Mode {
    switch self {
    case .FM:
      return .FM
    case .USB:
      return .LSB
    case .LSB:
      return .USB
    }
  }
}

public protocol Rig {
  func connect(completion: @escaping () -> Void)
  func disconnect()
  func getVfoAFreq() -> Int
  func getVfoBFreq() -> Int
  func setVfoAFreq(_ f: Int)
  func setVfoBFreq(_ f: Int)
  func enableSplit()
  func setVfoAMode(_ m: Mode)
  func setVfoBMode(_ m: Mode)
}

private protocol RigStateObserver {
  func observe(connected: Bool)
  func observe(vfoAFreq: Int)
  func observe(vfoBFreq: Int)
}

private class Ic705BtDelegate: NSObject, CBCentralManagerDelegate,
  CBPeripheralDelegate
{
  override init() {
    ic705 = nil
    state = .INIT
    ctlChar = nil
    super.init()
  }
  
  // CBCentralManagerDelegate methods
  
  func centralManagerDidUpdateState(_ central: CBCentralManager) {
    if central.state == .poweredOn {
      central.scanForPeripherals(withServices: [k705BtleControlService])
    } else {
      logger.error("BT state changed to \(central.state.rawValue)")
      ic705 = nil
    }
  }
  
  func centralManager(
    _ central: CBCentralManager,
    didDiscover peripheral: CBPeripheral,
    advertisementData: [String: Any],
    rssi _: NSNumber
  ) {
    if let name = peripheral.name {
      if name == "ICOM BT(IC-705)" {
        logger
          .info(
            "Discovered ic705: \(peripheral.description)\nDATA:\n\(advertisementData)"
          )
        ic705 = peripheral
        peripheral.delegate = self
        central.connect(peripheral)
        central.stopScan()
      }
    }
  }
  
  func centralManager(_: CBCentralManager,
                      didConnect peripheral: CBPeripheral)
  {
    logger.info("Connected!")
    peripheral.discoverServices([k705BtleControlService])
  }
  
  // CBPeripheralDelegate methods
  func peripheral(
    _ peripheral: CBPeripheral,
    didDiscoverCharacteristicsFor service: CBService,
    error: Error?
  ) {
    if let error = error {
      logger.error("Error discovering characteristic: \(error)")
      return
    }
    for char in service.characteristics! {
      ctlChar = char
      peripheral.setNotifyValue(true, for: char)
    }
  }
  
  func peripheral(
    _ peripheral: CBPeripheral,
    didDiscoverServices error: Error?
  ) {
    if let error = error {
      logger.error("Error discovring service: \(error)")
      return
    }
    for service in peripheral.services! {
      logger.info("Discovered service: \(service)")
      if service.uuid == k705BtleControlService {
        peripheral.discoverCharacteristics([k705BtleServiceChar], for: service)
      }
    }
  }
  
  func peripheral(
    _ peripheral: CBPeripheral,
    didUpdateNotificationStateFor characteristic: CBCharacteristic,
    error: Error?
  ) {
    if let error = error {
      logger.error("Error update notification state: \(error)")
      return
    }
    var idPacket: [UInt8] = [0xFE, 0xF1, 0x00, 0x61]
    withUnsafeBytes(of: getBtId().uuid) {
      b in
      for i in 0 ..< b.count {
        idPacket.append(b.load(fromByteOffset: i, as: UInt8.self))
      }
    }
    idPacket.append(0xFD)
    peripheral.writeValue(
      .init(idPacket),
      for: characteristic,
      type: .withResponse
    )
    state = .ID_SENT
  }
  
  func peripheral(
    _ peripheral: CBPeripheral,
    didWriteValueFor char: CBCharacteristic,
    error: Error?
  ) {
    if let error = error {
      logger.error("Error write value: \(error)")
      return
    }
    switch state {
    case .ID_SENT:
      var namePacket: [UInt8] = [0xFE, 0xF1, 0x00, 0x62]
      "SatHunter705    ".utf8CString.withUnsafeBytes {
        b in
        for i in 0 ..< 16 {
          namePacket.append(b.load(fromByteOffset: i, as: UInt8.self))
        }
      }
      namePacket.append(0xFD)
      peripheral.writeValue(
        .init(namePacket),
        for: char,
        type: .withResponse
      )
      logger.info("state: NAME_SENT")
      state = .NAME_SENT
    case .NAME_SENT:
      let tokenPacket: [UInt8] = [0xFE, 0xF1, 0x00, 0x63, 0xEE, 0x39, 0x09,
                                  0x10,
                                  0xFD]
      peripheral.writeValue(
        .init(tokenPacket),
        for: char,
        type: .withResponse
      )
      logger.info("state: TOKEN_SENT")
      state = .TOKEN_SENT
    case .TOKEN_SENT:
      state = .STARTED
      schedulePolling()
      rigStateObserver?.observe(connected: true)
    case .STARTED:
      break
    default:
      logger.error("Invalid state")
    }
  }
  
  func peripheral(
    _: CBPeripheral,
    didUpdateValueFor characteristic: CBCharacteristic,
    error: Error?
  ) {
    if characteristic.uuid == k705BtleServiceChar {
      if error != nil {
        logger.error("didUpdateValueFor called with error: \(error)")
        return
      }
      let resp = characteristic.value!
      if resp.count < 5 || !resp[0 ... 3]
        .elementsEqual([0xFE, 0xFE, 0xE0, 0xA4]) || resp.last != 0xFD {
        // This packet is not addressed to us, or it's malformed. Ignore.
        return
      }
      switch resp[4] {
        // This is the response to our query of VFO.
      case 0x25:
        if resp[5] == 0 {
          rigStateObserver?.observe(vfoAFreq: fromBCD(resp[6...10]))
        } else if resp[5] == 1 {
          rigStateObserver?.observe(vfoBFreq: fromBCD(resp[6...10]))
        }
      default:
        return
      }
    }
  }
  // Public interfaces
  // non-blocking and there is no response. No guarantee that the packet
  // will be received.
  // For state-setting packets, packet loss is not the end of the day.
  // There may be mismatch with the UI state, but user can retry.
  // For state-getting packets, since they are periodically sent from here,
  // losing a packet is not a big deal.
  func sendPacket(_ data: Data) {
    ic705!.writeValue(data, for: ctlChar!, type: .withResponse)
  }

  private func schedulePolling() {
    DispatchQueue.global(qos: .userInteractive)
      .asyncAfter(wallDeadline: .now() + .milliseconds(250)) {
        [weak self] in
          if let s = self {
            // Get VFOA freq
            s.sendPacket(.init(chainBytes(kCivPreamble, [0x25, 0x00, 0xFD])))
            // Get VFOB freq
            s.sendPacket(.init(chainBytes(kCivPreamble, [0x25, 0x01, 0xFD])))
            s.schedulePolling()
          } else {
            logger.info("Rig state polling task exiting...")
            return
          }
      }
  }

  enum State {
    case INIT
    case ID_SENT
    case NAME_SENT
    case TOKEN_SENT
    case STARTED
  }

  var rigStateObserver: RigStateObserver?
  var ic705: CBPeripheral?
  
  private var state: State
  private var waitForStartSema: DispatchSemaphore?
  private var ctlChar: CBCharacteristic?
}

private let kCivPreamble: [UInt8] = [0xFE, 0xFE, 0xA4, 0xE0]

private func chainBytes(_ bs: [UInt8]...) -> [UInt8] {
  var result: [UInt8] = []
  for b in bs {
    result.append(contentsOf: b)
  }
  return result
}
public enum RigError : Error {
  case MalformedResponseError
  case TryAgainError
}

public class MyIc705: Rig, RigStateObserver {
 
  public init() {
  }
  
  func observe(vfoAFreq: Int) {
    rigStateMu.wait()
    rigState.vfoAFreq = vfoAFreq
    rigStateMu.signal()
  }
  
  func observe(vfoBFreq: Int) {
    rigStateMu.wait()
    rigState.vfoBFreq = vfoBFreq
    rigStateMu.signal()
  }
  
  func observe(connected _: Bool) {
    self.connectCompletion?()
  }

  public func connect(completion: @escaping () -> Void) {
    self.connectCompletion = completion
    btDelegate = Ic705BtDelegate()
    btDelegate!.rigStateObserver = self
    btMgr = CBCentralManager(delegate: btDelegate, queue: .global())
  }
  
  public func disconnect() {
    if let p = btDelegate?.ic705 {
      btMgr?.cancelPeripheralConnection(p)
    }
    btDelegate = nil
    btMgr = nil
  }

  public func getVfoAFreq() -> Int {
    rigStateMu.wait()
    let f = rigState.vfoAFreq
    rigStateMu.signal()
    return f
  }

  public func getVfoBFreq() -> Int {
    rigStateMu.wait()
    let f = rigState.vfoBFreq
    rigStateMu.signal()
    return f
  }

  public func setVfoAFreq(_ f: Int) {
    btDelegate?.sendPacket(.init(
      chainBytes(kCivPreamble, [0x25, 0x00], toBCD(f), [0xFD])
    ))
  }

  public func setVfoBFreq(_ f: Int) {
    btDelegate?.sendPacket(.init(
      chainBytes(kCivPreamble, [0x25, 0x01], toBCD(f), [0xFD])
    ))
  }

  public func enableSplit() {
    btDelegate?.sendPacket(.init(
      chainBytes(kCivPreamble, [0x0F, 0x01, 0xFD])
    ))
  }

  public func setVfoAMode(_ m: Mode) {
    btDelegate?.sendPacket(.init(
      chainBytes(kCivPreamble, [0x26, 0x00, m.toCivByte(), 00, 0xFD])
    ))
  }

  public func setVfoBMode(_ m: Mode) {
    btDelegate?.sendPacket(.init(
      chainBytes(kCivPreamble, [0x26, 0x01, m.toCivByte(), 00, 0xFD])
    ))
  }

  private var btDelegate: Ic705BtDelegate? = nil
  private var btMgr: CBCentralManager? = nil
  private var connectCompletion: (() -> Void)? = nil
  
  private struct RigState {
    var vfoAFreq: Int = 0
    var vfoBFreq: Int = 0
  }
  private var rigState = RigState()
  private var rigStateMu = DispatchSemaphore(value: 1)
}

fileprivate func toBCD(_ v: Int) -> [UInt8] {
  if v >= 1_000_000_000 {
    logger.error("Unable to convert \(v) to BCD. Overflow.")
  }
  var mv = v
  var result: [UInt8] = [0, 0, 0, 0, 0]
  var scale = 1_000_000_000
  for i in (0 ... 4).reversed() {
    result[i] |= UInt8(mv / scale) << 4
    mv %= scale
    scale /= 10
    result[i] |= UInt8(mv / scale)
    mv %= scale
    scale /= 10
  }
  return result
}

fileprivate func fromBCD<S: Sequence>(_ s: S) -> Int where S.Element == UInt8 {
  var result: Int = 0
  var scale: Int = 1
  for b in s {
    result += (Int(b) & 0x0f) * scale
    scale *= 10
    result += (Int(b) >> 4) * scale
    scale *= 10
  }
  return result
}
