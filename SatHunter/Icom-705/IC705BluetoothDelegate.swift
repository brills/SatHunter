//
//  IC705BluetoothDelegate.swift
//  SatHunter
//
//  Created by Aleksandar Zdravković on 8/10/24.
//

import Foundation
import CoreBluetooth
import OSLog

private let IC705_BLE_CONTROL_SERVICE =
  CBUUID(string: "14CF8001-1EC2-D408-1B04-2EB270F14203")
private let IC705_BLE_SERVICE_CHAR =
  CBUUID(string: "14CF8002-1EC2-D408-1B04-2EB270F14203")

private let logger = Logger()

class IC705BluetoothDelegate: NSObject, CBCentralManagerDelegate,
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
      central.scanForPeripherals(withServices: [IC705_BLE_CONTROL_SERVICE])
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
          .debug(
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
    peripheral.discoverServices([IC705_BLE_CONTROL_SERVICE])
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
      logger.debug("Discovered service: \(service)")
      if service.uuid == IC705_BLE_CONTROL_SERVICE {
        peripheral.discoverCharacteristics([IC705_BLE_SERVICE_CHAR], for: service)
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
      "SatHunter       ".utf8CString.withUnsafeBytes {
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
    if characteristic.uuid == IC705_BLE_SERVICE_CHAR {
      if error != nil {
        logger.error("didUpdateValueFor called with error: \(error)")
        return
      }
      let resp = characteristic.value!
      if resp.count < 5 || !resp[0 ... 3]
        .elementsEqual([0xFE, 0xFE, 0xE0, 0xA4]) || resp.last != 0xFD
      {
        // This packet is not addressed to us, or it's malformed. Ignore.
        return
      }
      switch resp[4] {
      // This is the response to our query of VFO.
      case 0x25:
          do {
                 if resp[5] == 0 {
                     try rigStateObserver?.observe(vfoAFreq: convertBCDToNumber(resp[6...10]))
                 } else if resp[5] == 1 {
                     try rigStateObserver?.observe(vfoBFreq: convertBCDToNumber(resp[6...10]))
                 }
             } catch {
                 // Handle the error here, for example by logging it or taking corrective action
                 print("Error observing VFO frequency: \(error)")
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
            s.sendPacket(.init(chainBytes(IC705_CIV_PREAMBLE, [0x25, 0x00, 0xFD])))
            // Get VFOB freq
            s.sendPacket(.init(chainBytes(IC705_CIV_PREAMBLE, [0x25, 0x01, 0xFD])))
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


