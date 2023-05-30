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
    case .LSB:
      return .USB
    case .USB:
      return .LSB
    }
  }
}

public protocol Rig {
  func connect()
  func getVfoAFreq() -> Result<Int, Error>
  func getVfoBFreq() -> Result<Int, Error>
  func setVfoAFreq(_ f: Int)
  func setVfoBFreq(_ f: Int)
  func enableSplit()
  func setVfoAMode(_ m: Mode)
  func setVfoBMode(_ m: Mode)
}

private class Ic705BtDelegate: NSObject, CBCentralManagerDelegate,
  CBPeripheralDelegate
{
  override init() {
    ic705 = nil
    state = .INIT
    ctlChar = nil
    waitForStartSema = DispatchSemaphore(value: 0)
    sendPacketSema = DispatchSemaphore(value: 1)
    
    mu = DispatchSemaphore(value: 1)
    expectedResponse = nil
    valueNotification = nil
    waitForValueNotifySema = nil
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
      logger
        .info(
          "Discovered char for service \(service.uuid) \(char.uuid)"
        )
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
    withUnsafeBytes(of: kMyUUID.uuid) {
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
      "my laptop       ".utf8CString.withUnsafeBytes {
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
      waitForStartSema?.signal()
      waitForStartSema = nil

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
      mu.wait()
      if let expect = expectedResponse {
        if error != nil {
          valueNotification = .failure(RigError.TryAgainError)
        } else if expect.matches(characteristic.value!) {
          valueNotification = .success(characteristic.value!)
        } else {
          valueNotification = .failure(RigError.MalformedResponseError)
        }
        waitForValueNotifySema?.signal()
        waitForValueNotifySema = nil
        expectedResponse = nil
      }
      mu.signal()
    }
  }

  // Public interfaces

  // Blocking. Idompotent.
  func waitForStart() {
    if let sem = waitForStartSema {
      sem.wait()
    }
  }

  // Blocking.
  // TODO: timeout
  func sendPacket(_ data: Data, expect: ExpectedResponse) -> Result<Data, Error> {
    sendPacketSema.wait()
    
    mu.wait()
    expectedResponse = expect
    waitForValueNotifySema = DispatchSemaphore(value: 0)
    mu.signal()
    
    ic705!.writeValue(data, for: ctlChar!, type: .withResponse)
    waitForValueNotifySema!.wait()
    
    sendPacketSema.signal()
    return valueNotification!
  }

  enum State {
    case INIT
    case ID_SENT
    case NAME_SENT
    case TOKEN_SENT
    case STARTED
  }
  
  struct ExpectedResponse {
    // Excluding the preamble (FE FE E0 A4)
    var expectedPrefix: [UInt8]
    // Excluding the preamble, expected prefix and the ending sentinal (FD)
    var expectedLength: Int
    
    func matches(_ response: Data) -> Bool {
      return (response.count == 4 + expectedPrefix.count + expectedLength + 1) &&
        response[0 ... 3].elementsEqual([0xFE, 0xFE, 0xE0, 0xA4]) && response
        .last == 0xFD &&
        response[4 ..< 4 + expectedPrefix.count].elementsEqual(expectedPrefix)
    }
    
    static func ok() -> ExpectedResponse {
      .init(expectedPrefix: [0xFB], expectedLength: 0)
    }
  }

  var ic705: CBPeripheral?
  private var state: State
  private var waitForStartSema: DispatchSemaphore?
  private var ctlChar: CBCharacteristic?
  private var sendPacketSema: DispatchSemaphore
  
  private var mu: DispatchSemaphore
  private var waitForValueNotifySema: DispatchSemaphore?
  private var expectedResponse: ExpectedResponse?
  private var valueNotification: Result<Data, Error>?
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

public class MyIc705: Rig {
  public init() {
    btMgr = nil
    btDelegate = nil
  }

  public func connect() {
    btDelegate = Ic705BtDelegate()
    btMgr = CBCentralManager(delegate: btDelegate, queue: .global())
    btDelegate?.waitForStart()
  }
  
  public func disconnect() {
    if let p = btDelegate?.ic705 {
      btMgr?.cancelPeripheralConnection(p)
    }
  }

  public func getVfoAFreq() -> Result<Int, Error> {
    let r = btDelegate?.sendPacket(.init(
      chainBytes(kCivPreamble, [0x25, 0x00, 0xFD])
    ), expect: .init(expectedPrefix: [0x25, 0x00], expectedLength: 5))
    switch r {
    case .none:
      return .failure(RigError.MalformedResponseError)
    case .failure(let err):
      return .failure(err)
    case .success(let data):
      return .success(fromBCD(data[6...10]))
    }
  }

  public func getVfoBFreq() -> Result<Int, Error> {
    let r = btDelegate?.sendPacket(.init(
      chainBytes(kCivPreamble, [0x25, 0x01, 0xFD])
    ), expect: .init(expectedPrefix: [0x25, 0x01], expectedLength: 5))
    switch r {
    case .none:
      return .failure(RigError.MalformedResponseError)
    case .failure(let err):
      return .failure(err)
    case .success(let data):
      return .success(fromBCD(data[6...10]))
    }

  }

  public func setVfoAFreq(_ f: Int) {
    let r = btDelegate?.sendPacket(.init(
      chainBytes(kCivPreamble, [0x25, 0x00], toBCD(f), [0xFD])
    ), expect: .ok())
    switch r {
    case let .failure(err):
      logger.error("Error setting VFO A freq. \(err)")
    default:
      break
    }
  }

  public func setVfoBFreq(_ f: Int) {
    let r = btDelegate?.sendPacket(.init(
      chainBytes(kCivPreamble, [0x25, 0x01], toBCD(f), [0xFD])
    ), expect: .ok())
    switch r {
    case let .failure(err):
      logger.error("Error setting VFO B freq. \(err)")
    default:
      break
    }
  }

  public func enableSplit() {
    let r = btDelegate?.sendPacket(.init(
      chainBytes(kCivPreamble, [0x0F, 0x01, 0xFD])
    ), expect: .ok())
    switch r {
    case let .failure(err):
      logger.error("Error enabling split. \(err)")
    default:
      break
    }
  }

  public func setVfoAMode(_ m: Mode) {
    let r = btDelegate?.sendPacket(.init(
      chainBytes(kCivPreamble, [0x26, 0x00, m.toCivByte(), 00, 0xFD])
    ), expect: .ok())
    switch r {
    case let .failure(err):
      logger.error("Error setting VFO A mode. \(err)")
    default:
      break
    }
  }

  public func setVfoBMode(_ m: Mode) {
    let r = btDelegate?.sendPacket(.init(
      chainBytes(kCivPreamble, [0x26, 0x01, m.toCivByte(), 00, 0xFD])
    ), expect: .ok())
    switch r {
    case let .failure(err):
      logger.error("Error setting VFO B mode. \(err)")
    default:
      break
    }
  }

  private var btDelegate: Ic705BtDelegate?
  private var btMgr: CBCentralManager?
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
