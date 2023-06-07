//
//  SkyView.swift
//  SatHunter
//
//  Created by Zhuo Peng on 6/6/23.
//

import CoreLocation
import SwiftUI

struct SkyViewBg: View {
  var width: Double
  var height: Double
  var body: some View {
    Circle().scale(1.0).stroke()
    Circle().scale(2 / 3.0).stroke()
    Circle().scale(1 / 3.0).stroke()
    Path {
      path in
      path.move(to: .init(x: width / 2, y: height / 2 - (width / 2)))
      path.addLine(to: .init(x: width / 2, y: height / 2 + (width / 2)))
    }.stroke()
    Path {
      path in
      path.move(to: .init(x: 0, y: height / 2))
      path.addLine(to: .init(x: width, y: height / 2))
    }.stroke()
  }
}

struct SatMark: View {
  var width: Double
  var height: Double
  @Binding var visible: Bool
  @Binding var azDeg: Double
  @Binding var elDeg: Double
  var body: some View {
    if visible {
      Path {
        path in
        // the Y origin is top-left corner, thus the minus sign before y * r.
        let center = azElToPoint(
          az: azDeg,
          el: elDeg,
          width: width,
          height: height
        )
        path.addArc(
          center: center,
          radius: 5,
          startAngle: .init(degrees: 0),
          endAngle: .init(degrees: 360),
          clockwise: true
        )
      }.fill(.red)
    } else {
      EmptyView()
    }
  }
}

func azElToPoint(az: Double, el: Double, width: Double,
                 height: Double) -> CGPoint
{
  var ur = 1 - el / 90
  ur = min(max(0, ur), 1)
  let ux = ur * sin(az.rad)
  let uy = ur * cos(az.rad)
  let r = min(width, height) / 2
  // the Y origin is top-left corner, thus the minus sign before y * r.
  return CGPoint(x: width / 2 + ux * r, y: height / 2 - uy * r)
}

struct SatTrack: View {
  var width: Double
  var height: Double
  // Az/el deg pairs
  @Binding var points: [(Double, Double)]
  var body: some View {
    if !points.isEmpty {
      Path {
        path in
        path.move(to: azElToPoint(
          az: points[0].0,
          el: points[0].1,
          width: width,
          height: height
        ))
        for p in points[1...] {
          path
            .addLine(to: azElToPoint(az: p.0, el: p.1, width: width,
                                     height: height))
        }
      }.stroke(Color.orange, lineWidth: 3)
    } else {
      EmptyView()
    }
  }
}

struct UserHeadingIndicator: View {
  var width: Double
  var height: Double
  @Binding var headingDeg: Double

  var body: some View {
    Path {
      path in
      path.move(to: .init(x: width / 2, y: height / 2))
      let r = min(width, height) / 2
      let heading = headingDeg.rad
      let x = width / 2 + r * sin(heading)
      let y = height / 2 - r * cos(heading)
      path.addLine(to: .init(x: x, y: y))
    }.stroke(.blue.opacity(0.4), lineWidth: 5)
  }
}

extension Binding {
  func withDefault<T>(_ defaultValue: T) -> Binding<T> where Value == T? {
    return Binding<T>(get: {
      self.wrappedValue ?? defaultValue
    }, set: { newValue in
      self.wrappedValue = newValue
    })
  }
}

struct SkyView: View {
  @ObservedObject var model: SatViewModel
  var body: some View {
    HStack {
      GeometryReader { g in
        let width = g.size.width
        let height = g.size.height
        ZStack {
          SkyViewBg(width: width, height: height)
          SatTrack(
            width: width,
            height: height,
            points: $model.passTrack
          )
          SatMark(
            width: width,
            height: height,
            visible: $model.visible.withDefault(false),
            azDeg: $model.currentAz.withDefault(0),
            elDeg: $model.currentEl.withDefault(0)
          )
          UserHeadingIndicator(width: width, height: height, headingDeg: $model.userHeading)
        }
      }
    }
  }
}

struct SkyView_Previews: PreviewProvider {
  static var previews: some View {
    HStack {
      GeometryReader { g in
        let width = g.size.width
        let height = g.size.height
        ZStack {
          SkyViewBg(width: width, height: height)
          SatTrack(
            width: width,
            height: height,
            points: .constant([(135, 22), (270, 15), (345, 0)])
          )
          SatMark(
            width: width,
            height: height,
            visible: .constant(true),
            azDeg: .constant(135),
            elDeg: .constant(22)
          )
          UserHeadingIndicator(
            width: width,
            height: height,
            headingDeg: .constant(45.0)
          )
        }
      }
    }
  }
}
