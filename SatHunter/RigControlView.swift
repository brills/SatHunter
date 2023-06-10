import CoreLocation
import SwiftUI

class DopplerShiftModel: NSObject, ObservableObject, CLLocationManagerDelegate {
  @Published var actualDownlinkFreq: Int? = nil
  @Published var actualUplinkFreq: Int? = nil
  @Published var downlinkFreq: Int = 0
  @Published var uplinkFreq: Int = 0
  @Published var transponderDownlinkShift: Int?
  @Published var transponderUplinkShift: Int?
  var transponder: Transponder?
  private var orbit: SatOrbitElements?
  var trackedSatTle: (String, String)? {
    didSet {
      if let tle = trackedSatTle {
        orbit = SatOrbitElements(tle)
      } else {
        orbit = nil
      }
    }
  }

  private var observer = SatObserver(
    name: "user",
    lat: 37.33481435508938,
    lon: -122.00893980785605,
    alt: 25
  )
  private var locationManager: CLLocationManager?
  private var dispatchQueue: DispatchQueue = .init(label: "doppler_shift_model")
  private var isLooping: Bool = false
  private var downlinkFreqShift: Int = 0
  private var uplinkFreqShift: Int = 0

  override init() {
    super.init()
    startLoop()
    locationManager = CLLocationManager()
    locationManager!.delegate = self
    locationManager!.requestWhenInUseAuthorization()
    locationManager!.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
    locationManager!.startUpdatingLocation()
  }

  func startLoop() {
    isLooping = true
    scheduleLoop(now: true)
  }

  func blockedRefresh() {
    refresh(forceBlocked: true)
  }

  private func scheduleLoop(now: Bool) {
    if now {
      dispatchQueue.async {
        [weak self] in
          if let self = self {
            if self.isLooping {
              self.refresh()
              self.scheduleLoop(now: false)
            }
          }
      }
    } else {
      dispatchQueue.asyncAfter(deadline: .now() + .milliseconds(500)) {
        [weak self] in
          if let self = self {
            if self.isLooping {
              self.refresh()
              self.scheduleLoop(now: false)
            }
          }
      }
    }
  }

  func stopLoop() {
    dispatchQueue.sync { self.isLooping = false }
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

  func setTrueFreq(_ f: FreqForDopplerCalculation) {
    var fValue: Int
    var setF: (DopplerShiftModel, Int) -> Void
    switch f {
    case let .DownLink(f):
      fValue = f
      setF = {
        (m: DopplerShiftModel, value: Int) in
          DispatchQueue.main.sync {
            m.downlinkFreq = value
          }
      }
    case let .UpLink(f):
      fValue = f
      setF = {
        (m: DopplerShiftModel, value: Int) in
          DispatchQueue.main.sync {
            m.uplinkFreq = value
          }
      }
    }

    guard let orbit = orbit else {
      setF(self, fValue)
      return
    }
    guard case let .success(observation) = getSatObservation(observer: observer,
                                                             orbit: orbit)
    else {
      setF(self, fValue)
      return
    }
    dispatchQueue.async {
      [weak self] in
        if let self = self {
          setF(
            self,
            fValue - getSatDopplerShift(observation: observation, freq: f)
          )
        }
    }
  }

  private func refresh(forceBlocked: Bool = false) {
    var down: Int?
    var up: Int?
    var transponderUpShift: Int?
    var transponderDownShift: Int?
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
          if let t = transponder {
            transponderDownShift = getSatDopplerShift(
              observation: observation,
              freq: .DownLink(t.downlinkCenterFreq)
            )
            if let uplinkCenterFreq = t.uplinkCenterFreq {
              transponderUpShift = getSatDopplerShift(
                observation: observation,
                freq: .UpLink(uplinkCenterFreq)
              )
            }
          }
        }
      }
    }
    if forceBlocked {
      transponderDownlinkShift = transponderDownShift
      transponderUplinkShift = transponderUpShift
      actualDownlinkFreq = down
      actualUplinkFreq = up
    } else {
      DispatchQueue.main.async {
        self.transponderDownlinkShift = transponderDownShift
        self.transponderUplinkShift = transponderUpShift
        self.actualDownlinkFreq = down
        self.actualUplinkFreq = up
      }
    }
  }
}

extension Int {
  var asFormattedFreq: String {
    String(format: "%010.06f", Double(self) / 1e6)
  }

  var asShortFormattedFreq: String {
    String(format: "%07.03f", Double(self) / 1e6)
  }
}

class RadioModel: ObservableObject {
  @Published var vfoAFreq: Int = 0
  @Published var vfoBFreq: Int = 0
  @Published var isOutOfTransponderRange: Bool = false
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

  var rig: MyIc705?
  var dopplerShiftModel: DopplerShiftModel?
  var transponder: Transponder?
  private var timer: Timer?
  private var isTracking: Bool = false

