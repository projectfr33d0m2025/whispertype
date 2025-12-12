# Release Notes

---

## WhisperType v1.2.0

### Major New Features

🪄 **Intelligent Processing Modes**
- **Five Processing Modes**: Raw, Clean, Formatted, Polished, and Professional
- **Filler Word Removal**: Automatically removes "um", "uh", "like", "you know" and other hesitations
- **Smart Formatting**: Automatic capitalization and punctuation improvements
- **AI Enhancement**: Grammar and clarity improvements with Polished/Professional modes

🤖 **Local-First AI Integration**
- **Ollama Support**: Connect to local Ollama for 100% private AI text enhancement
- **Cloud Fallback**: Optional OpenAI/OpenRouter integration for faster processing
- **Automatic Fallback**: Gracefully degrades to basic processing when AI is unavailable
- **Privacy Preserved**: Your audio never leaves your device; cloud only receives text (if enabled)

📚 **Custom Vocabulary System**
- **200 Custom Terms**: Add names, technical jargon, and specialized terminology
- **Fuzzy Matching**: Automatically corrects common misrecognitions
- **Whisper Hints**: Improves transcription accuracy with vocabulary priming
- **Import/Export**: CSV support for vocabulary backup and sharing

🎯 **App-Aware Context**
- **18 Default Presets**: Pre-configured modes for common apps (VS Code, Slack, Mail, etc.)
- **Custom Rules**: Override modes for any application
- **Smart Detection**: Automatically switches modes based on frontmost app
- **Developer Friendly**: Raw/Clean modes for terminal and code editors

### Improvements

- Redesigned Settings with dedicated tabs for Processing, Vocabulary, and App Rules
- Processing mode and AI status displayed in menu bar
- Toast notifications for AI fallback and rate limiting
- Improved recording overlay showing current mode and app context
- Better error handling and user feedback

### Technical Changes

- New PostProcessor architecture with modular processing chain
- LLMEngine with provider abstraction for easy extension
- VocabularyManager with efficient fuzzy matching
- AppAwareManager with context detection
- Performance optimizations for text processing

### System Requirements

- macOS 13.0 (Ventura) or later
- Apple Silicon (M1/M2/M3) or Intel Mac
- Microphone
- ~75MB to 3.1GB storage for Whisper models
- For AI features: Ollama installed locally, or OpenAI/OpenRouter API key

### Installation

1. Download `WhisperType-1.2.0.dmg`
2. Open the DMG and drag WhisperType to Applications
3. Right-click WhisperType and select "Open" (required for unsigned apps)
4. Grant Microphone and Accessibility permissions when prompted

### Upgrading from v1.1

Your existing settings and model downloads will be preserved. New features will use default settings:
- Processing mode defaults to "Formatted"
- App-awareness enabled by default
- AI enhancement disabled until you configure Ollama or cloud provider

---

## WhisperType v1.1.0

### New Features

🎵 **Recording Waveform Visualization**
- Beautiful animated waveform indicator appears while recording
- Real-time visual feedback showing your audio input levels
- Compact pill-shaped overlay positioned near the menu bar
- Smooth animations that respond to your voice

🌍 **Language Hint Configuration**
- Specify your input language in Settings → General for improved accuracy
- Supports 15+ languages including English, Chinese, Spanish, French, German, Japanese, Korean, and more
- Reduces transcription errors when Whisper knows which language to expect
- "Auto-detect" option available for mixed-language use

### Improvements

- Better visual feedback during recording
- Reduced hallucinations when input language is specified
- Slightly faster transcription when language is set (skips detection step)

### System Requirements

- macOS 13.0 (Ventura) or later
- Apple Silicon (M1/M2/M3) or Intel Mac
- Microphone
- ~75MB to 3.1GB storage for Whisper models

### Installation

1. Download `WhisperType-1.1.0.dmg`
2. Open the DMG and drag WhisperType to Applications
3. Right-click WhisperType and select "Open" (required for unsigned apps)
4. Grant Microphone and Accessibility permissions when prompted

---

## WhisperType v1.0.0

### What's New

This is the initial release of WhisperType, a free, privacy-focused voice transcription app for macOS.

### Features

- **System-Wide Voice Input**: Press Option+Space (customizable) to start recording from any text field
- **Local Processing**: All transcription happens on-device using whisper.cpp - no cloud services, no data leaves your Mac
- **Multiple Whisper Models**: Choose from various model sizes (tiny to large) based on your accuracy/speed needs
- **Menu Bar App**: Minimal, unobtrusive interface that stays out of your way
- **Configurable Hotkey**: Set your preferred keyboard shortcut for recording

### System Requirements

- macOS 13.0 (Ventura) or later
- Apple Silicon (M1/M2/M3) or Intel Mac
- Microphone
- ~50MB to 3GB storage for Whisper models (depending on model size)

### Installation

1. Download `WhisperType-1.0.0.dmg`
2. Open the DMG and drag WhisperType to Applications
3. Right-click WhisperType and select "Open" (required for unsigned apps)
4. Grant Microphone permission when prompted
5. Grant Accessibility permission in System Settings > Privacy & Security

### First Use

1. Click the WhisperType icon in the menu bar
2. Go to Settings > Models
3. Download your preferred Whisper model (start with "tiny" for quick testing)
4. Press Option+Space to start recording, release to transcribe

### Known Limitations

- App is not code-signed (requires right-click → Open on first launch)
- Large models (medium, large) require significant RAM and may be slow on older machines
- No real-time streaming transcription (coming in future versions)

---

## Feedback & Issues

Please report issues on GitHub: https://github.com/projectfr33d0m2025/whispertype/issues

## License

MIT License - Free to use, modify, and distribute.
