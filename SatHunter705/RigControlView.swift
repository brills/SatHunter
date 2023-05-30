//
//  RigControlView.swift
//  SatHunter705
//
//  Created by Zhuo Peng on 5/29/23.
//

import CoreLocation
import SwiftUI

class DopplerShiftModel: NSObject, ObservableObject, CLLocationManagerDelegate {
  @Published var actualDownlinkFreq: Int? = nil
  @Published var actualUplinkFreq: Int? = nil
  var downlinkFreq: Int = 0 {
    didSet {
      refresh()
    }
  }

  var uplinkFreq: Int = 0 {
    didSet {
      refresh()
    }
  }

  private var orbit: SatOrbitElements?
  var trackedSatTle: (String, String)? {
    didSet {
      if let tle = trackedSatTle {
        orbit = SatOrbitElements(tle)
      } else {
        orbit = nil
      }
      refresh()
    }
  }

  private var observer = SatObserver(
    name: "user",
    lat: 37.33481435508938,
    lon: -122.00893980785605,
    alt: 25
  )
  private var locationManager: CLLocationManager?
  private var timer: Timer?

  override init() {
    super.init()
    timer = Timer.scheduledTimer(
      withTimeInterval: 1,
      repeats: true,
      block: { _ in self.refresh() }
    )
    locationManager = CLLocationManager()
    locationManager!.delegate = self
    locationManager!.requestWhenInUseAuthorization()
    locationManager!.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
    locationManager!.startUpdatingLocation()
  }

  func locationManager(
    _: CLLocationManager,
    didUpdateLocations locations: [CLLocation]
  ) {
    if let location = locations.last {
      let userAlt = location.altitude
      let userLon = location.coordinate.longitude
      let userLat = location.coordinate.latitude
      observer = SatObserver(
        name: "user",
        lat: userLat,
        lon: userLon,
        alt: userAlt
      )
    }
  }

  func refresh() {
    var down: Int?
    var up: Int?
    if let orbit = orbit {
      if case let .success(observation) = getSatObservation(observer: observer,
                                                            orbit: orbit)
      {
        if observation.elevation > 0 {
          down = downlinkFreq + getSatDopplerShift(
            observation: observation,
            freq: .DownLink(downlinkFreq)
          )
          up = uplinkFreq + getSatDopplerShift(
            observation: observation,
            freq: .UpLink(uplinkFreq)
          )
        }
      }
    }
    actualDownlinkFreq = down
    actualUplinkFreq = up
  }
}

class RadioModel : ObservableObject {
  @Published var isConnected: Bool = false
  @Published var vfoAFreq: Int = 0
  @Published var vfoBFreq: Int = 0
  var mode: Mode = .LSB {
    didSet {
      configRig()
    }
  }
  var inverted: Bool = false {
    didSet {
      configRig()
    }
  }
  var dopplerShiftModel: DopplerShiftModel?
  private var rig: MyIc705
  private var timer: Timer?
  
  init() {
    self.rig = MyIc705()
  }
  
  func connect() {
    rig.connect()
    self.isConnected = true
  }
  
  func disconnect() {
    rig.disconnect()
    self.isConnected = false
  }
  
  func startTracking() {
    if timer != nil {
      timer!.invalidate()
    }
    configRig()
    timer = Timer.scheduledTimer(
      withTimeInterval: 1,
      repeats: true,
      block: { _ in self.syncFreq() }
    )
  }
  
  func configRig() {
    if !isConnected {
      return
    }
    rig.enableSplit()
    rig.setVfoAMode(mode)
    rig.setVfoBMode(inverted ? mode.inverted() : mode)
  }
  
  func stopTracking() {
    if let timer = timer {
      timer.invalidate()
    }
    timer = nil
  }
  
  private func syncFreq() {
    if let m = dopplerShiftModel {
      if let freq = m.actualDownlinkFreq {
        rig.setVfoAFreq(freq)
      }
      if let freq = m.actualUplinkFreq {
        rig.setVfoBFreq(freq)
      }
    }
  }
}

struct RigControlView: View {
  @Binding var trackedSatTle: (String, String)?
  @State private var downlinkFreqStr = "144.000"
  @State private var uplinkFreqStr = "440.000"
  @State private var selectedMode: Mode = .LSB
  @State private var isInverted: Bool = false
  @FocusState private var uplinkFreqInFocus: Bool
  @FocusState private var downlinkFreqInFocus: Bool
  @ObservedObject var dopplerShiftModel = DopplerShiftModel()
  @ObservedObject var radioModel = RadioModel()
  @State private var radioIsTracking: Bool = false

