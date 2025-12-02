# WhisperType

<p align="center">
  <img src="WhisperType/Resources/Assets.xcassets/AppIcon.appiconset/icon_128x128.png" alt="WhisperType Logo" width="128" height="128">
</p>

<p align="center">
  <strong>Privacy-focused, local voice-to-text for macOS</strong>
</p>

<p align="center">
  <a href="#features">Features</a> •
  <a href="#installation">Installation</a> •
  <a href="#usage">Usage</a> •
  <a href="#models">Models</a> •
  <a href="#settings">Settings</a> •
  <a href="#troubleshooting">Troubleshooting</a>
</p>

---

## Overview

WhisperType is a free, open-source menu bar application that provides **system-wide voice input** for macOS. Using OpenAI's Whisper speech recognition technology, all transcription happens **100% locally on your device** — no cloud services, no API calls, complete privacy.

**Key Benefits:**
- 🔒 **Complete Privacy** — Your voice never leaves your computer
- 🌐 **Works Everywhere** — Any text field in any application
- ⚡ **Fast & Accurate** — Powered by whisper.cpp with Apple Silicon optimization
- 💰 **Free Forever** — Open source, no subscriptions

## Features

- 🎤 **System-wide voice input** — Dictate in any application (browsers, editors, terminals, etc.)
- 🔒 **100% local processing** — No internet required after model download
- ⌨️ **Global hotkey** — Quick activation with customizable shortcut (default: `⌥Space`)
- 📦 **Multiple model sizes** — From tiny (75 MB) to large (3.1 GB)
- 🌍 **Multi-language support** — English-only or multilingual models available
- 🎯 **Menu bar app** — Unobtrusive, always accessible
- 🔊 **Audio feedback** — Optional sounds for recording start/stop

## Requirements

- **macOS 13.0** (Ventura) or later
- **8GB RAM minimum** (16GB recommended for larger models)
- **Disk space** — 75 MB to 3.1 GB depending on model choice

## Installation

### Download Release (Recommended)

