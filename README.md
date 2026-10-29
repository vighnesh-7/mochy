# Mochy

A macOS Dynamic Island app reconstructed from the installed **Notchy 2.0.0** (`/Applications/Notchy.app`, bundle `dev.notchy.app`).

Mochy is an original implementation. It does not copy Notchy binaries, artwork, typing-sound packs, Face Unlock videos, Sparkle keys, or analytics secrets.

## Observed Notchy surface (static evidence)

- Native SwiftUI menu-bar island (`LSUIElement`), Sparkle updates, widget extension, charge helper
- Tabs from Swift type metadata: Home, Now Playing, Calendar, Reminders, Notes, Focus, Translate, Activity, AI Usage, Ask AI, Launcher, Packages, Files, Clipboard, Shortcuts, Calculator, Quick Search, Notifications, Tasks, Cuely, Emoji, Timer, Mirror, Stocks, HomeKit, Terminal, Sound Mixer, Quick Settings
- Overlays: charging, AirPods, caps lock, volume/brightness HUDs, screenshots, downloads, calls, agent prompts, caffeine, Space name
- Local script API on `127.0.0.1:9999` with a token header
- URL scheme `notchy://show` (Mochy uses `mochy://show`)

String catalog: 6,903 English keys in `Notchy_Notchy.bundle/Strings/en.json.lzfse`. Hopper analysis of the 240 MB executable did not stay up after launch (provider start failed); type names came from `nm` + `swift-demangle`.

## Build

Command Line Tools are enough (full Xcode is not required):

```bash
cd ~/Desktop/mochy
./build.sh
open dist/Mochy.app
```

Settings (1.1) maps every Notchy settings page: General, Appearance, Behavior, Displays, Tabs, Home, Permissions, Battery & Fans, Caffeine, Calendar, Now Playing, Capture, Clipboard, Notifications, Calls & Messages, Face Unlock, Lock Screen, Typing Sounds, Pointer, Cuely, Timer, Activity, AI Usage, Desktop Pet, Connectivity, Terminal, Quick Search, Stocks, Spaces, Knock, Widgets, Developer, All Tools, About. Keyboard shortcuts (palette, settings, clipboard, hide/open, paste plain, typing pause, pomodoro, emergency quit) are in General and fire globally.

## Local API

```bash
curl -H "X-Mochy-Token: TOKEN" http://127.0.0.1:9999/status
curl -H "X-Mochy-Token: TOKEN" -d '{"title":"Hi","message":"from a script","duration":3}' http://127.0.0.1:9999/show
```

The token lives in Settings → Developer.

## Limitations vs Notchy

Not reconstructed at hardware/helper fidelity: SMC charge limit, fan control, DDC brightness, MediaRemote private adapter, paid license/Sparkle, Face Unlock password typing, and Notchy’s character sprite pack. Those pages exist in Settings with honest status.
