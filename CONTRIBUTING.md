# Contributing to WhisperType

Thank you for your interest in contributing to WhisperType! This document provides guidelines for contributing to the project.

## Getting Started

### Prerequisites

- **macOS 13.0+** (Ventura or later)
- **Xcode 15.0+**
- **Git** with submodule support

### Setting Up the Development Environment

1. **Clone the repository with submodules:**

```bash
git clone --recursive https://github.com/projectfr33d0m2025/whispertype.git
cd whispertype
```

If you already cloned without `--recursive`:

```bash
git submodule update --init --recursive
```

2. **Open in Xcode:**

```bash
open WhisperType.xcodeproj
```

3. **Add Swift Package Dependencies:**

In Xcode:
- Go to **File → Add Package Dependencies...**
- Add `https://github.com/soffes/HotKey`
- Add `https://github.com/sindresorhus/KeyboardShortcuts` (optional)

See [DEPENDENCIES.md](DEPENDENCIES.md) for detailed instructions.

4. **Build and Run:**

- Select the **WhisperType** scheme
- Press `⌘R` to build and run
- Grant permissions when prompted

## Project Structure

```
WhisperType/
├── App/                    # App lifecycle & coordination
│   ├── WhisperTypeApp.swift
│   ├── AppDelegate.swift
│   └── AppCoordinator.swift
├── Models/                 # Data models
│   ├── AppSettings.swift
│   ├── WhisperModel.swift
│   └── TranscriptionResult.swift
├── Managers/               # Core functionality
│   ├── ModelManager.swift
│   ├── AudioRecorder.swift
│   ├── WhisperWrapper.swift
│   ├── HotkeyManager.swift
│   └── TextInjector.swift
├── Views/                  # SwiftUI views
│   ├── MenuBar/
│   ├── Settings/
│   └── Components/
├── Utilities/              # Helpers
│   ├── Constants.swift
│   └── Permissions.swift
├── Bridging/               # C/C++ interop
│   └── WhisperType-Bridging-Header.h
└── Resources/              # Assets
    └── Assets.xcassets/
```

## Code Style Guidelines

### Swift Conventions

- Use Swift's official [API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- Prefer `@Observable` (Swift 5.9+) over `ObservableObject` where possible
- Use `async/await` instead of completion handlers
- Use Swift concurrency (actors) for thread safety

### Naming Conventions

- **Types**: `PascalCase` (e.g., `ModelManager`, `WhisperWrapper`)
- **Properties/Methods**: `camelCase` (e.g., `activeModel`, `startRecording()`)
- **Constants**: `camelCase` in `Constants.swift`

### File Organization

- One primary type per file (exceptions for small related types)
- Use `// MARK: -` comments to organize sections
- Keep files under 500 lines when possible

### Documentation

- Add doc comments (`///`) for public APIs
- Include parameter descriptions for complex methods
- Document error cases and edge conditions

## Making Changes

### Branching Strategy

- `main` — Stable release branch
- `develop` — Integration branch for features
- `feature/*` — Feature branches (e.g., `feature/coreml-support`)
- `fix/*` — Bug fix branches (e.g., `fix/memory-leak`)

### Pull Request Process

1. **Create a feature branch** from `develop`:
   ```bash
   git checkout develop
   git pull origin develop
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes** with clear, atomic commits

3. **Test thoroughly:**
   - Build succeeds without warnings
   - Feature works as expected
   - Existing functionality not broken

4. **Submit a Pull Request:**
   - Target the `develop` branch
   - Provide a clear description
   - Reference any related issues
   - Include screenshots for UI changes

### Commit Messages

Use clear, descriptive commit messages:

```
feat: Add CoreML backend support

- Implement CoreML model loading
- Add model conversion utility
- Update settings for backend selection

Closes #42
```

Prefixes:
- `feat:` — New feature
- `fix:` — Bug fix
- `docs:` — Documentation
- `refactor:` — Code refactoring
- `test:` — Tests
- `chore:` — Maintenance

## Testing

### Manual Testing Checklist

Before submitting a PR, verify:

- [ ] App launches without crash
- [ ] Menu bar icon appears correctly
- [ ] Hotkey triggers recording
- [ ] Transcription works and text is inserted
- [ ] Settings can be changed and persist
- [ ] Model download/switch/delete works
- [ ] Dark mode appearance is correct
- [ ] VoiceOver can navigate key UI elements

### Testing Different Configurations

- Test with different model sizes
- Test in various applications (browser, text editor, terminal)
- Test with different audio input devices

## Reporting Issues

### Bug Reports

Include:
1. **macOS version** and **Mac model** (Intel/Apple Silicon)
2. **WhisperType version**
3. **Steps to reproduce**
4. **Expected vs actual behavior**
5. **Console logs** if available (from Console.app)

### Feature Requests

Describe:
1. **Use case** — What problem does it solve?
2. **Proposed solution** — How should it work?
3. **Alternatives considered** — Other approaches you thought of

## Architecture Notes

### Key Components

- **AppCoordinator** — Central orchestrator for the recording → transcription → injection flow
- **WhisperWrapper** — Swift bridge to whisper.cpp C library
- **TextInjector** — CGEvent-based text insertion with clipboard fallback
- **HotkeyManager** — Global hotkey registration and handling

### Data Flow

```
Hotkey Press → AudioRecorder.start()
            → Record audio samples
Hotkey Release → AudioRecorder.stop()
             → WhisperWrapper.transcribe()
             → TextInjector.inject()
             → Text appears at cursor
```

## Getting Help

- **Questions?** Open a Discussion on GitHub
- **Found a bug?** Open an Issue
- **Want to contribute?** Check existing Issues for good first tasks

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

---

Thank you for contributing to WhisperType! 🎉