  init() {}

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
    guard let rig = rig else { return }
    if rig.connectionState != .Connected {
      return
    }
    rig.enableSplit()
    rig.setVfoAMode(vfoAMode)
    rig.setVfoBMode(vfoBMode)
  }

  func configCtcss() {
    guard let rig = rig else {
      return
    }
    if rig.connectionState != .Connected {
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

  func setFreqFromDopplerModel() {
    guard let rig = rig else { return }
    guard let m = dopplerShiftModel else { return }
    if let freq = m.actualDownlinkFreq {
      rig.setVfoAFreq(freq)
    }
    if let freq = m.actualUplinkFreq {
      rig.setVfoBFreq(freq)
    }
  }

  private func updateIsOutOfTransponderRange(_ v: Bool) {
    if v != isOutOfTransponderRange {
      isOutOfTransponderRange = v
    }
  }

  private func syncFreq() {
    guard let rig = rig else {
      return
    }
    if rig.connectionState != .Connected {
      return
    }
    vfoAFreq = rig.getVfoAFreq()
    vfoBFreq = rig.getVfoBFreq()

    // tracking locks the freq
    if isTracking {
      setFreqFromDopplerModel()
      return
    }

    guard let m = dopplerShiftModel else { return }
    // When not tracking, let the doppler model follow VFO A.
    m.setTrueFreq(.DownLink(vfoAFreq))
    // If transponder is available, then let VFO B follow VFO A.
    // How it follows depends on the type of transponder:
    guard let transponder = transponder else {
      updateIsOutOfTransponderRange(false)
      return
    }
    // No uplink. No reason for VFO B to follow.
    guard transponder.uplinkCenterFreq != nil else {
      updateIsOutOfTransponderRange(false)
      return
    }
    let setVfoBFreq: (Int) -> Void = {
      f in
      self.rig?.setVfoBFreq(f)
      m.setTrueFreq(.UpLink(f))
    }
    // downlink freq is not a range.
    if transponder.downlinkFreqUpper == 0 {
      let shiftedDownFreq = Int(transponder.downlinkFreqLower) +
        (m.transponderDownlinkShift ?? 0)
      let delta = vfoAFreq - shiftedDownFreq
      let shiftedUpFreq = Int(transponder.uplinkFreqLower) +
        (m.transponderUplinkShift ?? 0)
      setVfoBFreq(shiftedUpFreq + (transponder.inverted ? -delta : delta))
      updateIsOutOfTransponderRange(false)
      return
    }
    // downlink freq is a range. First check if VFO A is in that range
    let shiftedDownLower = Int(transponder.downlinkFreqLower) +
      (m.transponderDownlinkShift ?? 0)
    let shiftedDownUpper = Int(transponder.downlinkFreqUpper) +
      (m.transponderDownlinkShift ?? 0)
    guard shiftedDownLower <= vfoAFreq, vfoAFreq <= shiftedDownUpper else {
      updateIsOutOfTransponderRange(true)
      return
    }
    updateIsOutOfTransponderRange(false)
    let delta = vfoAFreq - shiftedDownLower
    let shiftedUpLower = Int(transponder.uplinkFreqLower) +
      (m.transponderUplinkShift ?? 0)
    let shiftedUpUpper = Int(transponder.uplinkFreqUpper) +
      (m.transponderUplinkShift ?? 0)
    if transponder.inverted {
      setVfoBFreq(shiftedUpUpper - delta)
    } else {
      setVfoBFreq(shiftedUpLower + delta)
    }
  }
}

// The picker has to be in its own view because its parent is redrawn too
// frequently due to the periodic update.
// https://developer.apple.com/forums/thread/127218
struct TransponderPicker : View {
  @Binding var transponderIdx: Int
  var trackedSat: Satellite
  var body: some View {
    HStack {
      Image(systemName: "antenna.radiowaves.left.and.right")
      Picker("Transponder", selection: $transponderIdx) {
        Text("Transponder not selected").tag(-1)
        ForEach(trackedSat.transponders.indices, id: \.self) {
          i in
          Text(trackedSat.transponders[i].description_p)
        }
      }
    }
  }
}

struct TransponderView : View {
  @Binding var transponderIdx: Int
  @Binding var transponderUplinkShift: Int?
  @Binding var transponderDownlinkShift: Int?
  var trackedSat: Satellite
  var body: some View {
    HStack {
      TransponderPicker(transponderIdx: $transponderIdx, trackedSat: trackedSat)
      // Only show doppler corrected freq range when the transponder has one.
      if transponderIdx >= 0 &&
         trackedSat.transponders[transponderIdx].downlinkFreqUpper > 0 &&
         trackedSat.transponders[transponderIdx].uplinkFreqLower > 0 &&
         trackedSat.transponders[transponderIdx].uplinkFreqUpper > 0 {
        VStack {
          HStack {
            Image(systemName: "arrow.down")
            Text(getShiftedFreq(
              baseFreq: trackedSat.transponders[transponderIdx]
                .downlinkFreqLower,
              shift: transponderDownlinkShift
            ))
            Text("-")
            Text(getShiftedFreq(
              baseFreq: trackedSat.transponders[transponderIdx]
                .downlinkFreqUpper,
              shift: transponderDownlinkShift
            ))
          }
          HStack {
            Image(systemName: "arrow.up")
            Text(getShiftedFreq(
              baseFreq: trackedSat.transponders[transponderIdx]
                .uplinkFreqLower,
              shift: transponderUplinkShift
            ))
            Text("-")
            Text(getShiftedFreq(
              baseFreq: trackedSat.transponders[transponderIdx]
                .uplinkFreqUpper,
              shift: transponderUplinkShift
            ))
          }
        }.font(.footnote.monospaced())
      }
      Spacer()
    }
  }

  private func getShiftedFreq(baseFreq: Int64, shift: Int?) -> String {
    if let shift = shift {
      return (Int(baseFreq) + shift).asShortFormattedFreq
    }
    return Int(baseFreq).asShortFormattedFreq
  }
}

struct RigControlView: View {
  var trackedSat: Satellite
  @State private var selectedVfoAMode: Mode = .LSB
  @State private var selectedVfoBMode: Mode = .LSB
  @EnvironmentObject private var rig: MyIc705
  @StateObject var dopplerShiftModel = DopplerShiftModel()
  @StateObject var radioModel = RadioModel()
  @State private var radioIsTracking: Bool = false
  @State private var transponderIdx: Int = -1
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
      SatFreqView(
        downlinkFreqAtSat: $dopplerShiftModel.downlinkFreq,
        uplinkFreqAtSat: $dopplerShiftModel.uplinkFreq,
        downlinkFreqAtGround: $dopplerShiftModel.actualDownlinkFreq,
        uplinkFreqAtGround: $dopplerShiftModel.actualUplinkFreq
      )
      TransponderView(
        transponderIdx: $transponderIdx,
        transponderUplinkShift: $dopplerShiftModel.transponderUplinkShift,
        transponderDownlinkShift: $dopplerShiftModel.transponderDownlinkShift,
        trackedSat: trackedSat)
        .onChange(of: transponderIdx, perform: { _ in setTransponder()} )
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
            Text("CW").tag(Mode.CW)
          }
          .pickerStyle(.segmented)
          .onChange(of: selectedVfoAMode) {
            _ in
            radioModel.vfoAMode = selectedVfoAMode
          }
          Text(getVfoAFreq())
            .font(.body.monospaced())
            .frame(maxHeight: .infinity)
            .foregroundColor(radioModel.isOutOfTransponderRange ? .red : .black)
        }
        Divider()
        Image(systemName: "arrow.up")
        VStack {
          Picker(selection: $selectedVfoBMode, label: Text("VFO B Mode")) {
            Text("LSB").tag(Mode.LSB)
            Text("USB").tag(Mode.USB)
            Text("FM").tag(Mode.FM)
            Text("CW").tag(Mode.CW)
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
        Button(rig.connectionState.description) {
          switch rig.connectionState {
          case .NotConnected:
            rig.connect()
          case .Connected:
            fallthrough
          case .Connecting:
            rig.disconnect()
          }
        }.onChange(of: rig.connectionState) {
          newValue in
          if newValue == .Connected {
            setTransponder()
          }
        }
        Toggle(isOn: $radioIsTracking) {
          Text(radioIsTracking ? "Tracking" : "Track")
        }
        .toggleStyle(.button)
        .disabled(rig.connectionState != .Connected)
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
      dopplerShiftModel.trackedSatTle = trackedSat.tleTuple
      dopplerShiftModel.startLoop()
      radioModel.rig = rig
      radioModel.dopplerShiftModel = dopplerShiftModel
      radioModel.vfoAMode = selectedVfoAMode
      radioModel.vfoBMode = selectedVfoBMode
      radioModel.startLoop()
    }
    .onDisappear {
      radioModel.stopLoop()
    }
  }

  private func setTransponder() {
    var transponder: Transponder?
    if transponderIdx >= 0, transponderIdx < trackedSat.transponders.count {
      transponder = trackedSat.transponders[transponderIdx]
    }
    dopplerShiftModel.stopLoop()
    radioModel.stopLoop()
    radioModel.transponder = transponder
    dopplerShiftModel.transponder = transponder
    if let transponder = transponder {
      dopplerShiftModel.downlinkFreq = transponder.downlinkCenterFreq
      if let uplinkFreq = transponder.uplinkCenterFreq {
        dopplerShiftModel.uplinkFreq = uplinkFreq
      } else {
        dopplerShiftModel.uplinkFreq = transponder.downlinkCenterFreq
      }
      selectedVfoAMode = transponder.downlinkMode.libPredictMode
      selectedVfoBMode = transponder.uplinkMode.libPredictMode
    } else {
      dopplerShiftModel.uplinkFreq = 0
      dopplerShiftModel.setTrueFreq(.DownLink(radioModel.vfoAFreq))
    }
    dopplerShiftModel.blockedRefresh()
    radioModel.setFreqFromDopplerModel()
    dopplerShiftModel.startLoop()
    radioModel.startLoop()
    if transponder != nil {
      radioIsTracking = true
    }
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
}
