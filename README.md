# TransFloat 译浮

A lightweight macOS menu bar app that translates selected text and displays the result as a floating "desktop lyrics" bar at the bottom of your screen.

![TransFloat](logo.svg)

## Features

- **Select & Translate**: Select any text in any app, press `⌃⌥D` (Control+Option+D) to translate
- **Floating Bar**: Translation appears as a sleek, semi-transparent bar at the bottom of the screen
- **Auto Dismiss**: Bar disappears after 3 seconds, hover to keep it visible
- **10 Languages**: Switch target language from the menu bar (Chinese, English, Japanese, Korean, French, German, Spanish, Russian, Dutch, Traditional Chinese)
- **Free**: Uses Google Translate — no API key needed
- **Lightweight**: Pure Swift, no Electron, no dependencies

## Install (Download)

1. Go to [**Releases**](https://github.com/wwwwxu/TransFloat/releases/latest)
2. Download **TransFloat.zip**
3. Unzip and move `TransFloat.app` to your Applications folder
4. **First launch**: Right-click the app → "Open" → click "Open" in the dialog (needed once for unsigned apps)
5. Grant **Accessibility** permission when prompted (System Settings → Privacy & Security → Accessibility)

> **If macOS says "damaged" or won't open**, run this in Terminal:
> ```bash
> xattr -cr /Applications/TransFloat.app
> ```
> Then open again normally.

## Usage

1. Launch TransFloat — a 🌐 globe icon appears in the menu bar
2. Select any text in any app
3. Press **⌃⌥D** (Control + Option + D)
4. Translation appears at the bottom of the screen

### Menu Bar Options

Click the 🌐 icon to:
- **Toggle translation** on/off
- **Change target language** via submenu
- **Test translation** with a sample sentence
- **Quit** the app

## Build from Source

Requires Xcode Command Line Tools and macOS 13.0+.

```bash
git clone https://github.com/wwwwxu/TransFloat.git
cd TransFloat
bash build.sh
./TransFloat.app/Contents/MacOS/TransFloat
```

## Tech Stack

- Swift 5.9 / macOS 13+
- AppKit (NSPanel, NSStatusBar)
- SwiftUI (floating bar view)
- Carbon (RegisterEventHotKey for global hotkey)
- Google Translate free API

## License

MIT
