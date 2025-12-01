# WhisperType Dependencies

This document lists the external dependencies required for WhisperType.

## Swift Package Manager Dependencies

When opening the project in Xcode, add the following Swift packages:

### 1. HotKey (Required)
- **Repository**: https://github.com/soffes/HotKey
- **Purpose**: Global hotkey registration and handling
- **Usage**: Allows the app to capture keyboard shortcuts system-wide

**To add in Xcode:**
1. File → Add Package Dependencies...
2. Enter URL: `https://github.com/soffes/HotKey`
3. Select "Up to Next Major Version" with minimum 0.2.0
4. Add to WhisperType target

### 2. KeyboardShortcuts (Optional)
- **Repository**: https://github.com/sindresorhus/KeyboardShortcuts
- **Purpose**: User-friendly keyboard shortcut recording UI
- **Usage**: Settings UI for customizing hotkeys

**To add in Xcode:**
1. File → Add Package Dependencies...
2. Enter URL: `https://github.com/sindresorhus/KeyboardShortcuts`
3. Select "Up to Next Major Version" with minimum 2.0.0
4. Add to WhisperType target

## Git Submodules

### whisper.cpp (Already added)
- **Repository**: https://github.com/ggerganov/whisper.cpp
- **Location**: `Libraries/whisper.cpp`
- **Purpose**: Core speech-to-text transcription engine
- **Status**: ✅ Added in Phase 0.2

To update the submodule:
```bash
git submodule update --remote Libraries/whisper.cpp
```

## System Frameworks (Already linked)

The following Apple frameworks are already configured in the Xcode project:

- **Accelerate.framework**: Optimized vector/matrix operations for whisper.cpp
- **AVFoundation.framework**: Audio recording and processing
- **ApplicationServices.framework**: Accessibility API for text injection
- **AppKit.framework**: macOS UI components

## Build Configuration

The project is configured to:
- Link against Accelerate for performance
- Include whisper.cpp headers from `Libraries/whisper.cpp/include`
- Use the bridging header at `WhisperType/Bridging/WhisperType-Bridging-Header.h`

## Notes

- **HotKey** is essential for Phase 6 (Global Hotkey)
- **KeyboardShortcuts** can be added later for enhanced settings UI
- All dependencies should work on macOS 13.0+ as specified in the deployment target
