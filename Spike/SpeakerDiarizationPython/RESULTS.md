# Speaker Diarization Spike Results

## Summary

| Metric | Target | PyAnnote | Simple Baseline |
|--------|--------|----------|-----------------|
| 2-speaker accuracy | >85% | **87.5%** ✓ | 56.5% ❌ |
| 4-speaker accuracy | >75% | **87.3%** ✓ (with hint) | 29.5% ❌ |
| 4-speaker (auto) | >75% | 65.6% ❌ | - |
| Processing speed | <2x realtime | **0.07x** ✓ | 0.01-0.49x |

**Status:** PyAnnote meets all targets when speaker count is provided as hint.

## PyAnnote Results

### two_speakers_120s.wav
- **Accuracy:** 87.5% ✓
- **DER:** 12.50%
- **Processing time:** 7.22s (0.07x realtime)
- **Speaker count:** 2 (correct, auto-detected)
- **Segments:** 21 (ground truth: 11)

### four_speakers_300s.wav (with --num-speakers 4)
- **Accuracy:** 87.3% ✓
- **DER:** 12.93%
- **Processing time:** 13.14s (0.06x realtime)
- **Speaker count:** 4 (correct, with hint)
- **Segments:** 67 (ground truth: 20)

### four_speakers_300s.wav (auto-detect)
- **Accuracy:** 65.6% ❌
- **DER:** 34.62%
- **Speaker count:** Detected 3 (should be 4)
- **Note:** Merged SPEAKER_C and SPEAKER_D

### single_speaker_60s.wav
- **Accuracy:** 99.2% ✓
- **DER:** 49.50% (high false alarm rate from pauses)
- **Processing time:** 6.05s (0.07x realtime)
- **Speaker count:** 1 (correct, auto-detected)
- **Segments:** 3 (ground truth: 1)

## Installation Complexity

### Dependencies
- torch 2.8.0 (ARM64 native)
- torchaudio 2.8.0
- pyannote.audio 4.0.3
- ~80+ transitive dependencies
- Total disk: ~2.5GB

### Model Download
- First run downloads ~500MB models
- Cached in ~/.cache/huggingface/

### HuggingFace Authentication
Required. Must accept terms for:
1. pyannote/speaker-diarization-3.1
2. pyannote/segmentation-3.0
3. pyannote/speaker-diarization-community-1

### Apple Silicon Compatibility
- All packages installed successfully
- MPS (Metal) acceleration works
- torchcodec has FFmpeg issues (workaround: preload audio as waveform)
- Processing speed: 0.07x realtime on M-series

## Observations

1. **PyAnnote meets accuracy targets** when speaker count is known
2. **Auto-detection struggles** with 4+ speakers (merges similar voices)
3. **Very fast** - 0.07x realtime (14x faster than target)
4. **Over-segments** - more segments than ground truth (likely due to pauses)
5. **High missed speech** - some speech frames not detected as any speaker

## Integration Recommendations

### For WhisperType Meeting Recording

1. **Provide speaker count hint when known** - significantly improves accuracy
2. **Use preloaded waveform** - avoid torchcodec/FFmpeg dependency
3. **Post-process segments** - merge short gaps, smooth boundaries

### Integration Options

| Option | Pros | Cons |
|--------|------|------|
| Python subprocess | Simple, full PyAnnote | Process overhead, HF auth |
| Local REST API | Clean interface | More infrastructure |
| Pre-export to Core ML | Native Swift | Complex, may lose accuracy |

### Recommended: Python subprocess
```swift
let result = try Process.run("python", ["diarize.py", audioPath])
let segments = try JSONDecoder().decode(segments, from: result.stdout)
```

## Conclusion

**PyAnnote is viable for WhisperType speaker diarization.**

- Meets 2-speaker target (87.5% > 85%)
- Meets 4-speaker target with hint (87.3% > 75%)
- Processing is 14x faster than required
- Integration via Python subprocess is straightforward
