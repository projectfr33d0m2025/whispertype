# WhisperType

A privacy-focused, local voice-to-text application for macOS using OpenAI's Whisper.

## Overview

WhisperType is a menu bar application that provides system-wide voice input for macOS. All transcription happens locally on your device using the whisper.cpp library - no cloud services, no API calls, complete privacy.

**Status:** 🚧 Phase 0 & 1 Complete - Core infrastructure ready for development

## Features (Planned)

- 🎤 **System-wide voice input** - Works in any application
- 🔒 **100% local processing** - No internet required, complete privacy
- ⚡ **Fast transcription** - Optimized with Apple's Accelerate framework
- 🌍 **Multi-language support** - Choose from English-only or multilingual models
- ⌨️ **Global hotkey** - Quick activation with Cmd+Shift+Space (customizable)
- 📦 **Multiple model sizes** - From tiny (75 MB) to large (3.1 GB)
- 🎯 **Menu bar app** - Unobtrusive, always accessible

## Current Status

### ✅ Phase 0: Project Setup (Complete)

- [x] Xcode project structure created
- [x] whisper.cpp added as git submodule
- [x] Bridging header configured for C/C++ interop
- [x] Permissions configured (Microphone & Accessibility)
- [x] Build settings configured (Accelerate framework, header paths)

### ✅ Phase 1: Core Infrastructure (Complete)

- [x] App entry point and lifecycle management
- [x] Constants and configuration system
- [x] Model definitions (9 Whisper variants)
- [x] Settings persistence with UserDefaults
- [x] Permission handling utilities
- [x] App coordinator architecture

## Project Structure

```
WhisperType/
├── WhisperType.xcodeproj/          # Xcode project
├── WhisperType/
│   ├── App/                        # App lifecycle & coordination
│   │   ├── WhisperTypeApp.swift    # SwiftUI app entry
│   │   ├── AppDelegate.swift       # NSApplicationDelegate
│   │   └── AppCoordinator.swift    # Component coordinator
│   │
│   ├── Models/                     # Data models
│   │   ├── AppSettings.swift       # Observable settings
│   │   ├── WhisperModel.swift      # Model definitions
│   │   └── TranscriptionResult.swift
│   │
│   ├── Managers/                   # (To be implemented)
│   │   ├── ModelManager.swift
│   │   ├── AudioRecorder.swift
│   │   ├── WhisperWrapper.swift
│   │   └── TextInjector.swift
│   │
│   ├── Views/                      # (To be implemented)
│   │   ├── MenuBar/
│   │   └── Settings/
│   │
│   ├── Utilities/
│   │   ├── Constants.swift         # App constants
│   │   └── Permissions.swift       # Permission utilities
│   │
│   ├── Bridging/
│   │   └── WhisperType-Bridging-Header.h
│   │
│   └── Resources/
│       └── Assets.xcassets/
│
├── Libraries/
│   └── whisper.cpp/                # Whisper C++ library (submodule)
│
├── DEPENDENCIES.md                  # Setup instructions for SPM packages
└── tasks-whispertype.txt           # Implementation task tracker
```

## Requirements

- **macOS 13.0+** (Ventura or later)
- **Xcode 15.0+**
- **8GB RAM minimum** (16GB recommended for larger models)
- **Microphone access**
- **Accessibility access** (for text injection)

## Setup Instructions

### 1. Clone the Repository

```bash
git clone --recursive https://github.com/projectfr33d0m2025/whispertype.git
cd whispertype
```

If you already cloned without `--recursive`:

```bash
git submodule update --init --recursive
```

### 2. Open in Xcode

```bash
open WhisperType.xcodeproj
```

### 3. Add Swift Package Dependencies

The project requires the following Swift packages. In Xcode:

1. Go to **File → Add Package Dependencies...**
2. Add these packages:
   - **HotKey**: `https://github.com/soffes/HotKey`
   - **KeyboardShortcuts** (optional): `https://github.com/sindresorhus/KeyboardShortcuts`

See [DEPENDENCIES.md](DEPENDENCIES.md) for detailed instructions.

### 4. Build and Run

1. Select the **WhisperType** scheme
2. Press **Cmd+R** to build and run
3. Grant microphone and accessibility permissions when prompted

## Available Whisper Models

| Model | Size | Speed | Accuracy | Languages | Recommended For |
|-------|------|-------|----------|-----------|-----------------|
| Tiny (EN) | 75 MB | ⚡⚡⚡⚡⚡ | ⭐⭐ | English | Testing, low-end hardware |
| Base (EN) | 142 MB | ⚡⚡⚡⚡ | ⭐⭐⭐ | English | Everyday use |
| Small (EN) | 466 MB | ⚡⚡⚡ | ⭐⭐⭐⭐ | English | Good accuracy |
| Medium (EN) | 1.5 GB | ⚡⚡ | ⭐⭐⭐⭐ | English | Professional use |
| Large V3 | 3.1 GB | ⚡ | ⭐⭐⭐⭐⭐ | 74+ languages | Maximum accuracy |

*Models are downloaded from Hugging Face on first use.*

## Development Roadmap

- [x] **Phase 0**: Project Setup
- [x] **Phase 1**: Core Infrastructure
- [ ] **Phase 2**: Model Management (download, switch, delete)
- [ ] **Phase 3**: Audio Recording
- [ ] **Phase 4**: Whisper Integration
- [ ] **Phase 5**: Text Injection
- [ ] **Phase 6**: Global Hotkey
- [ ] **Phase 7**: Menu Bar UI
- [ ] **Phase 8**: Settings Window
- [ ] **Phase 9**: Full Integration & Testing
- [ ] **Phase 10**: Polish & Distribution

See [tasks-whispertype.txt](tasks-whispertype.txt) for detailed task breakdown.

## Architecture

WhisperType uses a coordinator pattern to manage components:

```
┌─────────────────────────────────────┐
│        WhisperTypeApp (@main)       │
├─────────────────────────────────────┤
│          AppDelegate                │
│    - Permission checks              │
│    - Lifecycle management           │
└──────────┬──────────────────────────┘
           │
           ▼
┌──────────────────────────────────────┐
│       AppCoordinator                 │
│  - Manages all components            │
│  - Orchestrates workflow             │
└──────────┬───────────────────────────┘
           │
     ┌─────┼─────────┬─────────┬───────┐
     ▼     ▼         ▼         ▼       ▼
  Model  Audio   Whisper   Text    Hotkey
 Manager Recorder Wrapper Injector Manager
```

## Configuration

All settings are stored in `~/Library/Application Support/WhisperType/`:

- **Models/**: Downloaded Whisper models
- **vocabulary.json**: Custom vocabulary words
- **history.json**: Transcription history
- **AudioHistory/**: Recorded audio files (optional)

## Contributing

This project is in active development. Contributions, issues, and feature requests are welcome!

## License

MIT License - See LICENSE file for details

## Privacy

WhisperType is designed with privacy as a core principle:

- ✅ All processing happens on-device
- ✅ No internet connection required (except for model downloads)
- ✅ No telemetry or analytics
- ✅ No cloud services or APIs
- ✅ Your voice data never leaves your computer

## Credits

- Built with [whisper.cpp](https://github.com/ggerganov/whisper.cpp) by Georgi Gerganov
- Uses OpenAI's [Whisper](https://github.com/openai/whisper) models
- Inspired by tools like Superwhisper

---

**Note**: This project is currently in Phase 1 of development. Core functionality is being built progressively. Star and watch this repository for updates!
