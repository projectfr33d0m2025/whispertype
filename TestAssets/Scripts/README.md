# Test Audio Generation with ElevenLabs

This directory contains scripts and tools for generating test audio files using ElevenLabs.

## Quick Start

### 1. Generate Audio Files

For each script file (`*_script.txt`), generate audio using ElevenLabs:

```bash
# Option A: Use ElevenLabs Web UI
# 1. Go to https://elevenlabs.io
# 2. Copy text from script file
# 3. Select appropriate voice
# 4. Generate and download

# Option B: Use ElevenLabs API (see generate_audio.py)
python3 generate_audio.py --script single_speaker_script.txt --output ../Audio/single_speaker_60s.wav
```

### 2. Generate Ground Truth Labels

After generating audio, create ground truth JSON:

```bash
python3 generate_ground_truth.py two_speakers_script.txt ../Audio/two_speakers_120s_labels.json
```

### 3. Generate All Mock Data

```bash
python3 generate_mock_data.py
```

## File Overview

| Script File | Output Audio | Output Labels | Voices Needed |
|-------------|--------------|---------------|---------------|
| `single_speaker_script.txt` | `single_speaker_60s.wav` | N/A | 1 |
| `two_speakers_script.txt` | `two_speakers_120s.wav` | `two_speakers_120s_labels.json` | 2 |
| `four_speakers_script.txt` | `four_speakers_300s.wav` | `four_speakers_300s_labels.json` | 4 |
| `known_text_script.txt` | `known_text_30s.wav` | `known_text_30s_expected.txt` | 1 |

## Recommended ElevenLabs Voices

Use distinct voices for multi-speaker files:

| Speaker | Recommended Voice | Voice ID | Gender |
|---------|-------------------|----------|--------|
| Speaker A | Adam | pNInz6obpgDQGcFmaJgB | Male |
| Speaker B | Rachel | 21m00Tcm4TlvDq8ikWAM | Female |
| Speaker C | Clyde | 2EiwWnXFnvU5JabPnv8n | Male |
| Speaker D | Domi | AZnzlk1XvdvUeBnXmlld | Female |

## Audio Format Requirements

All generated audio should be:
- **Sample Rate:** 16000 Hz (16kHz)
- **Channels:** Mono
- **Bit Depth:** 16-bit
- **Format:** WAV

Use ffmpeg to convert if needed:
```bash
ffmpeg -i input.mp3 -ar 16000 -ac 1 -sample_fmt s16 output.wav
```