1. Download the latest `.dmg` from [Releases](https://github.com/projectfr33d0m2025/whispertype/releases)
2. Open the `.dmg` file
3. Drag **WhisperType** to your **Applications** folder
4. Launch WhisperType from Applications
5. Grant required permissions when prompted

### Build from Source

See [CONTRIBUTING.md](CONTRIBUTING.md) for build instructions.

### Building a Release DMG

To create a distributable DMG:

```bash
# 1. Build whisper.cpp libraries (if not already done)
./Scripts/build-whisper.sh

# 2. Build and create DMG in one step
./Scripts/distribute.sh

# Or run steps separately:
./Scripts/build-release.sh  # Build the app
./Scripts/create-dmg.sh     # Create the DMG
```

The DMG will be created in `build/WhisperType-X.X.X.dmg`.

**Note:** This app is distributed unsigned. Users will need to right-click and select "Open" on first launch.

## First Launch Setup

When you first launch WhisperType:

1. **Grant Microphone Permission**
   - WhisperType needs access to your microphone to record your voice
   - Click "OK" when prompted, or go to System Settings → Privacy & Security → Microphone

2. **Grant Accessibility Permission**
   - Required to type text into other applications
   - You'll be prompted to open System Settings
   - Find WhisperType in the list and enable it
   - You may need to restart WhisperType after granting permission

3. **Download a Model**
   - Click the menu bar icon → Settings → Models
   - Choose a model (we recommend **Base (EN)** for most users)
   - Click **Download** and wait for it to complete
   - Click **Set Active** to use the model

4. **You're Ready!**
   - Press `⌥Space` (Option + Space) to start recording
   - Speak naturally
   - Release the key to transcribe and insert text

## Usage

### Basic Voice Input

1. **Click in any text field** where you want to type
2. **Press and hold** `⌥Space` (or your configured hotkey)
3. **Speak** your text naturally
4. **Release** the hotkey
5. Your speech is transcribed and inserted at the cursor

### Recording Modes

WhisperType supports two recording modes:

| Mode | How it Works |
|------|--------------|
| **Hold to Record** (default) | Press and hold hotkey to record, release to transcribe |
| **Toggle Recording** | Press once to start, press again to stop and transcribe |

Change the mode in Settings → Hotkey → Mode.

### Menu Bar Status

The menu bar icon shows the current status:

| Icon | Status |
|------|--------|
| 📊 Waveform (blue) | Ready |
| 🎤 Microphone (red) | Recording |
| ⏳ Spinner | Processing |
| ⚠️ Warning | Error |

Click the icon to open the menu with status details and quick access to settings.

## Models

WhisperType uses OpenAI's Whisper models. Choose based on your needs:

### English-Only Models (Recommended for English speakers)

| Model | Size | Speed | Accuracy | Best For |
|-------|------|-------|----------|----------|
| **Tiny (EN)** | 75 MB | ⚡⚡⚡⚡⚡ | ⭐⭐ | Testing, older hardware |
| **Base (EN)** | 142 MB | ⚡⚡⚡⚡ | ⭐⭐⭐ | **Everyday use** ✓ |
| **Small (EN)** | 466 MB | ⚡⚡⚡ | ⭐⭐⭐⭐ | Good accuracy |
| **Medium (EN)** | 1.5 GB | ⚡⚡ | ⭐⭐⭐⭐ | Professional use |

### Multilingual Models

| Model | Size | Speed | Accuracy | Languages |
|-------|------|-------|----------|-----------|
| **Tiny** | 75 MB | ⚡⚡⚡⚡⚡ | ⭐⭐ | 74+ languages |
| **Base** | 142 MB | ⚡⚡⚡⚡ | ⭐⭐⭐ | 74+ languages |
| **Small** | 466 MB | ⚡⚡⚡ | ⭐⭐⭐⭐ | 74+ languages |
| **Medium** | 1.5 GB | ⚡⚡ | ⭐⭐⭐⭐ | 74+ languages |
| **Large V3** | 3.1 GB | ⚡ | ⭐⭐⭐⭐⭐ | Maximum accuracy |

### Recommendations

- **Most users:** Start with **Base (EN)** — good balance of speed and accuracy
- **Noisy environment or accents:** Try **Small (EN)** or **Medium (EN)**
- **Non-English languages:** Use multilingual models
- **Maximum accuracy:** **Large V3** (requires more RAM and time)

Models are downloaded from Hugging Face on first use and stored locally.

## Settings

Access settings by clicking the menu bar icon → **Settings**.

### General Tab

- **Launch at Login** — Start WhisperType when you log in
- **Microphone** — Select which microphone to use
- **Audio Feedback** — Play sounds when recording starts/stops

### Models Tab

- View all available models
- Download, delete, or switch active model
- See storage usage
- Open models folder

### Hotkey Tab

- **Current Hotkey** — Shows your current keyboard shortcut
- **Record New Hotkey** — Click and press a new key combination
- **Reset to Default** — Restore to `⌥Space`
- **Recording Mode** — Choose Hold-to-Record or Toggle

## Troubleshooting

### "No model loaded" Error

1. Open Settings → Models
2. Download a model if none are downloaded
3. Click "Set Active" on your preferred model
4. Wait for the model to load (check menu bar status)

### "Microphone permission required" Error

1. Open **System Settings** → **Privacy & Security** → **Microphone**
2. Find WhisperType and enable it
3. Restart WhisperType if needed

### "Accessibility permission required" Error

1. Open **System Settings** → **Privacy & Security** → **Accessibility**
2. Click the lock icon and authenticate
3. Find WhisperType and enable it
4. **Restart WhisperType** (required after granting accessibility)

### Hotkey Not Working

- Ensure WhisperType is running (check menu bar)
- Check if another app is using the same hotkey
- Try changing the hotkey in Settings → Hotkey
- Some apps may block global hotkeys — try a different hotkey combination

### Poor Transcription Quality

- **Speak clearly** and at a normal pace
- **Reduce background noise** or use a better microphone
- Try a **larger model** (Small or Medium)
- For non-English, use **multilingual models**

### App Won't Start

1. Check if WhisperType is already running in the menu bar
2. Try force-quitting and restarting
3. Reset settings: Delete `~/Library/Application Support/WhisperType/` and restart

### High Memory Usage

- Larger models use more RAM
- Switch to a smaller model if memory is limited
- Close WhisperType when not needed to free memory

## Data & Privacy

WhisperType is designed with privacy as a core principle:

- ✅ **All processing on-device** — Your voice is never sent to the internet
- ✅ **No internet required** — Works offline (except for initial model download)
- ✅ **No telemetry** — We don't collect any usage data
- ✅ **No accounts** — No sign-up required
- ✅ **Open source** — Verify the code yourself

**Data Storage:**
- Models: `~/Library/Application Support/WhisperType/Models/`
- Settings: macOS UserDefaults

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `⌥Space` | Start/stop recording (default, customizable) |
| `⌘,` | Open Settings |
| `⌘Q` | Quit WhisperType |

## FAQ

### Is WhisperType really free?

Yes! WhisperType is open source under the MIT license. No subscriptions, no in-app purchases.

### Does it work offline?

Yes, after you download a model, WhisperType works completely offline.

### What languages are supported?

English-only models support English. Multilingual models support 74+ languages including Spanish, French, German, Chinese, Japanese, Korean, Arabic, and many more.

### How accurate is it?

Accuracy depends on the model size, audio quality, and speaking clarity. The Base model is suitable for most use cases. For better accuracy, try the Small or Medium models.

### Does it work in all apps?

WhisperType works in most text fields, including browsers, text editors, IDEs, terminals, and messaging apps. Some apps with custom text input may not work perfectly.

### Can I use it for long dictation?

Yes, but keep recordings reasonable (a few minutes). Very long recordings may use significant memory and processing time.

## Credits

- Built with [whisper.cpp](https://github.com/ggerganov/whisper.cpp) by Georgi Gerganov
- Uses OpenAI's [Whisper](https://github.com/openai/whisper) models
- Hotkey handling via [HotKey](https://github.com/soffes/HotKey) by Sam Soffes

## License

MIT License — See [LICENSE](LICENSE) for details.

## Contributing

Contributions are welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

---

<p align="center">
  Made with ❤️ for privacy
</p>