  var body: some View {
    VStack {
      HStack {
        Image(systemName: "arrow.down")
        TextField("MHz", text: $downlinkFreqStr).keyboardType(.numbersAndPunctuation)
          .submitLabel(.done)
          .focused($downlinkFreqInFocus)
          .onChange(of: downlinkFreqInFocus) {
            newValue in
            if !newValue {
              setDownlinkFreq()
            }
          }
          .onSubmit {
            setDownlinkFreq()
          }
          .frame(maxHeight: .infinity)
        Divider()
        Image(systemName: "dot.radiowaves.forward").rotation3DEffect(
          .degrees(180),
          axis: (x: 1, y: 0, z: 0)
        )
        Text(getActualDownlinkFreq())
          .frame(maxHeight: .infinity)
      }.font(.body.monospaced())
      HStack {
        Image(systemName: "arrow.up")
        TextField("MHz", text: $uplinkFreqStr)
          .submitLabel(.done)
          .keyboardType(.numbersAndPunctuation)
          .focused($uplinkFreqInFocus)
          .onChange(of: uplinkFreqInFocus) {
            newValue in
            if !newValue {
              setUplinkFreq()
            }
          }
          .onSubmit {
            setUplinkFreq()
          }
          .frame(maxHeight: .infinity)
        Divider()
        Image(systemName: "dot.radiowaves.forward")
        Text(getActualUplinkFreq())
          .frame(maxHeight: .infinity)
      }.font(.body.monospaced())
      HStack {
        Text("Mode")
        Picker(selection: $selectedMode, label: Text("Mode")) {
          Text("LSB").tag(Mode.LSB)
          Text("USB").tag(Mode.USB)
          Text("FM").tag(Mode.FM)
        }
        .pickerStyle(.segmented)
        .onChange(of: selectedMode) {
          _ in
          radioModel.mode = selectedMode
        }
        Divider()
        Toggle(isOn: $isInverted) {
          Text("Inverted")
        }
        .toggleStyle(.button)
        .disabled(selectedMode == .FM)
        .onChange(of: isInverted) {
          _ in
          radioModel.inverted = isInverted
        }
      }
      HStack {
        Spacer()
      }.buttonStyle(.borderedProminent)
      Divider()
      HStack {
        Text("Radio")
        Button(radioModel.isConnected ? "Connected" : "Connect") {
          if !radioModel.isConnected {
            radioModel.connect()
          }
        }
        Toggle(isOn: $radioIsTracking) {
          Text("Tracking")
        }
        .toggleStyle(.button)
        .disabled(!radioModel.isConnected || trackedSatTle == nil)
        .onChange(of: radioIsTracking) {
          newValue in
          if newValue {
            radioModel.startTracking()
          } else {
            radioModel.stopTracking()
          }
        }
        Spacer()
      }
    }
    .buttonStyle(.bordered)
    .fixedSize(horizontal: false, vertical: true)
    .onAppear {
      dopplerShiftModel.trackedSatTle = trackedSatTle
      radioModel.dopplerShiftModel = dopplerShiftModel
      radioModel.mode = selectedMode
      radioModel.inverted = isInverted
      setDownlinkFreq()
      setUplinkFreq()
    }
    .onDisappear {
      radioModel.disconnect()
    }
  }

  private func getActualDownlinkFreq() -> String {
    if let f = dopplerShiftModel.actualDownlinkFreq {
      return String(format: "%010.06f", Double(f) / 1e6)
    }
    return "N/A"
  }

  private func getActualUplinkFreq() -> String {
    if let f = dopplerShiftModel.actualUplinkFreq {
      return String(format: "%010.06f", Double(f) / 1e6)
    }
    return "N/A"
  }

  private func setDownlinkFreq() {
    if let freq = Double(downlinkFreqStr) {
      dopplerShiftModel.downlinkFreq = Int(freq * 1e6)
    } else {
      dopplerShiftModel.downlinkFreq = 0
    }
  }

  private func setUplinkFreq() {
    if let freq = Double(uplinkFreqStr) {
      dopplerShiftModel.uplinkFreq = Int(freq * 1e6)
    } else {
      dopplerShiftModel.uplinkFreq = 0
    }
  }
}

struct RigControlView_Previews: PreviewProvider {
  static var previews: some View {
    RigControlView(trackedSatTle: .constant(nil))
  }
}
