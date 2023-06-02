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

extension Int {
  var asFormattedFreq: String {
    String(format:"%010.06f", Double(self) / 1e6)
  }
}

class RadioModel : ObservableObject {
  enum ConnectionState {
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
  @Published var connectionState: ConnectionState = .NotConnected
  @Published var vfoAFreq: Int = 0
  @Published var vfoBFreq: Int = 0
  var vfoAMode: Mode = .LSB {
    didSet {
      configRig()
    }
  }
  var vfoBMode: Mode = .LSB {
    didSet {
      configRig()
    }
  }
  var ctcss: ToneFreq = .NotSet {
    didSet {
      configCtcss()
    }
  }
  var dopplerShiftModel: DopplerShiftModel?
  private var rig: MyIc705
  private var timer: Timer?
  private var isTracking: Bool = false
  
  init() {
    self.rig = MyIc705()
  }
  
  func connect() {
    connectionState = .Connecting
    rig.connect {
      DispatchQueue.main.async {
        self.connectionState = .Connected
        self.startLoop()
      }
    }
  }
  
  func disconnect() {
    self.stopLoop()
    rig.disconnect()
    connectionState = .NotConnected
    vfoAFreq = 0
    vfoBFreq = 0
  }
  
  func startLoop() {
    if timer != nil {
      timer!.invalidate()
    }
    configRig()
    configCtcss()
    timer = Timer.scheduledTimer(
      withTimeInterval: 0.5,
      repeats: true,
      block: { _ in self.syncFreq() }
    )
  }
  
  func stopLoop() {
    if let timer = timer {
      timer.invalidate()
    }
    timer = nil
  }
  
  func startTracking() {
    isTracking = true
  }
  
  func stopTracking() {
    isTracking = false
  }
  
  func configRig() {
    if connectionState != .Connected {
      return
    }
    rig.enableSplit()
    rig.setVfoAMode(vfoAMode)
    rig.setVfoBMode(vfoBMode)
  }
  
  func configCtcss() {
    if connectionState != .Connected {
      return
    }
    if ctcss == .NotSet {
      rig.selectVfo(false)
      rig.enableVfoARepeaterTone(false)
      rig.selectVfo(true)
    } else {
      rig.selectVfo(false)
      rig.enableVfoARepeaterTone(true)
      rig.setVfoAToneFreq(ctcss)
      rig.selectVfo(true)
    }
  }
  
  private func syncFreq() {
    if connectionState != .Connected {
      return
    }
    if isTracking {
      if let m = dopplerShiftModel {
        if let freq = m.actualDownlinkFreq {
          rig.setVfoAFreq(freq)
        }
        if let freq = m.actualUplinkFreq {
          rig.setVfoBFreq(freq)
        }
      }
    }
    vfoAFreq = rig.getVfoAFreq()
    vfoBFreq = rig.getVfoBFreq()
  }
}

struct RigControlView: View {
  @Binding var trackedSat: Satellite?
  @State private var downlinkFreqStr = "144.000"
  @State private var uplinkFreqStr = "440.000"
  @State private var selectedVfoAMode: Mode = .LSB
  @State private var selectedVfoBMode: Mode = .LSB
  @FocusState private var uplinkFreqInFocus: Bool
  @FocusState private var downlinkFreqInFocus: Bool
  @ObservedObject var dopplerShiftModel = DopplerShiftModel()
  @ObservedObject var radioModel = RadioModel()
  @State private var radioIsTracking: Bool = false
  @State private var transponderIdx: Int = 0
  @State private var selectedCtcss: ToneFreq = .NotSet

