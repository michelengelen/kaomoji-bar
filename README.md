# Kaomoji Bar

A macOS menu bar kaomoji picker. Click the `ツ` icon in the menu bar.
Type to search. Click a kaomoji to copy it to the clipboard.

- SwiftUI `MenuBarExtra` (window style), no dependencies.
- 103 kaomoji in 6 categories, plus a "Recently used" section
  (stored in `UserDefaults`).
- Press Return to copy the first search match.
- Quit with the footer button or `⌘Q` while the popup is open.

## Requirements

- macOS 14 or newer.
- Xcode Command Line Tools (`xcode-select --install`).

## Build and install

```bash
./make-app.sh            # assemble "Kaomoji Bar.app" next to the script
./make-app.sh --install  # also replace /Applications/Kaomoji Bar.app and relaunch
```

The script builds with Swift Package Manager and assembles an ad-hoc
signed app bundle. `LSUIElement` keeps the app out of the Dock.

A locally built app carries no quarantine flag, so Gatekeeper does not
block it.

To start the app at login: System Settings → General → Login Items →
add `Kaomoji Bar.app`.

## Data

`Sources/KaomojiData.swift` is generated. The dataset lives in a
TypeScript module that a web version of this picker shares. To
regenerate after a dataset change, compile the module to CommonJS and
run the converter:

```bash
tsc data.ts --outDir /tmp/kaomoji-gen --module commonjs --target es2020
node gen-swift.cjs /tmp/kaomoji-gen/data.js Sources/KaomojiData.swift
```

Do not edit `KaomojiData.swift` by hand.
