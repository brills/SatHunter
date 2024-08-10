# SatHunter

SatHunter helps IC-705 owners make satellite contacts with ease.

It provides aids for aiming the antenna at the satellite, and
controls the IC-705 via bluetooth, adjusting the up/down frequencies
automatically with doppler shifts.

[Get it on App Store](https://apps.apple.com/us/app/sathunter/id6449915406).

## Features

- Simple control
    - Connect to your IC-705, select a satellite, select a transponder, then you only need
      to worry about rotating the antenna.
- Intuitive satellite tracking
    - Point your iPhone in the same direction as the antenna, then turn your antenna
      according to the indicator. 
- Full doppler tuning (FDT / One True Rule)
    - For FM satellites, your IC-705 will be fixed on the right frequency thanks to
       real-time doppler prediction and great frequency stability of IC-705
    - For linear satellites, the uplink frequency automatically and correctly matches
      the downlink frequency when you are tuning the main VFO knob.
- Updatable satellite and transponder database
- Open source software

## Getting Started
See the [guide](Docs/GettingStarted.md).

## Roadmap

- Test in field how well IC-705 can work a linear satellite in half-duplex.
  - The main challenge is going to be the drift in the LO on the satellite. If we can 
    identify that to be the case, we may be able to measure the drift by tuning
    exactly to the beacon of the satellite. If we are able to measure it, we will
    be able to compensate it.
- CW support. IC-705 CI-V supports sending CW. The challenge is to design a UI flow
  that would allow simple CW QSO, given that users may not have both of their hands
  available.
- Basic logging support. IC-705 can record QSOs, but sometimes it can be difficult
  to recall via which satellite was a QSO done. A simple log button that saves the
  current time, current satellite, current frequencies would be helpful.

## Privacy

This App requires access to location information (GPS coordinates and device heading) and
Bluetooth.

All the information acquired is only for computing the satellite orbit and doppler shift as well
as controlling the IC-705. Nothing is shared with anyone.

## Tested Devices

My only iPhone is an iPhone XR. So this is the only device I can physically
test each release with. The xcode simulators do not have bluetooth support.

The app currently only supports IC-705.

## Contribution

See the [contribution guide](Docs/Contribution.md)

## License

Copyright 2023- Zhuo Peng

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.

## Vendored third-party libraries

- `libpredict`: https://github.com/la1k/libpredict .
   See `libpredict/COPYING` for the license and `libpredict/LICENSE` for the licensing term.

