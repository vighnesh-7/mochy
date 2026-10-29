# Mochy

A notch utility for macOS 14+ that turns the camera housing into a Dynamic Island. Its feature set is modeled on Notchy 2.0, but Mochy is an original implementation. It contains no Notchy code, artwork, sounds, update keys, analytics or licensing.

## What's in the island

**Beside the notch (live activities).** The most time-sensitive activity wins:

- volume
- download progress
- Pomodoro or timer
- now playing (artwork and moving bars in the album color)
- caffeine
- charging

**Alerts drop out of the notch** for:

- new tracks
- plugging in, unplugging, fully charged, and low battery at 20%, 10% and 5%
- upcoming calendar events, with a **Join** button for Zoom, Meet, Teams, Webex and FaceTime links
- finished downloads
- Pomodoro phase changes
- files added to the Shelf

**Expanded tabs.** Hover over or click the notch to open it. Tabs sit left of the camera; Command Palette, Pin and Settings sit to the right.

| Tab | What it does |
| --- | --- |
| Home | Up to four cards: Now Playing, Today, Quick Controls (caffeine, focus, pin, color picker), To-Do, Battery, System, Weather |
| Shelf | Drop files to park them, drag them back out, or drop them on **AirDrop** |
| Clipboard | Searchable history of text, links and files; pin items; click to copy |
| To-Do | Quick list, plus Reminders due today |
| Pomodoro | Pomodoro, countdown and stopwatch, with rounds, +1 min and skip |
| Calendar | Today's agenda and tomorrow's first events |
| System | CPU sparkline, memory, network, storage, and battery vitals (health, cycles, temperature, watts, adapter) |

Notes, Calculator, Search, Launcher, Emoji and Mirror can be turned on in Settings › Tabs, and every tab is always available from the Command Palette.

## Keyboard shortcuts

All shortcuts are global and can be changed in Settings › Keyboard Shortcuts. They use Carbon hot keys, so Accessibility access isn't needed.

| Shortcut | Action |
| --- | --- |
| ⌃⌥Space | Open or close the island |
| ⌃⌥K | Command palette |
| ⌃⌥C | Clipboard history (search field focused) |
| ⌃⌥T | To-Do (new item field focused) |
| ⌃⌥S | Shelf |
| ⌃⌥P | Start or pause Pomodoro |
| ⌃⌥A | Toggle caffeine |
| ⌃⌥I | Pin the island open |
| ⌃⌥M | Play or pause media |
| ⌃⌥, | Settings |

Press Esc in the island to close the palette, or the island itself.

## Now Playing

Mochy reads the system Now Playing session, the same one Control Center uses. It works with Music, Spotify, Podcasts, and video in Safari or Chrome, including YouTube.

Since macOS 15.4, only Apple-entitled processes may read that session. Mochy therefore ships a small Objective-C bridge (`Native/MediaRemoteBridge.m`), which is loaded by `/usr/bin/perl`, an entitled system binary. The bridge streams JSON to the app. It uses the same approach as the open-source *mediaremote-adapter* project, and a future macOS update could close it.

## Build

Command Line Tools are enough:

```bash
cd ~/Desktop/mochy
./build.sh
open dist/Mochy.app
```

`build.sh` compiles the bridge with `clang` and the app with `swiftc`. It then assembles `dist/Mochy.app` and ad-hoc signs it. Open at Login needs the app to be in `/Applications`.

`Tools/Snapshot.swift` renders island states to PNG files for design review. It isn't part of the app.

## URL scheme and local API

The URL scheme accepts these addresses:

- `mochy://open`
- `mochy://close`
- `mochy://settings`
- `mochy://palette`
- `mochy://pomodoro`
- `mochy://caffeine`
- `mochy://tab/<home|shelf|clipboard|todo|timer|calendar|stats|…>`

The local API is off by default; turn it on in Settings › Developer. It only accepts connections from this Mac.

```bash
curl -H "X-Mochy-Token: TOKEN" http://127.0.0.1:9999/status
curl -X POST -H "X-Mochy-Token: TOKEN" http://127.0.0.1:9999/show \
  -d '{"title":"Build finished","subtitle":"main","symbol":"hammer.fill","color":"#30D158","duration":4}'
curl -X POST -H "X-Mochy-Token: TOKEN" http://127.0.0.1:9999/expand -d '{"tab":"todo"}'
```

## Limitations

- Mochy doesn't replace the system volume and brightness indicators.
- CPU and GPU temperatures aren't shown; they need private SMC sensors.
- The following are left out by design: charge limiting, fan control, external-display brightness (DDC), Face Unlock and the desktop pet.
- Clipboard history skips items that apps mark as concealed or transient, such as password managers.
