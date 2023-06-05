# SatHunter

SatHunter helps IC-705 owners make satellite contacts with ease.

It provides aids for aiming the antenna at the satellite, and
controls the IC-705 via bluetooth, adjusting the up/down frequencies
automatically with doppler shifts.

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

## Privacy

This App requires access to location information (GPS coordinates and device heading) and
Bluetooth.

All the information acquired is only for computing the satellite orbit and doppler shift as well
as controlling the IC-705. Nothing is shared with anyone.

## Contribution

This project started as a personal effort by NE6NE.

All kinds of contributions are welcome. Please report issues on GitHub, or even better, create
Pull Requests to fix them!

The author is not an App developer by trade, not do they have any design talent. If you identified any
room for improvement in UI / UX please create an issue or PR. You may define the aesthetic taste of
this App.

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

