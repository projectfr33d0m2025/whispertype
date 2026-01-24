# Speaker Diarization Spike (Python/PyAnnote)

Validates PyAnnote-based speaker diarization for WhisperType meeting transcription.

## Two Approaches

1. **spike_diarization.py** - PyAnnote (neural, requires HF token, high accuracy)
2. **spike_diarization_simple.py** - MFCC clustering (no auth, baseline only)

## Prerequisites

1. Python 3.10+
2. For PyAnnote: HuggingFace account with token
3. Accept model terms at: https://huggingface.co/pyannote/speaker-diarization-3.1

## Setup

```bash
cd Spike/SpeakerDiarizationPython

# Create venv
python3 -m venv venv
source venv/bin/activate

# Install deps
pip install -r requirements.txt

# Set HF token
export HF_TOKEN="your_token_here"
```

## Usage

### Run PyAnnote Diarization (requires HF token)

```bash
# Set token
export HF_TOKEN="your_token_here"

# Basic
python spike_diarization.py ../../TestAssets/Audio/two_speakers_120s.wav -o results.json

# With speaker hint
python spike_diarization.py audio.wav --num-speakers 2 -o results.json
```

### Run Simple Baseline (no auth required)

```bash
python spike_diarization_simple.py ../../TestAssets/Audio/two_speakers_120s.wav -o results_simple.json
```

### Evaluate Results

```bash
python spike_evaluate.py results.json ../../TestAssets/Audio/two_speakers_labels.json
```

## Test Files

| File | Speakers | Duration |
|------|----------|----------|
| `two_speakers_120s.wav` | 2 | 1:46 |
| `four_speakers_300s.wav` | 4 | 3:28 |
| `single_speaker_60s.wav` | 1 | 1:29 |

## Output Format

```json
{
  "audio_file": "two_speakers_120s.wav",
  "duration_seconds": 106.5,
  "speakers": ["SPEAKER_00", "SPEAKER_01"],
  "segments": [
    {"speaker": "SPEAKER_00", "start": 0.119, "end": 7.139},
    ...
  ],
  "metadata": {
    "model": "pyannote/speaker-diarization-3.1",
    "diarization_time_seconds": 12.5,
    "realtime_factor": 0.12
  }
}
```

## Known Issues

- First run downloads ~500MB model
- MPS (Apple Silicon) may have compatibility issues with some torch versions
- Models require HuggingFace authentication