  var body: some View {
    VStack {
      // TODO: Generalize this "section header" UI component.
      ZStack {
        Rectangle().fill(.blue).opacity(0.3)
        HStack {
          Spacer()
          Text("Satellite")
          Spacer()
        }
      }
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
        Image(systemName: "dot.radiowaves.forward")
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
        Image(systemName: "antenna.radiowaves.left.and.right")
        if trackedSat == nil {
          Text("No transponder info available")
        } else {
          // Bug: the picker dropdown is redrawn as the doppler model refreshes
          // causing glitches.
          // https://developer.apple.com/forums/thread/127218
          Picker("Transponder", selection: $transponderIdx) {
            ForEach(trackedSat!.transponders.indices, id: \.self) {
              i in
              Text(trackedSat!.transponders[i].description_p)
            }
          }
          Button("Set") {
            guard let trackedSat else {
              return
            }
            guard transponderIdx >= 0 && transponderIdx < trackedSat
              .transponders.count else {
              return
            }
            setTransponder(trackedSat.transponders[transponderIdx])
          }
        }
        Spacer()
      }
      ZStack {
        Rectangle().fill(.blue).opacity(0.3)
        HStack {
          Spacer()
          Text("Radio")
          Spacer()
        }
      }
      HStack {
        Image(systemName: "arrow.down")
        VStack {
          Picker(selection: $selectedVfoAMode, label: Text("VFO A Mode")) {
            Text("LSB").tag(Mode.LSB)
            Text("USB").tag(Mode.USB)
            Text("FM").tag(Mode.FM)
          }
          .pickerStyle(.segmented)
          .onChange(of: selectedVfoAMode) {
            _ in
            radioModel.vfoAMode = selectedVfoAMode
          }
          Text(getVfoAFreq())
            .font(.body.monospaced())
            .frame(maxHeight: .infinity)
        }
        Divider()
        Image(systemName: "arrow.up")
        VStack {
          Picker(selection: $selectedVfoBMode, label: Text("VFO B Mode")) {
            Text("LSB").tag(Mode.LSB)
            Text("USB").tag(Mode.USB)
            Text("FM").tag(Mode.FM)
          }
          .pickerStyle(.segmented)
          .onChange(of: selectedVfoBMode) {
            _ in
            radioModel.vfoBMode = selectedVfoBMode
          }
          Text(getVfoBFreq())
            .font(.body.monospaced())
            .frame(maxHeight: .infinity)
        }
      }
      HStack {
        Button(radioModel.connectionState.description) {
          switch radioModel.connectionState {
          case .NotConnected:
            radioModel.connect()
          case .Connected:
            fallthrough
          case .Connecting:
            radioModel.disconnect()
          }
        }
        Toggle(isOn: $radioIsTracking) {
          Text(radioIsTracking ? "Tracking" : "Track")
        }
        .toggleStyle(.button)
        .disabled(radioModel
          .connectionState != .Connected || trackedSat == nil)
        .onChange(of: radioIsTracking) {
          newValue in
          if newValue {
            radioModel.startTracking()
          } else {
            radioModel.stopTracking()
          }
        }
        Spacer()
        Picker(selection: $selectedCtcss, label: Text("CTCSS")) {
          ForEach(ToneFreq.allCases) {
            f in
            Text(f.description).tag(f)
          }
        }.onChange(of: selectedCtcss) {
          newValue in
          radioModel.ctcss = newValue
        }
      }
    }
    .buttonStyle(.bordered)
    .fixedSize(horizontal: false, vertical: true)
    .onAppear {
      dopplerShiftModel.trackedSatTle = trackedSat?.tleTuple
      radioModel.dopplerShiftModel = dopplerShiftModel
      radioModel.vfoAMode = selectedVfoAMode
      radioModel.vfoBMode = selectedVfoBMode
      setDownlinkFreq()
      setUplinkFreq()
    }
    .onDisappear {
      radioModel.disconnect()
    }
  }
 
  private func setTransponder(_ transponder: Transponder) {
    dopplerShiftModel.downlinkFreq = transponder.downlinkCenterFreq
    if let uplinkFreq = transponder.uplinkCenterFreq {
      dopplerShiftModel.uplinkFreq = uplinkFreq
    } else {
      dopplerShiftModel.uplinkFreq = transponder.downlinkCenterFreq
    }

    selectedVfoAMode = transponder.downlinkMode.libPredictMode
    selectedVfoBMode = transponder.uplinkMode.libPredictMode
    downlinkFreqStr = String(format: "%07.03f", Double(dopplerShiftModel.downlinkFreq) / 1e6)
    uplinkFreqStr = String(format: "%07.03f", Double(dopplerShiftModel.uplinkFreq) / 1e6)
  }

  private func getVfoAFreq() -> String {
    if radioModel.vfoAFreq > 0 {
      return radioModel.vfoAFreq.asFormattedFreq
    }
    return "N/A"
  }
  private func getVfoBFreq() -> String {
    if radioModel.vfoBFreq > 0 {
      return radioModel.vfoBFreq.asFormattedFreq
    }
    return "N/A"
  }
  private func getActualDownlinkFreq() -> String {
    if let f = dopplerShiftModel.actualDownlinkFreq {
      return f.asFormattedFreq
    }
    return "N/A"
  }

  private func getActualUplinkFreq() -> String {
    if let f = dopplerShiftModel.actualUplinkFreq {
      return f.asFormattedFreq
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
